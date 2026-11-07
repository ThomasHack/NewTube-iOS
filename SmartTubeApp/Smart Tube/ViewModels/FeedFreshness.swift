import Foundation

/// How long loaded content counts as fresh. Returning to a page within this time shows what's already
/// loaded; after it, the page refreshes while keeping its current content on screen.
enum FeedFreshness {
    static let refreshInterval: TimeInterval = 5 * 60

    static func isStale(_ loadedAt: Date?, threshold: TimeInterval = refreshInterval) -> Bool {
        guard let loadedAt else { return true }
        return Date().timeIntervalSince(loadedAt) > threshold
    }
}
