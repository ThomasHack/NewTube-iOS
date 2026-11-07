import AVFoundation
import Foundation
import MediaPlayer
import NewTubeCore
import Observation
import UIKit
import os

private let playerLog = AppLogger(category: "Player")

// MARK: - PlaybackViewModel
//
// Manages video playback state and the AVPlayer instance.
// Mirrors the Android `PlaybackPresenter` + `PlayerUIController`.

@MainActor
@Observable
final class PlaybackViewModel {

    // MARK: - Sub-module managers
    // Each manager owns a subset of playback state and exposes a narrow interface.
    // PlaybackViewModel is the coordinator that injects dependencies and forwards calls.

    let sponsorBlockManager: SponsorBlockSkipManager
    let captionsManager: CaptionsManager
    let audioManager: AudioTrackManager
    let qualityManager: PlaybackQualityManager

    // MARK: - State

    var playerInfo: PlayerInfo?
    var isLoading: Bool = false {
        didSet { if !isLoading { retryStatusMessage = nil } }
    }
    /// Short user-facing message shown under the loading spinner when the player
    /// enters the multi-phase stream-negotiation fallback chain. `nil` while the
    /// fast path is still in-flight or after loading completes.
    var retryStatusMessage: String? = nil
    /// True only during the initial load sequence (before first readyToPlay).
    /// The 8s loadTracks timeout in attemptComposition is applied only while this
    /// flag is set, giving fast startup (≤20 s) for the initial stream.
    /// After first playback begins the flag is cleared, so quality-switch
    /// reloads can wait the full CDN time without being cut short.
    var needsQuickStartup: Bool = false
    /// Timestamp set at the start of `load(video:)` — used to log total video-start latency.
    var videoLoadStartedAt: Date = .distantPast
    /// Video ID (and title) that `load(video:)` was last called with. Compared against
    /// `currentVideo.id` when `isPlaying` fires for the first time in each load cycle
    /// to detect a wrong-video outcome (fix236).
    var intendedVideoId: String? = nil
    /// Set to `true` at the start of each `load()` and cleared on the first
    /// `isPlaying = true` of that load cycle so the check fires exactly once.
    var pendingWrongVideoCheck: Bool = false
    var isPlaying: Bool = false {
        didSet {
            PlaybackIdleTimer.setPlaying(isPlaying, owner: ObjectIdentifier(self))
            guard isPlaying, !oldValue else { return }
            // fix13: Cross-process Darwin notification for regression-test timing.
            // XCTDarwinNotificationExpectation in WKHLSReplayRegressionUITests receives
            // this within ~1 ms when readyToPlay fires, bypassing XCTest's ~1.2 s UIKit
            // modal accessibility-settle delay so hot cycles measure ~0.84 s (readyToPlay
            // time) instead of ~1.6 s (accessibility overhead).
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("com.void.newtube.player.ready" as CFString),
                nil, nil, true
            )
            checkWrongVideoOnFirstPlay()
        }
    }
    var videoEnded: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0

    // MARK: - Forwarding computed properties (views unchanged)

    var availableFormats: [VideoFormat] {
        get { qualityManager.availableFormats }
        set { qualityManager.availableFormats = newValue }
    }
    var selectedFormat: VideoFormat? {
        get { qualityManager.selectedFormat }
        set { qualityManager.selectedFormat = newValue }
    }

    /// The quality label last chosen by the user — persists even after CDN failure
    /// clears `selectedFormat`. Use this for UI labels that should show user intent.
    var pendingQualityLabel: String {
        qualityManager.pendingQualityLabel
    }
    var sponsorSegments: [SponsorSegment] {
        get { sponsorBlockManager.sponsorSegments }
        set { sponsorBlockManager.sponsorSegments = newValue }
    }
    var currentToastSegment: SponsorSegment? {
        get { sponsorBlockManager.currentToastSegment }
        set { sponsorBlockManager.currentToastSegment = newValue }
    }
    var availableCaptions: [CaptionTrack] {
        get { captionsManager.availableCaptions }
        set { captionsManager.availableCaptions = newValue }
    }
    var selectedCaption: CaptionTrack? {
        get { captionsManager.selectedCaption }
        set { captionsManager.selectedCaption = newValue }
    }
    var currentCaptionCue: CaptionCue? {
        get { captionsManager.currentCaptionCue }
        set { captionsManager.currentCaptionCue = newValue }
    }
    var availableAudioTracks: [AudioTrack] {
        get { audioManager.availableAudioTracks }
        set { audioManager.availableAudioTracks = newValue }
    }
    var selectedAudioTrack: AudioTrack? {
        get { audioManager.selectedAudioTrack }
        set { audioManager.selectedAudioTrack = newValue }
    }
    /// Short message displayed by `ToastModifier` in the player; cleared automatically after 2 s.
    var toastMessage: String? = nil
    var relatedVideos: [Video] = []
    var chapters: [Chapter] = []
    var hasPrevious: Bool = false
    var hasNext: Bool = false
    /// The last stream URL handed to AVPlayer (primary or fallback). Shown in Stats for Nerds.
    var lastAttemptedStreamURL: URL?
    var error: Error? {
        didSet {
            guard let error else { return }
            let nsError = error as NSError
            // Transient connectivity errors are expected in poor-network conditions and aren't
            // actionable, so they would only add log noise — skip them.
            //   -1    = unknown (generic network failure, same signal as below)
            //   -999  = request cancelled (AVPlayer or URLSession cancelled in-flight
            //           request — user navigated away or a superseded task was cancelled)
            //   -1001 = request timed out (slow server or poor connectivity)
            //   -1005 = network connection lost
            //   -1009 = device offline
            //   -1202 = invalid/untrusted certificate (SSL inspection proxy, user-side issue)
            let transientCodes = [-1, -999, -1001, -1005, -1009, -1202]
            guard !(nsError.domain == NSURLErrorDomain && transientCodes.contains(nsError.code)) else {
                return
            }
            // APIError.unavailable means YouTube's server returned a known-unplayable status
            // (bot-detection, rate-limit, private/members-only, region block, cipher-protected
            // URLs). These are never app bugs, so don't log them as errors. Pattern-match
            // directly on the type rather than relying on NSError.code (which shifts when enum
            // cases are reordered). APIError.ipBlocked is logged in the loading path — skip
            // double-logging here.
            if let apiError = error as? APIError {
                if case .unavailable = apiError { return }
                if case .ipBlocked = apiError { return }
            }
            playerLog.error(
                "\(nsError.domain)(\(nsError.code)): \(error.localizedDescription) — video=\(currentVideo?.id ?? "unknown") retries=\(retryAttempts) t=\(Int(currentTime))s"
            )
        }
    }
    let likeDislike: LikeDislikeController
    let comments: CommentsController
    var likeStatus: LikeStatus { likeDislike.likeStatus }
    func like() { likeDislike.like(videoId: currentVideo?.id) }
    func dislike() { likeDislike.dislike(videoId: currentVideo?.id) }
    var statsForNerdsVisible: Bool = false
    var statsSnapshot: StatsForNerdsSnapshot = .empty
    /// End-screen cards to overlay during the final seconds of the video.
    var endCards: [EndCard] = []
    /// When `true`, the player loads only the audio-only adaptive stream and displays
    /// the video thumbnail in place of the player layer. Updated from `AppSettings.audioOnlyMode`.
    var isAudioOnlyMode: Bool = false
    /// `true` when an actual audio-only AVPlayerItem (not HLS) is the current item.
    /// Used by `toggleAudioOnlyLive` to decide whether to reload HLS on turn-off.
    var audioOnlyItemActive: Bool = false

    // MARK: - Captions (forwarded to CaptionsManager)
    // MARK: - Audio tracks (forwarded to AudioTrackManager)

    /// True if playback was active when `suspend()` was last called.
    /// Used by `PlayerView.onAppear` to decide whether to resume after a
    /// sheet dismissal — prevents overriding an intentional user pause.
    var wasPlayingBeforeSuspend: Bool = false

    /// The chapter whose start time is closest-but-not-greater-than `currentTime`.
    /// Nil when no chapters are available or the video hasn't started.
    var currentChapter: Chapter? {
        guard !chapters.isEmpty else { return nil }
        return chapters.last(where: { $0.startTime <= currentTime })
    }

    /// True when there is a chapter ahead of the current playhead position.
    var hasNextChapter: Bool {
        chapters.contains { $0.startTime > currentTime }
    }

    /// True when the playhead can be moved backward to a chapter boundary —
    /// either to the start of the current chapter (if >3 s in) or to the previous one.
    var hasPreviousChapter: Bool {
        guard let current = currentChapter else { return false }
        if currentTime - current.startTime > 3 { return true }
        return chapters.contains { $0.startTime < current.startTime }
    }

    // MARK: - History

    /// Videos played before the current one (oldest first).
    var history: [Video] = []
    /// The video currently loaded (nil before first load).
    var currentVideo: Video? = nil

    // MARK: - AVPlayer

    let player = AVPlayer()
    @ObservationIgnored nonisolated(unsafe) var timeObserver: Any?
    @ObservationIgnored nonisolated(unsafe) var audioSessionObserver: Any?
    @ObservationIgnored nonisolated(unsafe) var rateObserver: NSKeyValueObservation?
    /// True while the video is being routed to an external display via AirPlay.
    var isAirPlaying: Bool = false
    @ObservationIgnored nonisolated(unsafe) var airPlayObserver: NSKeyValueObservation?
    /// Counts exhaustive retry cycles (0 = no retry yet). Set by exhaustiveRetry(video:originalError:).
    var retryAttempts: Int = 0
    /// The stream type that produced the current AVPlayerItem, set by each successful load path.
    /// Identifies which fallback path was used.
    var lastSuccessfulStreamType: String = "unknown"
    /// Elapsed ms from `load()` to the first `readyToPlay` (low-quality fast-start frame). 0 = not yet measured.
    var timeToPlayMs: Int = 0
    /// Elapsed ms from `load()` to the quality-ramp task firing (~readyToPlay + 800 ms). 0 = not yet measured.
    var timeToHighQualityMs: Int = 0
    /// Cache hit/miss summary set at load time (e.g. "pi:HIT").
    var cacheStatusSummary: String = ""
    /// Task running the exhaustive retry loop; cancelled on new load or retryLoad.
    var exhaustiveRetryTask: Task<Void, Never>?
    /// Set after a Cannot-Decode failure on the Auto HLS master — forwarded to qualityManager.
    var hasAppliedH264Cap: Bool {
        get { qualityManager.hasAppliedH264Cap }
        set { qualityManager.hasAppliedH264Cap = newValue }
    }
    /// True while a SponsorBlock auto-skip seek is in-flight — forwarded to sponsorBlockManager.
    var isSkippingSegment: Bool { sponsorBlockManager.isSkippingSegment }
    var itemObserverTask: Task<Void, Never>?
    var endObserverTask: Task<Void, Never>?
    var stallObserverTask: Task<Void, Never>?
    /// Observes `AVPlayerItem.duration` via KVO after `.readyToPlay` for HLS streams
    /// where the duration is `.invalid` at ready-time and arrives later. Cancelled in `stop()`.
    var durationObserverTask: Task<Void, Never>?
    /// Number of `AVPlayerItemPlaybackStalled` (or rateObserver rate→0) events in this session.
    var stallCount: Int = 0
    /// Wall-clock time of the first stall in the current sequence. Used by rateObserver to
    /// detect a rapid-repeat stall loop (≥3 stalls in <30s) where seeks re-stall immediately
    /// because the CDN URL is expired/rate-limited. Reset to nil alongside stallCount in load().
    var firstRapidStallTime: Date? = nil
    var qualityTask: Task<Void, Never>? {
        get { qualityManager.qualityTask }
        set { qualityManager.qualityTask = newValue }
    }
    /// True while `replaceCurrentItem` is executing; guards the rate observer from
    /// treating the transient rate-drop as an unexpected external pause.
    var isSwappingItem: Bool = false
    /// True while an AVAudioSession interruption (e.g. an incoming phone call) is in
    /// progress. Suppresses the rate-observer's stall detection/recovery so a
    /// deliberate interruption-pause isn't mistaken for a playback stall (#244).
    var isHandlingAudioInterruption: Bool = false
    /// Captures `isPlaying` at the start of an audio interruption so playback can be
    /// resumed on `.ended` only if it was actually playing before the call (#244).
    var wasPlayingBeforeInterruption: Bool = false
    /// True from when a quality-change replaceCurrentItem fires until readyToPlay is
    /// handled. The time observer skips currentTime updates during this window so the
    /// UI position is preserved and any user seek during transition is not lost.
    var isQualityChangePending: Bool = false
    var hlsVariantURLs: [Int: URL] {
        get { qualityManager.hlsVariantURLs }
        set { qualityManager.hlsVariantURLs = newValue }
    }
    let sleepTimer = SleepTimerController()
    /// Remaining minutes on the sleep timer (nil = off). Observable so PlayerView can show it.
    var sleepTimerMinutes: Int? { sleepTimer.sleepTimerMinutes }
    func setSleepTimer(minutes: Int?) {
        sleepTimer.setSleepTimer(minutes: minutes) { [weak self] in
            self?.player.pause()
            self?.isPlaying = false
        }
    }
    /// Available sleep timer durations in minutes.
    static let sleepTimerOptions: [Int] = [15, 30, 45, 60]
    /// Position to seek to once the AVPlayerItem is ready.
    var savedPositionToRestore: TimeInterval? = nil
    /// Manages watch-history state: position saving, playback-started ping,
    /// and watchtime segment reporting. See WatchtimeTracker.
    var tracker: WatchtimeTracker

    // AVMediaSelectionGroup (forwarded to AudioTrackManager)
    @ObservationIgnored nonisolated var audioSelectionGroup: AVMediaSelectionGroup? {
        get { audioManager.audioSelectionGroup }
        set { audioManager.audioSelectionGroup = newValue }
    }
    @ObservationIgnored var audioOptionsByID: [String: AVMediaSelectionOption] {
        get { audioManager.audioOptionsByID }
        set { audioManager.audioOptionsByID = newValue }
    }

    // Caption cues (forwarded to CaptionsManager)
    var captionCues: [CaptionCue] {
        get { captionsManager.captionCues }
        set { captionsManager.captionCues = newValue }
    }
    @ObservationIgnored var captionFetchTask: Task<Void, Never>? {
        get { captionsManager.captionFetchTask }
        set { captionsManager.captionFetchTask = newValue }
    }
    /// Debounce task for preview seeks while dragging the slider.
    /// Fires a seek after the thumb has been held still for 300 ms.
    var seekDebounceTask: Task<Void, Never>?
    /// Tracks the in-flight loadAsync so it can be cancelled if load() is called again.
    var loadTask: Task<Void, Never>?
    /// Phase 2 background work: nextInfo, endCards, trackingURLs, neighbour prefetch.
    /// Cancelled at the start of every new load() and in stop().
    var phase2Task: Task<Void, Never>?
    /// Background prefetch task: either fetches AndroidVR playerInfo (muxed fallback)
    /// or pre-warms AVAssetTrack arrays for the user's preferred quality tier.
    /// Cancelled on every new video load.
    var prefetchTask: Task<Void, Never>?
    /// fix2/fix30: TVEmbedded PlayerInfo pre-fetch started inside tryAllStreams alongside
    /// the AndroidVR rqh=1 timeout.
    /// By the time exhaustiveRetry reaches Phase 1, the result is typically ready —
    /// eliminating the sequential ~0.5 s Phase 1 network fetch.
    var tvEmbeddedEarlyTask: Task<PlayerInfo?, Never>?

    // fix12: videoId of the item stop() left alive in player.currentItem (parked).
    // When load() is called for the same id and the item is still .readyToPlay, the
    // entire exhaustiveRetry race (~1.27s) is skipped — audio session re-activated and
    // playback resumes in <0.1s. Cleared when a different video is requested.
    var parkedVideoId: String?

    // MARK: - Now Playing cache
    // Never read nowPlayingInfo back from MPNowPlayingInfoCenter — doing a
    // read-modify-write while MediaPlayer is processing on its accessQueue
    // causes EXC_BREAKPOINT. Mirror the dict locally instead.
    @ObservationIgnored var nowPlayingInfoCache: [String: Any] = [:]
    // Cached thumbnail for MPMediaItemArtwork. Written from a background URLSession task;
    // read from MediaPlayer's internal artwork-closure thread. nonisolated(unsafe) is
    // intentional: UIImage is immutable after creation and the worst-case race is that
    // MediaPlayer gets nil on the first render (it will retry on the next state update).
    nonisolated(unsafe) var cachedArtwork: UIImage? = nil
    @ObservationIgnored var cachedArtworkVideoID: String? = nil

    // MARK: - Dependencies

    let api: InnerTubeAPI
    let sponsorBlock: SponsorBlockService
    let deArrow: DeArrowService
    var settings: AppSettings
    var hasAuthToken: Bool = false
    var currentAuthToken: String? = nil

    init(
        api: InnerTubeAPI = InnerTubeAPI(),
        sponsorBlock: SponsorBlockService = SponsorBlockService(),
        deArrow: DeArrowService = DeArrowService(),
        settings: AppSettings = AppSettings()
    ) {
        self.api = api
        self.tracker = WatchtimeTracker(api: api)
        self.sponsorBlock = sponsorBlock
        self.deArrow = deArrow
        self.settings = settings

        // Create managers before any other setup (they hold no back-references yet).
        let sbm = SponsorBlockSkipManager()
        let cam = CaptionsManager()
        let aqm = PlaybackQualityManager(player: player)
        let atm = AudioTrackManager(player: player)
        self.sponsorBlockManager = sbm
        self.captionsManager = cam
        self.qualityManager = aqm
        self.audioManager = atm
        self.likeDislike = LikeDislikeController(
            api: api,
            logError: { msg in playerLog.error("[likeDislike] \(msg)") }
        )
        self.comments = CommentsController(api: api)

        player.allowsExternalPlayback = true
        do {
            // Only configure the audio category at init time. setActive(true) is
            // deliberately deferred to loadAsync (PlaybackViewModel+Loading.swift ~line 494)
            // so that cold-launching the app does not interrupt background audio from
            // other apps before the user starts a video (GitHub issue #54).
            // setCategory alone does not interrupt other apps per AVAudioSession docs.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            playerLog.error("AVAudioSession category setup failed: \(error.localizedDescription)")
        }
        setupTimeObserver()
        setupRateObserver()
        setupRemoteCommandCenter()
        setupAudioSessionObserver()
        setupAirPlayObserver()

        // Wire delegates (self is now fully initialised).
        sbm.delegate = self
        sbm.player = player
        aqm.delegate = self
        atm.delegate = self

        // Auto-enable Stats for Nerds during UI test runs so tests don't need to
        // navigate the more menu manually. Activated by `--uitesting-stats-for-nerds`.
        if ProcessInfo.processInfo.arguments.contains("--uitesting-stats-for-nerds") {
            statsForNerdsVisible = true
        }
    }

    deinit {
        if let obs = timeObserver { player.removeTimeObserver(obs) }
        rateObserver?.invalidate()
        airPlayObserver?.invalidate()
        if let obs = audioSessionObserver { NotificationCenter.default.removeObserver(obs) }
        let owner = ObjectIdentifier(self)
        Task { @MainActor in PlaybackIdleTimer.setPlaying(false, owner: owner) }
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)
    }

    // MARK: - Load video

    /// The ID of the video currently loaded (or being loaded). Exposed so PlayerView
    /// can detect spurious onAppear/onDisappear cycles (e.g. when a ShareLink sheet
    /// temporarily covers the player) and skip unnecessary reloads.
    var currentVideoId: String? { currentVideo?.id }

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        isAudioOnlyMode = newSettings.audioOnlyMode
    }
}

