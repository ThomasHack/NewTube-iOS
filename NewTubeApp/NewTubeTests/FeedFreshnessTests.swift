import Foundation
import Testing

@testable import NewTube
@testable import NewTubeCore

// MARK: - FeedFreshnessTests
//
// Switching between pages must not refetch a feed that was loaded recently, and an empty page must
// show progress until its fetch has finished.

@Suite("Feed freshness")
@MainActor
struct FeedFreshnessTests {
    private let mock = MockInnerTubeAPI()
    private let news = BrowseSection(id: "news", title: "News", type: .news)
    private let live = BrowseSection(id: "live", title: "Live", type: .live)
    private let playlists = BrowseSection(id: "playlists", title: "Playlists", type: .playlists)
    /// Hide notifications reach every view model in the process, so these IDs must stay unique.
    private let videoId = "freshness-video-\(UUID().uuidString)"

    private func fetchCount(_ method: String) -> Int {
        mock.calls.filter { $0.method == method }.count
    }

    private func loadedVM() async -> BrowseViewModel {
        mock.newsResult = VideoGroup(title: "News", videos: [Video(id: videoId, title: "One", channelTitle: "Channel")])
        let vm = BrowseViewModel(api: mock, initialSection: news)
        vm.loadContent(refresh: true)
        await waitUntil { !vm.isLoading }
        return vm
    }

    @Test func aNewViewModelAwaitsContent() {
        let vm = BrowseViewModel(api: mock, initialSection: news)
        #expect(vm.isAwaitingContent)
    }

    @Test func loadingStartsSynchronously() {
        let vm = BrowseViewModel(api: mock, initialSection: news)
        vm.loadContent(refresh: true)
        #expect(vm.isLoading)
    }

    @Test func aFinishedEmptyFetchNoLongerAwaitsContent() async {
        let vm = BrowseViewModel(api: mock, initialSection: playlists)
        vm.loadContent(refresh: true)
        #expect(vm.isAwaitingContent)
        await waitUntil { !vm.isAwaitingContent }
        #expect(vm.videoGroups.isEmpty)
        #expect(!vm.isAwaitingContent)
    }

    @Test func aFailedFetchNoLongerAwaitsContent() async {
        mock.errorToThrow = URLError(.notConnectedToInternet)
        let vm = BrowseViewModel(api: mock, initialSection: playlists)
        vm.loadContent(refresh: true)
        await waitUntil { !vm.isAwaitingContent }
        #expect(!vm.isAwaitingContent)
    }

    @Test func aFreshFeedIsNotRefetched() async {
        let vm = await loadedVM()
        let fetches = fetchCount("fetchNews")
        vm.refreshIfStale()
        #expect(!vm.isLoading)
        #expect(fetchCount("fetchNews") == fetches)
    }

    @Test func aStaleFeedRefreshesWithoutClearingWhatIsShown() async {
        let vm = await loadedVM()
        let fetches = fetchCount("fetchNews")
        vm.refreshIfStale(threshold: -1)
        #expect(vm.isLoading)
        #expect(!vm.videoGroups.isEmpty)
        await waitUntil { !vm.isLoading }
        #expect(fetchCount("fetchNews") == fetches + 1)
    }

    @Test func settingTheSameSessionsTokenAgainDoesNotReload() async {
        let vm = await loadedVM()
        await vm.updateAuthToken("token")
        await waitUntil { !vm.isLoading }
        let fetches = fetchCount("fetchNews")
        await vm.updateAuthToken("token")
        await vm.updateAuthToken("refreshed-token")
        #expect(!vm.isLoading)
        #expect(fetchCount("fetchNews") == fetches)
    }

    @Test func switchingBackToARecentSectionRestoresItWithoutFetching() async {
        let vm = await loadedVM()
        vm.select(section: live)
        await waitUntil { !vm.isLoading }
        let fetches = fetchCount("fetchNews")

        vm.select(section: news)
        #expect(!vm.isLoading)
        #expect(vm.videoGroups.flatMap(\.videos).map(\.id) == [videoId])
        #expect(fetchCount("fetchNews") == fetches)
    }

    @Test func aHiddenVideoStaysHiddenWhenItsSectionIsRestored() async {
        let vm = await loadedVM()
        vm.select(section: live)
        await waitUntil { !vm.isLoading }
        let fetches = fetchCount("fetchNews")

        vm.removeVideo(id: videoId)
        vm.select(section: news)
        #expect(vm.videoGroups.flatMap(\.videos).isEmpty)
        #expect(fetchCount("fetchNews") == fetches)
    }

    @Test func aRecentlyLoadedChannelIsNotRefetched() async {
        mock.channelResult = (Channel(id: "UCchannel", title: "Channel"), VideoGroup(title: "Home", videos: []))
        let vm = ChannelViewModel(api: mock)
        await vm.loadAsync(channelId: "UCchannel")
        let fetches = fetchCount("fetchChannel")

        vm.loadIfStale(channelId: "UCchannel")
        #expect(!vm.isLoading)
        #expect(fetchCount("fetchChannel") == fetches)
    }
}

@Suite("AppFeeds")
@MainActor
struct AppFeedsTests {
    @Test func pagesKeepTheirViewModelUntilReset() {
        let feeds = AppFeeds(api: MockInnerTubeAPI())
        let channel = feeds.channel(id: "channel")
        let playlist = feeds.playlist(id: "playlist")
        #expect(feeds.channel(id: "channel") === channel)
        #expect(feeds.playlist(id: "playlist") === playlist)

        feeds.reset()
        #expect(feeds.channel(id: "channel") !== channel)
        #expect(feeds.playlist(id: "playlist") !== playlist)
    }

    @Test func eachChannelHasItsOwnViewModel() {
        let feeds = AppFeeds(api: MockInnerTubeAPI())
        #expect(feeds.channel(id: "one") !== feeds.channel(id: "two"))
    }
}
