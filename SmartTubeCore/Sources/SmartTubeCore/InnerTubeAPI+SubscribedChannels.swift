import Foundation
import os

private let tubeLog = Logger(subsystem: appSubsystem, category: "InnerTube")

// MARK: - Subscribed channels
//
// The TV guide only lists part of a large subscription list. `FEchannels` is YouTube's full,
// paged list, so its pages are merged in. It's known to work with a web session, and is also
// tried with the TV client, which is what's available when the cookie exchange failed.

extension InnerTubeAPI {
    /// Stops a looping continuation token from fetching forever.
    private static let maxChannelListPages = 100

    /// Fetches the channels the authenticated user subscribes to, without duplicates.
    public func fetchSubscribedChannels() async throws -> [Channel] {
        var channels: [Channel] = []
        var firstError: Error?

        do {
            let guide = parseGuideChannels(
                from: try await postTV(endpoint: "guide", body: makeBody(client: tvClientContext)))
            tubeLog.notice("fetchSubscribedChannels guide → \(guide.count, privacy: .public) channels")
            channels += guide
        } catch {
            firstError = error
            tubeLog.error("fetchSubscribedChannels guide failed: \(String(describing: error), privacy: .public)")
        }

        let tvList = await fetchChannelList(label: "TV") { [self] token in
            var body = makeBody(client: tvClientContext, continuationToken: token)
            if token == nil { body["browseId"] = "FEchannels" }
            return try await postTV(endpoint: "browse", body: body)
        }
        channels += tvList

        if let sapisid {
            let webList = await fetchChannelList(label: "WEB") { [self] token in
                var body = makeBody(client: webClientContext, continuationToken: token)
                if token == nil { body["browseId"] = "FEchannels" }
                return try await postWebSession(endpoint: "browse", body: body, sapisid: sapisid)
            }
            channels += webList
        } else {
            tubeLog.notice("fetchSubscribedChannels: no web session, skipping WEB FEchannels")
        }

        if channels.isEmpty {
            tubeLog.notice("fetchSubscribedChannels: no list available, using the subscription feed")
            var body = makeBody(client: tvClientContext)
            body["browseId"] = "FEsubscriptions"
            do {
                return parseSubscribedChannels(from: try await postTV(endpoint: "browse", body: body))
            } catch {
                throw firstError ?? error
            }
        }

        var seen = Set<String>()
        let unique = channels.filter { seen.insert($0.id).inserted }
        tubeLog.notice("fetchSubscribedChannels → \(unique.count, privacy: .public) channels in total")
        return unique
    }

    /// Follows the continuation tokens of one channel list. A failing page ends the list, because
    /// the other sources may still have the channels.
    private func fetchChannelList(
        label: String, fetchPage: (String?) async throws -> [String: Any]
    ) async -> [Channel] {
        var channels: [Channel] = []
        var token: String?
        for page in 1...Self.maxChannelListPages {
            do {
                let (pageChannels, next) = parseChannelListPage(from: try await fetchPage(token))
                channels += pageChannels
                tubeLog.notice(
                    "FEchannels [\(label, privacy: .public)] page \(page, privacy: .public): \(pageChannels.count, privacy: .public) channels, more=\(next != nil, privacy: .public)"
                )
                guard let next, next != token, !Task.isCancelled else { break }
                token = next
            } catch {
                tubeLog.error(
                    "FEchannels [\(label, privacy: .public)] failed: \(String(describing: error), privacy: .public)")
                break
            }
        }
        return channels
    }

    /// Reads the channels and the next page's token from an `FEchannels` response.
    func parseChannelListPage(from json: [String: Any]) -> (channels: [Channel], nextToken: String?) {
        var channels: [Channel] = []
        var nextToken: String?

        func walk(_ object: Any, depth: Int) {
            guard depth < 50 else { return }
            if let array = object as? [Any] {
                for item in array { walk(item, depth: depth + 1) }
                return
            }
            guard let dict = object as? [String: Any] else { return }

            for key in ["channelRenderer", "gridChannelRenderer", "compactChannelRenderer"] {
                if let renderer = dict[key] as? [String: Any], let channel = channel(fromRenderer: renderer) {
                    channels.append(channel)
                    return
                }
            }
            if let tile = dict["tileRenderer"] as? [String: Any], let channel = channel(fromTile: tile) {
                channels.append(channel)
                return
            }
            if nextToken == nil {
                nextToken =
                    (dict["continuationCommand"] as? [String: Any])?["token"] as? String
                    ?? (dict["nextContinuationData"] as? [String: Any])?["continuation"] as? String
            }
            for value in dict.values { walk(value, depth: depth + 1) }
        }

        walk(json, depth: 0)
        return (channels, nextToken)
    }

    private func channel(fromRenderer renderer: [String: Any]) -> Channel? {
        guard let id = renderer["channelId"] as? String, !id.isEmpty else { return nil }
        let title = (renderer["title"] as? [String: Any]).flatMap { extractText($0) } ?? ""
        return Channel(
            id: id, title: title, thumbnailURL: lastThumbnailURL(in: renderer["thumbnail"]), isSubscribed: true)
    }

    private func channel(fromTile tile: [String: Any]) -> Channel? {
        guard (tile["contentType"] as? String) == "TILE_CONTENT_TYPE_CHANNEL",
            let id = ((tile["onSelectCommand"] as? [String: Any])?["browseEndpoint"] as? [String: Any])?["browseId"]
                as? String,
            id.hasPrefix("UC")
        else { return nil }
        let metadata = (tile["metadata"] as? [String: Any])?["tileMetadataRenderer"] as? [String: Any]
        let title = (metadata?["title"] as? [String: Any]).flatMap { extractText($0) } ?? ""
        let header = (tile["header"] as? [String: Any])?["tileHeaderRenderer"] as? [String: Any]
        return Channel(
            id: id, title: title, thumbnailURL: lastThumbnailURL(in: header?["thumbnail"]), isSubscribed: true)
    }

    /// YouTube sends channel avatars with protocol-relative URLs.
    private func lastThumbnailURL(in thumbnail: Any?) -> URL? {
        guard let thumbnails = (thumbnail as? [String: Any])?["thumbnails"] as? [[String: Any]],
            let url = thumbnails.last?["url"] as? String
        else { return nil }
        return URL(string: url.hasPrefix("//") ? "https:\(url)" : url)
    }

    /// A WEB client request authenticated with the web session, which www.youtube.com accepts.
    private func postWebSession(endpoint: String, body: [String: Any], sapisid: String) async throws -> [String: Any] {
        guard
            var components = URLComponents(
                url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)
        else { throw APIError.invalidURL(endpoint) }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { throw APIError.invalidURL(endpoint) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(InnerTubeClients.Web.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.Web.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue(InnerTubeAPI.sapisidhash(sapisid: sapisid), forHTTPHeaderField: "Authorization")
        request.setValue("1", forHTTPHeaderField: "X-Origin")
        activeChannel.apply(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        return json
    }
}
