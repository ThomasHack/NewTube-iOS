#if DEBUG
import Foundation
import SmartTubeCore
import SwiftUI

// MARK: - PreviewData

/// Sample content for SwiftUI previews. Every screen has its own data, so previews of different
/// screens look different. Thumbnails load from YouTube's image CDN, so they need a network
/// connection; nothing else does, and no sign-in is required.
enum PreviewData {
    static let channel = Channel(
        id: "UCpreview",
        title: "Blender Studio",
        description: "Open movies, tutorials and production notes.",
        subscriberCount: "1.2M subscribers",
        isSubscribed: true
    )

    /// A channel whose name doesn't fit on one line.
    static let longNamedChannel = Channel(
        id: "UClong",
        title: "The International Society of Exceptionally Long Channel Names",
        subscriberCount: "48 subscribers"
    )

    static let channels: [Channel] = [
        "Blender Studio", "Computerphile", "Kurzgesagt", "Linus Tech Tips", "Mark Rober", "MKBHD", "Numberphile",
        "Veritasium",
    ]
    .enumerated().map { Channel(id: "UCchannel\($0)", title: $1, isSubscribed: true) }

    static let accountChannels: [YouTubeChannel] = [
        YouTubeChannel(name: "Preview User", avatarURL: nil, pageId: nil),
        YouTubeChannel(name: "Preview Brand Channel", avatarURL: nil, pageId: "page1"),
        YouTubeChannel(name: "Family Videos", avatarURL: nil, pageId: "page2"),
    ]

    /// The Home feed: a mix of channels and lengths.
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

    /// The Subscriptions feed: recent uploads from followed channels.
    static let subscriptions: [Video] = [
        video(
            "9bZkp7q19f0", "How GPUs actually work", channel: "Computerphile", duration: 912, views: 88_000,
            age: "2 hours ago"),
        video(
            "kJQP7kiw5Fk", "The smallest number nobody can name", channel: "Numberphile", duration: 1_204,
            views: 310_000, age: "6 hours ago"),
        video(
            "YQHsXMglC9A", "Why this bridge should not stand", channel: "Veritasium", duration: 1_532, views: 2_100_000,
            age: "Yesterday"),
        video(
            "hLQl3WQQoQ0", "We built the world's largest vending machine", channel: "Mark Rober", duration: 1_088,
            views: 9_400_000, age: "2 days ago"),
        video(
            "RgKAFK5djSk", "The best TV of the year", channel: "MKBHD", duration: 744, views: 3_300_000,
            age: "3 days ago"),
        video(
            "fJ9rUzIMcZQ", "A tour of the solar system", channel: "Kurzgesagt", duration: 660, views: 7_800_000,
            age: "4 days ago"),
        video(
            "CevxZvSJLk8", "Building the ultimate home server", channel: "Linus Tech Tips", duration: 1_390,
            views: 1_200_000, age: "5 days ago"),
        video(
            "pRpeEdMmmQ0", "Rendering a forest in real time", channel: "Blender Studio", duration: 522, views: 76_000,
            age: "1 week ago"),
    ]

    /// The signed-out Home feed, which is a search for popular videos.
    static let popular: [Video] = [
        video(
            "JGwWNGJdvx8", "The most popular video this week", channel: "Trending", duration: 263, views: 54_000_000,
            age: "1 week ago"),
        video(
            "OPf0YbXqDm0", "Top 10 moments of the year", channel: "Best Of", duration: 840, views: 21_000_000,
            age: "2 weeks ago"),
        video(
            "CevxZvSJLk8", "This went viral for a reason", channel: "Daily Clips", duration: 95, views: 12_000_000,
            age: "3 weeks ago"),
        video(
            "fJ9rUzIMcZQ", "Everyone is watching this", channel: "Trending", duration: 412, views: 8_600_000,
            age: "1 month ago"),
    ]

