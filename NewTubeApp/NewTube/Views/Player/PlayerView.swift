import AVFoundation
import NewTubeCore
import SwiftUI

// MARK: - PlayerView
//
// Full-screen playback in the system player. This view owns the playback lifecycle and turns the
// view model's state into what `NativePlayerController` shows.

struct PlayerView: View {
    let video: Video
    @State private var vm: PlaybackViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SettingsStore.self) private var store
    @Environment(AuthService.self) private var authService
    @Environment(AppNavigator.self) private var navigator
    /// True while the app is backgrounded, when `onDisappear` isn't a real navigation away.
    @State private var isInBackground = false
    @State private var showSignIn = false

    init(video: Video, api: InnerTubeAPI) {
        self.video = video
        _vm = State(initialValue: PlaybackViewModel(api: api))
    }

    /// Doesn't load anything, because `vm` already has its video.
    init(preview vm: PlaybackViewModel) {
        video = vm.currentVideo ?? Video(id: "", title: "", channelTitle: "")
        _vm = State(initialValue: vm)
    }

    private var currentVideo: Video { vm.playerInfo?.video ?? video }

    private var menuState: PlayerMenuState {
        PlayerMenuState(
            formats: vm.availableFormats,
            selectedFormat: vm.selectedFormat,
            playbackSpeed: store.settings.playbackSpeed,
            captions: vm.availableCaptions,
            selectedCaption: vm.selectedCaption,
            sleepTimerMinutes: vm.sleepTimerMinutes,
            isSignedIn: authService.isSignedIn,
            likeStatus: vm.likeStatus,
            isAudioOnly: vm.isAudioOnlyMode,
            isInQueue: currentVideo.playlistId == CurrentQueueStore.playlistID,
            isQueueShuffled: store.settings.queueShuffleEnabled,
            isShowingStats: vm.statsForNerdsVisible,
            hasPrevious: vm.hasPrevious,
            hasNext: vm.hasNext,
            hasChannel: currentVideo.channelId?.isEmpty == false
        )
    }

    private var itemInfo: PlayerItemInfo {
        PlayerItemInfo(
            videoId: currentVideo.id,
            title: currentVideo.title,
            channelTitle: currentVideo.channelTitle,
            description: currentVideo.description,
            thumbnailURL: currentVideo.thumbnailURL,
            duration: vm.duration,
            chapters: vm.chapters,
            sponsorSegments: vm.sponsorSegments
        )
    }

    var body: some View {
        NativePlayerController(
            vm: vm,
            menuState: menuState,
            itemInfo: itemInfo,
            // Read here so a new item, which arrives while loading, updates the controller.
            isLoading: vm.isLoading,
            skipSegment: vm.currentToastSegment,
            videoGravity: store.settings.videoGravityMode.avGravity,
            perform: perform
        )
        .ignoresSafeArea()
        .onAppear {
            if vm.currentVideoId == video.id {
                // Appearing again, e.g. after a sheet. Don't override an intentional pause.
                if vm.wasPlayingBeforeSuspend { vm.resume() }
            } else {
                vm.load(video: video)
            }
            vm.setPlaybackSpeed(store.settings.playbackSpeed)
            vm.updateSettings(store.settings)
            vm.updateAuthToken(authService.accessToken)
        }
        .onDisappear {
            guard !isInBackground else { return }
            vm.suspend()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                isInBackground = true
                vm.handleBackground()
            case .active:
                isInBackground = false
                vm.handleForeground()
            default:
                break
            }
        }
        .task(id: vm.isLoading) {
            guard !vm.isLoading else { return }
            await vm.prefetchAllQualityTracks()
        }
        .alert(
            "Playback Error",
            isPresented: Binding(get: { vm.error != nil && !showSignIn }, set: { _ in }),
            presenting: vm.error
        ) { error in
            errorActions(for: error)
        } message: { error in
            Text(error.localizedDescription)
        }
        .fullScreenCover(isPresented: $showSignIn) { SignInView() }
    }

    // MARK: - Errors

    @ViewBuilder
    private func errorActions(for error: Error) -> some View {
        switch error as? APIError {
        case .ipBlocked:
            // Retrying from the same IP also fails, and may extend YouTube's block.
            EmptyView()
        case .signInRequired:
            Button("Sign In") { showSignIn = true }
        default:
            Button("Try Again") { vm.retryLoad() }
        }
        Button("Close", role: .cancel) { navigator.playingVideo = nil }
    }

    // MARK: - Commands

    private func perform(_ command: PlayerCommand) {
        switch command {
        case .selectFormat(let format):
            vm.selectFormat(format)
        case .setSpeed(let speed):
            store.settings.playbackSpeed = speed
            vm.setPlaybackSpeed(speed)
        case .selectCaption(let track):
            vm.selectCaption(track)
        case .setSleepTimer(let minutes):
            vm.setSleepTimer(minutes: minutes)
        case .like:
            vm.like()
        case .dislike:
            vm.dislike()
        case .toggleAudioOnly:
            vm.toggleAudioOnlyLive()
            store.settings.audioOnlyMode = vm.isAudioOnlyMode
        case .toggleQueueShuffle:
            store.settings.queueShuffleEnabled.toggle()
        case .toggleStats:
            vm.toggleStatsForNerds()
        case .openChannel:
            guard let channelId = currentVideo.channelId else { return }
            vm.stop()
            navigator.openChannel(id: channelId)
        case .previousVideo:
            vm.playPrevious()
        case .nextVideo:
            vm.playNext()
        case .skipSegment:
            vm.skipToastSegment()
        }
    }
}
