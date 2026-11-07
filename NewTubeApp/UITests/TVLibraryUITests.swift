import XCTest

final class TVLibraryUITests: NewTubeUITestCase {
    private var addFeedButton: XCUIElement { element("rss.emptyAddFeedButton") }

    override func setUpWithError() throws {
        try super.setUpWithError()
        openTab("Library")
        assertAppears(element("library.chipBar"))
    }

    func testShowsTheThreeSections() {
        for title in ["History", "Playlists", "RSS Feeds"] {
            assertAppears(element("library.chipBar").buttons[title])
        }
    }

    func testRSSSectionOffersToAddAFeed() {
        let chipBar = element("library.chipBar")
        assertFocused(chipBar.buttons["History"])
        remote.press(.right)
        assertFocused(chipBar.buttons["Playlists"])
        remote.press(.right)
        assertFocused(chipBar.buttons["RSS Feeds"])
        remote.press(.select)
        assertAppears(addFeedButton)
    }
}
