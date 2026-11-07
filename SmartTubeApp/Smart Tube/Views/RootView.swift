import OSLog
import SmartTubeCore
import SwiftUI

// MARK: - RootView

struct RootView: View {
    @Environment(SettingsStore.self) private var store

    init() {}

    var body: some View {
        MainTVTabView()
            .tint(store.settings.accentColor.color)
            .preferredColorScheme(store.settings.themeName.colorScheme)
    }
}

// MARK: - AppSection

/// The fixed sidebar entries, in display order.
enum AppSection: String, CaseIterable, Identifiable {
    case search
    case home
    case subscriptions
    case library
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: String(localized: "Search")
        case .home: String(localized: "Home")
        case .subscriptions: String(localized: "Subscriptions")
        case .library: String(localized: "Library")
        case .settings: String(localized: "Settings")
        }
    }

    var icon: String {
        switch self {
        case .search: AppSymbol.search
        case .home: AppSymbol.home
        case .subscriptions: AppSymbol.subscriptions
        case .library: AppSymbol.library
        case .settings: AppSymbol.settings
        }
    }

    @MainActor @ViewBuilder
    func destination(feeds: AppFeeds) -> some View {
        switch self {
        case .search: SearchView()
        // Apple TV has no chip bar on Home: it shows recommendations only, and subscriptions get a
        // tab of their own.
        case .home: HomeView(sectionVM: feeds.home, section: feeds.home.currentSection)
        case .subscriptions: HomeView(sectionVM: feeds.subscriptions, section: feeds.subscriptions.currentSection)
        case .library: LibraryView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - MainTVTabView

/// The sidebar and everything presented above it. Each tab has its own stack, and the player covers
/// all of them, so it isn't tab content and the sidebar can't appear over it.
struct MainTVTabView: View {
    @State private var searchVM = SearchViewModel()
    @State private var navigator = AppNavigator()
    @State private var showAccount = false
    @Environment(AuthService.self) private var auth
    @Environment(SidebarChannelsViewModel.self) private var sidebarChannels
    @Environment(AppFeeds.self) private var feeds
    @Environment(\.innerTubeAPI) private var api
    /// Replaces each tab's content; previews use this to supply sample data.
    private let tabContent: ((AppSection) -> AnyView)?

    init(tabContent: ((AppSection) -> AnyView)? = nil) {
        self.tabContent = tabContent
    }

    var body: some View {
        TabView(selection: $navigator.selectedTab) {
            ForEach(AppSection.allCases) { section in
                Tab(
                    section.title,
                    systemImage: section.icon,
                    value: AppTab.section(section),
                    role: section == .search ? .search : nil
                ) {
                    AppTabStack(tab: .section(section)) {
                        if let tabContent {
                            tabContent(section)
                        } else {
                            section.destination(feeds: feeds)
                        }
                    }
                }
            }
            if !sidebarChannels.channels.isEmpty {
                TabSection("Channels") {
                    ForEach(sidebarChannels.channels) { channel in
                        Tab(value: AppTab.channel(id: channel.id)) {
                            AppTabStack(tab: .channel(id: channel.id)) {
                                ChannelView(channelId: channel.id, viewModel: feeds.channel(id: channel.id))
                            }
                        } label: {
                            Label {
                                Text(channel.title)
                            } icon: {
                                if let avatar = sidebarChannels.avatars[channel.id] {
                                    Image(uiImage: avatar)
                                } else {
                                    Image(systemName: AppSymbol.channel)
                                }
                            }
                        }
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSidebarHeader {
            SidebarAccountButton { showAccount = true }
        }
        .sheet(isPresented: $showAccount) {
            if auth.isSignedIn {
                AccountSheet()
            } else {
                SignInView()
            }
        }
        .fullScreenCover(item: $navigator.playingVideo) { video in
            PlayerView(video: video, api: api)
        }
        .environment(searchVM)
        .environment(navigator)
        .task(id: SidebarChannelsKey(authToken: auth.accessToken, pageId: auth.activePageId)) {
            await sidebarChannels.load(authToken: auth.accessToken)
        }
        .onChange(of: sidebarChannels.channels) { _, channels in
            // The selected channel can disappear when it's unfollowed or the account changes.
            if case .channel(let id) = navigator.selectedTab, !channels.contains(where: { $0.id == id }) {
                navigator.selectedTab = .section(.home)
            }
        }
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if !isSignedIn { resetNavigation() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activeChannelDidChange)) { _ in
            resetNavigation()
        }
    }

    private func resetNavigation() {
        navigator.reset()
        feeds.reset()
    }
}

private struct SidebarChannelsKey: Hashable {
    let authToken: String?
    let pageId: String?
}

// MARK: - AppTabStack

/// One tab's `NavigationStack`, bound to its path in `AppNavigator`.
private struct AppTabStack<Content: View>: View {
    let tab: AppTab
    /// A closure, so a tab's page is only created once the tab is on screen. `TabView` evaluates every
    /// tab whenever the selection changes, and there can be hundreds of channels.
    @ViewBuilder let content: () -> Content
    @Environment(AppNavigator.self) private var navigator
    @Environment(AppFeeds.self) private var feeds

    var body: some View {
        NavigationStack(
            path: Binding(
                get: { navigator.path(for: tab) },
                set: { navigator.setPath($0, for: tab) }
            )
        ) {
            content()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .channel(let id):
                        ChannelView(channelId: id, viewModel: feeds.channel(id: id))
                    case .playlist(let id, let title):
                        PlaylistView(playlistId: id, playlistTitle: title, viewModel: feeds.playlist(id: id))
                    }
                }
        }
    }
}

// MARK: - Previews

#if DEBUG
extension MainTVTabView {
    /// MainTVTabView injects its own SearchViewModel, so sample data has to go inside it.
    fileprivate static func preview() -> MainTVTabView {
        let searchVM = SearchViewModel.preview()
        return MainTVTabView { section in
            switch section {
            case .home:
                let home = BrowseSection(type: .recommended)
                return AnyView(
                    HomeView(sectionVM: .preview(section: home, state: .loaded(PreviewData.videos)), section: home))
            case .subscriptions:
                let subscriptions = BrowseSection(type: .subscriptions)
                return AnyView(
                    HomeView(
                        sectionVM: .preview(section: subscriptions, state: .loaded(PreviewData.subscriptions)),
                        section: subscriptions))
            case .search: return AnyView(SearchView().environment(searchVM))
            case .library: return AnyView(LibraryView())
            case .settings: return AnyView(SettingsView())
            }
        }
    }
}

#Preview("Sidebar – Signed in") {
    MainTVTabView.preview()
        .previewEnvironment()
}
#Preview("Sidebar – No channels") {
    MainTVTabView.preview()
        .previewEnvironment(sidebarChannels: .preview(channels: []))
}
#Preview("Sidebar – Signed out") {
    MainTVTabView.preview()
        .previewEnvironment(signedIn: false)
}
#endif
