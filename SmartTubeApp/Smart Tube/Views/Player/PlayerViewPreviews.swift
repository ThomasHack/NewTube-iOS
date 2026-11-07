import SmartTubeCore
import SwiftUI

// MARK: - Previews
//
// The app's additions to the system player. The player's own controls need a real stream, so try
// those in the running app.

#if DEBUG
extension PlayerContentOverlay {
    fileprivate static func preview(configure: (PlaybackViewModel) -> Void) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PlayerContentOverlay(vm: .preview(configure: configure))
        }
    }
}

#Preview("Player") {
    PlayerView(preview: .preview())
        .previewEnvironment()
}
#Preview("Player – Error") {
    PlayerView(preview: .preview { $0.error = URLError(.notConnectedToInternet) })
        .previewEnvironment()
}
#Preview("Overlay – Retrying") {
    PlayerContentOverlay.preview { $0.retryStatusMessage = "Trying another stream…" }
}
#Preview("Overlay – Audio only") {
    PlayerContentOverlay.preview { $0.isAudioOnlyMode = true }
}
#Preview("Overlay – Stats for nerds") {
    PlayerContentOverlay.preview { $0.statsForNerdsVisible = true }
}
#Preview("Caption") {
    ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()
        CaptionCueView(text: "A large and lovable rabbit deals with three tiny bullies.")
            .padding(.bottom, 60)
    }
}
#endif
