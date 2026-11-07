import SmartTubeCore
import SwiftUI

// MARK: - LibraryView
//
// Shows subscriptions, playlists, watch history and liked videos for the
// signed-in account.  Mirrors the Android launcher activities for
// Subscriptions, Playlists, History and Channels.

public struct LibraryView: View {
    @Environment(AuthService.self) private var auth
    @Environment(BrowseViewModel.self) private var browseVM
    @Environment(\.innerTubeAPI) private var api
    @Environment(SettingsStore.self) private var store
    // Subscriptions has its own tab on Apple TV.
    @State private var selectedSection: LibrarySection = .history
    @State private var selectedVideo: Video?
    @State private var selectedPlaylist: Video?
    @State private var channelDestination: ChannelDestination?
    @State private var scrollStore = ScrollOffsetStore()
    @State private var savedScrollOffset: CGFloat? = nil
    @State private var restoreOffset: CGFloat? = nil
    @State private var queueVideosCount: Int = 0
    @FocusState private var focusedSection: LibrarySection?

    enum LibrarySection: String, CaseIterable, Identifiable {
        case subscriptions = "Subs"
        case history = "History"
        case playlists = "Playlists"
        case channels = "Channels"
        case rss = "RSS Feeds"

        // Subscriptions have their own tab.
        static var allCases: [LibrarySection] {
            [.history, .playlists, .channels, .rss]
        }

        var id: String { rawValue }
        var browseSectionType: BrowseSection.SectionType {
            switch self {
            case .subscriptions: return .subscriptions
            case .history: return .history
            case .playlists: return .playlists
            case .channels: return .channels
            case .rss: return .history  // not used — RSS renders its own view
            }
        }
    }

    public init() {}

    public var body: some View {
        Group {
            libraryContent
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedVideo) { video in
            PlayerView(video: video, api: api)
        }
        .navigationDestination(item: $selectedPlaylist) { stub in
            PlaylistView(playlistId: stub.id, playlistTitle: stub.title, api: api)
        }
        .navigationDestination(item: $channelDestination) { dest in
            ChannelView(channelId: dest.channelId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openChannel)) { note in
            guard let channelId = note.userInfo?["channelId"] as? String, !channelId.isEmpty else { return }
            channelDestination = ChannelDestination(channelId: channelId)
        }
    }

    private var libraryContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(LibrarySection.allCases) { sec in
                    let isSelected = selectedSection == sec
                    Button {
                        guard selectedSection != sec else { return }
                        selectedSection = sec
                    } label: {
                        Text(sec.rawValue)
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                (isSelected || focusedSection == sec) ? Color.primary : Color.secondary.opacity(0.15),
                                in: Capsule()
                            )
                            .foregroundStyle(
                                (isSelected || focusedSection == sec) ? Color(white: 0) : Color.primary
                            )
                    }
                    .buttonStyle(.borderless)
                    .scaleEffect(focusedSection == sec ? 1.12 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: focusedSection)
                    .animation(.easeInOut(duration: 0.15), value: selectedSection)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    .accessibilityIdentifier("library.chip.\(sec.rawValue.lowercased())")
                    .focused($focusedSection, equals: sec)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .focusSection()
            .defaultFocus($focusedSection, selectedSection)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("library.chipBar")

