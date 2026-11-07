import CryptoKit
import Foundation

// MARK: - SettingsPINHasher (#126)
//
// Hashes the Settings-screen parental-control PIN before it's persisted in
// `AppSettings.settingsPINHash` (see AppSettings.swift), so the raw PIN never sits in
// UserDefaults. This is a speed bump against a curious kid poking at the app's own
// settings, not a defense against a determined attacker with on-device storage access —
// a 4-digit PIN's keyspace (10,000 combinations) is trivial to brute-force locally
// regardless of hashing, so a per-install salt would add complexity without adding
// real protection here.

public enum SettingsPINHasher {
    public static func hash(_ pin: String) -> String {
        SHA256.hash(data: Data(pin.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
