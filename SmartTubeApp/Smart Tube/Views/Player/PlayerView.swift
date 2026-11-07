import AVFoundation
import AVKit
import SmartTubeCore
import SwiftUI
import UIKit
import os

// MARK: - PlayerView
//
// Full-screen video player.  Wraps AVKit's `VideoPlayer` and overlays
// custom controls, chapter markers, and SponsorBlock skip toasts.
// Mirrors the Android `PlaybackFragment`.

struct PlayerView: View {
    let video: Video
    @State var vm: PlaybackViewModel
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.dismiss) var dismiss
    @Environment(SettingsStore.self) var store
    @Environment(AuthService.self) var authService
    @State var showSpeedPicker = false
    @State var showQualityPicker = false
    @State var showCaptionPicker = false
    @State var showAudioTrackPicker = false
    @State var showSleepTimerPicker = false
    @State var showMoreMenu = false
    @State var moreMenuContentHeight: CGFloat = 0
    @State var showDescriptionSheet = false
    @State var showCommentsSheet = false
    @State var slideOffset: CGFloat = 0
    @State var isTransitioning = false
    @State var channelDestination: ChannelDestination?
    /// True while the app is backgrounded. Prevents `onDisappear` from calling
    /// `suspend()` when the system fires it as a side-effect of backgrounding rather
    /// than actual navigation away from the player.
    @State var isInBackground = false
    /// True while this PlayerView instance is the top-most visible view.
    /// Guards scenePhase handlers so only the visible instance calls handleForeground/handleBackground,
    /// preventing ghost VMs from resuming audio when a new PlayerView is pushed on top.
    @State var isVisible = false
    /// Drives the quality-change toast shown after the user picks a resolution.
    @State var qualityToastMessage: String?
    @FocusState var playerFocused: Bool
    /// Which playback control is visually highlighted in the overlay.
    /// nil = not in controls-nav mode; all remote input targets the video layer.
    @State var highlightedControl: TVPlayerControl? = nil
    /// Namespace for the player ZStack itself, used with `.focusScope` +
    /// `.prefersDefaultFocus` so the ZStack claims default focus when pushed via
    /// NavigationStack — preventing any child view from stealing focus first.
    @Namespace var playerBodyNamespace
    /// Namespace IDs used with `.focusScope` on picker overlays so the tvOS focus
    /// engine moves focus into the overlay when it opens.
    @Namespace var moreMenuNamespace
    @Namespace var qualityPickerNamespace
    @Namespace var speedPickerNamespace
    @Namespace var sleepTimerNamespace
    @Namespace var captionPickerNamespace
    @Namespace var audioTrackPickerNamespace
    @Namespace var descriptionOverlayNamespace
    @Namespace var commentsOverlayNamespace
    /// Explicitly routes Siri Remote focus when overlays open programmatically.
    /// `moreMenuFocusedRow` drives D-pad navigation within the more menu via explicit
    /// `.onMoveCommand` (SwiftUI's spatial engine cannot navigate ZStack overlays).
    @FocusState var moreMenuFocusedRow: MoreMenuRow?
    @FocusState var qualityPickerFocused: Bool
    @FocusState var speedPickerFocused: Bool
    @FocusState var sleepTimerPickerFocused: Bool
    @FocusState var captionPickerFocused: Bool
    @FocusState var audioTrackPickerFocused: Bool
    @FocusState var skipToastButtonFocused: Bool
    init(video: Video, api: InnerTubeAPI) {
        self.video = video
        _vm = State(initialValue: PlaybackViewModel(api: api))
    }

    var body: some View {
        bodyWithLifecycleModifiers
    }

    // MARK: - Lifecycle + full player body
    // bodyWithLifecycleModifiers, makeControlsOverlay
    // → PlayerView+Lifecycle.swift

    // MARK: - Control elements
    // PlayerControlsOverlay (playPauseButton, seekButton, progressBar, etc.)
    // → PlayerView+ControlElements.swift

    // MARK: - Picker overlays + share sheet
    // qualityPickerOverlay / speedPickerOverlay / sleepTimerPickerOverlay
    // captionPickerOverlay / audioTrackPickerOverlay / presentShareSheet(url:)
    // → PlayerView+PickerOverlays.swift
}
