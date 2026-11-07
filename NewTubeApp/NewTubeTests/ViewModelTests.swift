import Foundation
import Testing

@testable import NewTube
@testable import NewTubeCore

// MARK: - MockInnerTubeAPI
//
// Synchronous, controllable stand-in for InnerTubeAPI.
// Set `*Result` properties to control what each fetch returns.
// All calls record themselves in `calls` for assertion.

@MainActor
final class MockInnerTubeAPI: InnerTubeAPIProtocol {

    // MARK: - Call recorder

    struct Call: Equatable {
        let method: String
        let args: [String]
    }
    var calls: [Call] = []

    // MARK: - Configurable return values

    var homeResult: VideoGroup = VideoGroup(title: "Home", videos: [])
    var homeRowsResult: [VideoGroup] = []
    var subscriptionsResult: VideoGroup = VideoGroup(title: "Subs", videos: [])
    var historyResult: VideoGroup = VideoGroup(title: "History", videos: [])
    var musicResult: VideoGroup = VideoGroup(title: "Music", videos: [])
    var gamingResult: VideoGroup = VideoGroup(title: "Gaming", videos: [])
    var newsResult: VideoGroup = VideoGroup(title: "News", videos: [])
    var liveResult: VideoGroup = VideoGroup(title: "Live", videos: [])
    var sportsResult: VideoGroup = VideoGroup(title: "Sports", videos: [])
    var playlistsResult: [PlaylistInfo] = []
    var channelsResult: [Channel] = []
    var channelThumbnailResult: URL? = nil
    var channelResult: (channel: Channel, videos: VideoGroup) = (
        Channel(id: "ch1", title: "Channel"), VideoGroup(title: "Ch", videos: [])
    )
    var channelVideosResult: VideoGroup = VideoGroup(title: "ChVideos", videos: [])
    /// Thrown only by `fetchChannelVideos`, so a test can fail the Videos tab while Home succeeds.
    var channelVideosError: Error?
    var searchResult: VideoGroup = VideoGroup(title: "Search", videos: [])
    var suggestionsResult: [String] = []
    var playlistVideosResult: VideoGroup = VideoGroup(title: "Playlist", videos: [])
    var errorToThrow: Error? = nil

    // MARK: - Protocol conformance

    func setAuthToken(_ token: String?) async {
        calls.append(Call(method: "setAuthToken", args: [token ?? "nil"]))
    }

    func setSAPISID(_ value: String?) async {
        calls.append(Call(method: "setSAPISID", args: [value ?? "nil"]))
    }

    func fetchHome(continuationToken: String?) async throws -> VideoGroup {
        calls.append(Call(method: "fetchHome", args: [continuationToken ?? "nil"]))
        if let e = errorToThrow { throw e }
        return homeResult
    }

    func fetchHomeRows(continuationToken: String?) async throws -> [VideoGroup] {
        calls.append(Call(method: "fetchHomeRows", args: [continuationToken ?? "nil"]))
        if let e = errorToThrow { throw e }
        return homeRowsResult
    }

    func fetchSubscriptions(continuationToken: String?) async throws -> VideoGroup {
        calls.append(Call(method: "fetchSubscriptions", args: [continuationToken ?? "nil"]))
        if let e = errorToThrow { throw e }
        return subscriptionsResult
    }

    func fetchHistory(continuationToken: String?) async throws -> VideoGroup {
        calls.append(Call(method: "fetchHistory", args: [continuationToken ?? "nil"]))
        if let e = errorToThrow { throw e }
        return historyResult
    }

    func fetchMusic() async throws -> VideoGroup {
        calls.append(Call(method: "fetchMusic", args: []))
        if let e = errorToThrow { throw e }
        return musicResult
    }

    func fetchGaming() async throws -> VideoGroup {
        calls.append(Call(method: "fetchGaming", args: []))
        if let e = errorToThrow { throw e }
        return gamingResult
    }

    func fetchNews() async throws -> VideoGroup {
        calls.append(Call(method: "fetchNews", args: []))
        if let e = errorToThrow { throw e }
        return newsResult
    }

