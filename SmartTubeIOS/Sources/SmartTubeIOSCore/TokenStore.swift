import Foundation

// MARK: - TokenStore

/// Where `TokenManager` persists its values. A nil value removes the entry.
public protocol TokenStore: Sendable {
    func value(forKey key: String) -> String?
    func setValue(_ value: String?, forKey key: String)
}

// MARK: - KeychainTokenStore

public struct KeychainTokenStore: TokenStore {
    private let service: String

    public init(service: String = "com.smarttube.auth") {
        self.service = service
    }

    public func value(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func setValue(_ value: String?, forKey key: String) {
        SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var query = baseQuery(forKey: key)
        query[kSecValueData] = data
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    private func baseQuery(forKey key: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
    }
}
