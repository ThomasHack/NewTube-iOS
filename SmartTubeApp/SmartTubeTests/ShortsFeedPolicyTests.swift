import Foundation
import Testing

@testable import SmartTube
@testable import SmartTubeCore

// MARK: - ShortsFeedPolicyTests

@Suite("Home and Recommended feeds without Shorts")
@MainActor
struct ShortsFeedPolicyTests {

    private let regular = Video(id: "regular_AAAA", title: "Regular", channelTitle: "Channel")
    private let short = Video(id: "short_AAAAAA", title: "Short", channelTitle: "Channel", isShort: true)

    private func makeAPI() -> MockInnerTubeAPI {
        let api = MockInnerTubeAPI()
        let feed = VideoGroup(title: "Feed", videos: [regular, short])
        api.homeResult = feed
        api.homeRowsResult = [feed]
        api.subscriptionsResult = feed
        api.shortsResult = VideoGroup(title: "Shorts", videos: [short])
        return api
    }

    private func calls(_ method: String, in api: MockInnerTubeAPI) -> Int {
        api.calls.filter { $0.method == method }.count
    }

    // MARK: Home

    @Test("Home with Shorts off doesn't fetch or expose them, and keeps regular videos")
    func homeWithoutShorts() async {
        let api = makeAPI()
        let vm = HomeViewModel(api: api, showsShorts: false)

        vm.load()
        await waitUntil { !vm.isLoadingAny && !vm.mergedVideos.isEmpty }

        #expect(calls("fetchShorts", in: api) == 0)
        #expect(vm.homeShortsVideos.isEmpty)
        #expect(vm.homeRegularVideos.map(\.id) == [regular.id])
    }

    @Test("Home with Shorts off ignores requests for more Shorts")
    func homeLoadMoreShortsIsNoOp() async {
        let api = makeAPI()
        let vm = HomeViewModel(api: api, showsShorts: false)

        await vm.loadMoreShortsIfNeeded()
        vm.loadNextShortsPage()

        #expect(calls("fetchShortsMore", in: api) == 0)
    }

    @Test("Home with Shorts on still fetches and exposes them")
    func homeWithShorts() async {
        let api = makeAPI()
        let vm = HomeViewModel(api: api, showsShorts: true)

        vm.load()
        await waitUntil { !vm.homeShortsVideos.isEmpty && !vm.isLoadingAny }

        #expect(calls("fetchShorts", in: api) == 1)
        #expect(vm.homeShortsVideos.map(\.id) == [short.id])
    }

    // MARK: Recommended

    private func loadRecommended(_ vm: BrowseViewModel) async {
        let section = BrowseSection(type: .recommended)
        await vm.updateAuthToken("token")
        vm.loadContent(for: section, refresh: true, source: "test")
        await waitUntil { !vm.isLoading && !vm.videoGroups.isEmpty }
    }

    @Test("Recommended with Shorts off makes no Shorts requests and exposes none")
    func recommendedWithoutShorts() async {
        let api = makeAPI()
        let vm = BrowseViewModel(api: api, showsRecommendedShorts: false)

        await loadRecommended(vm)

        #expect(calls("fetchShorts", in: api) == 0)
        #expect(calls("fetchSubscriptions", in: api) == 0)
        #expect(vm.recommendedShortsVideos.isEmpty)
        #expect(vm.videoGroups.flatMap(\.videos).contains { $0.id == regular.id })
    }

    @Test("Recommended with Shorts on still collects them")
    func recommendedWithShorts() async {
        let api = makeAPI()
        let vm = BrowseViewModel(api: api, showsRecommendedShorts: true)

        await loadRecommended(vm)

        #expect(calls("fetchShorts", in: api) == 1)
        #expect(vm.recommendedShortsVideos.map(\.id) == [short.id])
    }
}
