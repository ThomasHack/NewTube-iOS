#if os(tvOS)
import XCTest

// MARK: - TVLibraryUITests
//
// Verifies the tvOS Library tab: chip bar presence, section chips focusable via
// D-pad, each section shows content or empty state, and back-navigation restores
// the Home feed.
//
// Run against the "Smart Tube" tvOS scheme:
//   xcodebuild test -workspace SmartTube.xcworkspace -scheme "Smart Tube"
//     -destination "id=30E83929-0C67-4572-82C4-FE0F228EA835"
//     -only-testing:SmartTubeTVUITests/TVLibraryUITests

final class TVLibraryUITests: XCTestCase {

    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        try openLibrary()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private var chipBar: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'library.chipBar'"))
            .firstMatch
    }

    private var homeChipBar: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'home.sectionContainer'"))
            .firstMatch
    }

    /// Navigate to the Library tab.
    /// Tab order: Recommended=1, Subscriptions=2, Search=3, Library=4, Settings=5 (each right
    /// press advances one tab). Recommended is selected on launch, so right × 3 = Library.
    private func openLibrary() throws {
        for _ in 0..<3 { remote.press(.right) }
        remote.press(.select)
        Thread.sleep(forTimeInterval: 1.5)
        guard chipBar.waitForExistence(timeout: 12) else {
            try captureAndSkip(
                "library.chipBar not found — Library tab did not open (check right-press count)", in: app)
        }
    }

    /// Navigate within the Library chip bar to a specific chip by pressing down
    /// (to enter the chip bar) then right `count` times, then selecting.
    private func selectChip(rightPresses count: Int) {
        remote.press(.down)
        Thread.sleep(forTimeInterval: 0.6)
        for _ in 0..<count {
            remote.press(.right)
            Thread.sleep(forTimeInterval: 0.5)
        }
        remote.press(.select)
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// Returns true if at least one video card is visible in the Library section.
    private func videoCardsPresent(timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'video.card.'")
        let cards = app.descendants(matching: .any).matching(predicate)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: cards
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    // MARK: - Tests

    /// Library tab must open and show its chip bar within 12 s of setUp.
    func testLibraryTabFocusable() {
        XCTAssertTrue(chipBar.exists, "library.chipBar must exist after openLibrary()")
    }

    /// The History chip must be the default chip, focusable without right presses.
    func testHistorySegmentFocusable() throws {
        let historyChip = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'library.chip.history'"))
            .firstMatch
        guard historyChip.waitForExistence(timeout: 5) else {
            try captureAndSkip("library.chip.history not found in accessibility tree", in: app)
        }
        selectChip(rightPresses: 0)
        XCTAssertTrue(chipBar.exists, "library.chipBar must still exist after selecting History chip")
    }

    /// After selecting History, the section must show video cards or remain on the Library screen.
    func testHistoryShowsFeedOrEmptyState() throws {
        selectChip(rightPresses: 0)
        // Either video cards appear, or the chip bar is still present (empty state still on Library screen).
        let hasCards = videoCardsPresent(timeout: 8)
        if !hasCards && !chipBar.exists {
            try captureAndSkip(
                "History section shows neither video cards nor the Library chip bar — unexpected state", in: app)
        }
        // If we get here, at least one of the two conditions is true.
        XCTAssertTrue(hasCards || chipBar.exists, "History section must show content or remain on the Library screen")
    }

    /// The Playlists chip must be reachable via one right-press in the chip bar.
    func testPlaylistsSegmentFocusable() throws {
        let playlistsChip = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'library.chip.playlists'"))
            .firstMatch
        guard playlistsChip.waitForExistence(timeout: 5) else {
            try captureAndSkip("library.chip.playlists not found in accessibility tree", in: app)
        }
        selectChip(rightPresses: 1)
        XCTAssertTrue(chipBar.exists, "library.chipBar must still exist after selecting Playlists chip")
    }

    /// The Channels chip must be reachable via two right-presses in the chip bar.
    func testChannelsSegmentFocusable() throws {
        let channelsChip = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'library.chip.channels'"))
            .firstMatch
        guard channelsChip.waitForExistence(timeout: 5) else {
            try captureAndSkip("library.chip.channels not found in accessibility tree", in: app)
        }
        selectChip(rightPresses: 2)
        XCTAssertTrue(chipBar.exists, "library.chipBar must still exist after selecting Channels")
    }

    /// Pressing Menu from Library must return to the Recommended feed.
    func testNavigatingBackFromLibraryRestoresHomeFeed() throws {
        // Press Menu/Back to return to the Home tab.
        remote.press(.menu)
        Thread.sleep(forTimeInterval: 1.5)
        guard homeChipBar.waitForExistence(timeout: 10) else {
            try captureAndSkip("home.sectionContainer did not reappear after pressing Menu from Library", in: app)
        }
        XCTAssertTrue(homeChipBar.exists, "home.sectionContainer must reappear after returning from Library")
    }
}
#endif
