import Foundation
import Testing

@testable import NewTubeCore

// MARK: - LocalWatchHistoryStoreTests (#150)

@MainActor
@Suite("LocalWatchHistoryStore (#150)")
struct LocalWatchHistoryStoreTests {

    private struct Fixture {
        let store: LocalWatchHistoryStore
        let defaults: UserDefaults
        let suite: String
    }

    private func makeFixture() throws -> Fixture {
        let suite = "LocalWatchHistoryStoreTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return Fixture(store: LocalWatchHistoryStore(defaults: defaults), defaults: defaults, suite: suite)
    }

    private func video(_ id: String) -> Video {
        Video(id: id, title: "Title \(id)", channelTitle: "Chan", channelId: "UC1")
    }

    @Test("records most recent first")
    func mostRecentFirst() throws {
        let fixture = try makeFixture()
        let store = fixture.store
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        store.record(video("a"), at: Date(timeIntervalSince1970: 1))
        store.record(video("b"), at: Date(timeIntervalSince1970: 2))
        #expect(store.videos.map(\.id) == ["b", "a"])
    }

    @Test("re-watching a video moves it to the front without duplicating")
    func dedupeMovesToFront() throws {
        let fixture = try makeFixture()
        let store = fixture.store
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        store.record(video("a"))
        store.record(video("b"))
        store.record(video("a"))
        #expect(store.videos.map(\.id) == ["a", "b"])
    }

    @Test("caps at maxEntries, evicting the oldest")
    func capsEntries() throws {
        let fixture = try makeFixture()
        let store = fixture.store
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        for index in 0..<(LocalWatchHistoryStore.maxEntries + 5) { store.record(video("v\(index)")) }
        #expect(store.entries.count == LocalWatchHistoryStore.maxEntries)
        #expect(store.videos.first?.id == "v\(LocalWatchHistoryStore.maxEntries + 4)")
        #expect(!store.videos.contains { $0.id == "v0" })
    }

    @Test("persists across instances sharing the same defaults")
    func persists() throws {
        let fixture = try makeFixture()
        let store = fixture.store
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        store.record(video("a"))
        let reloaded = LocalWatchHistoryStore(defaults: fixture.defaults)
        #expect(reloaded.videos.map(\.id) == ["a"])
    }

    @Test("clear removes everything, including from disk")
    func clearEmpties() throws {
        let fixture = try makeFixture()
        let store = fixture.store
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        store.record(video("a"))
        store.clear()
        #expect(store.videos.isEmpty)
        #expect(LocalWatchHistoryStore(defaults: fixture.defaults).videos.isEmpty)
    }

    @Test("stored entries keep display fields but drop per-fetch tokens")
    func slimsVideo() throws {
        let fixture = try makeFixture()
        let store = fixture.store
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        var item = video("a")
        item.notInterestedToken = "secret-token"
        store.record(item)
        #expect(store.videos.first?.title == "Title a")
        #expect(store.videos.first?.notInterestedToken == nil)
    }
}
