import AVFoundation
import AVKit
import SmartTubeIOSCore
import SwiftUI
import UIKit

// MARK: - Self-contained auxiliary views used by PlayerView
//
// Extracted from PlayerView.swift to keep that file under 1 000 lines.

// MARK: - StatsForNerdsOverlay

struct StatsForNerdsOverlay: View {
    let snapshot: StatsForNerdsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            row("Video ID", snapshot.videoId)
            row(
                "Resolution",
                snapshot.fps > 0
                    ? "\(snapshot.displayResolution) @ \(snapshot.fps) fps"
                    : snapshot.displayResolution)
            if !snapshot.pendingQualityLabel.isEmpty {
                identifiedRow(
                    "Selected", snapshot.pendingQualityLabel,
                    valueId: "stats.selectedQuality")
            }
            row("Codec", snapshot.codec)
            row("Nominal Bitrate", snapshot.nominalBitrate)
            row("Connection Speed", snapshot.observedBitrate)
            row("Dropped Frames", "\(snapshot.droppedFrames)")
            row("Stalls", "\(snapshot.stalls)")
            Divider().background(.white.opacity(0.2)).padding(.vertical, 2)
            row("TTP (low-q)", snapshot.timeToPlayMs > 0 ? "\(snapshot.timeToPlayMs) ms" : "—")
            row("TTP (hi-q)", snapshot.timeToHighQualityMs > 0 ? "\(snapshot.timeToHighQualityMs) ms" : "—")
            row("Stream Type", snapshot.streamType.isEmpty ? "—" : snapshot.streamType)
            row("Cache", snapshot.cacheStatus.isEmpty ? "—" : snapshot.cacheStatus)
            smallRow("Stream URL", snapshot.streamURL.isEmpty ? "—" : snapshot.streamURL)
            Divider().background(.white.opacity(0.2)).padding(.vertical, 2)
            Text("Two-finger tap to dismiss")
                .foregroundStyle(.white.opacity(0.4))
                .font(.system(.caption2, design: .monospaced))
                .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .foregroundStyle(.white.opacity(0.55))
                .frame(minWidth: 130, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(.white)
        }
        .font(.system(.caption, design: .monospaced))
    }

    private func smallRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .foregroundStyle(.white.opacity(0.55))
                .frame(minWidth: 130, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(.white.opacity(0.8))
        }
        .font(.system(.caption2, design: .monospaced))
    }

    /// Like `row` but applies an accessibility identifier to the value text,
    /// allowing XCUITest to locate it directly by identifier.
    private func identifiedRow(_ key: String, _ value: String, valueId: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .foregroundStyle(.white.opacity(0.55))
                .frame(minWidth: 130, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(.white)
                .accessibilityIdentifier(valueId)
        }
        .font(.system(.caption, design: .monospaced))
    }
}

// MARK: - RelatedVideosView

// MARK: - CommentRowView

struct CommentRowView: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: comment.authorAvatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.secondary.opacity(0.3))
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.author)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(comment.publishedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(timestampLinkedAttributedString(comment.text))
                    .font(.callout)
                if !comment.likeCount.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup")
                            .font(.caption2)
                        Text(comment.likeCount)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func timestampLinkedAttributedString(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        for (range, seconds) in findTimestamps(in: text) {
            guard let attrRange = Range(range, in: attributed) else { continue }
            attributed[attrRange].link = URL(string: "smarttube://seek/\(Int(seconds))")
        }
        return attributed
    }
}

// MARK: - AppSettings.VideoGravityMode → AVLayerVideoGravity mapping

extension AppSettings.VideoGravityMode {
    var avGravity: AVLayerVideoGravity {
        self == .fill ? .resizeAspectFill : .resizeAspect
    }
}

// MARK: - AirPlayRoutePickerView
