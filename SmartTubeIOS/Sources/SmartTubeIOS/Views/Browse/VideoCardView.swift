import SmartTubeIOSCore
import SwiftUI
import os

private let focusLog = Logger(subsystem: "com.smarttube", category: "focus")
private let feedLog = Logger(subsystem: "com.smarttube", category: "feed")

// MARK: - Notification names

extension Notification.Name {
    /// Posted when the user selects "Open Channel" from a video's context menu.
    /// userInfo keys: "channelId", "channelTitle"
    static let openChannel = Notification.Name("com.smarttube.openChannel")
    /// Posted when a feature requests navigation to the Search tab (e.g. empty-state CTA).
    static let navigateToSearch = Notification.Name("com.smarttube.navigateToSearch")
    // hideVideoFromFeed and hideChannelFromFeed are defined in SmartTubeIOSCore/FeedFeedbackNotifications.swift
}

// MARK: - VideoCardView
//
// A card showing a video thumbnail, title, channel and metadata.
// Adapts its layout for list (compact) and grid (default) modes.

public struct VideoCardView: View {
    public let video: Video
    public var compact: Bool = false
    /// When set, this is the `playlistId` of the list the user is currently browsing.
    /// Pass `"WL"` when inside the Watch Later playlist so the context menu shows
    /// "Remove from Watch Later" instead of "Save to Watch Later".
    public var currentPlaylistId: String? = nil
    /// Called when the user selects the card.
    public var onSelect: (() -> Void)? = nil

    @Environment(AuthService.self) private var authService
    @Environment(SettingsStore.self) private var store
    @Environment(\.innerTubeAPI) private var api
    @State private var localProgress: Double?
    @State private var watchLaterAlert: AlertItem?
    @State private var playlistPickerMode: PlaylistPickerSheet.Mode?
    /// Index into `video.thumbnailFallbackURLs`. -1 = use primary `thumbnailURL`.
    @State private var thumbnailFallbackIndex: Int = -1
    @FocusState private var isFocused: Bool

    private var effectiveProgress: Double? {
        localProgress ?? video.watchProgress
    }

    /// #125: falls back to `video.playlistId` when the caller doesn't explicitly pass
    /// `currentPlaylistId` (e.g. the "Watch Later" home tab, which renders through the
    /// generic HomeView section grid that has no per-card playlist context of its own) — lets
    /// Remove/Move-to-Playlist actions work there too, not just from PlaylistView.
    private var effectivePlaylistId: String? {
        currentPlaylistId ?? video.playlistId
    }

    public init(video: Video, compact: Bool = false, currentPlaylistId: String? = nil, onSelect: (() -> Void)? = nil) {
        self.video = video
        self.compact = compact
        self.currentPlaylistId = currentPlaylistId
        self.onSelect = onSelect
    }

    // MARK: - Shared card content (tasks + context menu)
    // Extracted so the body can wrap it in a Button, which handles the Select button
    // press natively.

