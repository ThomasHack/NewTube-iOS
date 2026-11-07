import NewTubeCore
import SwiftUI

// MARK: - LibraryView
//
// Shows subscriptions, playlists, watch history and liked videos for the
// signed-in account.  Mirrors the Android launcher activities for
// Subscriptions, Playlists, History and Channels.

struct LibraryView: View {
    @Environment(AuthService.self) private var auth
    @Environment(BrowseViewModel.self) private var browseVM
    @Environment(AppNavigator.self) private var navigator
    @Environment(SettingsStore.self) private var store
    @Environment(AppFeeds.self) private var feeds
    @State private var showSignIn = false
    @State private var scrollStore = ScrollOffsetStore()
    @State private var savedScrollOffset: CGFloat? = nil
    @State private var restoreOffset: CGFloat? = nil
    @State private var queueVideosCount: Int = 0

    enum LibrarySection: String, CaseIterable, Identifiable {
        case subscriptions = "Subs"
        case history = "History"
        case playlists = "Playlists"
        case rss = "RSS Feeds"

        // Subscriptions have their own tab, and channels are listed in the sidebar.
        static var allCases: [LibrarySection] {
            [.history, .playlists, .rss]
        }

        var id: String { rawValue }
        var browseSectionType: BrowseSection.SectionType {
            switch self {
            case .subscriptions: return .subscriptions
            case .history: return .history
            case .playlists: return .playlists
            case .rss: return .history  // not used — RSS renders its own view
            }
        }
    }

    private var selectedSection: LibrarySection {
        get { feeds.librarySection }
        nonmutating set { feeds.librarySection = newValue }
    }

    init() {}

    var body: some View {
        Group {
            libraryContent
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showSignIn) { SignInView() }
    }

    private var libraryContent: some View {
        VStack(spacing: 0) {
            Picker(
                "Library",
                selection: Binding(
                    get: { selectedSection },
                    set: { selectedSection = $0 }
                )
            ) {
                ForEach(LibrarySection.allCases) { section in
                    Text(LocalizedStringKey(section.rawValue)).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 800)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .focusSection()
            .accessibilityIdentifier("library.chipBar")

            Group {
                if selectedSection == .rss {
                    RSSFeedsView(vm: feeds.rss)
                } else if !auth.isSignedIn && selectedSection != .subscriptions {
                    segmentSignInPrompt
                } else if browseVM.isAwaitingContent && browseVM.videoGroups.flatMap({ $0.videos }).isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if browseVM.videoGroups.flatMap({ $0.videos }).isEmpty {
                    emptyLibraryView
                } else {
                    let videos = browseVM.videoGroups.flatMap { $0.videos }
                        .filter { !$0.isShort }
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
                                    navigator.openPlaylist(id: video.id, title: video.title)
                                } else {
                                    navigator.play(video)
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
            browseVM.refreshIfStale()
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
            navigator.openPlaylist(id: CurrentQueueStore.playlistID, title: "Current Queue")
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
                    navigator.openSearch()
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
            Button("Sign In") { showSignIn = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("History") {
    NavigationStack { LibraryView() }
        .previewEnvironment()
}
#Preview("History – Loading") {
    NavigationStack { LibraryView() }
        .previewEnvironment(browseVM: .preview(librarySection: .history, state: .loading))
}
#Preview("History – Empty") {
    NavigationStack { LibraryView() }
        .previewEnvironment(browseVM: .preview(librarySection: .history, state: .empty))
}
#Preview("Playlists") {
    NavigationStack { LibraryView() }
        .previewEnvironment(
            browseVM: .preview(librarySection: .playlists, state: .loaded(PreviewData.playlistCards)),
            librarySection: .playlists)
}
#Preview("Playlists – Empty") {
    NavigationStack { LibraryView() }
        .previewEnvironment(browseVM: .preview(librarySection: .playlists, state: .empty), librarySection: .playlists)
}
#Preview("RSS Feeds") {
    NavigationStack { LibraryView() }
        .previewEnvironment(librarySection: .rss)
}
#Preview("RSS Feeds – Loading") {
    NavigationStack { LibraryView() }
        .previewEnvironment(librarySection: .rss, rss: .preview(videos: [], isLoading: true))
}
#Preview("RSS Feeds – No feeds") {
    NavigationStack { LibraryView() }
        .previewEnvironment(librarySection: .rss, rss: .preview(videos: []))
}
#Preview("Signed out") {
    NavigationStack { LibraryView() }
        .previewEnvironment(signedIn: false)
}
#endif
