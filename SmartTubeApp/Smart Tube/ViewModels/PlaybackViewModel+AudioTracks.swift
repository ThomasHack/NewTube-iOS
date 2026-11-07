import AVFoundation
import SmartTubeCore

// MARK: - Audio Track Selection (thin wrapper — logic lives in AudioTrackManager)

extension PlaybackViewModel {

    func selectAudioTrack(_ track: AudioTrack?) {
        audioManager.selectAudioTrack(track)
    }
}