    private var cardContent: some View {
        Group {
            if compact {
                compactLayout
            } else {
                gridLayout
            }
        }
        .task {
            localProgress = await VideoStateStore.shared.state(for: video.id)?.watchedFraction
        }
        .task(id: video.id) {
            await VideoPreloadCache.shared.prefetch(
                videoId: video.id,
                sponsorCategories: store.settings.activeSponsorCategories,
                authToken: authService.accessToken,
                priority: .visible
            )
        }
        .contextMenu {
            if let channelId = video.channelId, !channelId.isEmpty {
                Button {
                    NotificationCenter.default.post(
                        name: .openChannel,
                        object: nil,
                        userInfo: ["channelId": channelId, "channelTitle": video.channelTitle]
                    )
                } label: {
                    Label("Open Channel", systemImage: AppSymbol.personRectangle)
                }
            }
            if authService.isSignedIn {
                if effectivePlaylistId == "WL" {
                    Button(role: .destructive) {
                        // Removal is keyed by setVideoId (the playlist-entry token), not the
                        // video ID — see InnerTubeAPI+Social.swift's removeFromWatchLater (#122).
                        // It's only populated when this card came from browsing the WL playlist
                        // itself, which is the only place this button is shown.
                        // A video saved this session may be listed before YouTube indexed it,
                        // without its own token; use the one returned when it was saved.
                        guard
                            let setVideoId = video.setVideoId
                                ?? WatchLaterMembershipStore.shared.setVideoId(for: video.id)
                        else {
                            watchLaterAlert = AlertItem(
                                title: String(localized: "Could Not Remove", bundle: .module),
                                message: String(
                                    localized: "Missing playlist entry information for \"\(video.title)\".",
                                    bundle: .module)
                            )
                            return
                        }
                        Task {
                            do {
                                try await api.removeFromWatchLater(setVideoId: setVideoId)
                                WatchLaterMembershipStore.shared.markRemoved(video.id)
                                watchLaterAlert = AlertItem(
                                    title: String(localized: "Removed from Watch Later", bundle: .module),
                                    message: String(
                                        localized: "\"\(video.title)\" was removed from your Watch Later playlist.",
                                        bundle: .module)
                                )
                            } catch {
                                watchLaterAlert = AlertItem(
                                    title: String(localized: "Could Not Remove", bundle: .module),
                                    message: error.localizedDescription
                                )
                            }
                        }
                    } label: {
                        Label("Remove from Watch Later", systemImage: AppSymbol.watchLater)
                    }
                } else {
                    Button {
                        Task {
                            do {
                                let setVideoId = try await api.addToWatchLater(videoId: video.id)
                                WatchLaterMembershipStore.shared.markSaved(video, setVideoId: setVideoId)
                                watchLaterAlert = AlertItem(
                                    title: String(localized: "Saved to Watch Later", bundle: .module),
                                    message: String(
                                        localized: "\"\(video.title)\" was added to your Watch Later playlist.",
                                        bundle: .module)
                                )
                            } catch {
                                watchLaterAlert = AlertItem(
                                    title: String(localized: "Could Not Save", bundle: .module),
                                    message: error.localizedDescription
                                )
                            }
                        }
                    } label: {
                        Label("Save to Watch Later", systemImage: AppSymbol.watchLater)
                    }
                }
                Button {
                    playlistPickerMode = .copy
                } label: {
                    Label("Copy to Playlist", systemImage: "rectangle.stack.badge.plus")
                }
                if effectivePlaylistId != nil {
                    Button {
                        playlistPickerMode = .move
                    } label: {
                        Label("Move to Playlist", systemImage: "arrow.right.circle")
                    }
                }
            }
            Button {
                Task { await CurrentQueueStore.shared.append(video) }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            Button {
                Task {
                    let count = await CurrentQueueStore.shared.videos.count
                    await CurrentQueueStore.shared.insertNext(video, afterIndex: count - 1)
                }
            } label: {
                Label("Play Next", systemImage: "text.insert")
            }
            if authService.isSignedIn {
                Button(role: .destructive) {
                    Task {
                        if let token = video.notInterestedToken {
                            try? await api.sendFeedback(token: token)
                        } else {
                            try? await api.sendFeedbackForVideo(videoId: video.id, iconType: "NOT_INTERESTED")
                        }
                        NotificationCenter.default.post(
                            name: .hideVideoFromFeed,
                            object: nil,
                            userInfo: ["videoId": video.id]
                        )
                    }
                } label: {
                    Label("Not Interested", systemImage: "hand.raised")
                }
                if let channelId = video.channelId, !channelId.isEmpty {
                    Button(role: .destructive) {
                        Task {
                            if let token = video.hideChannelToken {
                                try? await api.sendFeedback(token: token)
                            } else {
                                try? await api.sendFeedbackForVideo(videoId: video.id, iconType: "BLOCK_CHANNEL")
                            }
                            store.settings.blockedChannels[channelId] = video.channelTitle
                            NotificationCenter.default.post(
                                name: .hideChannelFromFeed,
                                object: nil,
                                userInfo: ["channelId": channelId]
                            )
                        }
                    } label: {
                        Label("Don't Recommend Channel", systemImage: "person.slash")
                    }
                }
            }
        } preview: {
            Group {
                if compact {
                    compactLayout
                } else {
                    gridLayout
                }
            }
            .padding(12)
            .frame(width: 300)
            .background(.background)
        }
    }

    // MARK: - Body

    public var body: some View {
        // Modifier order is critical on tvOS:
        //
        //   cardContent  (contains .contextMenu — handles long press)
        //       .focusable()          — registers view with focus engine (D-pad navigation)
        //       .onTapGesture { }     — fires on Select press (outermost → receives event first)
        //       .focused($isFocused)  — tracks focus state (does not consume events)
        //
        // Why this order works:
        // • .onTapGesture outermost → Select button press fires the action.
        //   (.focusable() outermost broke Select because the focus engine intercepted
        //    the primary-action event before the inner tap gesture could see it.)
        // • .contextMenu innermost, co-located in the same modifier chain as
        //   .onTapGesture → SwiftUI's gesture arbiter can cancel the pending tap
        //   recogniser when it detects a long press, so long press shows the menu
        //   without also playing the video.
        // • .focusable() between contextMenu and onTapGesture keeps the view in the
        //   focus engine so D-pad UP/DOWN can reach it.
        cardContent
            .focusable()
            .onTapGesture { onSelect?() }
            .focused($isFocused)
            .onAppear { feedLog.info("[feed] id=\(self.video.id) title=\(self.video.title)") }
            .onChange(of: isFocused) { _, newValue in
                focusLog.info("[VideoCard] isFocused=\(newValue) id=\(self.video.id)")
            }
            .shadow(color: isFocused ? .white.opacity(0.9) : .clear, radius: 18, x: 0, y: 0)
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .zIndex(isFocused ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .alert(item: $watchLaterAlert) { item in
                Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
            }
            .sheet(item: $playlistPickerMode) { mode in
                PlaylistPickerSheet(
                    mode: mode, video: video, sourcePlaylistId: effectivePlaylistId, api: api,
                    onFinished: handlePlaylistPickerResult
                )
            }
    }

    private func handlePlaylistPickerResult(_ result: Result<PlaylistInfo, Error>) {
        switch result {
        case .success(let playlist):
            watchLaterAlert = AlertItem(
                title: String(localized: "Added to Playlist", bundle: .module),
                message: String(
                    localized: "\"\(video.title)\" was added to \"\(playlist.title)\".", bundle: .module)
            )
        case .failure(let error):
            watchLaterAlert = AlertItem(
                title: String(localized: "Could Not Update Playlist", bundle: .module),
                message: error.localizedDescription
            )
        }
    }

    // MARK: Grid layout (default)

    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(thumbnailView.clipped())
                .overlay(alignment: .bottom) {
                    if let progress = effectiveProgress, progress > 0 {
                        watchProgressBar(progress)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    let dur = video.formattedDuration
                    if !dur.isEmpty { durationBadge(dur) }
                }
                .overlay(alignment: .bottomLeading) {
                    if let label = uploadDateLabel { durationBadge(label) }
                }
                .overlay(alignment: .topLeading) {
                    if video.isLive { liveBadge }
                }
                .overlay(alignment: .topTrailing) {
                    if WatchLaterMembershipStore.shared.contains(video.id) { watchLaterSavedBadge }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2, reservesSpace: true)
                    .accessibilityIdentifier("video.card.title")
                Text(video.channelTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .onTapGesture {
                        guard let channelId = video.channelId, !channelId.isEmpty else { return }
                        NotificationCenter.default.post(
                            name: .openChannel,
                            object: nil,
                            userInfo: ["channelId": channelId, "channelTitle": video.channelTitle]
                        )
                    }
                    .accessibilityIdentifier("video.card.channelName")
                HStack(spacing: 4) {
                    let vc = video.formattedViewCount
                    if !vc.isEmpty { Text(vc) }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
    }

    // MARK: Compact (list) layout

    private var compactLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            thumbnailView
                .frame(width: 120, height: 68)
                .overlay(alignment: .bottom) {
                    if let progress = effectiveProgress, progress > 0 {
                        watchProgressBar(progress)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .bottomTrailing) {
                    let dur = video.formattedDuration
                    if !dur.isEmpty { durationBadge(dur) }
                }
                .overlay(alignment: .bottomLeading) {
                    if let label = uploadDateLabel { durationBadge(label) }
                }
                .overlay(alignment: .topTrailing) {
                    if WatchLaterMembershipStore.shared.contains(video.id) { watchLaterSavedBadge }
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.subheadline)
                    .lineLimit(2)
                    .accessibilityIdentifier("video.card.title")
                Text(video.channelTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        guard let channelId = video.channelId, !channelId.isEmpty else { return }
                        NotificationCenter.default.post(
                            name: .openChannel,
                            object: nil,
                            userInfo: ["channelId": channelId, "channelTitle": video.channelTitle]
                        )
                    }
                    .accessibilityIdentifier("video.card.channelName")
                let vc = video.formattedViewCount
                if !vc.isEmpty {
                    Text(vc)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())  // #153: see gridLayout's doc comment
    }

    // MARK: Shared

    /// Returns the DeArrow thumbnail URL if the feature is enabled and a timestamp is available.
    private var deArrowThumbnailURL: URL? {
        guard store.settings.deArrowEnabled,
            let ts = video.deArrowThumbnailTimestamp
        else { return nil }
        return URL(string: "https://i.ytimg.com/vi/\(video.id)/\(Int(ts)).jpg")
    }

    /// The title to show — community de-arrow title when enabled, raw title otherwise.
    private var displayTitle: String {
        if store.settings.deArrowEnabled, let t = video.deArrowTitle { return t }
        return video.title
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if video.thumbnailURL == nil, video.id == "WL" || video.id == "LL" {
            systemPlaylistThumbnail
        } else {
            // Walk a fallback chain on each successive failure:
            //   -1 → deArrowThumbnailURL (community thumbnail), else maxresdefault.jpg when
            //        High Resolution is on, else thumbnailURL (API-provided)
            //    (High Resolution only: hq720.jpg, then the standard chain below)
            //    0 → sddefault.jpg  (640×480, available for most videos)
            //    1 → hqdefault.jpg  (480×360, always available)
            //    2 → mqdefault.jpg  (320×180, always available — last resort)
            // High-res URLs are built from `/vi/<id>/`, so they only make sense for real
            // videos: playlist placeholder cards (Playlists section: id == playlistId) would
            // walk the whole chain against a playlist ID and end on a grey placeholder, and
            // Shorts would swap their portrait thumbnail for a landscape one.
            let highRes =
                store.settings.highResThumbnails && video.playlistId != video.id && !video.isShort
            let fallbacks = highRes ? video.highResThumbnailFallbackURLs : video.thumbnailFallbackURLs
            let url: URL? =
                thumbnailFallbackIndex < 0
                ? (deArrowThumbnailURL ?? (highRes ? video.maxResThumbnailURL : video.thumbnailURL) ?? fallbacks.first)
                : (thumbnailFallbackIndex < fallbacks.count ? fallbacks[thumbnailFallbackIndex] : nil)
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    let nextIndex = thumbnailFallbackIndex + 1
                    if nextIndex < fallbacks.count {
                        placeholderThumbnail
                            .onAppear { thumbnailFallbackIndex = nextIndex }
                    } else {
                        placeholderThumbnail
                    }
                default:
                    placeholderThumbnail.overlay(ProgressView())
                }
            }
            .task(id: video.id) {
                // Reset so a reused card slot always tries the primary URL for the new video.
                thumbnailFallbackIndex = -1
            }
        }
    }

    private var systemPlaylistThumbnail: some View {
        let icon = video.id == "WL" ? "clock.fill" : "hand.thumbsup.fill"
        return ZStack {
            Rectangle().fill(Color.secondary.opacity(0.15))
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.secondary)
        }
    }

    private var placeholderThumbnail: some View {
        Rectangle().fill(Color.secondary.opacity(0.2))
    }

    private func watchProgressBar(_ fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                Rectangle()
                    .fill(Color.red)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 3)
    }

