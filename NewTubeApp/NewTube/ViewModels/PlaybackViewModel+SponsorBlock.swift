import AVFoundation
import NewTubeCore
import os

// MARK: - SponsorBlock (thin wrapper — logic lives in SponsorBlockSkipManager)

extension PlaybackViewModel {

    @discardableResult
    func checkSponsorSkip(at time: TimeInterval) -> Bool {
        sponsorBlockManager.checkSponsorSkip(at: time)
    }

    func skipToastSegment() {
        sponsorBlockManager.skipToastSegment()
    }
}
