import SwiftUI

// MARK: - SettingsPageLayout

/// Lays out a settings page like the system Settings app: the app's icon on the left, a narrow list
/// on the right.
struct SettingsPageLayout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            Image("AppIconImage")
                .resizable()
                .scaledToFit()
                .frame(width: 480)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            content
                // Focused rows grow past the list's edges.
                .scrollClipDisabled()
                .frame(width: 900)
        }
    }
}
