import AVFoundation
import AVKit
import SmartTubeCore
import SwiftUI
import UIKit
import os

private let swipeLog = AppLogger(category: "Player")

// MARK: - PlayerView Lifecycle
extension PlayerView {

    // MARK: - Title and back-button overlay
    //
    // Extracted from bodyWithLifecycleModifiers to keep the Swift type-checker from
    // timing out on the cumulative modifier chain in that var (compiler error:
    // "unable to type-check this expression in reasonable time").
    @ViewBuilder
    private var titleAndBackButtonOverlay: some View {
        HStack(spacing: 0) {
            Button {
                vm.stop()
                withAnimation(.none) { dismiss() }
            } label: {
                Color.clear.frame(width: 60, height: 60)
            }
            .accessibilityIdentifier("player.backButton")
            .buttonStyle(.plain)
            .focusable(false)
            Text(vm.playerInfo?.video.title ?? video.title)
                .font(.caption)
                .opacity(0)  // visually invisible (including emoji), accessible
                .accessibilityIdentifier("player.titleLabel")
                .accessibilityLabel(vm.playerInfo?.video.title ?? video.title)
                // macOS AX prunes opacity-0 elements by default — force the element
                // into the accessibility tree so XCUITest can always read it.
                .accessibilityHidden(false)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Player content base view
    //
    // Contains the GeometryReader / ZStack with AVLayer, and controls.
    // Extracted from bodyWithLifecycleModifiers so the Swift type-checker handles each
    // property in a separate inference scope (compiler error: "unable to type-check
    // this expression in reasonable time").
    private var playerContentView: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // PlayerAVLayerView: bare AVPlayerLayer without AVPlayerViewController.
                // AVPlayerViewController (VideoPlayer) dominates the UIKit accessibility
                // tree, making all overlaid SwiftUI elements invisible to XCUITest.
                PlayerAVLayerView(player: vm.player, videoGravity: store.settings.videoGravityMode.avGravity)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                if vm.isAudioOnlyMode {
                    audioOnlyThumbnailOverlay
                }

                // Loading spinner
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
                    .allowsHitTesting(false)
                }

                // Hold-to-speed badge — shown while user long-presses to boost to 2×
                if vm.isHoldingToSpeed {
                    HoldSpeedBadge()
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        .animation(.easeOut(duration: 0.15), value: vm.isHoldingToSpeed)
                }

                // Custom overlay controls
                if vm.controlsVisible {
                    makeControlsOverlay(size: geo.size, safeAreaInsets: geo.safeAreaInsets)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: vm.controlsVisible)
                }

                // Error banner
                if let err = vm.error {
                    errorBanner(err)
                }

                // SponsorBlock skip toast
                sponsorSkipToast

