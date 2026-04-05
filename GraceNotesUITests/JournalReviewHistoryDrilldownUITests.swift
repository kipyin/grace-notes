import XCTest

/// Issue #198: Days you wrote card chrome opens shared history calendar drilldown.
final class JournalReviewHistoryDrilldownUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    @MainActor
    func test_past_daysYouWrote_titleOpensJournalingDaysDrilldown() {
        let app = XCUIApplication()
        app.configureGraceNotesUITestLaunch(resetUITestStore: true, wideReviewRhythm: true)
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Gratitudes"].waitForExistence(timeout: 5),
            "Expected UI test launch to bypass onboarding."
        )
        app.tabBars.buttons["Past"].tap()

        XCTAssertTrue(
            app.graceNotesReflectionRhythmTitleReady.waitForExistence(timeout: 25),
            "Expected Past tab rhythm panel with English seed."
        )
        XCTAssertTrue(
            app.scrollViews["ReviewRhythmHorizontalScroll"].waitForExistence(timeout: 25),
            "Expected rhythm data loaded (not loading skeleton) before chrome tap."
        )

        app.graceNotesReflectionRhythmTitleReady.tap()

        let done = app.buttons["ReviewHistoryJournalingDaysDrilldownDone"].firstMatch
        XCTAssertTrue(
            done.waitForExistence(timeout: 8),
            "Expected history drilldown sheet with Done toolbar button."
        )
        done.tap()

        XCTAssertTrue(
            app.graceNotesReflectionRhythmTitleReady.waitForExistence(timeout: 5),
            "Expected Past list after dismissing drilldown."
        )
    }
}
