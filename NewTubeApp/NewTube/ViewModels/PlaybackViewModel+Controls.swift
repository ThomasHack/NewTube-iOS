import AVFoundation
import MediaPlayer
import NewTubeCore
import os

private let playerLog = AppLogger(category: "Player")

// MARK: - Transport Controls & Scrubbing

extension PlaybackViewModel {

    func togglePlayPause() {
        if videoEnded {
            videoEnded = false
            seek(to: 0)
            player.rate = Float(settings.playbackSpeed)
            isPlaying = true
            updateNowPlayingPlayback()
            return
        }
        if isPlaying { player.pause() } else { player.rate = Float(settings.playbackSpeed) }
        isPlaying.toggle()
        updateNowPlayingPlayback()
    }

    /// Issues a seek to the given time.
    func seek(to time: TimeInterval) {
        player.seek(
            to: CMTime(seconds: time, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.currentTime = time }
        }
    }

    func seekRelative(seconds: TimeInterval) {
        seek(to: max(0, currentTime + seconds))
    }

    func setPlaybackSpeed(_ speed: Double) {
        // The system player's play button starts playback at this rate.
        player.defaultRate = Float(speed)
        // Setting player.rate to a non-zero value on a paused AVPlayer restarts
        // playback — only apply the rate while actively playing.
        if isPlaying {
            player.rate = Float(speed)
        }
    }

}
