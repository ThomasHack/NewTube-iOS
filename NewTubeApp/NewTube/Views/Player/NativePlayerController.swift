import AVFoundation
import AVKit
import NewTubeCore
import SwiftUI

// MARK: - PlayerItemInfo

/// What the system player shows about the current item.
struct PlayerItemInfo: Equatable {
    var videoId: String
    var title: String
    var channelTitle: String
    var description: String?
    var thumbnailURL: URL?
    var duration: TimeInterval
    var chapters: [Chapter]
    var sponsorSegments: [SponsorSegment]
}

// MARK: - NativePlayerController

/// `AVPlayerViewController` showing the view model's player, with the app's features added through
/// the system's extension points: transport bar menus, contextual actions, chapter markers, an info
/// tab for comments and a content overlay.
struct NativePlayerController: UIViewControllerRepresentable {
    let vm: PlaybackViewModel
    let menuState: PlayerMenuState
    let itemInfo: PlayerItemInfo
    let isLoading: Bool
    let skipSegment: SponsorSegment?
    let videoGravity: AVLayerVideoGravity
    let perform: (PlayerCommand) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = vm.player
        context.coordinator.addContentOverlay(PlayerContentOverlay(vm: vm), to: controller)

        let comments = UIHostingController(
            rootView: PlayerCommentsTab(comments: vm.comments, videoId: { vm.currentVideoId }))
        comments.title = String(localized: "Comments")
        comments.preferredContentSize = CGSize(width: 0, height: 620)
        controller.customInfoViewControllers = [comments]
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.perform = perform
        controller.videoGravity = videoGravity

        if coordinator.menuState != menuState {
            coordinator.menuState = menuState
            controller.transportBarCustomMenuItems = PlayerMenu.items(for: menuState) { [weak coordinator] command in
                coordinator?.perform?(command)
            }
        }
        if coordinator.skipSegment != skipSegment {
            coordinator.skipSegment = skipSegment
            controller.contextualActions =
                skipSegment.map { segment in
                    let title = String(localized: "Skip \(segment.category.displayName)")
                    return [
                        UIAction(title: title) { [weak coordinator] _ in
                            coordinator?.perform?(.skipSegment)
                        }
                    ]
                } ?? []
        }
        if let item = vm.player.currentItem {
            coordinator.configure(item, with: itemInfo)
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator {
        var perform: ((PlayerCommand) -> Void)?
        var menuState: PlayerMenuState?
        var skipSegment: SponsorSegment?
        private var configuredItem: AVPlayerItem?
        private var configuredInfo: PlayerItemInfo?
        private var artworkTask: Task<Void, Never>?

        func addContentOverlay(_ overlay: PlayerContentOverlay, to controller: AVPlayerViewController) {
            guard let container = controller.contentOverlayView else { return }
            let host = UIHostingController(rootView: overlay)
            host.view.backgroundColor = .clear
            host.view.isUserInteractionEnabled = false
            host.view.frame = container.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            controller.addChild(host)
            container.addSubview(host.view)
            host.didMove(toParent: controller)
        }

        /// Quality changes and fallbacks swap the item, so this applies to whichever is current.
        func configure(_ item: AVPlayerItem, with info: PlayerItemInfo) {
            guard item !== configuredItem || info != configuredInfo else { return }
            configuredItem = item
            configuredInfo = info

            let metadata = PlayerItemMetadata.items(for: info)
            item.externalMetadata = metadata
            item.navigationMarkerGroups = PlayerItemMetadata.chapterMarkers(for: info)
            item.interstitialTimeRanges = PlayerItemMetadata.segmentRanges(for: info)

            artworkTask?.cancel()
            guard let url = info.thumbnailURL else { return }
            artworkTask = Task { [weak item] in
                guard let (data, _) = try? await URLSession.shared.data(from: url), !Task.isCancelled else { return }
                item?.externalMetadata = metadata + [PlayerItemMetadata.artwork(data)]
            }
        }
    }
}

// MARK: - PlayerItemMetadata

enum PlayerItemMetadata {
    static func items(for info: PlayerItemInfo) -> [AVMetadataItem] {
        var items = [
            item(.commonIdentifierTitle, info.title),
            item(.iTunesMetadataTrackSubTitle, info.channelTitle),
        ]
        if let description = info.description, !description.isEmpty {
            items.append(item(.commonIdentifierDescription, description))
        }
        return items
    }

    static func artwork(_ data: Data) -> AVMetadataItem {
        let artwork = AVMutableMetadataItem()
        artwork.identifier = .commonIdentifierArtwork
        artwork.value = data as NSData
        artwork.dataType = kCMMetadataBaseDataType_JPEG as String
        artwork.extendedLanguageTag = "und"
        return artwork
    }

    static func chapterMarkers(for info: PlayerItemInfo) -> [AVNavigationMarkersGroup] {
        guard !info.chapters.isEmpty, info.duration > 0 else { return [] }
        let markers = info.chapters.enumerated().map { index, chapter in
            let end = index + 1 < info.chapters.count ? info.chapters[index + 1].startTime : info.duration
            return AVTimedMetadataGroup(
                items: [item(.commonIdentifierTitle, chapter.title)],
                timeRange: timeRange(from: chapter.startTime, to: end)
            )
        }
        return [AVNavigationMarkersGroup(title: nil, timedNavigationMarkers: markers)]
    }

    static func segmentRanges(for info: PlayerItemInfo) -> [AVInterstitialTimeRange] {
        info.sponsorSegments.map { AVInterstitialTimeRange(timeRange: timeRange(from: $0.start, to: $0.end)) }
    }

    private static func item(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item
    }

    private static func timeRange(from start: TimeInterval, to end: TimeInterval) -> CMTimeRange {
        CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )
    }
}

// MARK: - PlayerContentOverlay

/// What the system player can't show itself. Sits above the video and below its controls, and
/// never takes focus.
struct PlayerContentOverlay: View {
    let vm: PlaybackViewModel

    var body: some View {
        ZStack {
            if vm.isAudioOnlyMode {
                audioOnlyArtwork
            }
            if let message = vm.retryStatusMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.bottom, 200)
                }
            }
            if let cue = vm.currentCaptionCue {
                VStack {
                    Spacer()
                    CaptionCueView(text: cue.text)
                        .padding(.bottom, 60)
                }
            }
            if vm.statsForNerdsVisible {
                StatsForNerdsOverlay(snapshot: vm.statsSnapshot)
            }
        }
    }

    /// The player keeps its item, which has no picture in this mode.
    private var audioOnlyArtwork: some View {
        ZStack {
            Color.black
            AsyncImage(url: vm.playerInfo?.video.thumbnailURL ?? vm.currentVideo?.thumbnailURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit().frame(maxWidth: 640)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 96))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityLabel("Audio only — thumbnail")
    }
}

// MARK: - PlayerCommentsTab

/// The Comments tab in the system player's info panel.
struct PlayerCommentsTab: View {
    let comments: CommentsController
    let videoId: () -> String?

    var body: some View {
        Group {
            if comments.isLoading {
                ProgressView()
            } else if comments.comments.isEmpty {
                ContentUnavailableView("No Comments", systemImage: "bubble.left.and.bubble.right")
            } else {
                List(comments.comments) { comment in
                    CommentRowView(comment: comment)
                        .focusable()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if let id = videoId() { comments.load(videoId: id) }
        }
    }
}
