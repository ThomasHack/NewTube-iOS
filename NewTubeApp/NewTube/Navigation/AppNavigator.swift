import NewTubeCore
import Observation

// MARK: - AppTab

/// A top-level sidebar entry.
enum AppTab: Hashable {
    case section(AppSection)
    case channel(id: String)
}

// MARK: - AppRoute

/// A page pushed onto a tab's `NavigationStack`. The player isn't a route: it covers the tabs.
enum AppRoute: Hashable {
    case channel(id: String)
    case playlist(id: String, title: String)
}

// MARK: - AppNavigator

/// Owns all app-level navigation: the selected tab, one stack per tab, and the player above them.
@MainActor
@Observable
final class AppNavigator {
    var selectedTab: AppTab = .section(.home)
    var playingVideo: Video?
    private var paths: [AppTab: [AppRoute]] = [:]

    func path(for tab: AppTab) -> [AppRoute] {
        paths[tab] ?? []
    }

    func setPath(_ path: [AppRoute], for tab: AppTab) {
        paths[tab] = path
    }

    func play(_ video: Video) {
        playingVideo = video
    }

    /// Closes the player if it's open, then shows the channel in the current tab.
    func openChannel(id: String) {
        guard !id.isEmpty else { return }
        playingVideo = nil
        // The channel's own sidebar tab is already showing it.
        if selectedTab == .channel(id: id), path(for: selectedTab).isEmpty { return }
        push(.channel(id: id))
    }

    func openPlaylist(id: String, title: String) {
        push(.playlist(id: id, title: title))
    }

    func openSearch() {
        selectedTab = .section(.search)
    }

    /// Returns to Home with every stack empty, e.g. because the account or channel changed.
    func reset() {
        playingVideo = nil
        paths = [:]
        selectedTab = .section(.home)
    }

    private func push(_ route: AppRoute) {
        var path = path(for: selectedTab)
        guard path.last != route else { return }
        path.append(route)
        setPath(path, for: selectedTab)
    }
}
