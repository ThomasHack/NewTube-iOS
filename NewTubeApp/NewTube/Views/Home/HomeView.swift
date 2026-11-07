import NewTubeCore
import SwiftUI

// MARK: - HomeView
//
// A video feed for one section, shown by the Home and Subscriptions tabs.

struct HomeView: View {
    @State private var sectionVM: BrowseViewModel
    @Environment(AuthService.self) private var auth
    @Environment(SettingsStore.self) private var store
    @Environment(AppNavigator.self) private var navigator
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedSection: BrowseSection = BrowseSection.allSections[0]
    @State private var showSignIn = false
    // Auto-retry tracking: record the video count at the moment a scroll trigger fires, so onChange
    // can detect whether the next page added anything visible (a page can hold only Shorts).
    @State private var needsMoreVideos = false
    @State private var videoCountAtTrigger = 0

    init(sectionVM: BrowseViewModel, section: BrowseSection? = nil) {
        _sectionVM = State(initialValue: sectionVM)
        if let section { _selectedSection = State(initialValue: section) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            contentArea
                .focusSection()
        }
        .fullScreenCover(isPresented: $showSignIn) { SignInView() }
        .task(id: auth.accessToken) {
            // Apple TV never shows the mixed Home feed, so it must not be loaded there.
            await sectionVM.updateAuthToken(auth.accessToken)
            // This task restarts whenever the view reappears, e.g. after switching tabs.
            sectionVM.refreshIfStale()
        }
        .task(id: selectedSection) {
            // Reset auto-retry flags when switching sections to prevent stale
            // triggers from a previous section firing on the new section's content.
            needsMoreVideos = false
            if selectedSection.type != .home {
                // Safety net: if sectionVM somehow fell out of sync with selectedSection
                // (e.g., the chip action raced with an in-flight cancellation, or an
                // @Observable tracking gap left the view empty), force a reload.
                if sectionVM.currentSection != selectedSection {
                    sectionVM.select(section: selectedSection)
                }
            }
        }
    }

