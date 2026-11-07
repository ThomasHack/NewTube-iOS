import Foundation
import SmartTubeCore

// MARK: - Comments
//
// Fetches top-level comments via InnerTubeAPI, skipping the request if they are
// already loaded or in flight. `videoId` is supplied per call.

/// Fetches and caches top-level comments for a video.
@MainActor
@Observable
final class CommentsController {

    private(set) var comments: [Comment] = []
    private(set) var isLoading = false

    private let api: InnerTubeAPI
    private let logError: (String) -> Void

    init(api: InnerTubeAPI, logError: @escaping (String) -> Void = { _ in }) {
        self.api = api
        self.logError = logError
    }

    /// Fetches top-level comments for `videoId`. No-op if already loaded or in flight.
    func load(videoId: String) {
        guard comments.isEmpty, !isLoading else { return }
        isLoading = true
        Task {
            do {
                comments = try await api.fetchComments(videoId: videoId)
            } catch {
                logError("fetchComments failed: \(String(describing: error))")
            }
            isLoading = false
        }
    }
}
