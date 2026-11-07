import AVFoundation
import AVKit
import SwiftUI
import UIKit

// MARK: - AVPlayerLayerView

/// Lightweight UIViewRepresentable wrapping an `AVPlayerLayer` directly.
/// Unlike `VideoPlayer` / `AVPlayerViewController`, it does not interfere
/// with the UIKit accessibility tree so SwiftUI overlays remain reachable.
/// `AVPlayerViewController` would also bring system transport controls, which the
/// custom player UI replaces.
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
