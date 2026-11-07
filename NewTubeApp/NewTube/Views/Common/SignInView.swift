import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: - SignInView
//
// Google Device Authorization Grant sign-in UI (mirrors Android's equivalent).
// No browser redirect — the user enters a short code at youtube.com/activate.

struct SignInView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showError = false

    init() {}

    var body: some View {
        tvBody
    }

    /// Full-screen layout: the content is centered, with Cancel below it in every state.
    private var tvBody: some View {
        VStack(spacing: 48) {
            Spacer(minLength: 0)
            if let info = auth.pendingActivation {
                tvActivationView(info: info)
            } else {
                tvLoadingView
            }
            Spacer(minLength: 0)
            Button("Cancel") {
                auth.cancelSignIn()
                dismiss()
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .alert("Sign-In Failed", isPresented: $showError, presenting: auth.error) { _ in
            Button("Try Again") { Task { await auth.beginSignIn() } }
            Button("Cancel", role: .cancel) { auth.error = nil }
        } message: { err in
            Text(err.localizedDescription)
        }
        .onChange(of: auth.error == nil ? 0 : 1) { _, hasError in
            if hasError == 1 { showError = true }
        }
        .task { await auth.beginSignIn() }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
    }

    private var tvLoadingView: some View {
        VStack(spacing: 24) {
            ProgressView().controlSize(.large)
            Text("Connecting to Google…")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func tvActivationView(info: AuthService.ActivationInfo) -> some View {
        HStack(alignment: .center, spacing: 80) {
            // Left column: instructions + code + countdown
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: AppSymbol.tvMediabox)
                        .font(.system(size: 56))
                        .foregroundStyle(.red)

                    Text("Sign in to NewTube")
                        .font(.largeTitle).fontWeight(.bold)

                    Text("On any device, open the link below and enter the code.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Go to:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(info.verificationURL.absoluteString)
                        .font(.title3).fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }

                Text(info.userCode)
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .tracking(10)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 32)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                CountdownView(expiresAt: info.expiresAt) {
                    Task { await auth.beginSignIn() }
                }

                HStack(spacing: 12) {
                    ProgressView()
                    Text("Waiting for authorisation…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            // Right column: QR code
            VStack(spacing: 16) {
                QRCodeView(content: activationQRURL(info: info))
                    .frame(width: 280, height: 280)
                    .padding(16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Text("Scan to open activation page")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Loading screen

    // MARK: - Activation code screen

    /// Builds the URL that Google accepts to auto-fill the user code:
    /// https://www.google.com/device?user_code=XXXX-XXXX
    private func activationQRURL(info: AuthService.ActivationInfo) -> String {
        guard var components = URLComponents(url: info.verificationURL, resolvingAgainstBaseURL: false) else {
            return info.verificationURL.absoluteString
        }
        let existing = components.queryItems ?? []
        components.queryItems = existing + [URLQueryItem(name: "user_code", value: info.userCode)]
        return components.url?.absoluteString ?? info.verificationURL.absoluteString
    }

}

// MARK: - QRCodeView

struct QRCodeView: View {
    let content: String

    var body: some View {
        if let img = makeQRImage() {
            GeometryReader { geo in
                img
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        } else {
            Image(systemName: AppSymbol.qrcode)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    private func makeQRImage() -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.correctionLevel = "M"
        guard let data = content.data(using: .utf8) else { return nil }
        filter.message = data

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up so the QR is crisp at any display size
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = ciImage.transformed(by: scale)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        let uiImage = UIImage(cgImage: cgImage)
        return Image(uiImage: uiImage)
    }
}

// MARK: - CountdownView

private struct CountdownView: View {
    let expiresAt: Date
    let onExpired: () -> Void

    @State private var remaining: TimeInterval = 0

    var body: some View {
        Group {
            if remaining > 0 {
                Label(timeString, systemImage: AppSymbol.clock)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Code expired")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .task {
            remaining = max(0, expiresAt.timeIntervalSinceNow)
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remaining = max(0, expiresAt.timeIntervalSinceNow)
            }
            // Give an in-flight poll (e.g. fired by handleForeground on app return)
            // a few seconds to complete before creating a new device code.
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            onExpired()
        }
    }

    private var timeString: String {
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        let fmt = String(localized: "Code expires in %d:%02d")
        return String(format: fmt, mins, secs)
    }
}

// MARK: - Previews

#if DEBUG
/// Sign-in already in progress, so the view doesn't start a real one when it appears.
private struct SignInPreview: View {
    let activation: AuthService.ActivationInfo?
    @Environment(AuthService.self) private var auth

    var body: some View {
        SignInView()
            .onAppear {
                auth.isSigningIn = true
                auth.pendingActivation = activation
            }
    }
}

#Preview("Connecting") {
    SignInPreview(activation: nil)
        .previewEnvironment(signedIn: false)
}
#Preview("Enter the code") {
    SignInPreview(
        activation: AuthService.ActivationInfo(
            userCode: "ABCD-1234",
            verificationURL: URL(string: "https://yt.be/activate")!,
            expiresAt: Date().addingTimeInterval(1_800)
        )
    )
    .previewEnvironment(signedIn: false)
}
#endif
