import AVFoundation
import SmartTubeCore
import SwiftUI
import UIKit

// MARK: - ShortsPlayerView
//
// Full-screen vertical-swipe player for YouTube Shorts.
// Swipe up advances to the next short; swipe down goes to the previous one.
//
// AVPlayerViewController intercepts all UIKit touches before SwiftUI sees them,
// so a plain SwiftUI DragGesture layered above VideoPlayer is never delivered.
// Instead, a UIViewRepresentable installs a UIPanGestureRecognizer directly
// into the window that is set to cancel the AVPlayer's own recognizers, giving
// SwiftUI-side navigation full priority.

struct ShortsPlayerView: View {
    let startIndex: Int
    @State var videos: [Video]
    @State var vm: PlaybackViewModel
    @State var currentIndex: Int
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @Environment(SettingsStore.self) var store
    @Environment(AuthService.self) var authService
    @State var slideOffset: CGFloat = 0
    @State var isTransitioning = false
    @State var isFetchingMore = false
    /// True while the app is backgrounded — guards onDisappear from calling stop()
    /// when the system fires it as a side-effect of backgrounding rather than navigation.
    @State var isInBackground = false
    let api: InnerTubeAPI

    init(videos: [Video], startIndex: Int = 0, api: InnerTubeAPI) {
        self.startIndex = startIndex
        self.api = api
        self._videos = State(initialValue: videos)
        self._currentIndex = State(initialValue: startIndex)
        self._vm = State(initialValue: PlaybackViewModel(api: api))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                    Color.black.ignoresSafeArea()
                } else {
                    // PlayerAVLayerView instead of VideoPlayer/AVPlayerViewController.
                    // Using AVPlayerViewController (VideoPlayer) causes it to dominate
                    // the entire UIKit accessibility tree, hiding all overlaid SwiftUI
                    // elements (index badge, controls). A bare AVPlayerLayer renders
                    // video without any UIKit accessibility interference.
                    PlayerAVLayerView(player: vm.player, videoGravity: .resizeAspectFill)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }

                // Gesture capture layer — a UIViewRepresentable that installs a
                // UIPanGestureRecognizer at the UIKit level so it fires even when
                // AVPlayerViewController is absorbing touches below.

                if vm.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.5)
                        if let msg = vm.retryStatusMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.3), value: vm.retryStatusMessage)
                        }
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: vm.isLoading)
                }

                // Stats for Nerds overlay (toggled by two-finger tap)
                if vm.statsForNerdsVisible {
                    StatsForNerdsOverlay(snapshot: vm.statsSnapshot)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: vm.statsForNerdsVisible)
                }
            }
            .offset(y: slideOffset)
            .background(Color.black.ignoresSafeArea())
            // Siri Remote D-pad: up/down navigate prev/next short.
            .onMoveCommand { direction in
                guard !isTransitioning else { return }
                switch direction {
                case .up:
                    if let next = ShortsNavigation.targetIndex(
                        vertical: -100, horizontal: 0, current: currentIndex, count: videos.count)
                    {
                        performVerticalTransition(direction: -1) { goTo(next) }
                    }
                case .down:
                    if let prev = ShortsNavigation.targetIndex(
                        vertical: 100, horizontal: 0, current: currentIndex, count: videos.count)
                    {
                        performVerticalTransition(direction: 1) { goTo(prev) }
                    }
                default:
                    vm.toggleControls()
                }
            }
            // indexBadge, controls overlay, and error banner are placed OUTSIDE the
            // ZStack as overlays so UIViewRepresentable elements (SwipeGestureOverlay)
            // inside the ZStack cannot absorb them from the accessibility tree.
            .overlay(alignment: .topTrailing) {
                indexBadge
            }
            .overlay {
                if shouldShowControlsOverlay {
                    shortsOverlay
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("shorts.controlsOverlay")
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: shouldShowControlsOverlay)
                }
            }
            .overlay {
                if let err = vm.error {
                    Text(err.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("shorts.errorBanner")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isFetchingMore {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .padding(12)
                        .background(.black.opacity(0.4))
                        .clipShape(Circle())
                        .padding(.bottom, 60)
                        .padding(.trailing, 20)
                        .transition(.opacity)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                if vm.currentVideoId == videos[currentIndex].id {
                    if vm.wasPlayingBeforeSuspend { vm.resume() }
                } else {
                    loadVideo(at: currentIndex)
                }
                if ProcessInfo.processInfo.arguments.contains("--uitesting-show-controls") {
                    vm.showControls()
                    vm.cancelControlsHide()
                }
            }
            .onDisappear {
                guard !isInBackground else { return }
                vm.stop()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    isInBackground = true
                    vm.handleBackground()
                case .active:
                    isInBackground = false
                    vm.handleForeground()
                default:
                    break
                }
            }
        }  // NavigationStack
    }

    private var shouldShowControlsOverlay: Bool {
        vm.controlsVisible
    }
}
