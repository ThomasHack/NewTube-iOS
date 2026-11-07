import Foundation

/// Logging subsystem string derived from the app's bundle identifier at runtime.
public let appSubsystem: String = Bundle.main.bundleIdentifier ?? "com.void.smarttube.app"
