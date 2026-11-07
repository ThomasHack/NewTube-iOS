import OSLog
import SmartTubeIOSCore
import SwiftUI

private let rootLog = Logger(subsystem: "com.void.smarttube.app", category: "RootView")

// MARK: - RootView
//
// Entry point that decides whether to show the main tab UI or the
// sign-in screen.  On macOS it uses a sidebar-based navigation.

public struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(SettingsStore.self) private var store
    @Environment(BrowseViewModel.self) private var browseVM
    @Environment(\.innerTubeAPI) private var api
    /// Shared download service — observed here so the completion alert is shown
    /// at a stable level unaffected by context menu dismiss animations on cards.
    @State private var cardDownloadAlertItem: DownloadAlertItem?
    @State private var isLandscapeLayout = false

    public init() {}

    public var body: some View {
        @Bindable var browseVM = browseVM
        // Explicitly read cardDownloadService.state in body so SwiftUI's
        // @Observable tracking engine registers this view as a subscriber.
        // Without this, onChange(of: cardDownloadService.state) may not fire
        // when the state changes on an environment-injected @Observable object.
        Group {
            MainTVTabView()
        }
        .environment(\.isLandscapeLayout, isLandscapeLayout)
        .onGeometryChange(for: Bool.self) {
            $0.size.width > $0.size.height
        } action: {
            isLandscapeLayout = $0
        }
        .tint(store.settings.accentColor.color)
        .preferredColorScheme(store.settings.themeName.colorScheme)
        .sheet(isPresented: .constant(!auth.isSignedIn && requiresAuth)) {
            // Sign-in prompt is shown as a dismissible sheet so users
            // can still browse without being signed in.
            SignInView()
        }
    }

    private var requiresAuth: Bool { false }  // guest browsing is allowed
}

// MARK: - AppSection

enum AppSection: String, CaseIterable, Identifiable {
    // Apple TV has no chip bar on this tab: it shows recommendations only, and subscriptions
    // get a tab of their own.
    case home = "Recommended"
    case subscriptions = "Subscriptions"
    case search = "Search"
    case library = "Library"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return AppSymbol.home
        case .subscriptions: return AppSymbol.subscriptions
        case .search: return AppSymbol.search
        case .library: return AppSymbol.library
        case .settings: return AppSymbol.settings
        }
    }

    @MainActor @ViewBuilder
    func destination(api: InnerTubeAPI) -> some View {
        switch self {
        case .home: HomeView(api: api, section: BrowseSection(type: .recommended))
        case .subscriptions: HomeView(api: api, section: BrowseSection(type: .subscriptions))
        case .search: SearchView()
        case .library: LibraryView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - MainTabView  (iOS / iPadOS)

// Propagates the bottom safe-area inset (tab bar + home indicator) from inside a
// NavigationStack tab to the enclosing MainTabView so the mini player overlay can
// be positioned exactly at the top of the tab bar without hard-coding its height.
private struct TabBarBottomInsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MainTabView: View {
    @State private var searchVM = SearchViewModel()
    @State private var selectedTab: AppSection = .home
    @State private var tabBarBottomInset: CGFloat = 0
    @Environment(\.innerTubeAPI) private var api
    @Environment(SettingsStore.self) private var store

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppSection.allCases) { section in
                NavigationStack { section.destination(api: api) }
                    // Capture the bottom safe-area inset as seen from inside the tab
                    // (UITabBarController sets this to tab-bar height + home-indicator).
                    // The value is propagated up to tabBarBottomInset via PreferenceKey
                    // so the mini-player overlay can be positioned above the tab bar.
                    .background {
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: TabBarBottomInsetKey.self,
                                    value: geo.safeAreaInsets.bottom
                                )
                        }
                    }
                    .tabItem { Label(section.rawValue, systemImage: section.icon) }
                    .tag(section)
                    .accessibilityIdentifier("tab.\(section.rawValue.lowercased())")
            }
        }
        .onPreferenceChange(TabBarBottomInsetKey.self) { tabBarBottomInset = $0 }
        .environment(searchVM)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSearch)) { _ in
            selectedTab = .search
        }
        .onReceive(NotificationCenter.default.publisher(for: .activeChannelDidChange)) { _ in
            selectedTab = .home
        }
    }
}

