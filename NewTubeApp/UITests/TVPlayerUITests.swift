import XCTest

final class TVPlayerUITests: NewTubeUITestCase {
    private var playbackError: XCUIElement { app.alerts["Playback Error"] }
    private var closeButton: XCUIElement { playbackError.buttons["Close"].firstMatch }
    private var tryAgainButton: XCUIElement { playbackError.buttons["Try Again"].firstMatch }

    private func openFirstVideo() {
        assertAppears(card(Self.videoIDs[0]))
        remote.press(.right)
        assertFocused(card(Self.videoIDs[0]))
        remote.press(.select)
        assertAppears(element("player.view"))
    }

    func testVideoOpensPlayerAndReportsUnplayableVideo() {
        openFirstVideo()
        assertAppears(playbackError, timeout: 60)
        XCTAssertTrue(closeButton.exists)
        XCTAssertTrue(tryAgainButton.exists)
    }

    func testClosingErrorReturnsToTheSameVideo() {
        openFirstVideo()
        assertAppears(playbackError, timeout: 60)
        assertFocused(tryAgainButton)
        remote.press(.left)
        assertFocused(closeButton)
        remote.press(.select)
        assertDisappears(element("player.view"))
        assertFocused(card(Self.videoIDs[0]))
    }

    func testMenuLeavesPlayer() {
        openFirstVideo()
        assertAppears(playbackError, timeout: 60)
        remote.press(.menu)
        assertDisappears(element("player.view"))
        assertFocused(card(Self.videoIDs[0]))
    }
}
