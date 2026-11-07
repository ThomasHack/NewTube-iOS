import XCTest

// MARK: - UITestHelpers
//
// Shared utilities reused across all UI test suites.
// Not a subclass of XCTestCase — import by value from any test file.
// Note: The enum body uses iOS-only XCUIElement APIs (tap, swipe, coordinate),
// so the entire declaration is excluded from the tvOS build.

// MARK: - XCTestCase diagnostic helpers

extension XCTestCase {

    /// Captures a screenshot and accessibility-tree dump, attaches both with
    /// `keepAlways` lifetime, then throws `XCTSkip` with the given reason.
    ///
    /// The `throws -> Never` signature lets Swift treat every call site as a
    /// guaranteed scope-exit, so no trailing `return` is needed in guard-else blocks:
    ///
    ///     guard card.exists else {
    ///         try captureAndSkip("Feed empty — network issue", in: app)
    ///     }
    func captureAndSkip(
        _ reason: String,
        in app: XCUIApplication,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Never {
        if app.state != .notRunning {
            let shot = app.screenshot()
            let shotAttachment = XCTAttachment(screenshot: shot)
            shotAttachment.name = "Skip state: \(reason.prefix(60))"
            shotAttachment.lifetime = .keepAlways
            add(shotAttachment)

            let treeAttachment = XCTAttachment(string: app.debugDescription)
            treeAttachment.name = "Accessibility tree at skip"
            treeAttachment.lifetime = .keepAlways
            add(treeAttachment)
        }

        throw XCTSkip(reason, file: file, line: line)
    }

    /// Captures a screenshot and accessibility-tree dump and attaches both with
    /// `keepAlways` lifetime. Call this immediately before an assertion that may
    /// fail to provide visual context in the result bundle.
    func captureState(_ label: String = "failure", in app: XCUIApplication) {
        guard app.state != .notRunning else { return }
        let shot = app.screenshot()
        let shotAttachment = XCTAttachment(screenshot: shot)
        shotAttachment.name = "Screenshot: \(label)"
        shotAttachment.lifetime = .keepAlways
        add(shotAttachment)

        let treeAttachment = XCTAttachment(string: app.debugDescription)
        treeAttachment.name = "Accessibility tree: \(label)"
        treeAttachment.lifetime = .keepAlways
        add(treeAttachment)
    }

    /// Polls for an element's existence while guarding against app crashes.
    /// Unlike `waitForExistence(timeout:)`, this checks `app.state` before each
    /// accessibility query so an unexpected process termination returns `false`
    /// instead of triggering XCTest's crash-detection mechanism, which terminates
    /// the entire test case even with `continueAfterFailure = true`.
    func waitForExistenceGuarded(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let pollInterval: TimeInterval = 0.25
        repeat {
            guard app.state == .runningForeground || app.state == .runningBackground else {
                return false
            }
            if element.exists { return true }
            Thread.sleep(forTimeInterval: pollInterval)
        } while Date() < deadline
        guard app.state == .runningForeground || app.state == .runningBackground else {
            return false
        }
        return element.exists
    }
}
