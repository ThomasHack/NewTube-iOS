import AVFoundation
import Testing
import UIKit

@testable import SmartTube
@testable import SmartTubeCore

@Suite("Player menu")
@MainActor
struct PlayerMenuTests {
    private func titles(_ state: PlayerMenuState) -> [String] {
        PlayerMenu.items(for: state) { _ in }.map(\.title)
    }

    private func moreTitles(_ state: PlayerMenuState) -> [String] {
        let items = PlayerMenu.items(for: state) { _ in }
        return (items.last as? UIMenu)?.children.map(\.title) ?? []
    }

    @Test func aMinimalVideoOnlyOffersSpeedAndMore() {
        #expect(titles(PlayerMenuState()).count == 2)
    }

    @Test func videoNavigationAppearsOnlyWhenAvailable() {
        let state = PlayerMenuState(hasPrevious: true, hasNext: true)
        #expect(titles(state).count == 4)
    }

    @Test func likingNeedsAnAccount() {
        #expect(moreTitles(PlayerMenuState(isSignedIn: true)).count == moreTitles(PlayerMenuState()).count + 2)
    }

    @Test func queueShuffleOnlyAppearsInAQueue() {
        #expect(moreTitles(PlayerMenuState(isInQueue: true)).count == moreTitles(PlayerMenuState()).count + 1)
    }

    @Test func theSelectedSpeedIsMarked() {
        let items = PlayerMenu.items(for: PlayerMenuState(playbackSpeed: 2)) { _ in }
        let speedMenu = items.first as? UIMenu
        let selected = speedMenu?.children.compactMap { $0 as? UIAction }.filter { $0.state == .on }
        #expect(selected?.count == 1)
    }

    @Test func chaptersEndWhereTheNextOneStarts() throws {
        let info = PlayerItemInfo(
            videoId: "v", title: "T", channelTitle: "C", description: nil, thumbnailURL: nil, duration: 100,
            chapters: [Chapter(title: "One", startTime: 0), Chapter(title: "Two", startTime: 40)]
        )
        let markers = try #require(PlayerItemMetadata.chapterMarkers(for: info).first?.timedNavigationMarkers)
        #expect(markers.count == 2)
        #expect(markers[0].timeRange.end.seconds == 40)
        #expect(markers[1].timeRange.end.seconds == 100)
    }

    @Test func noMarkersBeforeTheDurationIsKnown() {
        let info = PlayerItemInfo(
            videoId: "v", title: "T", channelTitle: "C", description: nil, thumbnailURL: nil, duration: 0,
            chapters: [Chapter(title: "One", startTime: 0)]
        )
        #expect(PlayerItemMetadata.chapterMarkers(for: info).isEmpty)
    }

    @Test func aPausedPlayerIsNotStalled() {
        #expect(!PlaybackViewModel.rateDropIsStall(.paused))
        #expect(PlaybackViewModel.rateDropIsStall(.waitingToPlayAtSpecifiedRate))
    }
}
