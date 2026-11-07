import XCTest

// MARK: - NewTubeUITestCase

/// Launches the app in English with an injected Home feed, so tests need neither an account nor a
/// specific feed, and drives it with the Siri Remote. The app opens with the sidebar focused on Home.
class NewTubeUITestCase: XCTestCase {
    /// Not real videos: opening one reaches the player, which then reports an error.
    static let videoIDs = ["uitestvid01", "uitestvid02", "uitestvid03"]

    private(set) var app = XCUIApplication()
    let remote = XCUIRemote.shared

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--uitesting-reset-settings",
            "--uitesting-disable-prefetch",
            "--uitesting-inject-recommended-ids=\(Self.videoIDs.joined(separator: ","))",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "Accessibility tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        app.terminate()
    }

    // MARK: - Finding elements

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The button of a video card; its title and channel name carry the same identifier.
    func card(_ videoID: String) -> XCUIElement {
        app.buttons["video.card.\(videoID)"].firstMatch
    }

    /// A list row takes focus as a cell, not through the control with the identifier inside it.
    func row(_ identifier: String) -> XCUIElement {
        app.cells.containing(NSPredicate(format: "identifier == %@", identifier)).firstMatch
    }

    private func sidebarCell(_ title: String) -> XCUIElement {
        app.collectionViews["Sidebar"].cells.containing(NSPredicate(format: "label == %@", title)).firstMatch
    }

    // MARK: - Assertions

    func assertAppears(
        _ element: XCUIElement, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) didn't appear", file: file, line: line)
    }

    func assertDisappears(
        _ element: XCUIElement, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(
            element.wait(for: \.exists, toEqual: false, timeout: timeout), "\(element) didn't go away",
            file: file, line: line)
    }

    func assertFocused(
        _ element: XCUIElement, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(
            element.wait(for: \.hasFocus, toEqual: true, timeout: timeout), "\(element) didn't get focus",
            file: file, line: line)
    }

    // MARK: - Navigation

    /// Selects a tab in the sidebar, which must still have the focus it starts with.
    func openTab(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        assertFocused(sidebarCell("Home"), timeout: 20, file: file, line: line)
        let tabs = ["Search", "Home", "Subscriptions", "Library", "Settings"]
        guard let target = tabs.firstIndex(of: title), let home = tabs.firstIndex(of: "Home") else {
            XCTFail("Unknown tab \(title)", file: file, line: line)
            return
        }
        for _ in 0..<abs(target - home) { remote.press(target > home ? .down : .up) }
        assertFocused(sidebarCell(title), file: file, line: line)
        remote.press(.select)
    }

    /// Moves focus down a list to the row with this identifier, which may not be loaded yet.
    func moveDown(
        toRow identifier: String, maxPresses: Int = 60, file: StaticString = #filePath, line: UInt = #line
    ) {
        let target = row(identifier)
        for _ in 0..<maxPresses {
            if target.exists, target.hasFocus { return }
            remote.press(.down)
        }
        assertFocused(target, timeout: 2, file: file, line: line)
    }
}
