import AVFoundation
import AVKit
import SwiftUI
import UIKit

// MARK: - Platform-specific AVKit / UIKit views
//
// Extracted from PlayerView.swift to keep that file under 1 000 lines.

// MARK: - FullScreenPlayerLayerView (iOS)

// MARK: - AVPlayerLayerView

/// Lightweight UIViewRepresentable wrapping an `AVPlayerLayer` directly.
/// Unlike `VideoPlayer` / `AVPlayerViewController`, it does not interfere
/// with the UIKit accessibility tree so SwiftUI overlays remain reachable.
/// On tvOS, `AVPlayerViewController` would provide system transport controls
/// but `AVPlayerLayer` is used here for layout consistency with iOS.
/// Named `PlayerAVLayerView` to avoid a module-level name clash with
/// `ShortsPlayerView`, which uses this type via `videoGravity: .resizeAspectFill`.
struct PlayerAVLayerView: UIViewRepresentable {
    let player: AVPlayer?
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    var onLayerReady: ((AVPlayerLayer) -> Void)? = nil

    func makeUIView(context: Context) -> _PlayerUIView {
        let view = _PlayerUIView()
        view.backgroundColor = .black
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravity
        view.onLayerReady = onLayerReady
        return view
    }

    func updateUIView(_ uiView: _PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = videoGravity
    }

    final class _PlayerUIView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var onLayerReady: ((AVPlayerLayer) -> Void)?
        private var didFireCallback = false

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            guard newWindow != nil, !didFireCallback else { return }
            didFireCallback = true
            // Defer to next run-loop tick so the layer has a non-zero frame.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onLayerReady?(self.playerLayer)
            }
        }
    }
}

// MARK: - PiPDelegate

/// AVPictureInPictureControllerDelegate that notifies a SwiftUI closure when
/// PiP starts or stops, and implements the restore callback required for a
/// smooth transition back to full-screen without rebuffering.
final class PiPDelegate: NSObject, AVPictureInPictureControllerDelegate {
    private let onActiveChange: (Bool) -> Void
    private let onDidStart: (() -> Void)?

    init(onActiveChange: @escaping (Bool) -> Void, onDidStart: (() -> Void)? = nil) {
        self.onActiveChange = onActiveChange
        self.onDidStart = onDidStart
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        onDidStart?()
        onActiveChange(true)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        onActiveChange(false)
    }

    /// Called when the user taps the PiP window to return to the app.
    /// Must call completionHandler(true) once the UI is ready to show the video
    /// again — without this iOS cannot complete the restore animation and the
    /// player rebuffers/stutters.
    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // The AVPlayerLayer is always present and visible in PlayerView, so the
        // UI is immediately ready. Calling completionHandler(true) right away
        // lets AVKit animate the video seamlessly back into the layer.
        completionHandler(true)
    }
}

// MARK: - HoldSpeedBadge

struct HoldSpeedBadge: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "forward.fill")
                .font(.system(size: 20, weight: .semibold))
            Text("2×")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .allowsHitTesting(false)
    }
}

// MARK: - SwipeGestureOverlay (horizontal)

// MARK: - PlayerNSLayerView (macOS)
