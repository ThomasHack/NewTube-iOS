import SmartTubeIOSCore
import SwiftUI

// MARK: - ShortsPresentation
//
// Shared Identifiable wrapper used by HomeView and ChannelView to present
// ShortsPlayerView via .fullScreenCover(item:).

struct ShortsPresentation: Identifiable {
    let id = UUID()
    let videos: [Video]
    let startIndex: Int
}

// MARK: - ChannelDestination
//
// Identifiable wrapper used to drive navigationDestination(item:) for channel navigation
// triggered by the .openChannel NotificationCenter event.

struct ChannelDestination: Identifiable, Hashable {
    let channelId: String
    var id: String { channelId }
}

// MARK: - Shared layout constants

let videoGridRowSpacing: CGFloat = 40

// MARK: - Accent color

extension AppSettings.AccentColorChoice {
    /// `nil` falls back to the `AccentColor` asset.
    public var color: Color? {
        switch self {
        case .system: return nil
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        }
    }

    var displayName: String {
        switch self {
        case .system: return String(localized: "Default", bundle: .module)
        case .red: return String(localized: "Red", bundle: .module)
        case .orange: return String(localized: "Orange", bundle: .module)
        case .yellow: return String(localized: "Yellow", bundle: .module)
        case .green: return String(localized: "Green", bundle: .module)
        case .mint: return String(localized: "Mint", bundle: .module)
        case .teal: return String(localized: "Teal", bundle: .module)
        case .blue: return String(localized: "Blue", bundle: .module)
        case .indigo: return String(localized: "Indigo", bundle: .module)
        case .purple: return String(localized: "Purple", bundle: .module)
        case .pink: return String(localized: "Pink", bundle: .module)
        }
    }

    /// Pre-tinted, because Picker menus re-tint template images with the current accent.
    var swatch: Image {
        let tint = color.map { UIColor($0) } ?? UIColor(named: "AccentColor") ?? .systemBlue
        let base = UIImage(systemName: AppSymbol.colorSwatch) ?? UIImage()
        return Image(uiImage: base.withTintColor(tint, renderingMode: .alwaysOriginal))
    }
}

// MARK: - AlertItem

/// Shared alert payload for card actions.
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - AppSymbol
//
// Single source of truth for SF Symbol names used across the app.
// Use these constants instead of raw strings in Image(systemName:) and Label(..., systemImage:).

enum AppSymbol {
    // MARK: - Navigation tabs
    static let home = "house.fill"
    static let subscriptions = "rectangle.stack.badge.play.fill"
    static let search = "magnifyingglass"
    static let filter = "line.3.horizontal.decrease.circle"
    static let filterActive = "line.3.horizontal.decrease.circle.fill"
    static let library = "square.stack.fill"
    static let channel = "person.crop.circle.fill"
    static let settings = "gearshape.fill"

    // MARK: - Navigation / chevrons
    static let chevronLeft = "chevron.left"

    // MARK: - Playback controls
    static let previousTrack = "backward.end.fill"
    static let nextTrack = "forward.end.fill"
    static let previousChapter = "backward.end.alt.fill"
    static let nextChapter = "forward.end.alt.fill"
    static let thumbsUp = "hand.thumbsup"
    static let thumbsDown = "hand.thumbsdown"

    // MARK: - Actions
    static let checkmark = "checkmark"
    static let xmark = "xmark"
    static let watchLater = "clock.badge"
    static let audioOnly = "waveform.circle"

    // MARK: - Status / info
    static let warning = "exclamationmark.triangle.fill"
    static let clock = "clock"
    static let questionCircle = "questionmark.circle"
    static let qrcode = "qrcode"
    static let colorSwatch = "circle.fill"

    // MARK: - People / account
    static let personCircle = "person.crop.circle"
    static let personRectangle = "person.crop.rectangle"
    static let personCircleQuestion = "person.crop.circle.badge.questionmark"
    static let personCircleWarning = "person.crop.circle.badge.exclamationmark"

    // MARK: - Content
    static let stackLayers = "square.stack"
    static let tvMediabox = "tv.and.mediabox"
    static let tvPlay = "play.tv"
}
