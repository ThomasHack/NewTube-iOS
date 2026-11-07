import NewTubeCore
import SwiftUI

// MARK: - RSSFeedsView

/// Shows videos from all active user-added RSS feed subscriptions.
/// Mimics the queue/playlist layout (compact card list, newest-first).

struct RSSFeedsView: View {
    @Environment(SettingsStore.self) private var store
    /// Owned by the Library, so the feeds survive switching between its sections.
    let vm: RSSFeedsViewModel
    @State private var showAddFeed = false
    @State private var showManageFeeds = false

    @Environment(AppNavigator.self) private var navigator

    var body: some View {
        VStack(spacing: 0) {

            Group {
                if vm.isLoading && vm.videos.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.videos.isEmpty {
                    emptyState
                } else {
                    videoList
                }
            }
        }
        .sheet(isPresented: $showAddFeed, onDismiss: { vm.load() }) {
            AddRSSFeedView()
        }
        .sheet(isPresented: $showManageFeeds, onDismiss: { vm.load() }) {
            ManageRSSFeedsView()
        }
        .task {
            vm.loadIfStale()
        }
        .refreshable {
            vm.load()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No RSS Feeds")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Add a YouTube channel RSS feed to see videos here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showAddFeed = true
            } label: {
                Label("Add RSS Feed", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("rss.emptyAddFeedButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Video List

    private var videoList: some View {
        let hideVideoPremieres = store.settings.hideVideoPremieres
        let displayVideos = vm.videos
            .filter { !$0.isShort }
            .filter { !hideVideoPremieres || !$0.isUpcoming }
        return ScrollView {
            VideoGridSection(
                videos: displayVideos,
                onSelect: { video in
                    navigator.play(video)
                }
            )
            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
        }
    }
}
