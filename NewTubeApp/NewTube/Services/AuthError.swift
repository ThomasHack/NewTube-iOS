import Foundation

// MARK: - AuthError

enum AuthError: LocalizedError {
    case cancelled
    case missingCode
    case tokenExchangeFailed
    case notSignedIn
    case configurationError
    case deviceCodeRequestFailed
    case authorizationPending
    case slowDown
    case deviceCodeExpired

    var errorDescription: String? {
        switch self {
        case .cancelled: return String(localized: "Sign-in was cancelled")
        case .missingCode: return String(localized: "OAuth code was missing from callback")
        case .tokenExchangeFailed: return String(localized: "Failed to exchange code for tokens")
        case .notSignedIn: return String(localized: "You are not signed in")
        case .configurationError: return String(localized: "OAuth credentials could not be obtained")
        case .deviceCodeRequestFailed:
            return String(localized: "Could not start sign-in. Check your internet connection.")
        case .authorizationPending: return String(localized: "Waiting for authorisation…")
        case .slowDown: return String(localized: "Too many requests — slowing down")
        case .deviceCodeExpired: return String(localized: "The sign-in code expired. Please try again.")
        }
    }
}