// MARK: - Delegate conformances

extension PlaybackViewModel: SponsorBlockDelegate {
    func snapCurrentTime(to seconds: Double) { currentTime = seconds }
}

extension PlaybackViewModel: QualityContext {}

extension PlaybackViewModel: QualityEventHandler {
    func loadAudioTracks(from item: AVPlayerItem) {
        audioManager.loadAudioTracks(from: item)
    }

    func qualityItemDidBecomeReady(_ item: AVPlayerItem, seekTo time: TimeInterval) {
        // Clear the quality-change freeze so the time observer resumes.
        isQualityChangePending = false
        // currentTime was preserved during the transition (time observer suspended).
        // If the user seeked while the new item was loading, currentTime reflects
        // their intent (set in seek(to:) completion handler); otherwise it holds
        // the position captured at quality-change start.
        // Either way, currentTime is the authoritative target; `time` is the fallback
        // when currentTime is 0 (e.g. video is at the very start).
        let seekTarget = currentTime > 0 ? currentTime : time
        playerLog.notice(
            "[quality] readyToPlay — seekTarget=\(seekTarget)s (currentTime=\(currentTime)s savedTime=\(time)s)")
        if seekTarget > 0 { seek(to: seekTarget) }
        isPlaying = true
        loadAudioTracks(from: item)
    }

