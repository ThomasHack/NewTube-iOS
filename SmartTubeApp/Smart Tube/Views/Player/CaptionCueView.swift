import SwiftUI

// MARK: - CaptionCueView
//
// Renders the active caption cue over the video.
// Positioned at the bottom of the player just above the progress bar.
// YouTube-style: semi-transparent black pill background, white semibold text.

struct CaptionCueView: View {
    let text: String

    private var fontSize: CGFloat {
        36
    }

    private var textHorizontalPadding: CGFloat {
        18
    }

    private var textVerticalPadding: CGFloat {
        10
    }

    private var screenHorizontalPadding: CGFloat {
        80
    }

    init(text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, textHorizontalPadding)
            .padding(.vertical, textVerticalPadding)
            .background(Color.black.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            .padding(.horizontal, screenHorizontalPadding)
            .accessibilityIdentifier("player.captionCue")
    }
}
