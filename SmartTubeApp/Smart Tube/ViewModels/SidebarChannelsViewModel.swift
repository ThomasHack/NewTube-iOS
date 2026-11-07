import Foundation
import Observation
import SmartTubeCore
import UIKit

private let log = AppLogger(category: "SidebarChannels")

// MARK: - SidebarChannelsViewModel

/// The channels listed in the sidebar: YouTube subscriptions plus locally followed channels.
@MainActor
@Observable
final class SidebarChannelsViewModel {
    private(set) var channels: [Channel] = []
    private(set) var avatars: [String: UIImage] = [:]

    /// Keeps a long list from sending hundreds of requests at once.
    private static let maxConcurrentAvatarFetches = 6
    /// Publishing every avatar separately would rebuild the whole sidebar each time.
    private static let avatarBatchSize = 12

    private let api: any InnerTubeAPIProtocol
    private let localStore: LocalSubscriptionStore
    private let avatarCache: ChannelAvatarCache
    private var authToken: String?
    private var subscriptions: [Channel] = []

    init(
        api: any InnerTubeAPIProtocol,
        localStore: LocalSubscriptionStore = .shared,
        avatarCache: ChannelAvatarCache = .shared
    ) {
        self.api = api
        self.localStore = localStore
        self.avatarCache = avatarCache
    }

    func load(authToken: String?) async {
        self.authToken = authToken
        await api.setAuthToken(authToken)
        if authToken == nil {
            subscriptions = []
        } else {
            do {
                subscriptions = try await api.fetchSubscribedChannels()
            } catch {
                guard !Task.isCancelled else { return }
                // Keep the last list rather than dropping every subscription on a network error.
                log.error("Couldn't load subscribed channels: \(String(describing: error))")
            }
        }
        let local = await localStore.allChannels().map { $0.toChannel() }
        guard !Task.isCancelled else { return }
        channels = Self.sidebarList(subscriptions + local)
        await loadAvatars()
    }

    /// Reloads after a channel was followed or unfollowed.
    func reload() async {
        await load(authToken: authToken)
    }

    /// Sorted alphabetically, with duplicates and untitled channels removed.
    nonisolated static func sidebarList(_ channels: [Channel]) -> [Channel] {
        var seen = Set<String>()
        return
            channels
            .filter { !$0.title.isEmpty && seen.insert($0.id).inserted }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    // MARK: - Avatars

    private func loadAvatars() async {
        var needsDownload: [Channel] = []
        var cached = avatars
        for channel in channels {
            if cached[channel.id] == nil, let avatar = await avatarCache.avatar(channelId: channel.id) {
                cached[channel.id] = avatar
            }
            if await avatarCache.isExpired(channelId: channel.id) {
                needsDownload.append(channel)
            }
        }
        guard !Task.isCancelled else { return }
        avatars = cached

        let api = api
        let cache = avatarCache
        await withTaskGroup(of: (String, UIImage?).self) { group in
            var pending = needsDownload.makeIterator()
            func addNext() {
                guard let channel = pending.next() else { return }
                group.addTask {
                    var url = channel.thumbnailURL
                    if url == nil {
                        url = try? await api.fetchChannelThumbnailURL(channelId: channel.id)
                    }
                    guard let url else { return (channel.id, nil) }
                    return (channel.id, await cache.fetchAvatar(channelId: channel.id, url: url))
                }
            }
            for _ in 0..<Self.maxConcurrentAvatarFetches { addNext() }

            var batch: [String: UIImage] = [:]
            for await (channelId, avatar) in group {
                if let avatar { batch[channelId] = avatar }
                if batch.count >= Self.avatarBatchSize {
                    avatars.merge(batch) { _, new in new }
                    batch = [:]
                }
                if !Task.isCancelled { addNext() }
            }
            avatars.merge(batch) { _, new in new }
        }
    }
}

// MARK: - Previews

#if DEBUG
extension SidebarChannelsViewModel {
    /// Already lists `channels`, each with a generated avatar. Signed out, the list then reloads as
    /// the local follows, of which a preview has none.
    static func preview(channels: [Channel] = PreviewData.channels, signedIn: Bool = true) -> SidebarChannelsViewModel {
        let viewModel = SidebarChannelsViewModel(api: PreviewInnerTubeAPI(channels: channels))
        viewModel.channels = signedIn ? channels : []
        for (index, channel) in channels.enumerated() {
            viewModel.avatars[channel.id] = previewAvatar(initial: channel.title.prefix(1), index: index)
        }
        return viewModel
    }

    private static func previewAvatar(initial: Substring, index: Int) -> UIImage {
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemTeal]
        let size = CGSize(width: 48, height: 48)
        return UIGraphicsImageRenderer(size: size).image { _ in
            colors[index % colors.count].setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            let text = String(initial) as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24), .foregroundColor: UIColor.white,
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes)
        }.withRenderingMode(.alwaysOriginal)
    }
}
#endif
