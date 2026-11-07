import Foundation
import Testing
import UIKit

@testable import NewTube
@testable import NewTubeCore

@Suite("SidebarChannelsViewModel")
@MainActor
struct SidebarChannelsViewModelTests {
    private let api = MockInnerTubeAPI()
    private let store = LocalSubscriptionStore(suiteName: "test-\(UUID().uuidString)")

    private func makeVM() -> SidebarChannelsViewModel {
        // A failing download keeps these tests away from the network and the real cache.
        let cache = ChannelAvatarCache(directory: temporaryDirectory()) { _ in throw URLError(.notConnectedToInternet) }
        return SidebarChannelsViewModel(api: api, localStore: store, avatarCache: cache)
    }

    private func channel(_ id: String, _ title: String) -> Channel {
        Channel(id: id, title: title)
    }

    @Test func listIsAlphabeticalWithoutDuplicatesOrUntitledChannels() {
        let list = SidebarChannelsViewModel.sidebarList([
            channel("z", "Zebra"),
            channel("10", "Channel 10"),
            channel("a", "ätna"),
            channel("2", "Channel 2"),
            channel("z", "Zebra"),
            channel("untitled", ""),
            channel("b", "apple"),
        ])
        #expect(list.map(\.id) == ["b", "a", "2", "10", "z"])
    }

    @Test func signedInMergesSubscriptionsAndLocalFollows() async {
        api.channelsResult = [channel("sub", "Subscription")]
        await store.follow(LocalChannel(id: "local", title: "Followed"))
        let vm = makeVM()
        await vm.load(authToken: "token")
        #expect(vm.channels.map(\.id) == ["local", "sub"])
    }

    @Test func signedOutOnlyListsLocalFollows() async {
        api.channelsResult = [channel("sub", "Subscription")]
        await store.follow(LocalChannel(id: "local", title: "Followed"))
        let vm = makeVM()
        await vm.load(authToken: nil)
        #expect(vm.channels.map(\.id) == ["local"])
        #expect(!api.calls.contains { $0.method == "fetchSubscribedChannels" })
    }

    @Test func aFailedReloadKeepsSubscriptionsButDropsUnfollowedChannels() async {
        api.channelsResult = [channel("sub", "Subscription")]
        await store.follow(LocalChannel(id: "local", title: "Followed"))
        let vm = makeVM()
        await vm.load(authToken: "token")

        api.errorToThrow = URLError(.notConnectedToInternet)
        await store.unfollow(channelId: "local")
        await vm.reload()
        #expect(vm.channels.map(\.id) == ["sub"])
    }

    @Test func signingOutDropsSubscriptions() async {
        api.channelsResult = [channel("sub", "Subscription")]
        let vm = makeVM()
        await vm.load(authToken: "token")
        await vm.load(authToken: nil)
        #expect(vm.channels.isEmpty)
    }

    @Test func avatarsComeFromTheCacheWithoutAnotherDownload() async {
        let directory = temporaryDirectory()
        let imageData = testImagePNG()
        let downloads = DownloadCounter()
        let cache = ChannelAvatarCache(directory: directory) { _ in
            await downloads.increment()
            return imageData
        }
        api.channelsResult = [
            Channel(id: "sub", title: "Subscription", thumbnailURL: URL(string: "https://a.test/a.png"))
        ]
        let vm = SidebarChannelsViewModel(api: api, localStore: store, avatarCache: cache)

        await vm.load(authToken: "token")
        #expect(vm.avatars["sub"] != nil)
        #expect(await downloads.count == 1)

        let relaunched = SidebarChannelsViewModel(api: api, localStore: store, avatarCache: cache)
        await relaunched.load(authToken: "token")
        #expect(relaunched.avatars["sub"] != nil)
        #expect(await downloads.count == 1)
    }

    @Test func aChannelWithoutAThumbnailResolvesItsAvatarURL() async {
        let imageData = testImagePNG()
        let cache = ChannelAvatarCache(directory: temporaryDirectory()) { _ in imageData }
        api.channelsResult = [channel("sub", "Subscription")]
        api.channelThumbnailResult = URL(string: "https://a.test/a.png")
        let vm = SidebarChannelsViewModel(api: api, localStore: store, avatarCache: cache)

        await vm.load(authToken: "token")
        #expect(vm.avatars["sub"] != nil)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "avatars-\(UUID().uuidString)")
    }

    private func testImagePNG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 2))
        return renderer.pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 2))
        }
    }
}

private actor DownloadCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}
