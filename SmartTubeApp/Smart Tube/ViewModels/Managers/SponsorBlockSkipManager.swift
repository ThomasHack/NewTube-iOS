import AVFoundation
import SmartTubeCore

// MARK: - SponsorBlockDelegate

/// Implemented by PlaybackViewModel to give SponsorBlockSkipManager the minimal
/// cross-boundary surface it needs without taking a direct reference to the full VM.
@MainActor
protocol SponsorBlockDelegate: AnyObject {
    var settings: AppSettings { get }
    var duration: Double { get }
    func seek(to seconds: Double)
    func handlePlaybackEnd()
    /// Snaps the observable `currentTime` to `seconds` after a seek completes,
    /// so the UI does not flash the pre-seek position while AVPlayer settles.
    func snapCurrentTime(to seconds: Double)
}

private let skipLog = AppLogger(category: "SponsorBlock")

// MARK: - SponsorBlockSkipManager

/// Owns `sponsorSegments`, `currentToastSegment`, and `isSkippingSegment`.
/// Called from the PlaybackViewModel time observer; all logic migrated from
/// PlaybackViewModel+SponsorBlock.swift.
@MainActor
@Observable
final class SponsorBlockSkipManager {

    // MARK: - State

    var sponsorSegments: [SponsorSegment] = []
    var currentToastSegment: SponsorSegment? = nil
    /// True while a SponsorBlock auto-skip seek is in-flight. Guards against the
    /// periodic time observer re-triggering before the seek completes.
    private(set) var isSkippingSegment: Bool = false
    /// Segments that won't skip automatically again: already skipped, or moved into by the user.
    private var handledSegmentIDs: Set<UUID> = []
    private var lastCheckedTime: TimeInterval?
    /// Time observer ticks are 0.5 s apart, which is 1 s of video at 2× speed. A larger step is a seek.
    private static let maxPlaybackStep: TimeInterval = 2.5
    /// The skip button takes the remote's focus, so nothing can scrub while it's visible. Like Skip
    /// Intro, it goes away after a moment of playback.
    static let skipButtonDuration: TimeInterval = 5
    private var skipButtonSegmentID: UUID?
    private var skipButtonShownAt: TimeInterval = 0

    // MARK: - Dependencies

    @ObservationIgnored weak var delegate: (any SponsorBlockDelegate)?
    @ObservationIgnored var player: AVPlayer?

    // MARK: - Init

    init() {}

    // MARK: - Interface

    func reset() {
        sponsorSegments = []
        currentToastSegment = nil
        isSkippingSegment = false
        handledSegmentIDs = []
        lastCheckedTime = nil
        skipButtonSegmentID = nil
    }

    /// Called from the time observer. Handles per-category actions:
    ///   `.skip`      → seeks past the segment automatically.
    ///   `.showToast` → surfaces `currentToastSegment` for the skip button.
    ///   `.nothing`   → no-op.
    /// Returns true if an auto-seek was triggered.
    @discardableResult
    func checkSponsorSkip(at time: TimeInterval) -> Bool {
        guard let delegate else {
            currentToastSegment = nil
            return false
        }
        // Moving into a segment on purpose means watching it, not skipping straight back out.
        if let lastCheckedTime, abs(time - lastCheckedTime) > Self.maxPlaybackStep,
            let segment = sponsorSegments.first(where: { time >= $0.start && time < $0.end })
        {
            handledSegmentIDs.insert(segment.id)
        }
        lastCheckedTime = time
        let effectiveDuration = player?.currentItem?.duration.seconds ?? delegate.duration
        let decision = SponsorBlockDecisionEngine.decide(
            at: time,
            segments: sponsorSegments,
            settings: delegate.settings,
            isSkipInProgress: isSkippingSegment,
            duration: effectiveDuration,
            handledSegmentIDs: handledSegmentIDs
        )
        switch decision {
        case .clearToast:
            currentToastSegment = nil
            skipButtonSegmentID = nil
            return false
        case .showToast(let seg):
            if skipButtonSegmentID != seg.id {
                skipButtonSegmentID = seg.id
                skipButtonShownAt = time
            }
            currentToastSegment = time - skipButtonShownAt < Self.skipButtonDuration ? seg : nil
            return false
        case .skipToPlaybackEnd:
            currentToastSegment = nil
            delegate.handlePlaybackEnd()
            return true
        case .skip(let target, let segment):
            currentToastSegment = nil
            isSkippingSegment = true
            handledSegmentIDs.insert(segment.id)
            guard let player else { return true }
            skipLog.notice(
                "[skip] \(segment.category.rawValue) at \(time)s → \(target)s, player at \(player.currentTime().seconds)s, status=\(player.currentItem?.status.rawValue ?? -1) rate=\(player.rate)"
            )
            player.seek(
                to: CMTime(seconds: target, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600)
            ) { [weak self] finished in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let landed = self.player?.currentTime().seconds ?? -1
                    skipLog.notice("[skip] seek to \(target)s finished=\(finished) landed at \(landed)s")
                    if finished {
                        self.delegate?.snapCurrentTime(to: target)
                        // This seek wasn't the user's, so it shouldn't count as moving into a segment.
                        self.lastCheckedTime = landed
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    self.isSkippingSegment = false
                }
            }
            return true
        case .none:
            return true
        }
    }

    /// Manually skip the segment shown in `currentToastSegment` (called by skip button).
    func skipToastSegment() {
        guard let seg = currentToastSegment else { return }
        currentToastSegment = nil
        let effectiveDuration = player?.currentItem?.duration.seconds ?? delegate?.duration ?? 0
        if effectiveDuration > 0 && seg.end >= effectiveDuration - 2.0 {
            delegate?.handlePlaybackEnd()
            return
        }
        delegate?.seek(to: seg.end)
    }
}