    /// Watch history: most videos are partly watched.
    static let history: [Video] = [
        video("eRsGyueVLvQ", "Sintel – Open Movie", duration: 888, views: 8_100_000, age: "2 years ago", progress: 0.4),
        video(
            "YQHsXMglC9A", "Why this bridge should not stand", channel: "Veritasium", duration: 1_532, views: 2_100_000,
            age: "Yesterday", progress: 1),
        video(
            "kJQP7kiw5Fk", "The smallest number nobody can name", channel: "Numberphile", duration: 1_204,
            views: 310_000, age: "6 hours ago", progress: 0.75),
        video(
            "hLQl3WQQoQ0", "We built the world's largest vending machine", channel: "Mark Rober", duration: 1_088,
            views: 9_400_000, age: "2 days ago", progress: 0.1),
    ]

    /// A playlist's videos.
    static let playlistVideos: [Video] = [
        video("aqz-KE-bpKQ", "Big Buck Bunny in 4K at 60 FPS", duration: 635, views: 12_400_000, age: "3 years ago"),
        video("eRsGyueVLvQ", "Sintel – Open Movie", duration: 888, views: 8_100_000, age: "2 years ago"),
        video("R6MlUcmOul8", "Tears of Steel", duration: 734, views: 3_200_000, age: "8 months ago"),
        video("WhWc3b3KhnY", "Spring – Open Movie", duration: 464, views: 950_000, age: "5 days ago"),
    ]

    /// Search results for "open movies".
    static let searchResults: [Video] = [
        video("WhWc3b3KhnY", "Spring – Open Movie", duration: 464, views: 950_000, age: "5 days ago"),
        video("R6MlUcmOul8", "Tears of Steel", duration: 734, views: 3_200_000, age: "8 months ago"),
        video(
            "pRpeEdMmmQ0", "How open movies get made", channel: "Blender Studio", duration: 522, views: 76_000,
            age: "1 week ago"),
    ]

    /// RSS feed items.
    static let rssVideos: [Video] = [
        video(
            "9bZkp7q19f0", "Episode 12: Writing a compiler", channel: "Tech Podcast", duration: 3_240, views: nil,
            age: "Today"),
        video(
            "RgKAFK5djSk", "Episode 11: Fonts are hard", channel: "Tech Podcast", duration: 2_880, views: nil,
            age: "Last week"),
    ]

    static let rssFeeds: [RSSFeedInfo] = [
        RSSFeedInfo(
            title: "Tech Podcast", feedURL: URL(string: "https://example.com/podcast.xml")!, isActive: true,
            addedAt: .now),
        RSSFeedInfo(
            title: "Paused Feed", feedURL: URL(string: "https://example.com/paused.xml")!, isActive: false,
            addedAt: .now),
    ]

    static let playlists: [PlaylistInfo] = [
        PlaylistInfo(id: "PLpreview1", title: "Open Movies", videoCount: 12, thumbnailURL: thumbnail("aqz-KE-bpKQ")),
        PlaylistInfo(
            id: "PLpreview2", title: "Watch on the sofa", videoCount: 4, thumbnailURL: thumbnail("eRsGyueVLvQ")),
        PlaylistInfo(id: "PLpreview3", title: "Science", videoCount: 31, thumbnailURL: thumbnail("YQHsXMglC9A")),
    ]

    /// Playlists as the Library shows them: cards whose ID is the playlist's.
    static let playlistCards: [Video] = playlists.map {
        Video(
            id: $0.id, title: $0.title, channelTitle: "\($0.videoCount ?? 0) videos", thumbnailURL: $0.thumbnailURL,
            playlistId: $0.id)
    }

    // MARK: Video cards

    static let liveVideo = videos[6]
    static let inProgressVideo = videos[1]
    static let longTitleVideo = videos[2]
    static let watchedVideo = history[1]
    static let upcomingVideo = Video(
        id: "CevxZvSJLk8", title: "Premiere: The making of the movie", channelTitle: channel.title,
        thumbnailURL: thumbnail("CevxZvSJLk8"), publishedAt: Date().addingTimeInterval(24 * 60 * 60), isUpcoming: true)
    static let noThumbnailVideo = Video(
        id: "missing", title: "A video without a thumbnail", channelTitle: channel.title)

