import SwiftUI

// MARK: - SmartTubeLogo

/// The app's icon and name above the Home and Subscriptions feeds.
struct SmartTubeLogo: View {
    var body: some View {
        HStack(spacing: 16) {
            Image("AppIconImage")
                .resizable()
                .scaledToFit()
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(verbatim: "SmartTube")
                .font(.title2.weight(.bold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.logo")
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    SmartTubeLogo()
}
#endif
