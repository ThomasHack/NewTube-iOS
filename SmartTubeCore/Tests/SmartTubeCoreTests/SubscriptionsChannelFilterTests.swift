import Testing

@testable import SmartTubeIOSCore

// MARK: - SubscriptionsChannelFilterTests (#62)
//
// HomeView.feedContent's channel-filter and availableChannels logic lives inline in a
// SwiftUI computed property, not a standalone function — mirrors this codebase's
// existing convention for view-local filter predicates (see HideShortsFilterTests,
// which replicates VideoGridSection's inline hideShorts filter the same way rather
// than extracting it). This locally reproduces both pieces of #62's logic.

@Suite("Subscriptions channel filter (#62)")
struct SubscriptionsChannelFilterTests {

    private func makeVideo(id: String, channelId: String?, channelTitle: String) -> Video {
        Video(id: id, title: id, channelTitle: channelTitle, channelId: channelId)
    }

    // Mirrors HomeView.feedContent's `.filter { channelFilter == nil || $0.channelId == channelFilter }`.
    private func apply(channelFilter: String?, to videos: [Video]) -> [Video] {
        videos.filter { channelFilter == nil || $0.channelId == channelFilter }
    }

    // Mirrors HomeView.feedContent's `availableChannels` derivation.
    private func availableChannels(from videos: [Video]) -> [(id: String, title: String)] {
        var seen = Set<String>()
        var result: [(id: String, title: String)] = []
        for video in videos {
            guard let channelId = video.channelId, seen.insert(channelId).inserted else { continue }
            result.append((id: channelId, title: video.channelTitle))
        }
        return result.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @Test("nil filter passes every video through")
    func nilFilterPassesAll() {
        let videos = [
            makeVideo(id: "v1", channelId: "chA", channelTitle: "Channel A"),
            makeVideo(id: "v2", channelId: "chB", channelTitle: "Channel B"),
        ]
        #expect(apply(channelFilter: nil, to: videos).count == 2)
    }

    @Test("a set filter keeps only videos from that channel")
    func filterKeepsOnlyMatchingChannel() {
        let videos = [
            makeVideo(id: "v1", channelId: "chA", channelTitle: "Channel A"),
            makeVideo(id: "v2", channelId: "chB", channelTitle: "Channel B"),
            makeVideo(id: "v3", channelId: "chA", channelTitle: "Channel A"),
        ]
        let filtered = apply(channelFilter: "chA", to: videos)
        #expect(filtered.map(\.id) == ["v1", "v3"])
    }

    @Test("a video with no channelId never matches a non-nil filter")
    func nilChannelIdNeverMatches() {
        let videos = [makeVideo(id: "v1", channelId: nil, channelTitle: "Unknown")]
        #expect(apply(channelFilter: "chA", to: videos).isEmpty)
    }

    @Test("availableChannels deduplicates by channelId and sorts by title")
    func availableChannelsDedupesAndSorts() {
        let videos = [
            makeVideo(id: "v1", channelId: "chB", channelTitle: "Zeta Channel"),
            makeVideo(id: "v2", channelId: "chA", channelTitle: "Alpha Channel"),
            makeVideo(id: "v3", channelId: "chB", channelTitle: "Zeta Channel"),  // duplicate channel
        ]
        let channels = availableChannels(from: videos)
        #expect(channels.map(\.id) == ["chA", "chB"])
        #expect(channels.map(\.title) == ["Alpha Channel", "Zeta Channel"])
    }

    @Test("availableChannels excludes videos with no channelId")
    func availableChannelsExcludesNilChannelId() {
        let videos = [
            makeVideo(id: "v1", channelId: nil, channelTitle: "Unknown"),
            makeVideo(id: "v2", channelId: "chA", channelTitle: "Channel A"),
        ]
        #expect(availableChannels(from: videos).map(\.id) == ["chA"])
    }
}
