import NewTubeCore
import SwiftUI

// MARK: - AccountAvatar

struct AccountAvatar: View {
    let size: CGFloat
    @Environment(AuthService.self) private var auth

    var body: some View {
        AsyncImage(url: auth.accountAvatarURL) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                Circle().fill(Color.secondary.opacity(0.3))
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - AccountRows

/// The account rows shared by Settings and the sidebar's account sheet.
struct AccountRows: View {
    @Environment(AuthService.self) private var auth
    @State private var showSignIn = false

    var body: some View {
        if auth.isSignedIn {
            HStack {
                AccountAvatar(size: 64)
                Text(auth.accountName ?? "Unknown")
            }
            NavigationLink {
                ChannelSwitcherView()
            } label: {
                LabeledContent("Channel", value: auth.activeChannel?.name ?? "")
            }
            .accessibilityIdentifier("settings.channelLink")
            Button("Sign Out", role: .destructive) { auth.signOut() }
        } else {
            Button("Sign in with Google") { showSignIn = true }
                .accessibilityIdentifier("settings.signInButton")
                .fullScreenCover(isPresented: $showSignIn) { SignInView() }
        }
    }
}

// MARK: - SidebarAccountButton

/// The account entry at the very top of the sidebar, styled like the rows below it.
struct SidebarAccountButton: View {
    let action: () -> Void
    @Environment(AuthService.self) private var auth

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                AccountAvatar(size: 44)
                if auth.isSignedIn {
                    Text(auth.activeChannel?.name ?? auth.accountName ?? "Account")
                        .lineLimit(1)
                } else {
                    Text("Sign In")
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(SidebarRowButtonStyle())
        .accessibilityIdentifier("sidebar.accountButton")
    }
}

private struct SidebarRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SidebarRow(configuration: configuration)
    }

    private struct SidebarRow: View {
        let configuration: Configuration
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .font(.body.weight(isFocused ? .medium : .regular))
                .foregroundStyle(isFocused ? Color.black : Color.primary)
                .padding(.vertical, 10)
                .padding(.leading, 12)
                .padding(.trailing, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Capsule().fill(isFocused ? Color.white : Color.clear))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
}

// MARK: - AccountSheet

/// Opened from the sidebar. Settings' PIN also covers this, because it can switch or sign out the
/// account that Settings protects.
struct AccountSheet: View {
    @Environment(SettingsStore.self) private var store
    @State private var isUnlocked = false

    var body: some View {
        NavigationStack {
            if let pinHash = store.settings.settingsPINHash, !isUnlocked {
                SettingsPINLockView(expectedHash: pinHash) { isUnlocked = true }
            } else {
                Form { AccountRows() }
                    .navigationTitle("Account")
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Sidebar button – Signed in") {
    VStack(spacing: 20) {
        SidebarAccountButton {}
        Button("Another row") {}
    }
    .frame(width: 340)
    .previewEnvironment()
}
#Preview("Sidebar button – Signed out") {
    VStack(spacing: 20) {
        SidebarAccountButton {}
        Button("Another row") {}
    }
    .frame(width: 340)
    .previewEnvironment(signedIn: false)
}
#Preview("Account sheet") {
    AccountSheet()
        .previewEnvironment()
}
#Preview("Account sheet – Locked with a PIN") {
    AccountSheet()
        .previewEnvironment { $0.settingsPINHash = SettingsPINHasher.hash("1234") }
}
#endif
