// MARK: - ShortsFeedPolicy

public enum ShortsFeedPolicy {
    /// Whether the Home and Recommended feeds show Shorts by default. Apple TV leaves them
    /// out; its Subscriptions and other feeds aren't affected.
    public static let showsInHomeFeeds: Bool = {
        #if os(tvOS)
        false
        #else
        true
        #endif
    }()
}
