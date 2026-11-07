import SwiftUI
import UIKit
import os

private let swipeLog = Logger(subsystem: "com.void.smarttube.app", category: "TOSSwipe")

// MARK: - TOSSwipeNavigationOverlay
//
// Horizontal swipe-left/right navigation for the TOS (WKWebView) player —
// mirrors PlayerSwipeGestureOverlay's left/right behaviour for the AVPlayer
// pipeline (PlayerView+AVLayer.swift: left → playNext(), right → playPrevious()).
//
// Reuses PassthroughGestureView (SwipeGestureOverlay.swift) so the pan gesture
// recognizer is re-homed onto the window and never blocks touches to the
// WKWebView's own controls. To avoid stealing YouTube's native bottom
// scrubber/control-bar drag (which also uses horizontal pans for seeking),
// `gestureRecognizer(_:shouldReceive:)` only accepts touches starting in the
// top `verticalActivationFraction` of the screen.
