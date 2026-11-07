import UIKit

/// Keeps the tvOS screensaver from starting while any player is playing.
///
/// `isIdleTimerDisabled` is one app-wide flag, but several `PlaybackViewModel`s can exist at
/// once. Tracking owners stops one player that pauses or goes away from re-enabling the idle
/// timer while another is still playing.
@MainActor
enum PlaybackIdleTimer {
    private static var playingOwners: Set<ObjectIdentifier> = []

    static func setPlaying(_ playing: Bool, owner: ObjectIdentifier) {
        if playing {
            playingOwners.insert(owner)
        } else {
            playingOwners.remove(owner)
        }
        UIApplication.shared.isIdleTimerDisabled = !playingOwners.isEmpty
    }
}
