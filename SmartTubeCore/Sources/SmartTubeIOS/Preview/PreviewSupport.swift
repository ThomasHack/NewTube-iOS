#if DEBUG
import Foundation
import SmartTubeIOSCore
import SwiftUI

// MARK: - PreviewData

/// Sample content for SwiftUI previews. Thumbnails load from YouTube's image CDN, so they
/// need a network connection; nothing else does, and no sign-in is required.
enum PreviewData {
    static let channel = Channel(
        id: "UCpreview",
        title: "Blender Studio",
        description: "Open movies, tutorials and production notes.",
        subscriberCount: "1.2M subscribers",
        isSubscribed: true
    )

    static let videos: [Video] = [
        video("aqz-KE-bpKQ", "Big Buck Bunny in 4K at 60 FPS", duration: 635, views: 12_400_000, age: "3 years ago"),
        video("eRsGyueVLvQ", "Sintel – Open Movie", duration: 888, views: 8_100_000, age: "2 years ago", progress: 0.4),
        video(
            "R6MlUcmOul8",
            "Tears of Steel – A very long video title that needs to wrap onto more than one line to test truncation",
            duration: 734,
            views: 3_200_000,
            age: "8 months ago"
        ),
        video("WhWc3b3KhnY", "Spring – Open Movie", duration: 464, views: 950_000, age: "5 days ago"),
        video("dQw4w9WgXcQ", "Never Gonna Give You Up", duration: 213, views: 1_400_000_000, age: "15 years ago"),
        video("jNQXAC9IVRw", "Me at the zoo", duration: 19, views: 340_000_000, age: "20 years ago"),
        video("JGwWNGJdvx8", "Live: Studio session", duration: nil, views: 12_000, age: nil, isLive: true),
        video("OPf0YbXqDm0", "Behind the scenes", duration: 3_725, views: 41_000, age: "1 hour ago"),
    ]

    static let shorts: [Video] = [
        short("9bZkp7q19f0", "A quick tip in under a minute"),
        short("kJQP7kiw5Fk", "How this shot was made"),
        short("YQHsXMglC9A", "Studio tour"),
        short("hLQl3WQQoQ0", "Sixty-second recap"),
    ]

    static let playlists: [PlaylistInfo] = [
        PlaylistInfo(id: "PLpreview1", title: "Open Movies", videoCount: 12, thumbnailURL: thumbnail("aqz-KE-bpKQ")),
        PlaylistInfo(
            id: "PLpreview2", title: "Watch on the sofa", videoCount: 4, thumbnailURL: thumbnail("eRsGyueVLvQ")),
    ]

    static func thumbnail(_ id: String) -> URL? {
        URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
    }

    private static func video(
        _ id: String,
        _ title: String,
        duration: TimeInterval?,
        views: Int,
        age: String?,
        progress: Double? = nil,
        isLive: Bool = false
    ) -> Video {
        Video(
            id: id,
            title: title,
            channelTitle: channel.title,
            channelId: channel.id,
            thumbnailURL: thumbnail(id),
            duration: duration,
            viewCount: views,
            publishedTimeText: age,
            isLive: isLive,
            watchProgress: progress
        )
    }

    private static func short(_ id: String, _ title: String) -> Video {
        Video(
            id: id,
            title: title,
            channelTitle: channel.title,
            channelId: channel.id,
            thumbnailURL: thumbnail(id),
            duration: 45,
            viewCount: 250_000,
            isShort: true
        )
    }
}

// MARK: - PreviewInnerTubeAPI

/// An `InnerTubeAPIProtocol` that returns `PreviewData` and never touches the network.
final class PreviewInnerTubeAPI: InnerTubeAPIProtocol {
    private let searchResults: [Video]

    init(searchResults: [Video] = PreviewData.videos) {
        self.searchResults = searchResults
    }

    private var feed: VideoGroup { VideoGroup(title: "Preview", videos: PreviewData.videos) }

    func setAuthToken(_ token: String?) async {}
    func setSAPISID(_ value: String?) async {}

