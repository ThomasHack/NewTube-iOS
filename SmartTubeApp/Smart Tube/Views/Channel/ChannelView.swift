import SmartTubeCore
import SwiftUI

// MARK: - ChannelView
//
// Displays channel info, subscriber count and a grid of recent uploads.
// Mirrors the Android `ChannelFragment`.

struct ChannelView: View {
    let channelId: String
    let vm: ChannelViewModel
    @State private var isFollowedLocally = false
    @Environment(SettingsStore.self) private var store
    @Environment(AuthService.self) private var auth
    @Environment(AppNavigator.self) private var navigator
    @Environment(SidebarChannelsViewModel.self) private var sidebarChannels

    init(channelId: String, viewModel: ChannelViewModel) {
        self.channelId = channelId
        vm = viewModel
    }

    var body: some View {
        Group {
            if vm.channel == nil && vm.error == nil {
                ProgressView("Loading channel…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("channel.view")
            } else {
                content
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { vm.loadIfStale(channelId: channelId) }
        .task(id: vm.channel?.id) {
            guard let id = vm.channel?.id else { return }
            isFollowedLocally = await LocalSubscriptionStore.shared.isFollowing(id)
        }
        .alert("Error", isPresented: .constant(vm.error != nil), presenting: vm.error) { _ in
            Button("Retry") {
                vm.error = nil
                vm.load(channelId: channelId)
            }
            Button("Dismiss", role: .cancel) { vm.error = nil }
        } message: { err in
            Text(err.localizedDescription)
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let channel = vm.channel {
                    channelHeader(channel)
                }
                videosGrid(vm.videos.filter { !$0.isShort })
                if vm.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }
            }
        }
        .refreshable { vm.load(channelId: channelId) }
        .accessibilityIdentifier("channel.view")
    }

    // MARK: - Grid layouts

    private func videosGrid(_ videos: [Video]) -> some View {
        let compact = store.settings.compactThumbnails
        return Group {
            if compact {
                LazyVStack(spacing: 0) {
                    ForEach(videos) { video in
                        VideoCardView(video: video, compact: true, onSelect: { navigator.play(video) })
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .accessibilityIdentifier("video.card.\(video.id)")
                            .onAppear {
                                if video.id == videos.last?.id { vm.loadMore() }
                            }
                        Divider().padding(.horizontal)
                    }
                }
            } else {
                let columnCount = 4
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(stride(from: 0, to: videos.count, by: columnCount)), id: \.self) { startIdx in
                        let rowVideos = Array(videos[startIdx..<min(startIdx + columnCount, videos.count)])
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(rowVideos) { video in
                                VideoCardView(video: video, compact: false, onSelect: { navigator.play(video) })
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
                            if rowVideos.last?.id == videos.last?.id { vm.loadMore() }
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func toggleSponsorBlockExclusion(for channel: Channel) {
        if store.settings.sponsorBlockExcludedChannels[channel.id] != nil {
            store.settings.sponsorBlockExcludedChannels.removeValue(forKey: channel.id)
        } else {
            store.settings.sponsorBlockExcludedChannels[channel.id] = channel.title
        }
    }

    private func channelHeader(_ channel: Channel) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: channel.thumbnailURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.secondary.opacity(0.3))
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("channel.title")
                if let subs = channel.subscriberCount {
                    Text(subs)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let desc = channel.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            HStack(spacing: 24) {
                if !auth.isSignedIn {
                    Button {
                        Task { await toggleFollow(channel) }
                    } label: {
                        Label(
                            isFollowedLocally ? "Unfollow" : "Follow",
                            systemImage: isFollowedLocally ? "bell.slash" : "bell"
                        )
                    }
                    .accessibilityIdentifier("channel.followButton")
                }
                sponsorBlockButton(channel)
            }
        }
        .padding()
        .accessibilityIdentifier("channel.header")
    }

    private func sponsorBlockButton(_ channel: Channel) -> some View {
        let isExcluded = store.settings.sponsorBlockExcludedChannels[channel.id] != nil
        return Button {
            toggleSponsorBlockExclusion(for: channel)
        } label: {
            Label(
                isExcluded ? "Remove SponsorBlock Exclusion" : "Exclude from SponsorBlock",
                systemImage: isExcluded
                    ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.minus"
            )
        }
        .accessibilityIdentifier("channel.sponsorBlockButton")
    }

    private func toggleFollow(_ channel: Channel) async {
        if isFollowedLocally {
            await LocalSubscriptionStore.shared.unfollow(channelId: channel.id)
            isFollowedLocally = false
        } else {
            let local = LocalChannel(
                id: channel.id,
                title: channel.title,
                thumbnailURL: channel.thumbnailURL
            )
            await LocalSubscriptionStore.shared.follow(local)
            isFollowedLocally = true
        }
        await sidebarChannels.reload()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Channel") {
    NavigationStack { ChannelView(channelId: PreviewData.channel.id, viewModel: .preview()) }
        .previewEnvironment()
}
#Preview("Signed out – Follow button") {
    NavigationStack { ChannelView(channelId: PreviewData.channel.id, viewModel: .preview()) }
        .previewEnvironment(signedIn: false)
}
#Preview("Excluded from SponsorBlock") {
    NavigationStack { ChannelView(channelId: PreviewData.channel.id, viewModel: .preview()) }
        .previewEnvironment { $0.sponsorBlockExcludedChannels = [PreviewData.channel.id: PreviewData.channel.title] }
}
#Preview("Long name") {
    NavigationStack {
        ChannelView(
            channelId: PreviewData.longNamedChannel.id, viewModel: .preview(channel: PreviewData.longNamedChannel))
    }
    .previewEnvironment()
}
#Preview("No videos") {
    NavigationStack { ChannelView(channelId: PreviewData.channel.id, viewModel: .preview(videos: [])) }
        .previewEnvironment()
}
#Preview("Loading") {
    NavigationStack {
        ChannelView(
            channelId: PreviewData.channel.id, viewModel: ChannelViewModel(api: PreviewInnerTubeAPI(hangs: true)))
    }
    .previewEnvironment()
}
#Preview("Error") {
    NavigationStack { ChannelView(channelId: PreviewData.channel.id, viewModel: .previewFailed()) }
        .previewEnvironment()
}
#endif
