import NewTubeCore
import UIKit

// MARK: - PlayerCommand

/// What the system player's custom controls can ask for.
enum PlayerCommand {
    case selectFormat(VideoFormat?)
    case setSpeed(Double)
    case selectCaption(CaptionTrack?)
    case setSleepTimer(Int?)
    case like
    case dislike
    case toggleAudioOnly
    case toggleQueueShuffle
    case toggleStats
    case openChannel
    case previousVideo
    case nextVideo
    case skipSegment
}

// MARK: - PlayerMenuState

/// Everything the transport bar's menus show. They're only rebuilt when this changes.
struct PlayerMenuState: Equatable {
    var formats: [VideoFormat] = []
    var selectedFormat: VideoFormat?
    var playbackSpeed: Double = 1
    var captions: [CaptionTrack] = []
    var selectedCaption: CaptionTrack?
    var sleepTimerMinutes: Int?
    var isSignedIn = false
    var likeStatus: LikeStatus = .none
    var isAudioOnly = false
    var isInQueue = false
    var isQueueShuffled = false
    var isShowingStats = false
    var hasPrevious = false
    var hasNext = false
    var hasChannel = false
}

// MARK: - PlayerMenu

/// Builds the items in the system player's transport bar.
@MainActor
enum PlayerMenu {
    static func items(for state: PlayerMenuState, perform: @escaping (PlayerCommand) -> Void) -> [UIMenuElement] {
        var items: [UIMenuElement] = []
        if state.hasPrevious {
            items.append(
                action(String(localized: "Previous Video"), symbol: AppSymbol.previousTrack) { perform(.previousVideo) }
            )
        }
        if state.isSignedIn {
            items.append(
                action(
                    String(localized: "Like"),
                    symbol: state.likeStatus == .like ? "hand.thumbsup.fill" : AppSymbol.thumbsUp
                ) { perform(.like) })
            items.append(
                action(
                    String(localized: "Dislike"),
                    symbol: state.likeStatus == .dislike ? "hand.thumbsdown.fill" : AppSymbol.thumbsDown
                ) { perform(.dislike) })
        }
        if !state.captions.isEmpty {
            items.append(captionsMenu(state, perform))
        }
        items.append(speedMenu(state, perform))
        if !state.formats.isEmpty {
            items.append(qualityMenu(state, perform))
        }
        items.append(moreMenu(state, perform))
        return items
    }

    private static func qualityMenu(_ state: PlayerMenuState, _ perform: @escaping (PlayerCommand) -> Void) -> UIMenu {
        var options = [
            option(String(localized: "Auto"), isOn: state.selectedFormat == nil) { perform(.selectFormat(nil)) }
        ]
        options += state.formats.map { format in
            option(format.qualityLabel, isOn: state.selectedFormat?.id == format.id) { perform(.selectFormat(format)) }
        }
        return UIMenu(
            title: String(localized: "Quality"), image: UIImage(systemName: "film.stack"),
            options: .singleSelection, children: options)
    }

    private static func speedMenu(_ state: PlayerMenuState, _ perform: @escaping (PlayerCommand) -> Void) -> UIMenu {
        let options = AppSettings.availableSpeeds.map { speed in
            let title =
                speed == 1
                ? String(localized: "Normal") : "\(speed.formatted(.number.precision(.significantDigits(1...3))))×"
            return option(title, isOn: speed == state.playbackSpeed) { perform(.setSpeed(speed)) }
        }
        return UIMenu(
            title: String(localized: "Playback Speed"), image: UIImage(systemName: "speedometer"),
            options: .singleSelection, children: options)
    }

    private static func captionsMenu(_ state: PlayerMenuState, _ perform: @escaping (PlayerCommand) -> Void) -> UIMenu {
        var options = [
            option(String(localized: "Off"), isOn: state.selectedCaption == nil) { perform(.selectCaption(nil)) }
        ]
        options += state.captions.map { track in
            option(track.name, isOn: state.selectedCaption?.id == track.id) { perform(.selectCaption(track)) }
        }
        return UIMenu(
            title: String(localized: "Captions"), image: UIImage(systemName: "captions.bubble"),
            options: .singleSelection, children: options)
    }

    private static func sleepTimerMenu(_ state: PlayerMenuState, _ perform: @escaping (PlayerCommand) -> Void) -> UIMenu
    {
        var options = [
            option(String(localized: "Off"), isOn: state.sleepTimerMinutes == nil) { perform(.setSleepTimer(nil)) }
        ]
        options += PlaybackViewModel.sleepTimerOptions.map { minutes in
            option(
                String(localized: "\(minutes) min"), isOn: state.sleepTimerMinutes == minutes
            ) { perform(.setSleepTimer(minutes)) }
        }
        return UIMenu(
            title: String(localized: "Sleep Timer"), image: UIImage(systemName: "moon.zzz"),
            options: .singleSelection, children: options)
    }

    private static func moreMenu(_ state: PlayerMenuState, _ perform: @escaping (PlayerCommand) -> Void) -> UIMenu {
        var items: [UIMenuElement] = []
        if state.hasChannel {
            items.append(
                action(String(localized: "Open Channel"), symbol: AppSymbol.personRectangle) { perform(.openChannel) })
        }
        if state.hasNext {
            items.append(action(String(localized: "Next Video"), symbol: AppSymbol.nextTrack) { perform(.nextVideo) })
        }
        items.append(sleepTimerMenu(state, perform))
        items.append(
            action(String(localized: "Audio Only"), symbol: AppSymbol.audioOnly, isOn: state.isAudioOnly) {
                perform(.toggleAudioOnly)
            })
        if state.isInQueue {
            items.append(
                action(String(localized: "Shuffle Queue"), symbol: "shuffle", isOn: state.isQueueShuffled) {
                    perform(.toggleQueueShuffle)
                })
        }
        items.append(
            action(String(localized: "Stats for Nerds"), symbol: "chart.bar.doc.horizontal", isOn: state.isShowingStats)
            {
                perform(.toggleStats)
            })
        return UIMenu(title: String(localized: "More"), image: UIImage(systemName: "ellipsis"), children: items)
    }

    private static func action(
        _ title: String, symbol: String, isOn: Bool = false, handler: @escaping () -> Void
    ) -> UIAction {
        UIAction(title: title, image: UIImage(systemName: symbol), state: isOn ? .on : .off) { _ in handler() }
    }

    private static func option(_ title: String, isOn: Bool, handler: @escaping () -> Void) -> UIAction {
        UIAction(title: title, state: isOn ? .on : .off) { _ in handler() }
    }
}
