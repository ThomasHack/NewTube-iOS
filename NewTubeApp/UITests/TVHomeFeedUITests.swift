import XCTest

final class TVHomeFeedUITests: NewTubeUITestCase {
    func testShowsLogoAndVideos() {
        assertAppears(element("home.logo"))
        for id in Self.videoIDs { assertAppears(card(id)) }
    }

    func testFocusMovesFromSidebarThroughVideos() {
        assertAppears(card(Self.videoIDs[0]))
        remote.press(.right)
        assertFocused(card(Self.videoIDs[0]))
        remote.press(.right)
        assertFocused(card(Self.videoIDs[1]))
    }

    func testMenuReturnsFromFeedToSidebar() {
        assertAppears(card(Self.videoIDs[0]))
        remote.press(.right)
        assertFocused(card(Self.videoIDs[0]))
        remote.press(.menu)
        assertFocused(
            app.collectionViews["Sidebar"].cells.containing(NSPredicate(format: "label == 'Home'")).firstMatch)
        XCTAssertEqual(app.state, .runningForeground)
    }
}
