import Foundation
import SmartTubeCore
import UIKit

private let log = AppLogger(category: "ChannelAvatarCache")

// MARK: - ChannelAvatarCache

/// Keeps round channel avatars in the Caches directory, so the sidebar shows them at launch without
/// any network requests.
actor ChannelAvatarCache {
    static let shared = ChannelAvatarCache()

    /// Older avatars are still shown, but get replaced by a new download.
    static let maxAge: TimeInterval = 30 * 24 * 60 * 60
    private static let avatarSize = CGSize(width: 48, height: 48)

    private let directory: URL
    private let download: @Sendable (URL) async throws -> Data

    init(
        directory: URL = URL.cachesDirectory.appending(path: "ChannelAvatars", directoryHint: .isDirectory),
        download: @escaping @Sendable (URL) async throws -> Data = { url in
            try await URLSession.shared.data(from: url).0
        }
    ) {
        self.directory = directory
        self.download = download
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func avatar(channelId: String) -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL(channelId)) else { return nil }
        return UIImage(data: data, scale: 2)?.withRenderingMode(.alwaysOriginal)
    }

    func isExpired(channelId: String) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL(channelId).path)
        guard let modified = attributes?[.modificationDate] as? Date else { return true }
        return Date().timeIntervalSince(modified) > Self.maxAge
    }

    /// Downloads the image, stores it as a round avatar and returns it.
    func fetchAvatar(channelId: String, url: URL) async -> UIImage? {
        do {
            let data = try await download(url)
            guard let source = UIImage(data: data), let png = Self.roundAvatarPNG(from: source) else { return nil }
            try png.write(to: fileURL(channelId), options: .atomic)
            return avatar(channelId: channelId)
        } catch {
            log.error("Couldn't fetch the avatar of \(channelId): \(String(describing: error))")
            return nil
        }
    }

    private func fileURL(_ channelId: String) -> URL {
        let name = channelId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? channelId
        return directory.appending(path: "\(name).png")
    }

    private static func roundAvatarPNG(from source: UIImage) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let bounds = CGRect(origin: .zero, size: avatarSize)
        return UIGraphicsImageRenderer(size: avatarSize, format: format).pngData { _ in
            UIBezierPath(ovalIn: bounds).addClip()
            // Fill the circle, cropping whichever side is longer.
            let scale = max(bounds.width / source.size.width, bounds.height / source.size.height)
            let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(
                in: CGRect(
                    x: (bounds.width - size.width) / 2,
                    y: (bounds.height - size.height) / 2,
                    width: size.width,
                    height: size.height
                ))
        }
    }
}