                // Caption cue overlay — shown when a track is selected and a cue is active
                if let cue = vm.currentCaptionCue {
                    VStack(spacing: 0) {
                        Spacer()
                        CaptionCueView(text: cue.text)
                            // When controls are visible the scrub bar + bottom controls
                            // occupy ~130pt. Push captions above that area. When controls
                            // are hidden, a small margin from the safe-area bottom is enough.
                            .padding(.bottom, vm.controlsVisible ? 130 : 24)
                            .animation(.easeInOut(duration: 0.2), value: vm.controlsVisible)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                // End cards — shown in the final seconds of a video.
                // Displayed regardless of controls visibility, matching official YouTube behaviour.

                // Stats for Nerds overlay (toggled by two-finger tap)
                if vm.statsForNerdsVisible {
                    StatsForNerdsOverlay(snapshot: vm.statsSnapshot)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: vm.statsForNerdsVisible)
                }

                // Picker / sheet overlays — see PlayerView+Overlays.swift
                overlayStack
            }
            .offset(x: slideOffset)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Full player body with lifecycle modifiers
    //
    // Extracted from body so the compiled symbol for `body` shrinks from ~16 KB to ~100 bytes.
    // All lifecycle wiring (onAppear, onChange, tvOS focus, navigation, alerts) lives here
    // as its own compiled function, keeping the type tree out of PlayerView.body.
    // Extracted from bodyWithLifecycleModifiers to prevent Swift type-checker timeout
    // (error: "unable to type-check this expression in reasonable time").
    // Each property is a separate type-inference scope so the cumulative generic depth
    // of the modifier chain stays within the compiler threshold.
    private var tvosPlayerGestureModifiers: some View {
        playerContentView
            // When no overlay is open, the outer view is the exclusive focus target and
            // handles all remote input via onMoveCommand / onTapGesture.
            // When an overlay (more menu, quality, speed, sleep timer) is visible, focus is
            // yielded so the overlay's buttons are reachable by the Siri Remote.
            // `.focusScope` + `.prefersDefaultFocus` ensure the ZStack actively claims
            // default focus when presented, rather than waiting for the
            // focus engine to pick a child element or leaving focus on the previous screen.
            .focusScope(playerBodyNamespace)
            .prefersDefaultFocus(in: playerBodyNamespace)
            .focusable(!isAnyOverlayVisible && !isSkipToastActive)
            .focused($playerFocused)
            .modifier(
                ConditionalMoveCommand(enabled: !isAnyOverlayVisible && !isSkipToastActive) { direction in
                    swipeLog.debug(
                        "[tv] onMoveCommand dir=\(String(describing: direction)) isTransitioning=\(isTransitioning) highlighted=\(String(describing: highlightedControl))"
                    )
                    guard !isTransitioning else { return }
                    if let current = highlightedControl {
                        // Controls-nav mode: move the highlight between buttons.
                        highlightedControl = tvNextControl(from: current, direction: direction)
                        vm.showControls()
                    } else if vm.controlsVisible {
                        // Controls visible but nav not started yet.
                        // Left/right seeks directly (Siri Remote gen 1 edge-tap and D-pad seek UX);
                        // up/down enters control-navigation mode so the user can reach other buttons.
                        switch direction {
                        case .left: vm.seekRelative(seconds: -Double(store.settings.seekBackSeconds))
                        case .right: vm.seekRelative(seconds: Double(store.settings.seekForwardSeconds))
                        default:
                            highlightedControl = .playPause
                            vm.showControls()
                        }
                    } else {
                        // Controls hidden: left/right seek, up/down shows controls.
                        switch direction {
                        case .left: vm.seekRelative(seconds: -10)
                        case .right: vm.seekRelative(seconds: 10)
                        default:
                            vm.showControls()
                            highlightedControl = .playPause
                        }
                    }
                }
            )
            .onTapGesture {
                swipeLog.notice(
                    "[tv] onTapGesture (select) — isAnyOverlayVisible=\(isAnyOverlayVisible) highlighted=\(String(describing: highlightedControl)) controlsVisible=\(vm.controlsVisible)"
                )
                guard !isAnyOverlayVisible && !isSkipToastActive else { return }
                if let current = highlightedControl {
                    tvActivateControl(current)
                } else if vm.controlsVisible {
                    highlightedControl = .playPause
                    vm.showControls()
                } else {
                    vm.showControls()
                    highlightedControl = .playPause
                }
            }
            .onPlayPauseCommand { vm.togglePlayPause() }
            .onExitCommand {
                swipeLog.notice(
                    "[tv] onExitCommand — showMoreMenu=\(showMoreMenu) showQuality=\(showQualityPicker) showSpeed=\(showSpeedPicker) showSleep=\(showSleepTimerPicker) showCaption=\(showCaptionPicker) showAudio=\(showAudioTrackPicker) showDesc=\(showDescriptionSheet) showComments=\(showCommentsSheet) highlighted=\(String(describing: highlightedControl)) controlsVisible=\(vm.controlsVisible)"
                )
                // Dismiss any open overlay first — Menu/Back is the tvOS dismiss convention.
                if showMoreMenu {
                    showMoreMenu = false
                    return
                }
                if showQualityPicker {
                    showQualityPicker = false
                    return
                }
                if showSpeedPicker {
                    showSpeedPicker = false
                    return
                }
                if showSleepTimerPicker {
                    showSleepTimerPicker = false
                    return
                }
                if showCaptionPicker {
                    showCaptionPicker = false
                    return
                }
                if showAudioTrackPicker {
                    showAudioTrackPicker = false
                    return
                }
                if showDescriptionSheet {
                    showDescriptionSheet = false
                    return
                }
                if showCommentsSheet {
                    showCommentsSheet = false
                    return
                }
                if highlightedControl != nil {
                    // Esc/Menu from nav mode → exit nav mode, controls stay until timer.
                    highlightedControl = nil
                } else if vm.controlsVisible {
                    vm.toggleControls()
                } else {
                    vm.stop()
                    dismiss()
                }
            }
            .onChange(of: playerFocused) { _, focused in
                swipeLog.notice("[tv] playerFocused changed → \(focused) isAnyOverlayVisible=\(isAnyOverlayVisible)")
            }
    }

