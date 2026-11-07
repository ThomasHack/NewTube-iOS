import Foundation

// MARK: - HLS Audio Language Parser

/// Extracts a quoted attribute value from an HLS tag line.
/// E.g. `extractQuotedHLSAttribute("LANGUAGE", from: "#EXT-X-MEDIA:LANGUAGE=\"en\"")` → `"en"`.
public func extractQuotedHLSAttribute(_ name: String, from line: String) -> String? {
    let prefix = "\(name)=\""
    guard let start = line.range(of: prefix) else { return nil }
    let afterQuote = line[start.upperBound...]
    guard let end = afterQuote.firstIndex(of: "\"") else { return nil }
    return String(afterQuote[afterQuote.startIndex..<end])
}
