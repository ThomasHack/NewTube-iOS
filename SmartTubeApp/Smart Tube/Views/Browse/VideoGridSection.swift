import SmartTubeCore
import SwiftUI

// MARK: - VideoGridSection

struct VideoGridSection: View {
    let videos: [Video]
    let onSelect: (Video) -> Void
    var loadMore: (() -> Void)? = nil

    @Environment(SettingsStore.self) private var store

    var body: some View {
        let compact = store.settings.compactThumbnails
        if compact {
            LazyVStack(spacing: 0) {
                ForEach(videos) { video in
                    VideoCardView(video: video, compact: true, onSelect: { onSelect(video) })
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .accessibilityIdentifier("video.card.\(video.id)")
                        .onAppear {
                            if video.id == videos.last?.id { loadMore?() }
                        }
                    Divider().padding(.horizontal)
                }
            }
            .focusSection()
        } else {
            // LazyVGrid on tvOS causes the first row of grid items to appear
            // invisible — the focus engine cannot traverse cells that have not
            // been laid out yet. Use LazyVStack + HStack rows (4 per row) instead.
            let columnCount = 4
            LazyVStack(alignment: .leading, spacing: videoGridRowSpacing) {
                ForEach(Array(stride(from: 0, to: videos.count, by: columnCount)), id: \.self) { startIdx in
                    let rowVideos = Array(videos[startIdx..<min(startIdx + columnCount, videos.count)])
                    HStack(alignment: .top, spacing: videoGridRowSpacing) {
                        ForEach(rowVideos) { video in
                            VideoCardView(video: video, compact: false, onSelect: { onSelect(video) })
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("video.card.\(video.id)")
                        }
                        let remainder = columnCount - rowVideos.count
                        if remainder > 0 {
                            ForEach(0..<remainder, id: \.self) { _ in
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .onAppear {
                        if rowVideos.last?.id == videos.last?.id { loadMore?() }
                    }
                }
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 8)
            .focusSection()
        }
    }
}

// MARK: - VideoRowSection

/// Horizontal scrolling shelf row — used for home feed shelves (layout == .row).
struct VideoRowSection: View {
    let videos: [Video]
    let onSelect: (Video) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: videoGridRowSpacing) {
                ForEach(videos) { video in
                    VideoCardView(video: video, compact: false, onSelect: { onSelect(video) })
                        .frame(width: 360)
                        .accessibilityIdentifier("video.card.\(video.id)")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .focusSection()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Grid") {
    ScrollView { VideoGridSection(videos: PreviewData.videos, onSelect: { _ in }) }
        .previewEnvironment()
}
#Preview("Row") {
    VideoRowSection(videos: PreviewData.subscriptions, onSelect: { _ in })
        .previewEnvironment()
}
#endif
