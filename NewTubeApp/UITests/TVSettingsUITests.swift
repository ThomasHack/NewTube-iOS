import XCTest

final class TVSettingsUITests: NewTubeUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        openTab("Settings")
        assertAppears(element("settings.signInButton"))
    }

    func testPlayerSettingsAreReachable() {
        moveDown(toRow: "settings.preferredQualityPicker")
    }

    func testResetIsAtTheEndOfTheList() {
        moveDown(toRow: "settings.sponsorBlockToggle")
        moveDown(toRow: "settings.resetAllButton")
    }

    /// The keypad's own identifiers are replaced by the one its parent sets, so keys go by label.
    func testMismatchedPINsAreRejected() {
        moveDown(toRow: "settings.setPINButton")
        remote.press(.select)
        assertAppears(app.staticTexts["Enter New PIN"])

        assertFocused(app.buttons["1"].firstMatch)
        for _ in 0..<4 { remote.press(.select) }
        assertAppears(app.staticTexts["Confirm New PIN"])

        assertFocused(app.buttons["1"].firstMatch)
        remote.press(.right)
        assertFocused(app.buttons["2"].firstMatch)
        for _ in 0..<4 { remote.press(.select) }
        assertAppears(app.staticTexts["PINs didn't match. Try again."])
        assertAppears(app.staticTexts["Enter New PIN"])
    }
}
