import SmartTubeCore
import SwiftUI
import UIKit
import os

extension ShortsPlayerView {

    // MARK: - Navigation

    /// Animates the current content off-screen in `direction` (-1 = up, +1 = down),
    /// runs `action` to switch to the new video, then slides the new content in
    /// from the opposite side.
    func performVerticalTransition(direction: CGFloat, action: @escaping () -> Void) {
        let screenHeight: CGFloat = 800
        isTransitioning = true
        withAnimation(.easeIn(duration: 0.2)) {
            slideOffset = direction * screenHeight
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            action()  // switch video, clears AVPlayer
            slideOffset = -direction * screenHeight  // snap to opposite side (off-screen)
            withAnimation(.easeOut(duration: 0.25)) {
                slideOffset = 0  // slide new content in
            }
            try? await Task.sleep(for: .milliseconds(270))
            isTransitioning = false
        }
    }

    func goTo(_ index: Int) {
        guard index >= 0, index < videos.count else { return }

        currentIndex = index
        loadVideo(at: index)

        // Pre-fetch more Shorts when within 2 of the end.
        if index >= videos.count - 2 {
            loadMoreIfNeeded()
        }
        // Pre-fetch the next 2 shorts so swiping is instant.
        let lookahead = videos[(index + 1)..<min(index + 3, videos.count)].map(\.id)
        if !lookahead.isEmpty {
            let token = authService.accessToken
            let cats = store.settings.activeSponsorCategories
            Task(priority: .background) {
                for videoId in lookahead {
                    await VideoPreloadCache.shared.prefetch(
                        videoId: videoId,
                        sponsorCategories: cats,
                        authToken: token,
                        priority: .speculative
                    )
                }
            }
        }
    }

    /// Fetches an additional batch of Shorts and appends them, deduplicating by id.
    func loadMoreIfNeeded() {
        guard !ProcessInfo.processInfo.arguments.contains("--uitesting") else { return }
        guard !isFetchingMore else { return }
        isFetchingMore = true
        let existingIDs = Set(videos.map(\.id))
        Task { @MainActor in
            defer { isFetchingMore = false }
            guard let group = try? await api.fetchShorts() else { return }
            let newVideos = group.videos.filter { !existingIDs.contains($0.id) }
            guard !newVideos.isEmpty else { return }
            videos.append(contentsOf: newVideos)
        }
    }

    func loadVideo(at index: Int) {
        let video = videos[index]
        vm.load(video: video)
        vm.setPlaybackSpeed(store.settings.playbackSpeed)
        vm.updateSettings(store.settings)
    }

}