    func fetchLive() async throws -> VideoGroup {
        calls.append(Call(method: "fetchLive", args: []))
        if let e = errorToThrow { throw e }
        return liveResult
    }

    func fetchSports() async throws -> VideoGroup {
        calls.append(Call(method: "fetchSports", args: []))
        if let e = errorToThrow { throw e }
        return sportsResult
    }

    func fetchUserPlaylists() async throws -> [PlaylistInfo] {
        calls.append(Call(method: "fetchUserPlaylists", args: []))
        if let e = errorToThrow { throw e }
        return playlistsResult
    }

    func fetchSubscribedChannels() async throws -> [Channel] {
        calls.append(Call(method: "fetchSubscribedChannels", args: []))
        if let e = errorToThrow { throw e }
        return channelsResult
    }

    func fetchChannelThumbnailURL(channelId: String) async throws -> URL? {
        calls.append(Call(method: "fetchChannelThumbnailURL", args: [channelId]))
        return channelThumbnailResult
    }

    func fetchChannel(channelId: String) async throws -> (channel: Channel, videos: VideoGroup) {
        calls.append(Call(method: "fetchChannel", args: [channelId]))
        if let e = errorToThrow { throw e }
        return channelResult
    }

    func fetchChannelVideos(channelId: String, continuationToken: String?) async throws -> VideoGroup {
        calls.append(Call(method: "fetchChannelVideos", args: [channelId, continuationToken ?? "nil"]))
        if let error = channelVideosError ?? errorToThrow { throw error }
        return channelVideosResult
    }

    func search(query: String, continuationToken: String?, filter: SearchFilter) async throws -> VideoGroup {
        calls.append(Call(method: "search", args: [query, continuationToken ?? "nil"]))
        if let e = errorToThrow { throw e }
        return searchResult
    }

    func fetchSearchSuggestions(query: String) async throws -> [String] {
        calls.append(Call(method: "fetchSearchSuggestions", args: [query]))
        if let e = errorToThrow { throw e }
        return suggestionsResult
    }

    func fetchPlaylistVideos(playlistId: String, continuationToken: String?) async throws -> VideoGroup {
        calls.append(Call(method: "fetchPlaylistVideos", args: [playlistId, continuationToken ?? "nil"]))
        if let e = errorToThrow { throw e }
        return playlistVideosResult
    }

    func addToWatchLater(videoId: String) throws -> String? {
        calls.append(Call(method: "addToWatchLater", args: [videoId]))
        if let e = errorToThrow { throw e }
        return nil
    }

    func removeFromWatchLater(setVideoId: String) throws {
        calls.append(Call(method: "removeFromWatchLater", args: [setVideoId]))
        if let e = errorToThrow { throw e }
    }

    func addToPlaylist(playlistId: String, videoId: String) throws {
        calls.append(Call(method: "addToPlaylist", args: [playlistId, videoId]))
        if let e = errorToThrow { throw e }
    }

    func removeFromPlaylist(playlistId: String, setVideoId: String) throws {
        calls.append(Call(method: "removeFromPlaylist", args: [playlistId, setVideoId]))
        if let e = errorToThrow { throw e }
    }

    func sendFeedback(token: String) async throws {
        calls.append(Call(method: "sendFeedback", args: [token]))
        if let e = errorToThrow { throw e }
    }

    func sendFeedbackForVideo(videoId: String, iconType: String) async throws {
        calls.append(Call(method: "sendFeedbackForVideo", args: [videoId, iconType]))
        if let e = errorToThrow { throw e }
    }
}

// MARK: - Helpers

/// Yields control enough times so internal @MainActor Tasks spawned by
/// the ViewModel can complete against an immediately-returning mock API.
///
/// Without `until:`, this is a fixed delay (3 yields + 50ms) — fine when the
/// global executor is lightly loaded, but flaky under heavy parallel test
/// contention (confirmed: running the full `swift test` suite reliably
/// produced failures here that a `--filter ViewModelTests --no-parallel` run
/// never does — the underlying async work just hadn't completed yet when the
/// fixed delay elapsed). Pass `until:` for any assertion that depends on a
/// specific condition to poll for it directly instead of guessing a delay.
@MainActor
private func waitForTasks(timeout: TimeInterval = 2, until condition: (@MainActor () -> Bool)? = nil) async {
    guard let condition else {
        for _ in 0..<3 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(50))
        return
    }
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        await Task.yield()
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(10))
    }
}

