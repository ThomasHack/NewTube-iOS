import SmartTubeCore
import SwiftUI

// MARK: - Previews
//
// The player's states without a stream, so the video area is black.

#if DEBUG
extension PlayerView {
    fileprivate static func preview(
        overlay: PreviewOverlay = .none,
        highlightedControl: TVPlayerControl? = nil,
        configure: (PlaybackViewModel) -> Void = { _ in }
    ) -> some View {
        PlayerView(preview: .preview(configure: configure), overlay: overlay, highlightedControl: highlightedControl)
            .previewEnvironment()
    }
}

#Preview("Controls – Playing") { PlayerView.preview() }
#Preview("Controls – Paused") { PlayerView.preview { $0.isPlaying = false } }
#Preview("Controls – Hidden") { PlayerView.preview { $0.controlsVisible = false } }
#Preview("Controls – No chapters") { PlayerView.preview { $0.chapters = [] } }
#Preview("Controls – First video") {
    PlayerView.preview {
        $0.hasPrevious = false
        $0.chapters = []
    }
}
#Preview("Controls – Scrubbing") {
    PlayerView.preview {
        $0.isScrubbing = true
        $0.scrubTime = 450
    }
}
#Preview("Highlight – Channel") { PlayerView.preview(highlightedControl: .channel) }
#Preview("Highlight – Play/Pause") { PlayerView.preview(highlightedControl: .playPause) }
#Preview("Highlight – Next video") { PlayerView.preview(highlightedControl: .nextVideo) }
#Preview("Loading") {
    PlayerView.preview {
        $0.isLoading = true
        $0.controlsVisible = false
    }
}
#Preview("Loading – Retrying") {
    PlayerView.preview {
        $0.isLoading = true
        $0.controlsVisible = false
        $0.retryStatusMessage = "Trying another stream…"
    }
}
#Preview("Video ended") {
    PlayerView.preview {
        $0.isPlaying = false
        $0.videoEnded = true
        $0.currentTime = 635
    }
}
#Preview("Error") {
    PlayerView.preview {
        $0.isPlaying = false
        $0.controlsVisible = false
        $0.error = URLError(.notConnectedToInternet)
    }
}
#Preview("SponsorBlock skip button") {
    PlayerView.preview {
        $0.controlsVisible = false
        $0.currentToastSegment = PreviewData.sponsorSegments[0]
    }
}
#Preview("Audio only") { PlayerView.preview { $0.isAudioOnlyMode = true } }
#Preview("Hold for 2× speed") {
    PlayerView.preview {
        $0.controlsVisible = false
        $0.isHoldingToSpeed = true
    }
}
#Preview("Stats for nerds") {
    PlayerView.preview {
        $0.controlsVisible = false
        $0.statsForNerdsVisible = true
    }
}
#Preview("More menu") { PlayerView.preview(overlay: .moreMenu) }
#Preview("Picker – Speed") { PlayerView.preview(overlay: .speed) }
#Preview("Picker – Quality") { PlayerView.preview(overlay: .quality) }
#Preview("Picker – Captions") { PlayerView.preview(overlay: .captions) }
#Preview("Picker – Audio track") { PlayerView.preview(overlay: .audioTrack) }
#Preview("Picker – Sleep timer") { PlayerView.preview(overlay: .sleepTimer) }
#Preview("Description") { PlayerView.preview(overlay: .description) }
#Preview("Caption") {
    ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()
        CaptionCueView(text: "A large and lovable rabbit deals with three tiny bullies.")
            .padding(.bottom, 24)
    }
}
#endif
