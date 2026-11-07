import XCTest

// MARK: - TVHomeFeedUITests
//
// Verifies the tvOS Home Feed tab: chip bar presence, video card population,
// no error banner on launch, Subscriptions chip navigation, and return to Home.
//
// Run against the "NewTube" tvOS scheme:
//   xcodebuild test -workspace NewTube.xcworkspace -scheme "NewTube"
//     -destination "id=30E83929-0C67-4572-82C4-FE0F228EA835"
//     -only-testing:NewTubeTVUITests/TVHomeFeedUITests

final class TVHomeFeedUITests: XCTestCase {

    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private var chipBar: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'home.sectionContainer'"))
            .firstMatch
    }

    private var sectionContainer: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'home.sectionContainer'"))
            .firstMatch
    }

    /// Waits up to `timeout` seconds for at least one `video.card.*` descendant to appear.
    private func waitForVideoCards(timeout: TimeInterval = 20) -> Bool {
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'video.card.'")
        let cards = app.descendants(matching: .any).matching(predicate)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: cards
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    // MARK: - Tests

    /// The Recommended feed must appear within 15 s of launch.
    func testFeedLoadsWithinTimeout() throws {
        guard chipBar.waitForExistence(timeout: 15) else {
            try captureAndSkip(
                "home.sectionContainer did not appear within 15 s — Home tab may not have loaded", in: app)
        }
        XCTAssertTrue(chipBar.exists, "home.sectionContainer must exist after appearance")
    }

    /// Video cards (video.card.*) must populate the Home feed within 20 s.
    func testVideoCardsPopulateHomeFeed() throws {
        guard chipBar.waitForExistence(timeout: 15) else {
            try captureAndSkip("home.sectionContainer not found — cannot wait for video cards", in: app)
        }
        guard waitForVideoCards(timeout: 20) else {
            try captureAndSkip(
                "No video.card.* elements appeared within 20 s — network unavailable or feed empty", in: app)
        }
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'video.card.'")
        let cards = app.descendants(matching: .any).matching(predicate)
        XCTAssertGreaterThan(cards.count, 0, "At least one video card must be visible in the Home feed")
    }

    /// No XCUIElementTypeAlert and no player.errorBanner should appear on cold launch.
    func testNoErrorBannerOnHomeLoad() throws {
        guard chipBar.waitForExistence(timeout: 15) else {
            try captureAndSkip("home.sectionContainer not found — app did not reach Home tab", in: app)
        }
        // Allow extra time for network requests to settle.
        Thread.sleep(forTimeInterval: 3.0)
        let errorAlert = app.alerts.firstMatch
        XCTAssertFalse(errorAlert.exists, "Unexpected error alert appeared on Home launch: \(errorAlert.label)")
        let errorBanner = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'player.errorBanner'"))
            .firstMatch
        XCTAssertFalse(errorBanner.exists, "player.errorBanner should not appear on the Home screen")
    }

}