private func makeVideo(_ id: String) -> Video {
    Video(id: id, title: "Video \(id)", channelTitle: "Channel")
}

/// Creates a `SearchViewModel` backed by a uniquely-suited `SearchHistoryStore`
/// instead of `.shared`, so tests don't read/write the same `UserDefaults`
/// search-history entries across the suite.
@MainActor
private func makeSearchViewModel(api: any InnerTubeAPIProtocol) -> SearchViewModel {
    SearchViewModel(api: api, historyStore: SearchHistoryStore(suiteName: "test-\(UUID().uuidString)"))
}

// MARK: - BrowseViewModelTests

@Suite("BrowseViewModel")
@MainActor
struct BrowseViewModelTests {

    @Test("loadContent for .subscriptions calls fetchSubscriptions and populates videoGroups")
    func loadSubscriptionsPopulatesGroups() async {
        let mock = MockInnerTubeAPI()
        mock.subscriptionsResult = VideoGroup(title: "Subs", videos: [makeVideo("subvid_AAAA")])

        let section = BrowseSection(id: "subscriptions", title: "Subscriptions", type: .subscriptions)
        let vm = BrowseViewModel(api: mock, initialSection: section)
        await vm.updateAuthToken("fake-token")  // authenticated path
        vm.loadContent(for: section, refresh: true, source: "test")
        await waitForTasks(until: { !vm.videoGroups.isEmpty })

        #expect(mock.calls.contains { $0.method == "fetchSubscriptions" })
        #expect(!vm.videoGroups.isEmpty)
        #expect(vm.videoGroups[0].videos[0].id == "subvid_AAAA")
    }