    // MARK: Player

    static let playerVideo = Video(
        id: "aqz-KE-bpKQ",
        title: "Big Buck Bunny in 4K at 60 FPS",
        channelTitle: channel.title,
        channelId: channel.id,
        description: """
            A large and lovable rabbit deals with three tiny bullies.

            00:00 Intro
            02:30 The butterfly
            07:15 The revenge

            Made with Blender. https://www.blender.org
            """,
        thumbnailURL: thumbnail("aqz-KE-bpKQ"),
        duration: 635,
        viewCount: 12_400_000,
        publishedTimeText: "3 years ago"
    )

    static let chapters: [Chapter] = [
        Chapter(title: "Intro", startTime: 0),
        Chapter(title: "The butterfly", startTime: 150),
        Chapter(title: "The revenge", startTime: 435),
    ]

    static let sponsorSegments: [SponsorSegment] = [
        SponsorSegment(start: 60, end: 90, category: .sponsor),
        SponsorSegment(start: 300, end: 320, category: .selfPromo),
        SponsorSegment(start: 600, end: 635, category: .outro),
    ]

    static let formats: [VideoFormat] = [
        VideoFormat(label: "2160p60", width: 3840, height: 2160, fps: 60, mimeType: "video/mp4", url: nil),
        VideoFormat(label: "1080p60", width: 1920, height: 1080, fps: 60, mimeType: "video/mp4", url: nil),
        VideoFormat(label: "720p", width: 1280, height: 720, fps: 30, mimeType: "video/mp4", url: nil),
        VideoFormat(label: "480p", width: 854, height: 480, fps: 30, mimeType: "video/mp4", url: nil),
    ]

    static let audioTracks: [AudioTrack] = [
        AudioTrack(id: "en", name: "English (original)", languageCode: "en", isOriginal: true),
        AudioTrack(id: "de", name: "Deutsch", languageCode: "de", isOriginal: false),
        AudioTrack(id: "es", name: "Español", languageCode: "es", isOriginal: false),
    ]

    static let comments: [Comment] = [
        Comment(
            id: "c1", author: "Film Fan", authorAvatarURL: nil,
            text: "This holds up so well. The fur still looks great.",
            likeCount: "1.2K", publishedTime: "2 years ago", isLiked: false),
        Comment(
            id: "c2", author: "Animator", authorAvatarURL: nil,
            text:
                "Worth watching frame by frame at 02:30. A much longer comment, to check how the row wraps when somebody has a lot to say about the timing of that scene.",
            likeCount: "312", publishedTime: "1 year ago", isLiked: true),
        Comment(
            id: "c3", author: "Someone", authorAvatarURL: nil, text: "First!", likeCount: "0",
            publishedTime: "3 days ago",
            isLiked: false),
    ]

    static func thumbnail(_ id: String) -> URL? {
        URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
    }

    private static func video(
        _ id: String,
        _ title: String,
        channel channelTitle: String = channel.title,
        duration: TimeInterval?,
        views: Int?,
        age: String?,
        progress: Double? = nil,
        isLive: Bool = false
    ) -> Video {
        Video(
            id: id,
            title: title,
            channelTitle: channelTitle,
            channelId: channel.id,
            thumbnailURL: thumbnail(id),
            duration: duration,
            viewCount: views,
            // The cards only show a date for videos that have one, and older than a week uses `age`.
            publishedAt: age.map { _ in Date().addingTimeInterval(-30 * 24 * 60 * 60) },
            publishedTimeText: age,
            isLive: isLive,
            watchProgress: progress
        )
    }
}

// MARK: - PreviewInnerTubeAPI

