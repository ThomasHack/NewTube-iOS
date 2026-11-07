import OSLog
import SmartTubeCore
import SwiftUI

// MARK: - RootView
//
// Entry point that decides whether to show the main tab UI or the
// sign-in screen.

struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(SettingsStore.self) private var store
    @Environment(BrowseViewModel.self) private var browseVM
    @Environment(\.innerTubeAPI) private var api

    init() {}

    var body: some View {
        @Bindable var browseVM = browseVM
        MainTVTabView()
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
