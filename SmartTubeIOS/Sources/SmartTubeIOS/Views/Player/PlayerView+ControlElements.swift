import AVFoundation
import AVKit
import SmartTubeIOSCore
import SwiftUI
import UIKit

private let controlsLog = AppLogger(category: "Player")

// MARK: - PlayerControlsOverlay
//
// Dedicated view for the interactive transport controls overlaid on the player.
// Extracted from PlayerView.body to reduce the compiled function size and
// the Swift generic type tree depth in __swift5_typeref.

struct PlayerControlsOverlay: View {
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    let video: Video
    let controlScale: CGFloat
    @Binding var showMoreMenu: Bool
    @Binding var channelDestination: ChannelDestination?

    let vm: PlaybackViewModel
    @Binding var highlightedControl: PlayerView.TVPlayerControl?
    @Environment(SettingsStore.self) var store
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack {
            // Top bar: back + title
            HStack {
                tvOverlayControl(
                    highlighted: highlightedControl == .back,
                    scale: 1.5,
                    shadowRadius: 12,
                    identifier: "player.backButton",
                    width: 64,
                    height: 64
                ) {
                    Image(systemName: AppSymbol.chevronLeft)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.playerInfo?.video.title ?? video.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .accessibilityIdentifier("player.titleLabel")
                    let channelId = vm.playerInfo?.video.channelId ?? video.channelId
                    let channelTitle = vm.playerInfo?.video.channelTitle ?? video.channelTitle
                    tvOverlayControl(
                        highlighted: highlightedControl == .channel,
                        scale: 1.5,
                        shadowRadius: 12,
                        identifier: "player.channelName",
                        enabled: channelId?.isEmpty == false
                    ) {
                        Text(channelTitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                Spacer()
                // Share / Download menu
                tvOverlayControl(
                    highlighted: highlightedControl == .more,
                    scale: 1.5,
                    shadowRadius: 12,
                    identifier: "player.moreButton",
                    width: 64,
                    height: 64
                ) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18 * controlScale))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 0)

            Spacer()

            // Centre: rewind / play-pause / forward
            HStack(spacing: 40) {
                seekButton(
                    symbol: "gobackward.\(store.settings.seekBackSeconds)",
                    seconds: -Double(store.settings.seekBackSeconds),
                    tvHighlighted: highlightedControl == .seekBack)
                playPauseButton
                seekButton(
                    symbol: "goforward.\(store.settings.seekForwardSeconds)",
                    seconds: Double(store.settings.seekForwardSeconds),
                    tvHighlighted: highlightedControl == .seekForward)
            }
            .disabled(vm.isLoading)
            .opacity(vm.isLoading ? 0.3 : 1)

            Spacer()

            // Bottom: progress bar + prev/next
            VStack(spacing: 8) {
                // Current chapter title — shown whenever chapters are available
                if let chapter = vm.currentChapter {
                    Text(chapter.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: chapter.title)
                }
                progressBar
                HStack {
                    // Previous video button
                    tvOverlayControl(
                        highlighted: highlightedControl == .prevVideo,
                        scale: 1.55,
                        shadowRadius: 14,
                        identifier: "player.prevBtn",
                        enabled: vm.hasPrevious && !vm.isLoading,
                        width: 64,
                        height: 64
                    ) {
                        Image(systemName: AppSymbol.previousTrack)
                            .font(.system(size: 18 * controlScale))
                            .foregroundStyle(vm.hasPrevious && !vm.isLoading ? .white : .white.opacity(0.3))
                    }

                    // Previous chapter button — only present when the video has chapters
                    if !vm.chapters.isEmpty {
                        tvOverlayControl(
                            highlighted: highlightedControl == .prevChapter,
                            scale: 1.55,
                            shadowRadius: 14,
                            identifier: "player.prevChapterBtn",
                            enabled: vm.hasPreviousChapter && !vm.isLoading,
                            width: 64,
                            height: 64
                        ) {
                            Image(systemName: AppSymbol.previousChapter)
                                .font(.system(size: 18 * controlScale))
                                .foregroundStyle(vm.hasPreviousChapter && !vm.isLoading ? .white : .white.opacity(0.3))
                        }
                    }

                    Spacer()

                    // Next chapter button — only present when the video has chapters
                    if !vm.chapters.isEmpty {
                        tvOverlayControl(
                            highlighted: highlightedControl == .nextChapter,
                            scale: 1.55,
                            shadowRadius: 14,
                            identifier: "player.nextChapterBtn",
                            enabled: vm.hasNextChapter && !vm.isLoading,
                            width: 64,
                            height: 64
                        ) {
                            Image(systemName: AppSymbol.nextChapter)
                                .font(.system(size: 18 * controlScale))
                                .foregroundStyle(vm.hasNextChapter && !vm.isLoading ? .white : .white.opacity(0.3))
                        }
                    }

                    // Next video button
                    tvOverlayControl(
                        highlighted: highlightedControl == .nextVideo,
                        scale: 1.55,
                        shadowRadius: 14,
                        identifier: "player.nextBtn",
                        enabled: vm.hasNext,
                        width: 64,
                        height: 64
                    ) {
                        Image(systemName: AppSymbol.nextTrack)
                            .font(.system(size: 18 * controlScale))
                            .foregroundStyle(vm.hasNext ? .white : .white.opacity(0.3))
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear, .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .contentShape(Rectangle())
            .onTapGesture {
                controlsLog.notice("[menu] gradient background tap — controlsVisible=\(vm.controlsVisible)")
                vm.toggleControls()
            }
        )
        // Controls overlay is not a focus section — the outer view handles all input.
        .onTapGesture { vm.toggleControls() }
    }
}

// MARK: - Control element views

extension PlayerControlsOverlay {

    /// The outer player routes remote input; labels avoid tvOS 26's forced Liquid Glass button chrome.
    func tvOverlayControl<Content: View>(
        highlighted: Bool,
        scale: CGFloat,
        shadowOpacity: Double = 0.85,
        shadowRadius: CGFloat,
        identifier: String,
        enabled: Bool = true,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: width, height: height)
            .scaleEffect(highlighted ? scale : 1)
            .shadow(color: highlighted ? .white.opacity(shadowOpacity) : .clear, radius: shadowRadius)
            .animation(.easeInOut(duration: 0.15), value: highlighted)
            .disabled(!enabled)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(identifier)
    }

    // MARK: - Play / Pause

    @ViewBuilder
    var playPauseButton: some View {
        tvOverlayControl(
            highlighted: highlightedControl == .playPause,
            scale: 1.6,
            shadowOpacity: 0.65,
            shadowRadius: 8,
            identifier: "player.playPauseButton",
            width: 88,
            height: 88
        ) {
            playPauseIcon
        }
    }

    var playPauseIcon: some View {
        Image(systemName: vm.videoEnded ? "arrow.counterclockwise" : (vm.isPlaying ? "pause.fill" : "play.fill"))
            .renderingMode(.original)
            .font(.system(size: 42 * controlScale))
            .foregroundStyle(.white)
    }

    // MARK: - Seek buttons

    @ViewBuilder
    func seekButton(symbol: String, seconds: TimeInterval, tvHighlighted: Bool = false) -> some View {
        tvOverlayControl(
            highlighted: tvHighlighted,
            scale: 1.55,
            shadowOpacity: 0.6,
            shadowRadius: 7,
            identifier: seconds < 0 ? "player.seekBackButton" : "player.seekForwardButton",
            width: 72,
            height: 72
        ) {
            seekIcon(symbol: symbol)
        }
    }

    func seekIcon(symbol: String) -> some View {
        Image(systemName: symbol)
            .renderingMode(.original)
            .font(.system(size: 28 * controlScale))
            .foregroundStyle(.white)
    }

    // MARK: - Progress bar

    var progressBar: some View {
        tvProgressBar
    }

    var iosProgressBar: some View {
        // Wrap in an outer GeometryReader so the highPriorityGesture below can
        // reference the bar's width.  The gesture is placed on the full-height
        // VStack (tooltip row + track row = 60 pt) so any touch in that area —
        // including the 28 pt invisible tooltip strip above the visible bar — will
        // activate the scrub drag.  Previously the gesture was only on the inner
        // 28 pt track ZStack, which meant touches on the empty tooltip row were
        // silently swallowed without triggering the seek.
        GeometryReader { outerGeo in
            let hPad: CGFloat = 20
            let trackW = outerGeo.size.width - hPad * 2

            VStack(spacing: 4) {
                // Tooltip row — always occupies space so layout doesn't jump
                GeometryReader { geo in
                    if vm.isScrubbing && vm.duration > 0 {
                        let fraction = CGFloat(vm.scrubTime / vm.duration)
                        let thumbX = hPad + trackW * fraction
                        let chapterAtScrub = vm.chapters.last(where: { $0.startTime <= vm.scrubTime })
                        let labelW: CGFloat = chapterAtScrub != nil ? min(outerGeo.size.width * 0.5, 180) : 64
                        let clampedX = min(max(thumbX, hPad + labelW / 2), outerGeo.size.width - hPad - labelW / 2)

                        VStack(spacing: 2) {
                            if let chapter = chapterAtScrub {
                                Text(chapter.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            Text(formatDuration(vm.scrubTime))
                                .font(.caption.monospacedDigit())
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                        .frame(width: labelW)
                        .position(x: clampedX, y: geo.size.height / 2)
                    }
                }
                .frame(height: 28)

                // Track + slider row (custom — fully transparent thumb and track)
                GeometryReader { geo in
                    let time = vm.isScrubbing ? vm.scrubTime : vm.currentTime
                    let progress = vm.duration > 0 ? CGFloat(time / vm.duration) : 0
                    let thumbX = hPad + trackW * progress

                    ZStack {
                        // Background track
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                            .padding(.horizontal, hPad)

                        // Progress fill
                        HStack(spacing: 0) {
                            Capsule()
                                .fill(Color.red.opacity(0.5))
                                .frame(width: max(thumbX - hPad, 0), height: 4)
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, hPad)

                        // Thumb
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 16, height: 16)
                            .position(x: thumbX, y: geo.size.height / 2)
                    }
                    .overlay(sponsorBlockMarkers)
                    .overlay(chapterMarkers)
                }
                .frame(height: 28)
            }
            .contentShape(Rectangle())
        }
        .frame(height: 60)
        .accessibilityIdentifier("player.progressBar")
    }

    // Chapter tick marks on the progress bar — small white notches at each chapter boundary.
    // Each tick has a 24×44 pt transparent tap area so the user can tap to jump to it.
    var chapterMarkers: some View {
        GeometryReader { geo in
            let hPad: CGFloat = 20
            let trackW = geo.size.width - hPad * 2
            ForEach(vm.chapters) { chapter in
                let x = hPad + trackW * CGFloat(chapter.startTime / max(vm.duration, 1))
                ZStack {
                    // Invisible enlarged hit area
                    Color.clear
                        .frame(width: 24, height: 44)
                    // Visible tick
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 2, height: 12)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !vm.isScrubbing else { return }
                    vm.seek(to: chapter.startTime)
                }
                .position(x: x, y: geo.size.height / 2)
            }
        }
    }

    // SponsorBlock segment markers on the progress bar
    var sponsorBlockMarkers: some View {
        GeometryReader { geo in
            let hPad: CGFloat = 20
            let trackW = geo.size.width - hPad * 2
            ForEach(vm.sponsorSegments) { seg in
                let x = hPad + trackW * CGFloat(seg.start / max(vm.duration, 1))
                let w = trackW * CGFloat((seg.end - seg.start) / max(vm.duration, 1))
                Rectangle()
                    .fill(seg.category.color.opacity(0.8))
                    .frame(width: max(w, 2), height: 4)
                    .position(x: x + w / 2, y: geo.size.height / 2)
            }
        }
    }
}

// MARK: - Slide transition + toast/error (PlayerView extension)

extension PlayerView {

    // MARK: - Slide transition

    /// Animates the current content off-screen in `direction` (-1 = left, +1 = right),
    /// runs `action` to load the next/previous video, then slides the new content in
    /// from the opposite side.
    func performHorizontalTransition(direction: CGFloat, screenWidth: CGFloat, action: @escaping () -> Void) {
        // Set the re-entry guard synchronously so any concurrent gesture event
        // arriving before the Task runs still sees isTransitioning == true.
        isTransitioning = true
        // Defer ALL SwiftUI state mutations (incl. the initial slide-out animation)
        // into the async Task so none of them execute synchronously inside UIKit's
        // touch-event delivery pass. On iOS 26 the UpdateCycle framework throws when
        // @Observable/@State mutations happen synchronously during event dispatch.
        Task { @MainActor in
            withAnimation(.easeIn(duration: 0.2)) {
                slideOffset = direction * screenWidth
            }
            try? await Task.sleep(for: .milliseconds(220))
            action()  // load new video, clears AVPlayer
            slideOffset = -direction * screenWidth  // snap to opposite side (off-screen)
            withAnimation(.easeOut(duration: 0.25)) {
                slideOffset = 0  // slide new content in
            }
            try? await Task.sleep(for: .milliseconds(270))
            isTransitioning = false
        }
    }

    // MARK: - Toast / error

    var sponsorSkipToast: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if let seg = vm.currentToastSegment {
                    Button("Skip \(seg.category.displayName)") {
                        vm.skipToastSegment()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(seg.category.color)
                    // When the skip-toast button is focused, D-pad left/right must still
                    // seek. Without this modifier the move event is consumed by the button
                    // and the ConditionalMoveCommand on the player body never fires
                    // (it is intentionally disabled while the toast is active so that the
                    // focus engine can see the button). Adding onMoveCommand here gives
                    // the button a way to pass the direction through to seeking.
                    .onMoveCommand { direction in
                        switch direction {
                        case .left: vm.seekRelative(seconds: -Double(store.settings.seekBackSeconds))
                        case .right: vm.seekRelative(seconds: Double(store.settings.seekForwardSeconds))
                        default: break
                        }
                    }
                    .focused($skipToastButtonFocused)
                    .padding()
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.easeInOut, value: vm.currentToastSegment?.id)
    }

    // Returns true when the error is an IP/VPN block (APIError.ipBlocked).
    // Extracted to a separate function so the Swift type-checker does not have to
    // resolve a closure-in-body pattern while simultaneously inferring `some View`.
    private func isIPBlockError(_ err: Error) -> Bool {
        if let apiError = err as? APIError, case .ipBlocked = apiError { return true }
        return false
    }

    // Returns true when the error requires the user to sign in (APIError.signInRequired).
    // Retrying is futile — show a "Sign In" button instead of "Try Again".
    private func isSignInRequiredError(_ err: Error) -> Bool {
        if let apiError = err as? APIError, case .signInRequired = apiError { return true }
        return false
    }

    @ViewBuilder
    func errorBanner(_ err: Error) -> some View {
        // IP-block errors show a specific message and no retry button — retrying
        // with the same IP will also fail and may extend the YouTube block duration.
        let isIPBlock = isIPBlockError(err)
        let isSignInRequired = isSignInRequiredError(err)
        VStack(spacing: 12) {
            HStack {
                Image(systemName: AppSymbol.warning)
                    .foregroundStyle(.yellow)
                Text(err.localizedDescription)
                    .font(.callout)
                    .foregroundStyle(.white)
            }
            if !isIPBlock && !isSignInRequired {
                Button {
                    vm.retryLoad()
                } label: {
                    Text("Try Again")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("player.retryButton")
            }
            if isSignInRequired {
                SignInButtonView()
            }
        }
        .padding()
        .background(.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
        .accessibilityIdentifier(isIPBlock ? "player.ipBlockBanner" : "player.errorBanner")
    }
}

// MARK: - Sign-in button (age-restricted / login-required errors)
//
// Isolated into its own view so the @State sheet-presentation flag lives in a
// dedicated scope.  PlayerControlsOverlay cannot hold its own mutable @State in
// the extension methods where this is used, so we delegate to this tiny helper.
private struct SignInButtonView: View {
    @State private var showSignIn = false

    var body: some View {
        Button {
            showSignIn = true
        } label: {
            Text("Sign In")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
        }
        .accessibilityIdentifier("player.signInButton")
        .sheet(isPresented: $showSignIn) { SignInView() }
    }
}