/// An `InnerTubeAPIProtocol` that returns `PreviewData` and never touches the network.
final class PreviewInnerTubeAPI: InnerTubeAPIProtocol {
    private let searchResults: [Video]
    private let playlistVideos: [Video]
    private let playlists: [PlaylistInfo]
    private let channels: [Channel]
    /// Requests for screen content never finish, so a preview stays in its loading state.
    private let hangs: Bool
    /// Requests for screen content fail, so a preview shows its error state.
    private let fails: Bool

    init(
        searchResults: [Video] = PreviewData.searchResults,
        playlistVideos: [Video] = PreviewData.playlistVideos,
        playlists: [PlaylistInfo] = PreviewData.playlists,
        channels: [Channel] = PreviewData.channels,
        hangs: Bool = false,
        fails: Bool = false
    ) {
        self.searchResults = searchResults
        self.playlistVideos = playlistVideos
        self.playlists = playlists
        self.channels = channels
        self.hangs = hangs
        self.fails = fails
    }

    private func simulateRequest() async throws {
        if fails { throw URLError(.notConnectedToInternet) }
        if hangs { try await Task.sleep(for: .seconds(3_600)) }
    }

    private var feed: VideoGroup { VideoGroup(title: "Preview", videos: PreviewData.videos) }

    func setAuthToken(_ token: String?) async {}
    func setSAPISID(_ value: String?) async {}

    func fetchHome(continuationToken: String?) async throws -> VideoGroup {
        VideoGroup(title: "Recommended", videos: PreviewData.videos)
    }
    func fetchHomeRows(continuationToken: String?) async throws -> [VideoGroup] {
        [VideoGroup(title: "Recommended", videos: PreviewData.videos)]
    }
    func fetchSubscriptions(continuationToken: String?) async throws -> VideoGroup { feed }
    func fetchHistory(continuationToken: String?) async throws -> VideoGroup { feed }
    func fetchMusic() async throws -> VideoGroup { feed }
    func fetchGaming() async throws -> VideoGroup { feed }
    func fetchNews() async throws -> VideoGroup { feed }
    func fetchLive() async throws -> VideoGroup { feed }
    func fetchSports() async throws -> VideoGroup { feed }

    func fetchUserPlaylists() async throws -> [PlaylistInfo] {
        try await simulateRequest()
        return playlists
    }
    func fetchSubscribedChannels() async throws -> [Channel] { channels }

    func fetchChannelThumbnailURL(channelId: String) async throws -> URL? { nil }
    func fetchChannel(channelId: String) async throws -> (channel: Channel, videos: VideoGroup) {
        try await simulateRequest()
        return (PreviewData.channel, feed)
    }
    func fetchChannelVideos(channelId: String, continuationToken: String?) async throws -> VideoGroup { feed }

    func search(query: String, continuationToken: String?, filter: SearchFilter) async throws -> VideoGroup {
        try await simulateRequest()
        return VideoGroup(title: "Results", videos: continuationToken == nil ? searchResults : [])
    }
    func fetchSearchSuggestions(query: String) async throws -> [String] {
        ["\(query) trailer", "\(query) full movie", "\(query) behind the scenes"]
    }

