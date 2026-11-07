import Foundation

// MARK: - HLS Master Manifest Parser
//
// Parses an HLS master playlist (M3U8) and returns a map of stream height → variant URL.
// Extracted from PlaybackQualityManager.fetchHLSVariantURLs (task #133, SRP-1).
//
// The first-seen variant at each resolution is kept as-is: tvOS hardware decoders
// handle HEVC efficiently with lower power consumption.

/// Parses `manifestText` as an HLS master playlist and returns a map of
/// stream height (e.g. 1080) → absolute variant playlist URL.
///
/// - Parameters:
///   - manifestText: The raw text content of the `.m3u8` master playlist.
///   - baseURL: Base URL used to resolve relative URIs in the manifest.
/// - Returns: Dictionary mapping height in pixels to the best variant URL for that height.
public func parseHLSMasterManifest(_ manifestText: String, baseURL: URL) -> [Int: URL] {
    var variants: [Int: URL] = [:]
    var variantIsH264: [Int: Bool] = [:]
    let lines = manifestText.components(separatedBy: .newlines)
    var pendingHeight: Int? = nil
    var pendingIsH264: Bool = false

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("#EXT-X-STREAM-INF") {
            pendingHeight = nil
            pendingIsH264 = false

            if let range = trimmed.range(of: #"RESOLUTION=\d+x(\d+)"#, options: .regularExpression) {
                let match = String(trimmed[range])
                if let xIdx = match.firstIndex(of: "x"),
                    let height = Int(match[match.index(after: xIdx)...])
                {
                    pendingHeight = height
                }
            }
            if let codecsRange = trimmed.range(of: #"CODECS="[^"]*""#, options: .regularExpression) {
                pendingIsH264 = trimmed[codecsRange].contains("avc1")
            }

        } else if !trimmed.hasPrefix("#"), !trimmed.isEmpty, let height = pendingHeight {
            let variantURL: URL?
            if trimmed.hasPrefix("http") {
                variantURL = URL(string: trimmed)
            } else {
                variantURL = URL(string: trimmed, relativeTo: baseURL).map { $0.absoluteURL }
            }

            if let resolvedURL = variantURL {
                if variants[height] == nil {
                    variants[height] = resolvedURL
                    variantIsH264[height] = pendingIsH264
                } else {
                }
            }
            pendingHeight = nil
            pendingIsH264 = false

        } else if trimmed.hasPrefix("#") {
            // Any tag other than #EXT-X-STREAM-INF resets pending state so
            // we don't accidentally attach a URI from a different entry.
            if pendingHeight != nil, !trimmed.hasPrefix("#EXT-X-STREAM-INF") {
                pendingHeight = nil
                pendingIsH264 = false
            }
        }
    }

    return variants
}

/// Produces an AVFoundation-safe HLS master while preserving separate audio renditions.
/// YouTube's VisionOS master mixes H.264 and VP9 variants; tvOS may select an unsupported
/// VP9 entry even when resolution hints are set. Filtering the master (rather than loading
/// a video-only variant) keeps `EXT-X-MEDIA` audio groups and removes incompatible video.
public func filterHLSMasterManifest(
    _ manifest: String,
    maximumHeight: Int,
    requiredVideoCodec: String
) -> String {
    let lines = manifest.components(separatedBy: .newlines)
    var output: [String] = []
    var shouldDropNextURI = false

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if shouldDropNextURI {
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#EXT-X-STREAM-INF:") {
                shouldDropNextURI = false
            } else if trimmed.hasPrefix("#") {
                output.append(line)
                continue
            } else {
                shouldDropNextURI = false
                continue
            }
        }

        if trimmed.hasPrefix("#EXT-X-STREAM-INF:") {
            let height: Int? =
                trimmed
                .range(of: #"RESOLUTION=\d+x(\d+)"#, options: .regularExpression)
                .map { String(trimmed[$0]) }
                .flatMap { $0.components(separatedBy: "x").last }
                .flatMap(Int.init)
            let codecMatches = trimmed.localizedCaseInsensitiveContains(requiredVideoCodec)
            guard codecMatches, let height, height <= maximumHeight else {
                shouldDropNextURI = true
                continue
            }
            output.append(line)
            continue
        }

        if trimmed.hasPrefix("#EXT-X-MEDIA:"),
            trimmed.localizedCaseInsensitiveContains("TYPE=AUDIO"),
            hlsMediaLineIsOriginalAudio(trimmed)
        {
            if trimmed.contains("DEFAULT=NO") {
                output.append(line.replacingOccurrences(of: "DEFAULT=NO", with: "DEFAULT=YES"))
            } else if !trimmed.contains("DEFAULT=") {
                output.append(line + ",DEFAULT=YES")
            } else {
                output.append(line)
            }
            continue
        }

        output.append(line)
    }

    return output.joined(separator: "\n")
}

private func hlsMediaLineIsOriginalAudio(_ line: String) -> Bool {
    if line.localizedCaseInsensitiveContains("original")
        && !line.localizedCaseInsensitiveContains("dubbed")
    {
        return true
    }
    guard let encoded = extractQuotedHLSAttribute("YT-EXT-XTAGS", from: line) else {
        return false
    }
    let padded = encoded + String(repeating: "=", count: (4 - encoded.count % 4) % 4)
    guard let data = Data(base64Encoded: padded) else { return false }
    return data.range(of: Data("original".utf8)) != nil
        && data.range(of: Data("dubbed".utf8)) == nil
}