    func qualityItemDidFail(error: Error?, quality: AppSettings.VideoQuality, hasAppliedH264Cap: Bool) async {
        let nsErr = (error as? NSError) ?? NSError(domain: "", code: 0)
        let action = qualityRecoveryAction(
            for: nsErr,
            quality: quality,
            hasAppliedH264Cap: hasAppliedH264Cap
        )
        switch action {
        case .retry403Recovery:
            if let video = currentVideo {
                playerLog.notice("Quality-switch 403 — invalidating cache and re-fetching player info")
                await VideoPreloadCache.shared.invalidatePlayerInfo(for: video.id)
                HLSManifestCache.shared.invalidate(for: video.id)
                qualityManager.selectedFormat = nil
                await retryWith403Recovery(video: video, originalError: error)
            }
        case .revertToAuto:
            playerLog.notice("Quality-switch failed — reverting selectedFormat to Auto")
            qualityManager.selectedFormat = nil
            toastMessage = "Quality unavailable — reverting to Auto"
            await qualityManager.reloadHLSItem(seekTo: currentTime, quality: .auto)
        case .retryWithH264Cap:
            playerLog.notice("Auto HLS Cannot Decode — retrying with H.264 bitrate cap")
            qualityManager.hasAppliedH264Cap = true
            toastMessage = "Adjusting quality for this device…"
            await qualityManager.reloadHLSItemH264Capped(seekTo: currentTime)
        case .fail(let e):
            self.error = e
        }
    }

    func qualitySelectDASHFormat(videoURL: URL, audioURL: URL, seekTo: TimeInterval) async {
        await rebuildCompositionForQuality(videoURL: videoURL, audioURL: audioURL, seekTo: seekTo)
    }

    // MARK: - Wrong-video detection (fix236)

    /// Fires once per `load()` cycle when `isPlaying` transitions to `true`.
    /// Compares `currentVideo.id` against `intendedVideoId` set at `load()` time.
    /// On mismatch: logs an error and shows the user a toast.
    private func checkWrongVideoOnFirstPlay() {
        guard pendingWrongVideoCheck else { return }
        pendingWrongVideoCheck = false
        guard let intended = intendedVideoId,
            let active = currentVideo,
            active.id != intended
        else { return }
        playerLog.error("[WrongVideo] MISMATCH at readyToPlay — intended=\(intended) active=\(active.id)")
        toastMessage = "⚠️ Wrong video loaded"
    }
}

extension PlaybackViewModel: AudioTrackDelegate {}
