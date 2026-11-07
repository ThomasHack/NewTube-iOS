import Foundation
import Testing

@testable import SmartTubeIOSCore

// MARK: - WatchtimeTrackerOverlapTests
//
// Checkpoints overlap in practice: the TOS player ticks every 250 ms, and pause() is
// followed by saveProgress() on close. WatchtimeTracker used to update its segment state
// only after the network awaits, so overlapping calls re-sent the same watched interval
// and, near the end, the final ping more than once.

private final class StatsCountingURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var urls: [URL] = []

    static func reset() { lock.withLock { urls = [] } }
    static func watchtimePings() -> [URL] {
        lock.withLock { urls.filter { $0.path.hasSuffix("/api/stats/watchtime") } }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url { Self.lock.withLock { Self.urls.append(url) } }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
@Suite("WatchtimeTracker overlapping checkpoints", .serialized)
struct WatchtimeTrackerOverlapTests {

    private func makeTracker() -> WatchtimeTracker {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StatsCountingURLProtocol.self]
        let api = InnerTubeAPI(authToken: "fake-token", session: URLSession(configuration: config))
        let tracker = WatchtimeTracker(api: api)
        _ = tracker.transition(
            to: "overlapvid-\(UUID().uuidString)", cpn: "cpn", flushPosition: 0, flushDuration: 0)
        let bound = URL(string: "https://s.youtube.com/api/stats/watchtime?ei=E&vm=V&of=O")!
        tracker.setTrackingURLs(PlaybackTrackingURLs(playbackURL: bound, watchtimeURL: bound))
        return tracker
    }

    private func finalFlags(_ urls: [URL]) -> [Bool] {
        urls.map { url in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .contains { $0.name == "final" && $0.value == "1" } ?? false
        }
    }

    @Test("two overlapping checkpoints at the same position send one watchtime ping")
    func overlappingCheckpointsDoNotDuplicate() async {
        StatsCountingURLProtocol.reset()
        let tracker = makeTracker()
        await tracker.checkpoint(position: 10, duration: 1000)  // opens the record: [0, 10]
        let afterFirst = StatsCountingURLProtocol.watchtimePings().count

        async let a: Void = tracker.checkpoint(position: 20, duration: 1000)
        async let b: Void = tracker.checkpoint(position: 20, duration: 1000)
        _ = await (a, b)

        #expect(StatsCountingURLProtocol.watchtimePings().count - afterFirst == 1)
    }

    @Test("two overlapping near-end checkpoints send the final ping once")
    func overlappingFinalCheckpointsSendFinalOnce() async {
        StatsCountingURLProtocol.reset()
        let tracker = makeTracker()
        await tracker.checkpoint(position: 10, duration: 1000)

        async let a: Void = tracker.checkpoint(position: 990, duration: 1000)
        async let b: Void = tracker.checkpoint(position: 991, duration: 1000)
        _ = await (a, b)

        #expect(finalFlags(StatsCountingURLProtocol.watchtimePings()).filter { $0 }.count == 1)
    }

    @Test("sequential checkpoints still report each new interval")
    func sequentialCheckpointsStillReport() async {
        StatsCountingURLProtocol.reset()
        let tracker = makeTracker()
        await tracker.checkpoint(position: 10, duration: 1000)
        await tracker.checkpoint(position: 40, duration: 1000)
        await tracker.checkpoint(position: 70, duration: 1000)
        #expect(StatsCountingURLProtocol.watchtimePings().count == 3)
    }
}