    // MARK: - Chip bar

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        sectionFeed
            .accessibilityIdentifier("home.sectionContainer")
    }

    // MARK: - Section feed

    @ViewBuilder
    private var sectionFeed: some View {
        if sectionVM.isAwaitingContent && sectionVM.videoGroups.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if sectionVM.videoGroups.isEmpty {
            feedEmptyState
        } else {
            feedContent
        }
    }

    private var feedContent: some View {
        let hideVideoPremieres = store.settings.hideVideoPremieres
        // #121: History is the one place watched videos are the point — never filtered.
        let applyHideWatched = store.settings.hideWatchedVideos && selectedSection.type != .history
        let hideWatchedThreshold = store.settings.hideWatchedThreshold

        let rowGroups: [VideoGroup] = sectionVM.videoGroups.filter { $0.layout == .row }.map { g in
            var copy = g
            var videos = g.videos.filter { !$0.isShort }
            if hideVideoPremieres { videos = videos.filter { !$0.isUpcoming } }
            if applyHideWatched { videos = videos.filter { !$0.isWatched(threshold: hideWatchedThreshold) } }
            copy.videos = videos
            return copy
        }
        // VStack (not LazyVStack) is required here. LazyVGrid inside LazyVStack
        // collapses to zero height — grid items become invisible and non-tappable
        // because LazyVStack never provides a measured height to LazyVGrid.
        // Row groups are few (typically ≤15 carousels) so eager rendering is fine.
        let gridVideos = sectionVM.videoGroups.filter { $0.layout != .row }
            .flatMap(\.videos)
            .filter { !$0.isShort }
            .filter { !hideVideoPremieres || !$0.isUpcoming }
            .filter { !applyHideWatched || !$0.isWatched(threshold: hideWatchedThreshold) }

        // The raw last video of the last group is the canonical pagination trigger for
        // loadMoreIfNeeded — it checks membership in videoGroups.last, so passing a
        // filtered video won't match if the last group holds only Shorts.
        let paginationTrigger: Video? = sectionVM.videoGroups.last?.videos.last

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Also keeps the first row clear of the collapsed sidebar above it.
                NewTubeLogo()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                ForEach(rowGroups) { group in
                    if let title = group.title, !title.isEmpty {
                        Text(title)
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                    }
                    VideoRowSection(videos: group.videos, onSelect: { selectVideo($0) })
                }
                if !gridVideos.isEmpty {
                    VideoGridSection(
                        videos: gridVideos,
                        onSelect: { selectVideo($0) },
                        loadMore: {
                            videoCountAtTrigger = visibleVideoCount
                            needsMoreVideos = true
                            if let last = paginationTrigger {
                                sectionVM.loadMoreIfNeeded(lastVideo: last)
                            }
                        }
                    )
                }
                if sectionVM.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }
            }
        }
        .accessibilityIdentifier("home.sectionFeed")
        .refreshable { sectionVM.loadContent(refresh: true) }
        .focusSection()
        .onChange(of: sectionVM.videoGroups.flatMap(\.videos).count) { _, _ in
            // Keep fetching until a page adds a visible video or the pages run out. Compare against
            // the count from when the scroll trigger fired, not the last page. loadMoreIfNeeded's own
            // guards prevent runaway loops.
            guard needsMoreVideos, let trigger = sectionVM.videoGroups.last?.videos.last else { return }
            if visibleVideoCount > videoCountAtTrigger || sectionVM.videoGroups.last?.nextPageToken == nil {
                needsMoreVideos = false
            } else {
                sectionVM.loadMoreIfNeeded(lastVideo: trigger)
            }
        }
    }

    private var visibleVideoCount: Int {
        sectionVM.videoGroups.flatMap(\.videos).filter { !$0.isShort }.count
    }

    private var feedEmptyState: some View {
        VStack(spacing: 16) {
            if sectionVM.isAuthRequired && !auth.isSignedIn {
                Image(systemName: AppSymbol.personCircleWarning)
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Sign in to see this section")
                    .font(.title3)
                Text("Your Google account is required.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Sign In") { showSignIn = true }
                    .buttonStyle(.borderedProminent)
            } else if !auth.isSignedIn && selectedSection.type == .subscriptions {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Follow channels to see their latest videos here")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                Text("Search for a channel and tap Follow.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Search") {
                    navigator.openSearch()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: AppSymbol.tvPlay)
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Nothing here yet")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Button("Refresh") { sectionVM.loadContent(refresh: true) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Video selection

    private func selectVideo(_ video: Video) {
        if video.playlistId == video.id {
            navigator.openPlaylist(id: video.id, title: video.title)
        } else {
            navigator.play(video)
        }
    }
}

// MARK: - Previews

#if DEBUG
extension HomeView {
    fileprivate static func preview(
        _ type: BrowseSection.SectionType, _ state: BrowseViewModel.PreviewState, signedIn: Bool = true
    ) -> some View {
        let section = BrowseSection(type: type)
        return NavigationStack {
            HomeView(sectionVM: .preview(section: section, state: state, signedIn: signedIn), section: section)
        }
        .previewEnvironment(signedIn: signedIn)
    }
}

#Preview("Home") { HomeView.preview(.recommended, .loaded(PreviewData.videos)) }
#Preview("Home – Loading") { HomeView.preview(.recommended, .loading) }
#Preview("Home – Nothing here") { HomeView.preview(.recommended, .empty) }
#Preview("Home – Signed out") { HomeView.preview(.recommended, .loaded(PreviewData.popular), signedIn: false) }
#Preview("Subscriptions") { HomeView.preview(.subscriptions, .loaded(PreviewData.subscriptions)) }
#Preview("Subscriptions – Loading") { HomeView.preview(.subscriptions, .loading) }
#Preview("Subscriptions – No videos") { HomeView.preview(.subscriptions, .empty) }
#Preview("Subscriptions – Not following anyone") { HomeView.preview(.subscriptions, .empty, signedIn: false) }
#Preview("Subscriptions – Sign-in required") { HomeView.preview(.subscriptions, .signInRequired, signedIn: false) }
#Preview("Home – Compact cards") {
    let section = BrowseSection(type: .recommended)
    return NavigationStack {
        HomeView(sectionVM: .preview(section: section, state: .loaded(PreviewData.videos)), section: section)
    }
    .previewEnvironment { $0.compactThumbnails = true }
}
#endif
