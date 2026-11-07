import SmartTubeCore
import SwiftUI

// MARK: - ShortsRowSection

/// Portrait (9:16) card row/grid section.
///
/// Use `scrollAxis = .horizontal` (default) for the horizontal scrolling shelf
/// shown in all non-Shorts feed chips (Home shelf, Subscriptions, Recommended, etc.).
/// Use `scrollAxis = .vertical` for the Shorts chip so users can scroll down
/// through all Shorts naturally.
struct ShortsRowSection: View {
    let videos: [Video]
    let onSelect: (Video) -> Void
    var accessibilityID: String = ""
    /// Called when the last card becomes visible — triggers the next page load.
    var loadMore: (() -> Void)? = nil
    /// Scroll direction. Defaults to `.horizontal` (standard portrait shelf).
    /// Pass `.vertical` for the Shorts chip to enable natural downward scrolling.
    var scrollAxis: Axis.Set = .horizontal

    // MARK: - Constants

    private let cardWidth: CGFloat = 200

    /// Maximum cards shown on tvOS in horizontal mode. A 1920-pt screen holds
    /// ~9 cards at 200 pt each; capping prevents overflow and keeps focus manageable.
    private let shortsCardMaxTVCount = 9

    // MARK: - Body

    var body: some View {
        if scrollAxis == .vertical {
            verticalBody
        } else {
            horizontalBody
        }
    }

    // MARK: - Horizontal layout (all chips except Shorts)

    @ViewBuilder private var horizontalBody: some View {
        // On tvOS, ScrollView(.horizontal) consumes UP/DOWN directional events
        // from the Siri remote, trapping focus inside the row and preventing
        // navigation to the content below. Use a plain HStack capped at
        // shortsCardMaxTVCount cards instead.
        HStack(alignment: .top, spacing: videoGridRowSpacing) {
            ForEach(Array(videos.prefix(shortsCardMaxTVCount))) { video in
                Button {
                    onSelect(video)
                } label: {
                    ShortsCardView(video: video, onTap: { onSelect(video) })
                        .frame(width: cardWidth, height: cardWidth * 16 / 9)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shorts.card.\(video.id)")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .accessibilityIdentifier(accessibilityID)
        .focusSection()
    }

    // MARK: - Vertical layout (Shorts chip)

    @ViewBuilder private var verticalBody: some View {
        // tvOS: plain LazyVStack capped at shortsCardMaxTVCount — no ScrollView
        // to avoid trapping Siri remote directional events.
        LazyVStack(alignment: .leading, spacing: videoGridRowSpacing) {
            ForEach(Array(videos.prefix(shortsCardMaxTVCount))) { video in
                Button {
                    onSelect(video)
                } label: {
                    ShortsCardView(video: video, onTap: { onSelect(video) })
                        .frame(maxWidth: .infinity)
                        .aspectRatio(9 / 16, contentMode: .fit)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shorts.card.\(video.id)")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .accessibilityIdentifier(accessibilityID)
        .focusSection()
    }
}
