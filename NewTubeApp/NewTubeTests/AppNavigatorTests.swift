import Testing

@testable import NewTube
@testable import NewTubeCore

@Suite("AppNavigator")
@MainActor
struct AppNavigatorTests {
    private let home = AppTab.section(.home)
    private let library = AppTab.section(.library)
    private let video = Video(id: "video", title: "Video", channelTitle: "Channel")

    @Test func openChannelPushesOntoTheSelectedTabOnly() {
        let navigator = AppNavigator()
        navigator.selectedTab = library
        navigator.openChannel(id: "channel")
        #expect(navigator.path(for: library) == [.channel(id: "channel")])
        #expect(navigator.path(for: home).isEmpty)
    }

    @Test func openChannelClosesThePlayer() {
        let navigator = AppNavigator()
        navigator.play(video)
        navigator.openChannel(id: "channel")
        #expect(navigator.playingVideo == nil)
        #expect(navigator.path(for: home) == [.channel(id: "channel")])
    }

    @Test func openingTheVisibleChannelAgainDoesNotPushADuplicate() {
        let navigator = AppNavigator()
        navigator.openChannel(id: "channel")
        navigator.openChannel(id: "channel")
        #expect(navigator.path(for: home) == [.channel(id: "channel")])
    }

    @Test func aChannelsOwnTabDoesNotPushItself() {
        let navigator = AppNavigator()
        navigator.selectedTab = .channel(id: "channel")
        navigator.play(video)
        navigator.openChannel(id: "channel")
        #expect(navigator.playingVideo == nil)
        #expect(navigator.path(for: .channel(id: "channel")).isEmpty)
    }

    @Test func aChannelsOwnTabPushesOtherChannels() {
        let navigator = AppNavigator()
        navigator.selectedTab = .channel(id: "channel")
        navigator.openChannel(id: "other")
        #expect(navigator.path(for: .channel(id: "channel")) == [.channel(id: "other")])
    }

    @Test func emptyChannelIdIsIgnored() {
        let navigator = AppNavigator()
        navigator.play(video)
        navigator.openChannel(id: "")
        #expect(navigator.playingVideo != nil)
        #expect(navigator.path(for: home).isEmpty)
    }

    @Test func openSearchSelectsTheSearchTab() {
        let navigator = AppNavigator()
        navigator.openSearch()
        #expect(navigator.selectedTab == .section(.search))
    }

    @Test func resetClearsEveryStackAndReturnsHome() {
        let navigator = AppNavigator()
        navigator.selectedTab = library
        navigator.openPlaylist(id: "playlist", title: "Playlist")
        navigator.play(video)
        navigator.reset()
        #expect(navigator.selectedTab == home)
        #expect(navigator.path(for: library).isEmpty)
        #expect(navigator.playingVideo == nil)
    }
}