    private func durationBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.black.opacity(0.75))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .padding(4)
    }

    private var uploadDateLabel: String? {
        guard !video.isLive else { return nil }
        // Upcoming/scheduled: show when the stream starts instead of an upload date.
        if video.isUpcoming {
            guard let date = video.publishedAt else { return nil }
            let cal = Calendar.current
            let timeFmt = DateFormatter()
            timeFmt.locale = .autoupdatingCurrent
            timeFmt.timeStyle = .short
            if cal.isDateInToday(date) {
                return "Scheduled: Today, \(timeFmt.string(from: date))"
            }
            if cal.isDateInTomorrow(date) {
                return "Scheduled: Tomorrow, \(timeFmt.string(from: date))"
            }
            let dateFmt = DateFormatter()
            dateFmt.locale = .autoupdatingCurrent
            dateFmt.dateStyle = .medium
            dateFmt.timeStyle = .short
            return "Scheduled: \(dateFmt.string(from: date))"
        }
        guard let date = video.publishedAt else { return nil }
        let now = Date()
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 86_400 { return "Today" }
        let days = Int(elapsed / 86_400)
        // For recent videos (<7 days) always compute fresh relative label — avoids
        // showing a stale "2 hours ago" from a cached `publishedTimeText`.
        if days < 7 { return days == 1 ? "1 day ago" : "\(days) days ago" }
        // For older videos, prefer the raw API text (e.g. "2 years ago", "3 months ago").
        // Formatting an approximate publishedAt as "May 12" looks precise but can be weeks off.
        if let raw = video.publishedTimeText, !raw.isEmpty {
            let cleaned = raw.replacingOccurrences(
                of: #"^(Streamed|Premiered|Started)\s+"#,
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty { return cleaned }
        }
        // Fallback: format the computed Date (exact for RSS feed videos, approximate for others).
        let sameYear = Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: now)
        return sameYear
            ? date.formatted(.dateTime.month(.abbreviated).day())
            : date.formatted(.dateTime.month(.abbreviated).year())
    }

    private var liveBadge: some View {
        Text("LIVE")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.red)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .padding(4)
    }

    /// #39: shown when this video was saved to Watch Later via this app. See
    /// WatchLaterMembershipStore's doc comment for why this can't reflect Watch
    /// Later state from other clients.
    private var watchLaterSavedBadge: some View {
        Image(systemName: "bookmark.fill")
            .font(.caption2)
            .padding(5)
            .background(.black.opacity(0.75))
            .foregroundStyle(.white)
            .clipShape(Circle())
            .padding(4)
            .accessibilityLabel(Text("Saved to Watch Later", bundle: .module))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Card") {
    VideoCardView(video: PreviewData.videos[0], onSelect: {})
        .frame(width: 420)
        .padding()
        .previewEnvironment()
}

#Preview("Compact") {
    VideoCardView(video: PreviewData.videos[1], compact: true, onSelect: {})
        .padding()
        .previewEnvironment()
}
#endif
