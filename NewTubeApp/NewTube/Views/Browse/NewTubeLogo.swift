import SwiftUI

// MARK: - NewTubeLogo

/// The app's logo above the Home and Subscriptions feeds.
struct NewTubeLogo: View {
    var body: some View {
        Image("NewTubeLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 56)
            .accessibilityLabel(Text(verbatim: "NewTube"))  // verbatim: the app's name isn't translated
            .accessibilityIdentifier("home.logo")
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    NewTubeLogo()
}
#endif
