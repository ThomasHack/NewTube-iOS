import NewTubeCore
import SwiftUI

// MARK: - PlaylistView
//
// Shows the videos inside a user playlist.
// Mirrors the Android `PlaylistFragment`.

struct PlaylistView: View {
    let playlistId: String
    let playlistTitle: String

    @Environment(AuthService.self) private var auth
    @Environment(SettingsStore.self) private var store
    @Environment(AppNavigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss
    @State private var vm: PlaylistViewModel

    init(playlistId: String, playlistTitle: String, viewModel: PlaylistViewModel) {
        self.playlistId = playlistId
        self.playlistTitle = playlistTitle
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.videos.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.videos.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle(playlistTitle)
        .toolbar {
            if playlistId == CurrentQueueStore.playlistID {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        Task {
                            await CurrentQueueStore.shared.clear()
                            dismiss()
                        }
                    } label: {
                        Label("Clear Queue", systemImage: "trash")
                    }
                }
            }
        }
        .onAppear {
            vm.load(playlistId: playlistId)
        }
        .alert("Error", isPresented: .constant(vm.error != nil), presenting: vm.error) { _ in
            Button("Retry") { vm.load(playlistId: playlistId) }
            Button("Dismiss", role: .cancel) { vm.error = nil }
        } message: { err in
            Text(err.localizedDescription)
        }
    }

    private var content: some View {
        ScrollView {
            if store.settings.compactThumbnails {

                LazyVStack(spacing: 0) {
                    ForEach(displayVideos) { video in
                        VideoCardView(
                            video: video, compact: true, currentPlaylistId: playlistId,
                            onSelect: {
                                Task { @MainActor in
                                    let captured = displayVideos
                                    await CurrentQueueStore.shared.replaceAll(with: captured)
                                    let startIdx =
                                        video.playlistIndex ?? captured.firstIndex(where: { $0.id == video.id }) ?? 0
                                    navigator.play(await CurrentQueueStore.shared.videoAt(index: startIdx) ?? video)
                                }
                            }
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .accessibilityIdentifier("video.card.\(video.id)")
                        .onAppear { vm.loadMoreIfNeeded(lastVideo: video) }
                        Divider().padding(.horizontal)
                    }
                    if vm.isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    }
                }
            } else {
                let columnCount = 4
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(stride(from: 0, to: displayVideos.count, by: columnCount)), id: \.self) { startIdx in
                        let rowVideos = Array(
                            displayVideos[startIdx..<min(startIdx + columnCount, displayVideos.count)])
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(rowVideos) { video in
                                VideoCardView(
                                    video: video, compact: false, currentPlaylistId: playlistId,
                                    onSelect: {
                                        Task { @MainActor in
                                            let captured = displayVideos
                                            await CurrentQueueStore.shared.replaceAll(with: captured)
                                            let startIdx =
                                                video.playlistIndex ?? captured.firstIndex(where: { $0.id == video.id })
                                                ?? 0
                                            navigator.play(
                                                await CurrentQueueStore.shared.videoAt(index: startIdx) ?? video)
                                        }
                                    }
                                )
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("video.card.\(video.id)")
                            }
                            let remainder = columnCount - rowVideos.count
                            if remainder > 0 {
                                ForEach(0..<remainder, id: \.self) { _ in
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .onAppear {
                            if let last = rowVideos.last { vm.loadMoreIfNeeded(lastVideo: last) }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                if vm.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }
            }
        }
        .accessibilityIdentifier("playlistView.feed")
        .refreshable { vm.load(playlistId: playlistId, refresh: true) }
    }

    private var displayVideos: [Video] {
        vm.videos.filter { !$0.isShort }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: AppSymbol.stackLayers)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No videos in this playlist")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#if DEBUG
private struct PreviewQueueLoader: QueuedPlaylistLoader {
    func loadQueuedVideos(for playlistId: String) -> [Video]? { PreviewData.playlistVideos }
}

#Preview("Playlist") {
    NavigationStack {
        PlaylistView(
            playlistId: "PLpreview1", playlistTitle: "Open Movies", viewModel: .preview(playlistId: "PLpreview1"))
    }
    .previewEnvironment()
}
#Preview("Current Queue") {
    NavigationStack {
        PlaylistView(
            playlistId: CurrentQueueStore.playlistID,
            playlistTitle: "Current Queue",
            viewModel: PlaylistViewModel(api: PreviewInnerTubeAPI(), queueLoader: PreviewQueueLoader())
        )
    }
    .previewEnvironment()
}
#Preview("Empty") {
    NavigationStack {
        PlaylistView(
            playlistId: "PLempty",
            playlistTitle: "An empty playlist",
            viewModel: PlaylistViewModel(api: PreviewInnerTubeAPI(playlistVideos: []))
        )
    }
    .previewEnvironment()
}
#Preview("Loading") {
    NavigationStack {
        PlaylistView(
            playlistId: "PLloading",
            playlistTitle: "Open Movies",
            viewModel: PlaylistViewModel(api: PreviewInnerTubeAPI(hangs: true))
        )
    }
    .previewEnvironment()
}
#endif