    // Second half of the tvOS modifier chain — split from tvosPlayerInputModifiers to
    // keep each property's generic depth under the Swift type-checker threshold.
    private var tvosPlayerOverlayModifiers: some View {
        tvosPlayerGestureModifiers
            .onChange(of: showMoreMenu) { _, visible in
                swipeLog.notice(
                    "[tv] showMoreMenu changed → \(visible) isAnyOverlayVisible=\(isAnyOverlayVisible) playerFocused=\(playerFocused)"
                )
                if visible {
                    // prefersDefaultFocus is consulted only when focus ENTERS a scope naturally.
                    // Since the overlay opens programmatically, we must explicitly route focus to
                    // the speed row so the Siri Remote Select button works immediately.
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)  // one render cycle (~50 ms)
                        moreMenuFocusedRow = .speed
                        swipeLog.notice("[tv] moreMenuFocusedRow set → .speed")
                    }
                } else {
                    moreMenuFocusedRow = nil
                }
            }
            .onChange(of: showSpeedPicker) { _, visible in
                swipeLog.notice("[tv] showSpeedPicker changed → \(visible)")
                if visible {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        speedPickerFocused = true
                        swipeLog.notice("[tv] speedPickerFocused set → true")
                    }
                }
            }
            .onChange(of: showQualityPicker) { _, visible in
                swipeLog.notice("[tv] showQualityPicker changed → \(visible)")
                if visible {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        qualityPickerFocused = true
                        swipeLog.notice("[tv] qualityPickerFocused set → true")
                    }
                }
            }
            .onChange(of: showSleepTimerPicker) { _, visible in
                swipeLog.notice("[tv] showSleepTimerPicker changed → \(visible)")
                if visible {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        sleepTimerPickerFocused = true
                        swipeLog.notice("[tv] sleepTimerPickerFocused set → true")
                    }
                }
            }
            .onChange(of: showCaptionPicker) { _, visible in
                swipeLog.notice("[tv] showCaptionPicker changed → \(visible)")
                if visible {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        captionPickerFocused = true
                        swipeLog.notice("[tv] captionPickerFocused set → true")
                    }
                } else {
                    captionPickerFocused = false
                }
            }
    }

    // Third split of the tvOS modifier chain.
    private var tvosPlayerChangeModifiers: some View {
        tvosPlayerOverlayModifiers
            .onChange(of: showAudioTrackPicker) { _, visible in
                swipeLog.notice("[tv] showAudioTrackPicker changed → \(visible)")
                if visible {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        audioTrackPickerFocused = true
                        swipeLog.notice("[tv] audioTrackPickerFocused set → true")
                    }
                } else {
                    audioTrackPickerFocused = false
                }
            }
            .onChange(of: vm.currentToastSegment) { _, segment in
                swipeLog.notice(
                    "[tv] currentToastSegment changed → \(segment == nil ? "nil" : segment!.category.rawValue)")
                if segment != nil {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        skipToastButtonFocused = true
                        swipeLog.notice("[tv] skipToastButtonFocused set → true")
                    }
                } else {
                    skipToastButtonFocused = false
                    if !isAnyOverlayVisible {
                        playerFocused = true
                    }
                }
            }
            .onChange(of: vm.controlsVisible) { _, visible in
                swipeLog.debug(
                    "[tv] controlsVisible changed → \(visible) highlighted=\(String(describing: highlightedControl)) isAnyOverlayVisible=\(isAnyOverlayVisible)"
                )
                if !visible {
                    highlightedControl = nil
                    // Only reclaim player focus when no overlay is open.
                    // focusScope(moreMenuNamespace) keeps focus inside the menu when
                    // controls hide, so no re-assertion is needed (and re-asserting
                    // would steal focus back from whichever row the user navigated to).
                    if !isAnyOverlayVisible {
                        playerFocused = true
                    }
                }
            }
            .onChange(of: isAnyOverlayVisible) { _, overlayVisible in
                swipeLog.notice(
                    "[tv] isAnyOverlayVisible changed → \(overlayVisible) — moreMenu=\(showMoreMenu) quality=\(showQualityPicker) speed=\(showSpeedPicker) sleep=\(showSleepTimerPicker)"
                )
                if overlayVisible {
                    // Pause the controls auto-hide timer so transport controls stay
                    // visible behind the overlay while it is open.
                    vm.cancelControlsHide()
                } else {
                    // Overlay dismissed — reclaim focus and clear nav state.
                    highlightedControl = nil
                    playerFocused = true
                }
            }
    }

    var bodyWithLifecycleModifiers: some View {
        tvosPlayerChangeModifiers
            // Always-visible title badge so XCUITest can read the current video title
            // without waiting for the controls overlay to be shown.
            // Also provides an always-accessible back button for UI automation.
            .overlay(alignment: .topLeading) {
                titleAndBackButtonOverlay
            }
            .onAppear {
                swipeLog.notice("[PlayerView] onAppear id=\(video.id)")
                isVisible = true
                playerFocused = true
                if vm.currentVideoId == video.id {
                    // Spurious appear (e.g. a sheet temporarily covered us) — only resume
                    // if playback was active before the view disappeared, so an intentional
                    // user pause is not overridden (e.g. pause → background → foreground).
                    if vm.wasPlayingBeforeSuspend {
                        vm.resume()
                    }
                } else {
                    vm.load(video: video)
                }
                vm.setPlaybackSpeed(store.settings.playbackSpeed)
                vm.updateSettings(store.settings)
                vm.updateAuthToken(authService.accessToken)
                // UI testing only: force-show controls so the test can find player.nextBtn.
                if ProcessInfo.processInfo.arguments.contains("--uitesting-show-controls") {
                    swipeLog.notice("[PlayerView] --uitesting-show-controls — showing controls")
                    vm.showControls()
                    vm.cancelControlsHide()
                }
                // UI testing only: force-show controls and/or the more menu so tests can
                // verify focus routing without relying on gesture delivery, which is
                // unreliable on the tvOS simulator.
                // Called AFTER load() so it runs after controlsVisible is reset to false.
                // cancelControlsHide() keeps the overlay permanently on screen for tests
                // that need to interact with controls elements.
                if ProcessInfo.processInfo.arguments.contains("--uitesting-show-controls") {
                    swipeLog.notice("[tv] --uitesting-show-controls launch arg detected — calling showControls()")
                    vm.showControls()
                    vm.cancelControlsHide()
                }
                if ProcessInfo.processInfo.arguments.contains("--uitesting-open-more-menu") {
                    swipeLog.notice(
                        "[tv] --uitesting-open-more-menu launch arg detected — scheduling showMoreMenu=true after focus settles"
                    )
                    Task { @MainActor in
                        // Brief delay lets the player body establish focus (via .prefersDefaultFocus)
                        // before the overlay opens, so moreMenuNamespace can attract focus correctly.
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        swipeLog.notice("[tv] --uitesting-open-more-menu: setting showMoreMenu=true")
                        showMoreMenu = true
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--uitesting-open-sleep-timer-picker") {
                    swipeLog.notice(
                        "[tv] --uitesting-open-sleep-timer-picker launch arg detected — scheduling showSleepTimerPicker=true"
                    )
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        swipeLog.notice("[tv] --uitesting-open-sleep-timer-picker: setting showSleepTimerPicker=true")
                        showSleepTimerPicker = true
                    }
                }
            }
            .onDisappear {
                swipeLog.notice("[PlayerView] onDisappear id=\(video.id) isInBackground=\(isInBackground)")
                isVisible = false
                guard !isInBackground else { return }
                vm.suspend()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    isInBackground = true
                    if isVisible { vm.handleBackground() }
                case .active:
                    isInBackground = false
                    if isVisible { vm.handleForeground() }
                default:
                    break
                }
            }
            // Intercept smarttube://seek/<seconds> links emitted by timestamp spans in
            // descriptions and comments, and forward them to the player seek function.
            .environment(
                \.openURL,
                OpenURLAction { url in
                    if url.scheme == "smarttube", url.host == "seek",
                        let seconds = TimeInterval(url.lastPathComponent)
                    {
                        vm.seek(to: seconds)
                        return .handled
                    }
                    return .systemAction
                })
    }

    // MARK: - Controls overlay

    /// Constructs the platform-appropriate `PlayerControlsOverlay` for this view.
    @ViewBuilder
    private func makeControlsOverlay(size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        PlayerControlsOverlay(
            size: size,
            safeAreaInsets: safeAreaInsets,
            video: video,
            showMoreMenu: $showMoreMenu,
            vm: vm,
            highlightedControl: $highlightedControl
        )
    }

    // MARK: - Audio-only thumbnail overlay

    /// Shown in place of the video layer when `vm.isAudioOnlyMode == true`.
    /// The AVPlayerLayer is kept in the hierarchy (for PiP continuity) but covered by this view.
    @ViewBuilder
    var audioOnlyThumbnailOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let thumb = vm.playerInfo?.video.thumbnailURL {
                AsyncImage(url: thumb) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    case .failure:
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.6))
                    default:
                        ProgressView()
                            .tint(.white)
                    }
                }
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .ignoresSafeArea()
        .accessibilityLabel("Audio only — thumbnail")
        .accessibilityIdentifier("player.audioOnlyOverlay")
    }
}
