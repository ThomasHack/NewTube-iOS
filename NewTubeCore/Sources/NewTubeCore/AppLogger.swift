import Foundation
import os

// MARK: - AppLogger

/// Thin `os.Logger` wrapper used across the app. Messages are logged locally only, as
/// `.public` so they stay readable in device logs (see docs/how-to/device-logs.md).
public struct AppLogger: Sendable {
    private let logger: Logger

    public init(category: String) {
        logger = Logger(subsystem: appSubsystem, category: category)
    }

    public func notice(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.notice("\(msg, privacy: .public)")
    }

    public func error(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.error("\(msg, privacy: .public)")
    }

    public func debug(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.debug("\(msg, privacy: .public)")
    }
}
