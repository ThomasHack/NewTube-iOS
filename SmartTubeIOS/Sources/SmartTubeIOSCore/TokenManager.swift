import Foundation

// MARK: - TokenManager
//
// Actor that owns the persisted OAuth tokens, kept in a `TokenStore` (the Keychain
// in the app).
//
// AuthService creates and holds a TokenManager, reading initial token state
// via `initialSnapshot` (nonisolated — safe from synchronous init).
// Consumers that want to react to future token changes subscribe to `updates`.
//
// Conservative scope (task #62): AuthService delegates Keychain I/O here but
// still maintains its own @Observable stored vars for UI binding. The
// AsyncStream is available for future consumer migration but not yet consumed
// by InnerTubeAPI / VideoPreloadCache.

public actor TokenManager {

    // MARK: - Types

    public enum Update: Sendable {
        case refreshed(token: String?, expiresAt: Date?)
        case signedOut
    }

    public struct Snapshot: Sendable {
        public let accessToken: String?
        public let refreshToken: String?
        public let tokenExpiry: Date?
        public let accountName: String?
        public let accountAvatarURL: URL?
        /// YouTube.com SAPISID cookie for WEB_CREATOR SAPISIDHASH auth.
        public let sapisid: String?
        /// Selected Brand Account (nil = primary account).
        public let pageId: String?
    }

    // MARK: - State

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?
    private var accountName: String?
    private var accountAvatarURL: URL?
    private var sapisid: String?
    private var pageId: String?

    private let store: any TokenStore

    // MARK: - Stream

    private var continuation: AsyncStream<Update>.Continuation?

    /// Subscribe to receive future token updates without polling AuthService.
    /// `nonisolated let` — accessible without `await`, safe cross-actor.
    public nonisolated let updates: AsyncStream<Update>

    // MARK: - Initial snapshot

    /// Snapshot of the stored values at init time.
    /// `nonisolated let` — AuthService.init() reads this without `await`.
    public nonisolated let initialSnapshot: Snapshot

    // MARK: - Init

    public init(store: any TokenStore = KeychainTokenStore()) {
        self.store = store

        var cont: AsyncStream<Update>.Continuation!
        let stream = AsyncStream<Update> { cont = $0 }
        updates = stream
        continuation = cont

        let snap = Snapshot(
            accessToken: store.value(forKey: "st_access_token"),
            refreshToken: store.value(forKey: "st_refresh_token"),
            tokenExpiry: store.value(forKey: "st_token_expiry").flatMap { ISO8601DateFormatter().date(from: $0) },
            accountName: store.value(forKey: "st_account_name"),
            accountAvatarURL: store.value(forKey: "st_avatar_url").flatMap(URL.init(string:)),
            sapisid: store.value(forKey: "st_sapisid"),
            pageId: store.value(forKey: "st_page_id")
        )
        initialSnapshot = snap
        accessToken = snap.accessToken
        refreshToken = snap.refreshToken
        tokenExpiry = snap.tokenExpiry
        accountName = snap.accountName
        accountAvatarURL = snap.accountAvatarURL
        sapisid = snap.sapisid
        pageId = snap.pageId
    }

    // MARK: - Reads

    public func currentAccessToken() -> String? { accessToken }
    public func currentRefreshToken() -> String? { refreshToken }
    public func currentTokenExpiry() -> Date? { tokenExpiry }
    public func currentAccountName() -> String? { accountName }
    public func currentAvatarURL() -> URL? { accountAvatarURL }
    public func currentPageId() -> String? { pageId }
    public func isSignedIn() -> Bool { accessToken != nil }

    // MARK: - Mutations

    public func setToken(
        access: String?,
        refresh: String?,
        expiry: Date?,
        accountName: String?,
        avatarURL: URL?
    ) {
        self.accessToken = access
        self.refreshToken = refresh
        self.tokenExpiry = expiry
        self.accountName = accountName
        self.accountAvatarURL = avatarURL
        persistToKeychain()
        continuation?.yield(.refreshed(token: access, expiresAt: expiry))
    }

    /// Persists the SAPISID cookie to Keychain so it survives app restarts and
    /// is available on the next launch without requiring a fresh cookie exchange.
    public func setSAPISID(_ value: String?) {
        sapisid = value
        store.setValue(value, forKey: "st_sapisid")
    }

    public func setPageId(_ value: String?) {
        pageId = value
        store.setValue(value, forKey: "st_page_id")
    }

    public func clearToken() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        accountName = nil
        accountAvatarURL = nil
        sapisid = nil
        pageId = nil
        deleteFromKeychain()
        continuation?.yield(.signedOut)
    }

    // MARK: - Private persistence

    private func persistToKeychain() {
        let fmt = ISO8601DateFormatter()
        store.setValue(accessToken, forKey: "st_access_token")
        store.setValue(refreshToken, forKey: "st_refresh_token")
        store.setValue(tokenExpiry.map { fmt.string(from: $0) }, forKey: "st_token_expiry")
        store.setValue(accountName, forKey: "st_account_name")
        store.setValue(accountAvatarURL?.absoluteString, forKey: "st_avatar_url")
    }

    private func deleteFromKeychain() {
        for key in [
            "st_access_token", "st_refresh_token", "st_token_expiry",
            "st_account_name", "st_avatar_url", "st_sapisid", "st_page_id",
        ] {
            store.setValue(nil, forKey: key)
        }
    }
}