    func fetchHome(continuationToken: String?) async throws -> VideoGroup {
        VideoGroup(title: "Recommended", videos: PreviewData.videos + PreviewData.shorts)
    }
    func fetchHomeRows(continuationToken: String?) async throws -> [VideoGroup] {
        [VideoGroup(title: "Recommended", videos: PreviewData.videos + PreviewData.shorts)]
    }
    func fetchSubscriptions(continuationToken: String?) async throws -> VideoGroup { feed }
    func fetchHistory(continuationToken: String?) async throws -> VideoGroup { feed }
    func fetchShorts() async throws -> VideoGroup { VideoGroup(title: "Shorts", videos: PreviewData.shorts) }
    func fetchShortsMore(continuationToken: String) async throws -> VideoGroup { VideoGroup() }
    func fetchMusic() async throws -> VideoGroup { feed }
    func fetchGaming() async throws -> VideoGroup { feed }
    func fetchNews() async throws -> VideoGroup { feed }
    func fetchLive() async throws -> VideoGroup { feed }
    func fetchSports() async throws -> VideoGroup { feed }

    func fetchUserPlaylists() async throws -> [PlaylistInfo] { PreviewData.playlists }
    func fetchSubscribedChannels() async throws -> [Channel] { [PreviewData.channel] }

    func fetchChannelThumbnailURL(channelId: String) async throws -> URL? { nil }
    func fetchChannel(channelId: String) async throws -> (channel: Channel, videos: VideoGroup) {
        (PreviewData.channel, feed)
    }
    func fetchChannelVideos(channelId: String, continuationToken: String?) async throws -> VideoGroup { feed }

    func search(query: String, continuationToken: String?, filter: SearchFilter) async throws -> VideoGroup {
        VideoGroup(title: "Results", videos: continuationToken == nil ? searchResults : [])
    }
    func fetchSearchSuggestions(query: String) async throws -> [String] {
        ["\(query) trailer", "\(query) full movie", "\(query) behind the scenes"]
    }

    func fetchPlaylistVideos(playlistId: String, continuationToken: String?) async throws -> VideoGroup { feed }

    func addToWatchLater(videoId: String) async throws -> String? { nil }
    func removeFromWatchLater(setVideoId: String) async throws {}
    func addToPlaylist(playlistId: String, videoId: String) async throws {}
    func removeFromPlaylist(playlistId: String, setVideoId: String) async throws {}
    func sendFeedback(token: String) async throws {}
    func sendFeedbackForVideo(videoId: String, iconType: String) async throws {}
}

// MARK: - SearchViewModel

extension SearchViewModel {
    /// A search screen with sample history, in the state reached by typing `query`.
    static func preview(query: String = "", results: [Video] = PreviewData.videos) -> SearchViewModel {
        let store = SearchHistoryStore(suiteName: "preview.search")
        let vm = SearchViewModel(api: PreviewInnerTubeAPI(searchResults: results), historyStore: store)
        Task {
            await store.clear()
            await store.add("lofi hip hop")
            await store.add("open movies")
            await vm.loadHistory()
        }
        if !query.isEmpty {
            vm.query = query
            Task { await vm.searchAsYouType(debounce: .zero) }
        }
        return vm
    }
}

// MARK: - Preview environment

extension View {
    /// Supplies everything `RootView` normally injects, backed by sample data. To override
    /// one of these values, apply `.environment(_:)` before this modifier, not after: the
    /// value nearest the view wins.
    func previewEnvironment(signedIn: Bool = true) -> some View {
        modifier(PreviewEnvironment(signedIn: signedIn))
    }
}

private struct PreviewEnvironment: ViewModifier {
    @State private var auth: AuthService
    @State private var settings = SettingsStore()
    @State private var browseVM = BrowseViewModel(api: PreviewInnerTubeAPI())
    @State private var searchVM = SearchViewModel.preview()

    init(signedIn: Bool) {
        let auth = AuthService()
        auth.isSignedIn = signedIn
        // Only ever reaches PreviewInnerTubeAPI, which ignores it.
        auth.accessToken = signedIn ? "preview-token" : nil
        auth.accountName = signedIn ? "Preview User" : nil
        _auth = State(initialValue: auth)
    }

    func body(content: Content) -> some View {
        content
            .environment(auth)
            .environment(settings)
            .environment(browseVM)
            .environment(searchVM)
            .tint(settings.settings.accentColor.color)
            .task(id: auth.accessToken) { await browseVM.updateAuthToken(auth.accessToken) }
    }
}
#endif