            Group {
                if selectedSection == .rss {
                    RSSFeedsView()
                } else if selectedSection == .channels {
                    channelsContent
                } else if !auth.isSignedIn && selectedSection != .subscriptions {
                    segmentSignInPrompt
                } else if browseVM.isLoading && browseVM.videoGroups.flatMap({ $0.videos }).isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if browseVM.videoGroups.flatMap({ $0.videos }).isEmpty && !browseVM.isLoading {
                    emptyLibraryView
                } else {
                    let applyHideShorts = store.settings.hideShorts && selectedSection != .history
                    let videos = browseVM.videoGroups.flatMap { $0.videos }
                        .filter { !applyHideShorts || !$0.isShort }
                    ScrollView {
                        // KVO reader — always present; writes to ScrollOffsetStore
                        // without triggering SwiftUI re-renders on every scroll tick.
                        ScrollOffsetReader(store: scrollStore)
                            .frame(width: 0, height: 0)

                        if browseVM.isLoading && videos.isEmpty {
                            ProgressView().frame(maxWidth: .infinity).padding()
                        }
                        if selectedSection == .playlists, queueVideosCount > 0 {
                            currentQueueRow
                        }
                        VideoGridSection(
                            videos: videos,
                            onSelect: { video in
                                if video.playlistId == video.id {
                                    selectedPlaylist = video
                                } else {
                                    selectedVideo = video
                                }
                            },
                            loadMore: {
                                if let last = videos.last {
                                    browseVM.loadMoreIfNeeded(lastVideo: last)
                                }
                            }
                        )
                        // Offset restorer — always present; no-op when restoreOffset is nil.
                        ScrollOffsetRestorer(targetOffset: restoreOffset) {
                            restoreOffset = nil
                        }
                        .frame(width: 0, height: 0)

                        if browseVM.isLoading && !videos.isEmpty {
                            ProgressView().frame(maxWidth: .infinity).padding()
                        }
                    }
                    .refreshable {
                        browseVM.loadContent(
                            for: BrowseSection(
                                id: selectedSection.id,
                                title: selectedSection.rawValue,
                                type: selectedSection.browseSectionType
                            ),
                            refresh: true
                        )
                    }
                }
            }
        }
        .onChange(of: selectedSection) { _, section in
            guard section != .rss else { return }
            browseVM.select(
                section: BrowseSection(
                    id: section.id,
                    title: section.rawValue,
                    type: section.browseSectionType
                ))
        }
        // tvOS: player is opened via navigationDestination(item: $selectedVideo).
        // Save offset when selectedVideo is set; restore when it clears.
        .onChange(of: selectedVideo) { old, new in
            if old == nil, new != nil {
                savedScrollOffset = scrollStore.scrollView?.contentOffset.y ?? 0
            } else if old != nil, new == nil, let saved = savedScrollOffset {
                restoreOffset = saved
                savedScrollOffset = nil
            }
        }
        .onDisappear {
            // Snapshot scroll position whenever the Library view leaves the screen
            // (player opening, tab switch, navigation push). At onDisappear time the
            // UIScrollView is still in memory and contentOffset is accurate.
            if let offset = scrollStore.scrollView?.contentOffset.y, offset > 0 {
                savedScrollOffset = offset
            }
        }
        .onAppear {
            guard selectedSection != .rss else { return }
            browseVM.select(
                section: BrowseSection(
                    id: selectedSection.id,
                    title: selectedSection.rawValue,
                    type: selectedSection.browseSectionType
                ))
            // Restore scroll position when returning from the player, another tab,
            // or any navigation that caused onDisappear to fire.
            if let saved = savedScrollOffset {
                restoreOffset = saved
                savedScrollOffset = nil
            }
        }
        .task(id: selectedSection) {
            guard selectedSection == .playlists else { return }
            queueVideosCount = await CurrentQueueStore.shared.videos.count
        }
    }

    /// Works signed out too: the view model falls back to locally followed channels.
    @ViewBuilder private var channelsContent: some View {
        if browseVM.isLoading && browseVM.subscribedChannels.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if browseVM.subscribedChannels.isEmpty {
            emptyLibraryView
        } else {
            ChannelListView(channels: browseVM.subscribedChannels) { channel in
                channelDestination = ChannelDestination(channelId: channel.id)
            }
            .focusSection()
        }
    }

    @ViewBuilder private var currentQueueRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "list.number")
                .font(.title2)
                .frame(width: 44, height: 44)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Current Queue")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text("\(queueVideosCount) video\(queueVideosCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedPlaylist = Video(
                id: CurrentQueueStore.playlistID,
                title: "Current Queue",
                channelTitle: ""
            )
        }
        .accessibilityIdentifier("library.currentQueueRow")
        Divider().padding(.horizontal)
    }

    @ViewBuilder private var emptyLibraryView: some View {
        if !auth.isSignedIn && selectedSection == .subscriptions {
            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Follow channels to see their latest videos here")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Search") {
                    NotificationCenter.default.post(name: .navigateToSearch, object: nil)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 16) {
                Image(systemName: AppSymbol.stackLayers)
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Nothing here yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var segmentSignInPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: AppSymbol.personCircleQuestion)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Sign in to see your \(selectedSection.rawValue.lowercased())")
                .font(.headline)
                .foregroundStyle(.secondary)
            NavigationLink("Sign In") {
                SignInView()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Signed in") {
    NavigationStack { LibraryView() }
        .previewEnvironment()
}

#Preview("Signed out") {
    NavigationStack { LibraryView() }
        .previewEnvironment(signedIn: false)
}
#endif
