import Observation
import SmartTubeCore

// MARK: - AppFeeds

/// The view models of the pages reached from the sidebar. A `.sidebarAdaptable` `TabView` discards a
/// tab's `@State` when another tab is selected, so anything that should survive switching tabs lives
/// here instead.
@MainActor
@Observable
final class AppFeeds {
    let home: BrowseViewModel
    let subscriptions: BrowseViewModel
    let rss: RSSFeedsViewModel
    var librarySection: LibraryView.LibrarySection = .history

    @ObservationIgnored private let api: any InnerTubeAPIProtocol
    @ObservationIgnored private var channels: [String: ChannelViewModel] = [:]
    @ObservationIgnored private var playlists: [String: PlaylistViewModel] = [:]

    init(api: any InnerTubeAPIProtocol, rss: RSSFeedsViewModel = RSSFeedsViewModel()) {
        self.api = api
        self.rss = rss
        home = BrowseViewModel(api: api, initialSection: BrowseSection(type: .recommended))
        subscriptions = BrowseViewModel(api: api, initialSection: BrowseSection(type: .subscriptions))
    }

    func channel(id: String) -> ChannelViewModel {
        if let existing = channels[id] { return existing }
        let viewModel = ChannelViewModel()
        channels[id] = viewModel
        return viewModel
    }

    func playlist(id: String) -> PlaylistViewModel {
        if let existing = playlists[id] { return existing }
        let viewModel = PlaylistViewModel(api: api)
        playlists[id] = viewModel
        return viewModel
    }

    /// Forgets account-specific pages. The feeds reload themselves when the account changes.
    func reset() {
        channels = [:]
        playlists = [:]
        librarySection = .history
    }
}