// MARK: - MainTVTabView  (tvOS)
// Top-bar TabView is the Apple-recommended navigation pattern for Apple TV.
// Each tab contains a NavigationStack so drill-down is available within each section.

struct MainTVTabView: View {
    @State private var searchVM = SearchViewModel()
    @State private var selectedTab: AppSection = .home
    @Environment(\.innerTubeAPI) private var api
    /// Replaces each tab's content; previews use this to supply sample data.
    private let tabContent: ((AppSection) -> AnyView)?

    init(tabContent: ((AppSection) -> AnyView)? = nil) {
        self.tabContent = tabContent
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppSection.allCases) { section in
                Tab(
                    section.rawValue,
                    systemImage: section.icon,
                    value: section,
                    role: section == .search ? .search : nil
                ) {
                    NavigationStack {
                        if let tabContent {
                            tabContent(section)
                        } else {
                            section.destination(api: api)
                        }
                    }
                }
            }
        }
        .environment(searchVM)
        .onReceive(NotificationCenter.default.publisher(for: .activeChannelDidChange)) { _ in
            selectedTab = .home
        }
    }
}

// MARK: - MainSidebarView  (macOS)

struct MainSidebarView: View {
    @Environment(AuthService.self) private var auth
    @Environment(BrowseViewModel.self) private var browseVM
    @Environment(SettingsStore.self) private var store
    @Environment(\.innerTubeAPI) private var api
    @State private var searchVM = SearchViewModel()

    @State private var selectedSection: AppSection? = .home
    /// Set when the IFrame player hits a fatal embed error on the current video so we
    /// drop through to the standard PlayerView for that video only. Cleared when the
    /// video changes.
    @State private var tosPlayerFallbackVideoId: String? = nil

    var body: some View {
        @Bindable var browseVM = browseVM
        ZStack {
            NavigationSplitView {
                List(AppSection.allCases, selection: $selectedSection) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
                .navigationTitle("SmartTube")
                if auth.isSignedIn {
                    Divider()
                    HStack {
                        AsyncImage(url: auth.accountAvatarURL) { img in
                            img.resizable()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        Text(auth.accountName ?? "Account")
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            } detail: {
                NavigationStack { (selectedSection ?? .home).destination(api: api) }
            }
            .environment(searchVM)
            .onReceive(NotificationCenter.default.publisher(for: .activeChannelDidChange)) { _ in
                selectedSection = .home
            }

            // Full-window player overlay — avoids macOS sheet coordinate issues that
            // prevent XCUITest click events from reaching controls inside a popover window.
            if let video = browseVM.deepLinkedVideo {
                PlayerView(video: video, api: api)
                    .environment(store)
                    .environment(auth)
                    .environment(browseVM)
                    .ignoresSafeArea()
            }
        }
        // When a different video is opened, clear the per-video fallback guard so
        // the next video gets a fresh attempt through the TOS player.
        .onChange(of: browseVM.deepLinkedVideo?.id) { _, newId in
            if newId != tosPlayerFallbackVideoId {
                tosPlayerFallbackVideoId = nil
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Tab bar") {
    // MainTVTabView injects its own SearchViewModel, so sample data has to go inside it.
    let searchVM = SearchViewModel.preview()
    MainTVTabView { section in
        switch section {
        case .home: AnyView(HomeView.preview(section: BrowseSection(type: .recommended)))
        case .subscriptions: AnyView(HomeView.preview(section: BrowseSection(type: .subscriptions)))
        case .search: AnyView(SearchView().environment(searchVM))
        case .library: AnyView(LibraryView())
        case .settings: AnyView(SettingsView())
        }
    }
    .previewEnvironment()
}
#endif