    func fetchPlaylistVideos(playlistId: String, continuationToken: String?) async throws -> VideoGroup {
        try await simulateRequest()
        return VideoGroup(title: "Playlist", videos: continuationToken == nil ? playlistVideos : [])
    }

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
    static func preview(
        query: String = "", results: [Video] = PreviewData.searchResults, hangs: Bool = false, fails: Bool = false
    ) -> SearchViewModel {
        let store = SearchHistoryStore(suiteName: "preview.search")
        let api = PreviewInnerTubeAPI(searchResults: results, hangs: hangs, fails: fails)
        let vm = SearchViewModel(api: api, historyStore: store)
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

// MARK: - PlaybackViewModel

extension PlaybackViewModel {
    /// A player showing its controls over `PreviewData.playerVideo`, partway through and without
    /// any stream. `configure` changes it into the state being previewed.
    static func preview(configure: (PlaybackViewModel) -> Void = { _ in }) -> PlaybackViewModel {
        let vm = PlaybackViewModel()
        vm.currentVideo = PreviewData.playerVideo
        vm.duration = 635
        vm.currentTime = 212
        vm.isPlaying = true
        vm.controlsVisible = true
        vm.chapters = PreviewData.chapters
        vm.sponsorSegments = PreviewData.sponsorSegments
        vm.availableFormats = PreviewData.formats
        vm.availableAudioTracks = PreviewData.audioTracks
        vm.selectedAudioTrack = PreviewData.audioTracks[0]
        vm.hasPrevious = true
        vm.hasNext = true
        configure(vm)
        return vm
    }
}

// MARK: - previewEnvironment

extension View {
    /// Injects everything the app's views expect from the environment.
    ///
    /// - Parameters:
    ///   - browseVM: What the Library shows. Defaults to a loaded History.
    ///   - settings: Changes to the default settings. No PIN is set unless this sets one.
    func previewEnvironment(
        signedIn: Bool = true,
        browseVM: BrowseViewModel? = nil,
        librarySection: LibraryView.LibrarySection = .history,
        rss: RSSFeedsViewModel? = nil,
        sidebarChannels: SidebarChannelsViewModel? = nil,
        accountChannels: [YouTubeChannel] = PreviewData.accountChannels,
        settings: @escaping (inout AppSettings) -> Void = { _ in }
    ) -> some View {
        modifier(
            PreviewEnvironment(
                signedIn: signedIn,
                browseVM: browseVM,
                librarySection: librarySection,
                rss: rss,
                sidebarChannels: sidebarChannels,
                accountChannels: accountChannels,
                settings: settings
            ))
    }
}

private struct PreviewEnvironment: ViewModifier {
    @State private var auth: AuthService
    @State private var settings: SettingsStore
    @State private var browseVM: BrowseViewModel
    @State private var searchVM = SearchViewModel.preview()
    @State private var navigator = AppNavigator()
    @State private var sidebarChannels: SidebarChannelsViewModel
    @State private var feeds: AppFeeds

    init(
        signedIn: Bool,
        browseVM: BrowseViewModel?,
        librarySection: LibraryView.LibrarySection,
        rss: RSSFeedsViewModel?,
        sidebarChannels: SidebarChannelsViewModel?,
        accountChannels: [YouTubeChannel],
        settings configure: (inout AppSettings) -> Void
    ) {
        let auth = AuthService()
        auth.isSignedIn = signedIn
        // Only ever reaches PreviewInnerTubeAPI, which ignores it.
        auth.accessToken = signedIn ? "preview-token" : nil
        auth.accountName = signedIn ? "Preview User" : nil
        auth.channels = signedIn ? accountChannels : []
        _auth = State(initialValue: auth)

        // Defaults rather than whatever an earlier preview saved, such as a PIN.
        let store = SettingsStore()
        var values = AppSettings()
        configure(&values)
        store.settings = values
        _settings = State(initialValue: store)

        _browseVM = State(
            initialValue: browseVM
                ?? .preview(librarySection: librarySection, state: .loaded(PreviewData.history), signedIn: signedIn))
        _sidebarChannels = State(
            initialValue: sidebarChannels ?? SidebarChannelsViewModel.preview(signedIn: signedIn))
        let feeds = AppFeeds(api: PreviewInnerTubeAPI(), rss: rss ?? RSSFeedsViewModel.preview())
        feeds.librarySection = librarySection
        _feeds = State(initialValue: feeds)
    }

    func body(content: Content) -> some View {
        content
            .environment(auth)
            .environment(settings)
            .environment(browseVM)
            .environment(searchVM)
            .environment(navigator)
            .environment(sidebarChannels)
            .environment(feeds)
            .tint(settings.settings.accentColor.color)
    }
}
#endif
