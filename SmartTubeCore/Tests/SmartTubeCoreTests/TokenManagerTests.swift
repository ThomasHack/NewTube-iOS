import Foundation
import Synchronization
import Testing

@testable import SmartTubeCore

// MARK: - TokenManager unit tests
//
// Tests verify the four guarantees in task #62, against an in-memory store: the test
// process has no Keychain entitlement (SecItemAdd returns -34018, signed or not).
//   1. Store roundtrip: setToken data survives a fresh instance
//   2. clearToken removes all stored entries
//   3. updates stream emits .refreshed on setToken
//   4. updates stream emits .signedOut on clearToken

/// Stands in for the Keychain. Share one between `TokenManager`s to simulate an app restart.
final class InMemoryTokenStore: TokenStore {
    private let values = Mutex<[String: String]>([:])

    func value(forKey key: String) -> String? {
        values.withLock { $0[key] }
    }

    func setValue(_ value: String?, forKey key: String) {
        values.withLock { $0[key] = value }
    }
}

@Suite("TokenManager")
struct TokenManagerTests {

    // MARK: - 1. Store roundtrip

    @Test("setToken persists all fields to the store across instances")
    func setTokenPersistsToStore() async throws {
        let store = InMemoryTokenStore()
        let tm = TokenManager(store: store)
        let expiry = Date(timeIntervalSinceNow: 3600)

        await tm.setToken(
            access: "access-abc",
            refresh: "refresh-xyz",
            expiry: expiry,
            accountName: "Alice",
            avatarURL: URL(string: "https://example.com/avatar.jpg")
        )

        // New instance reads from the same store
        let tm2 = TokenManager(store: store)
        #expect(tm2.initialSnapshot.accessToken == "access-abc")
        #expect(tm2.initialSnapshot.refreshToken == "refresh-xyz")
        #expect(tm2.initialSnapshot.accountName == "Alice")
        #expect(tm2.initialSnapshot.accountAvatarURL == URL(string: "https://example.com/avatar.jpg"))
        // tokenExpiry is encoded with ISO8601 — check it survived the round-trip within 1 s
        let loadedExpiry = try #require(tm2.initialSnapshot.tokenExpiry)
        #expect(abs(loadedExpiry.timeIntervalSince(expiry)) < 1)
    }

    // MARK: - 2. clearToken removes entries

    @Test("clearToken removes all stored entries")
    func clearTokenRemovesFromStore() async throws {
        let store = InMemoryTokenStore()
        let tm = TokenManager(store: store)

        await tm.setToken(access: "tok", refresh: "ref", expiry: nil, accountName: "Bob", avatarURL: nil)
        await tm.clearToken()

        let tm2 = TokenManager(store: store)
        #expect(tm2.initialSnapshot.accessToken == nil)
        #expect(tm2.initialSnapshot.refreshToken == nil)
        #expect(tm2.initialSnapshot.accountName == nil)
    }

    // MARK: - 3. Stream emits .refreshed on setToken

    @Test("updates stream emits .refreshed when setToken is called")
    func streamEmitsRefreshedOnSetToken() async throws {
        let tm = TokenManager(store: InMemoryTokenStore())

        // Subscribe before triggering
        let task = Task<TokenManager.Update?, Never> {
            for await update in tm.updates { return update }
            return nil
        }

        await tm.setToken(access: "tok-999", refresh: nil, expiry: nil, accountName: nil, avatarURL: nil)
        let update = await task.value

        if case .refreshed(let token, _) = update {
            #expect(token == "tok-999")
        } else {
            Issue.record("Expected .refreshed, got \(String(describing: update))")
        }
    }

    // MARK: - 4. Stream emits .signedOut on clearToken

    @Test("updates stream emits .signedOut when clearToken is called")
    func streamEmitsSignedOutOnClearToken() async throws {
        let tm = TokenManager(store: InMemoryTokenStore())

        // Subscribe before triggering
        let task = Task<TokenManager.Update?, Never> {
            for await update in tm.updates { return update }
            return nil
        }

        // Yield so the consuming task has a chance to start iterating
        await Task.yield()
        await tm.clearToken()
        let update = await task.value

        if case .signedOut = update {
            // pass
        } else {
            Issue.record("Expected .signedOut, got \(String(describing: update))")
        }
    }
}
