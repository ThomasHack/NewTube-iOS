import Foundation
import NewTubeCore

// MARK: - RSSFeedsViewModel

/// Fetches and merges videos from all active RSS feed subscriptions.
/// Deduplicates by video ID and sorts newest-first.

@MainActor
@Observable
final class RSSFeedsViewModel {

    // MARK: - State

    private(set) var videos: [Video] = []
    private(set) var isLoading = false
    var error: Error?
    private var loadedAt: Date?

    // MARK: - Dependencies

    private let feedStore: RSSFeedStore
    private let session: URLSession

    // MARK: - Init

    init(feedStore: RSSFeedStore = .shared, session: URLSession = .shared) {
        self.feedStore = feedStore
        self.session = session
    }

    // MARK: - Load

    func load() {
        isLoading = true
        Task { [weak self] in
            guard let self else { return }
            await self.fetchAll()
            self.loadedAt = Date()
            self.isLoading = false
        }
    }

    /// Loads the feeds unless they were loaded recently, e.g. when returning to the page.
    func loadIfStale() {
        guard !isLoading, FeedFreshness.isStale(loadedAt) else { return }
        load()
    }

    private func fetchAll() async {
        let activeFeeds = await feedStore.allFeeds().filter { $0.isActive }
        guard !activeFeeds.isEmpty else {
            videos = []
            return
        }

        let sessionCopy = session
        var allVideos: [Video] = []

        await withTaskGroup(of: [Video].self) { group in
            for feed in activeFeeds {
                let feedURL = feed.feedURL
                let channelId = RSSFeedInfo.channelId(from: feedURL) ?? "unknown"
                group.addTask {
                    guard let (data, response) = try? await sessionCopy.data(from: feedURL),
                        let http = response as? HTTPURLResponse,
                        (200..<300).contains(http.statusCode)
                    else { return [] }
                    return parseYouTubeRSS(data, channelId: channelId).videos
                }
            }
            for await feedVideos in group {
                allVideos.append(contentsOf: feedVideos)
            }
        }

        var seen = Set<String>()
        videos =
            allVideos
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            .filter { seen.insert($0.id).inserted }
    }

    func removeFeed(id: UUID) {
        Task {
            await feedStore.removeFeed(id: id)
            await fetchAll()
        }
    }
}

// MARK: - Previews

#if DEBUG
extension RSSFeedsViewModel {
    /// Already shows `videos`, so a preview has no load to wait for.
    static func preview(videos: [Video] = PreviewData.rssVideos, isLoading: Bool = false) -> RSSFeedsViewModel {
        let viewModel = RSSFeedsViewModel()
        viewModel.videos = videos
        viewModel.isLoading = isLoading
        viewModel.loadedAt = Date()
        return viewModel
    }
}
#endif