    @Test("loadContent for .history calls fetchHistory")
    func loadHistoryCallsFetch() async throws {
        let mock = MockInnerTubeAPI()
        mock.historyResult = VideoGroup(title: "History", videos: [makeVideo("histvid_AAAA")])

        let section = BrowseSection(id: "history", title: "History", type: .history)
        // Own empty local-history store: the shared one persists entries recorded by other
        // player tests across runs, and local entries are shown first (#150).
        let emptyLocal = try LocalWatchHistoryStore(
            defaults: #require(UserDefaults(suiteName: "hist-\(UUID().uuidString)")))
        let vm = BrowseViewModel(api: mock, initialSection: section, localHistory: emptyLocal)
        vm.loadContent(for: section, refresh: true, source: "test")
        await waitForTasks(until: { vm.videoGroups.first?.videos.first != nil })

        #expect(mock.calls.contains { $0.method == "fetchHistory" })
        #expect(vm.videoGroups.first?.videos.first?.id == "histvid_AAAA")
    }

    @Test("loadContent for .history shows local history first, then account history without duplicates (#150)")
    func loadHistoryMergesLocalFirst() async throws {
        let mock = MockInnerTubeAPI()
        mock.historyResult = VideoGroup(
            title: "History", videos: [makeVideo("histvid_AAAA"), makeVideo("histvid_BBBB")])
        let local = try LocalWatchHistoryStore(defaults: #require(UserDefaults(suiteName: "hist-\(UUID().uuidString)")))
        local.record(makeVideo("histvid_BBBB"))  // also in account history → must not duplicate
        local.record(makeVideo("localonly_CCCC"))

        let section = BrowseSection(id: "history", title: "History", type: .history)
        let vm = BrowseViewModel(api: mock, initialSection: section, localHistory: local)
        vm.loadContent(for: section, refresh: true, source: "test")
        await waitForTasks(until: { vm.videoGroups.first?.videos.count == 3 })

        #expect(vm.videoGroups.first?.videos.map(\.id) == ["localonly_CCCC", "histvid_BBBB", "histvid_AAAA"])
    }

    @Test("loadContent for .history shows local history even when the account fetch yields nothing (#150)")
    func loadHistoryLocalOnlyWhenRemoteEmpty() async throws {
        let mock = MockInnerTubeAPI()
        let local = try LocalWatchHistoryStore(defaults: #require(UserDefaults(suiteName: "hist-\(UUID().uuidString)")))
        local.record(makeVideo("localonly_CCCC"))

        let section = BrowseSection(id: "history", title: "History", type: .history)
        let vm = BrowseViewModel(api: mock, initialSection: section, localHistory: local)
        vm.loadContent(for: section, refresh: true, source: "test")
        await waitForTasks(until: { vm.videoGroups.first?.videos.first != nil })

        #expect(vm.videoGroups.first?.videos.map(\.id) == ["localonly_CCCC"])
        #expect(!vm.isAuthRequired)
    }

    @Test("Empty subscriptions (local path) does not set isAuthRequired")
    func emptyLocalSubscriptionsDoNotSetAuthRequired() async {
        let mock = MockInnerTubeAPI()
        // No auth token → takes local path; local follows are empty

        let section = BrowseSection(id: "subscriptions", title: "Subscriptions", type: .subscriptions)
        let vm = BrowseViewModel(api: mock, initialSection: section)
        vm.loadContent(for: section, refresh: true, source: "test")
        await waitForTasks()

        // Local path never gates on auth — empty means "no follows yet", not "sign in"
        #expect(!vm.isAuthRequired)
    }

    @Test("Error on non-auth section sets error property")
    func errorOnFetchSetsErrorProperty() async {
        struct TestError: Error {}
        let mock = MockInnerTubeAPI()
        mock.errorToThrow = TestError()

        let section = BrowseSection(id: "news", title: "News", type: .news)
        let vm = BrowseViewModel(api: mock, initialSection: section)
        vm.loadContent(for: section, refresh: true, source: "test")
        await waitForTasks(until: { vm.error != nil })

        #expect(vm.error != nil)
    }

    @Test("isLoading is false after fetch completes")
    func isLoadingFalseAfterFetch() async {
        let mock = MockInnerTubeAPI()
        mock.subscriptionsResult = VideoGroup(title: "Subs", videos: [makeVideo("vid_AAAAAAA")])

        let section = BrowseSection(id: "subscriptions", title: "Subscriptions", type: .subscriptions)
        let vm = BrowseViewModel(api: mock, initialSection: section)
        vm.loadContent(for: section, refresh: true, source: "test")
        // isLoading is false both before the fetch starts and after it ends, so
        // it can't be the polling condition on its own — and requiring a
        // recorded mock call doesn't work either, since unauthenticated
        // .subscriptions takes a local-store path that never calls the mock API
        // at all (see "Empty subscriptions (local path)" above). loadedAt is set
        // inside fetchSection's withThrowingTaskGroup body (BrowseViewModel.swift:475),
        // which can fire before the outer function (and its `defer { isLoading = false }`)
        // actually returns if other group children are still running — so require
        // both signals together rather than relying on loadedAt alone.
        await waitForTasks(until: { vm.loadedAt != nil && !vm.isLoading })

        #expect(!vm.isLoading)
    }

    @Test("loadContent for .watchLater (signed in) calls fetchPlaylistVideos(WL) and stamps playlistId")
    func loadWatchLaterPopulatesGroupsAndStampsPlaylistId() async {
        let mock = MockInnerTubeAPI()
        mock.playlistVideosResult = VideoGroup(title: "Watch Later", videos: [makeVideo("wlvid_AAAA")])

        let section = BrowseSection(id: "watchLater", title: "Watch Later", type: .watchLater)
        let vm = BrowseViewModel(api: mock, initialSection: section)
        await vm.updateAuthToken("fake-token")
        vm.loadContent(for: section, refresh: true, source: "test")
        await waitForTasks(until: { !vm.videoGroups.isEmpty })

        #expect(mock.calls.contains { $0.method == "fetchPlaylistVideos" && $0.args.first == "WL" })
        #expect(vm.videoGroups.first?.videos.first?.id == "wlvid_AAAA")
        #expect(
            vm.videoGroups.first?.videos.first?.playlistId == "WL",
            "videos must be stamped with playlistId=WL so VideoCardView's Remove/Move-to-Playlist actions work from this tab"
        )
    }

    @Test("Watch Later: adds and removes made in the app update the open list at once (#157)")
    func watchLaterListFollowsAppChanges() async throws {
        let mock = MockInnerTubeAPI()
        // Its removal notification reaches every open Watch Later list, so no other test may use this ID.
        mock.playlistVideosResult = VideoGroup(title: "Watch Later", videos: [makeVideo("wlremoved_AA")])
        let membership = try WatchLaterMembershipStore(
            defaults: #require(UserDefaults(suiteName: "wl-\(UUID().uuidString)")))
        let section = BrowseSection(id: "watchLater", title: "Watch Later", type: .watchLater)
        let vm = BrowseViewModel(api: mock, initialSection: section, watchLaterMembership: membership)
        await vm.updateAuthToken("fake-token")
        await waitForTasks(until: { vm.videoGroups.first?.videos.first?.id == "wlremoved_AA" })

        membership.markSaved(makeVideo("newsave_BBBB"), setVideoId: "SETVID_B")
        await waitForTasks(until: { vm.videoGroups.first?.videos.count == 2 })
        #expect(vm.videoGroups.first?.videos.map(\.id) == ["newsave_BBBB", "wlremoved_AA"])
        #expect(vm.videoGroups.first?.videos.first?.setVideoId == "SETVID_B")

        membership.markRemoved("wlremoved_AA")
        await waitForTasks(until: { vm.videoGroups.first?.videos.count == 1 })
        #expect(vm.videoGroups.first?.videos.map(\.id) == ["newsave_BBBB"])
    }

    @Test("Watch Later: a recent save YouTube hasn't indexed yet is shown on top after loading (#157)")
    func watchLaterLoadShowsUnindexedSave() async throws {
        let mock = MockInnerTubeAPI()
        mock.playlistVideosResult = VideoGroup(title: "Watch Later", videos: [makeVideo("wlvid_AAAA")])
        let membership = try WatchLaterMembershipStore(
            defaults: #require(UserDefaults(suiteName: "wl-\(UUID().uuidString)")))
        membership.markSaved(makeVideo("justsaved_CCCC"), setVideoId: "SETVID_C")
        let section = BrowseSection(id: "watchLater", title: "Watch Later", type: .watchLater)
        let vm = BrowseViewModel(api: mock, initialSection: section, watchLaterMembership: membership)
        await vm.updateAuthToken("fake-token")
        await waitForTasks(timeout: 5, until: { vm.videoGroups.first?.videos.count == 2 })
        #expect(vm.videoGroups.first?.videos.map(\.id) == ["justsaved_CCCC", "wlvid_AAAA"])
        #expect(vm.videoGroups.first?.videos.first?.playlistId == "WL")
    }

    @Test("Watch Later: an old saved video missing from page 1 does not trigger a retry (#157)")
    func watchLaterOldSaveDoesNotRetry() async throws {
        let mock = MockInnerTubeAPI()
        mock.playlistVideosResult = VideoGroup(title: "Watch Later", videos: [makeVideo("wlvid_AAAA")])
        let membership = try WatchLaterMembershipStore(
            defaults: #require(UserDefaults(suiteName: "wl-\(UUID().uuidString)")))
        membership.markSaved("oldsave_ZZZZ", at: Date(timeIntervalSinceNow: -3600))

        let section = BrowseSection(id: "watchLater", title: "Watch Later", type: .watchLater)
        let vm = BrowseViewModel(api: mock, initialSection: section, watchLaterMembership: membership)
        await vm.updateAuthToken("fake-token")
        await waitForTasks()  // updateAuthToken reloads the section; measure only the load below
        mock.calls.removeAll()
        vm.loadContent(for: section, refresh: true, source: "test")
        // A retry would happen before loading ends, so there's no need to outwait its delay.
        await waitForTasks(
            timeout: 5,
            until: { !vm.isLoading && mock.calls.contains { $0.method == "fetchPlaylistVideos" } })

        #expect(mock.calls.filter { $0.method == "fetchPlaylistVideos" }.count == 1)
    }

    @Test("Watch Later: a just-saved video missing from the response triggers one re-fetch (#157)")
    func watchLaterRecentSaveRetriesOnce() async throws {
        let mock = MockInnerTubeAPI()
        mock.playlistVideosResult = VideoGroup(title: "Watch Later", videos: [makeVideo("wlvid_AAAA")])
        let membership = try WatchLaterMembershipStore(
            defaults: #require(UserDefaults(suiteName: "wl-\(UUID().uuidString)")))
        membership.markSaved("justsaved_YYYY")

        let section = BrowseSection(id: "watchLater", title: "Watch Later", type: .watchLater)
        let vm = BrowseViewModel(api: mock, initialSection: section, watchLaterMembership: membership)
        await vm.updateAuthToken("fake-token")
        await waitForTasks()  // updateAuthToken reloads the section; measure only the load below
        mock.calls.removeAll()
        vm.loadContent(for: section, refresh: true, source: "test")
        await waitForTasks(timeout: 5, until: { mock.calls.filter { $0.method == "fetchPlaylistVideos" }.count == 2 })

        #expect(mock.calls.filter { $0.method == "fetchPlaylistVideos" }.count == 2)
    }

    @Test("loadContent for .watchLater (signed out) requires auth without calling the API")
    func loadWatchLaterSignedOutRequiresAuth() async {
        let mock = MockInnerTubeAPI()
        // No auth token set.

        let section = BrowseSection(id: "watchLater", title: "Watch Later", type: .watchLater)
        let vm = BrowseViewModel(api: mock, initialSection: section)
        vm.loadContent(for: section, refresh: true, source: "test")
        await waitForTasks()

        #expect(vm.isAuthRequired)
        #expect(!mock.calls.contains { $0.method == "fetchPlaylistVideos" })
    }
}

// MARK: - SearchViewModelTests

@Suite("SearchViewModel")
@MainActor
struct SearchViewModelTests {

    @Test("search() with non-empty query populates results")
    func searchPopulatesResults() async {
        let mock = MockInnerTubeAPI()
        mock.searchResult = VideoGroup(title: "Results", videos: [makeVideo("result_AAAAA")])

        let vm = makeSearchViewModel(api: mock)
        vm.query = "swift programming"
        vm.search()
        await waitForTasks()

        #expect(!vm.results.isEmpty)
        #expect(vm.results[0].id == "result_AAAAA")
    }

    @Test("search() with whitespace-only query is a no-op")
    func searchWithWhitespaceOnlyIsNoOp() async {
        let mock = MockInnerTubeAPI()
        mock.searchResult = VideoGroup(title: "Results", videos: [makeVideo("result_AAAAA")])

        let vm = makeSearchViewModel(api: mock)
        vm.query = "   "
        vm.search()
        await waitForTasks()

        #expect(vm.results.isEmpty)
        #expect(!mock.calls.contains { $0.method == "search" })
    }

    @Test("loadMore() with nextPageToken appends results")
    func loadMoreAppendsResults() async {
        let mock = MockInnerTubeAPI()
        let page1 = VideoGroup(title: "R", videos: [makeVideo("p1_0000001")], nextPageToken: "token123")
        let page2 = VideoGroup(title: "R", videos: [makeVideo("p2_0000002")])
        mock.searchResult = page1

        let vm = makeSearchViewModel(api: mock)
        vm.query = "test"
        vm.search()
        await waitForTasks()

        // Now set up page 2 and trigger loadMore
        mock.searchResult = page2
        vm.loadMore()
        await waitForTasks()

        #expect(vm.results.count == 2)
        let ids = vm.results.map(\.id)
        #expect(ids.contains("p1_0000001"))
        #expect(ids.contains("p2_0000002"))
    }

    @Test("isLoading is false after search completes")
    func isLoadingFalseAfterSearch() async {
        let mock = MockInnerTubeAPI()
        mock.searchResult = VideoGroup(title: "R", videos: [])

        let vm = makeSearchViewModel(api: mock)
        vm.query = "query"
        vm.search()
        await waitForTasks()

        #expect(!vm.isLoading)
    }

    @Test("applyFilter reruns search with new filter")
    func applyFilterReruns() async {
        let mock = MockInnerTubeAPI()
        mock.searchResult = VideoGroup(title: "R", videos: [makeVideo("vid_AAAAAAA")])

        let vm = makeSearchViewModel(api: mock)
        vm.query = "swift"
        vm.search()
        await waitForTasks()

        let beforeCount = mock.calls.filter { $0.method == "search" }.count
        var filter = SearchFilter()
        filter.sortOrder = .viewCount
        vm.applyFilter(filter)
        await waitForTasks()

        let afterCount = mock.calls.filter { $0.method == "search" }.count
        #expect(afterCount > beforeCount)
    }
}

// MARK: - PlaylistViewModelTests

@Suite("PlaylistViewModel")
@MainActor
struct PlaylistViewModelTests {

    @Test("load() fetches playlist videos and populates videos array")
    func loadPopulatesVideos() async {
        let mock = MockInnerTubeAPI()
        mock.playlistVideosResult = VideoGroup(
            title: "PL",
            videos: [
                makeVideo("plvid_AAAAA"),
                makeVideo("plvid_BBBBB"),
            ])

        let vm = PlaylistViewModel(api: mock)
        vm.load(playlistId: "PLtest1234567")
        await waitForTasks(until: { vm.videos.count == 2 })

        #expect(vm.videos.count == 2)
        #expect(mock.calls.contains { $0.method == "fetchPlaylistVideos" })
    }

    @Test("load() tags each video with playlistId")
    func loadTagsVideosWithPlaylistId() async {
        let mock = MockInnerTubeAPI()
        mock.playlistVideosResult = VideoGroup(title: "PL", videos: [makeVideo("vid_AAAAAAA")])

        let vm = PlaylistViewModel(api: mock)
        vm.load(playlistId: "PLtest1234567")
        await waitForTasks(until: { vm.videos.first != nil })

        #expect(vm.videos.first?.playlistId == "PLtest1234567")
    }

    @Test("load(refresh: true) clears videos and reloads")
    func loadRefreshClearsAndReloads() async {
        let mock = MockInnerTubeAPI()
        mock.playlistVideosResult = VideoGroup(title: "PL", videos: [makeVideo("vid_AAAAAAA")])

        let vm = PlaylistViewModel(api: mock)
        vm.load(playlistId: "PLtest1234567")
        await waitForTasks()

        // Refresh — should clear and re-fetch
        mock.playlistVideosResult = VideoGroup(title: "PL", videos: [makeVideo("vid_BBBBBBB")])
        vm.load(playlistId: "PLtest1234567", refresh: true)
        await waitForTasks()

        #expect(vm.videos.count == 1)
        #expect(vm.videos[0].id == "vid_BBBBBBB")
    }

    @Test("loadMoreIfNeeded appends next page when on last video")
    func loadMoreAppendsNextPage() async {
        let mock = MockInnerTubeAPI()
        let page1Video = makeVideo("page1_AAAAA")
        mock.playlistVideosResult = VideoGroup(
            title: "PL", videos: [page1Video], nextPageToken: "token_page2"
        )

        let vm = PlaylistViewModel(api: mock)
        vm.load(playlistId: "PLtest1234567")
        await waitForTasks()

        // Set up page 2
        mock.playlistVideosResult = VideoGroup(title: "PL", videos: [makeVideo("page2_BBBBB")])
        vm.loadMoreIfNeeded(lastVideo: page1Video)
        await waitForTasks()

        #expect(vm.videos.count == 2)
    }

    @Test("isLoading is false after fetch completes")
    func isLoadingFalseAfterFetch() async {
        let mock = MockInnerTubeAPI()
        mock.playlistVideosResult = VideoGroup(title: "PL", videos: [])

        let vm = PlaylistViewModel(api: mock)
        vm.load(playlistId: "PLtest1234567")
        await waitForTasks(until: { !vm.isLoading && !mock.calls.isEmpty })

        #expect(!vm.isLoading)
    }
}
