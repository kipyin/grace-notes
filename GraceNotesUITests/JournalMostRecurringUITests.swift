import XCTest

final class JournalMostRecurringUITests: XCTestCase {
    @MainActor
    private func launchAppWithWideReviewSeed() -> XCUIApplication {
        let app = XCUIApplication()
        app.configureGraceNotesUITestLaunch(resetUITestStore: true, wideReviewRhythm: true)
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Gratitudes"].waitForExistence(timeout: 5),
            "Expected UI test launch to bypass onboarding and open Today screen."
        )
        return app
    }

    private func mostRecurringRows(in app: XCUIApplication) -> XCUIElementQuery {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "MostRecurringThemeRow.")
        return app.buttons.matching(predicate)
    }

    @MainActor
    func test_reviewScreen_mostRecurringList_scrollsAndOpensThemeDrilldown() {
        let app = launchAppWithWideReviewSeed()
        app.tabBars.buttons["Past"].tap()

        XCTAssertTrue(
            app.staticTexts["Most recurring"].waitForExistence(timeout: 25),
            "Expected Most recurring panel in Past tab."
        )
        let list = app.scrollViews["MostRecurringThemesScroll"]
        XCTAssertTrue(list.waitForExistence(timeout: 10), "Expected identified Most Recurring scroll view.")

        let rows = mostRecurringRows(in: app)
        XCTAssertGreaterThan(rows.count, 0, "Expected at least one Most Recurring row.")
        let firstRow = rows.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 8), "Expected first Most Recurring row.")
        XCTAssertTrue(firstRow.isHittable, "Expected first Most Recurring row to be tappable.")
        XCTAssertGreaterThan(rows.count, 10, "Expected enough themes to require scrolling.")

        firstRow.tap()
        XCTAssertTrue(
            app.navigationBars["Theme details"].waitForExistence(timeout: 8),
            "Expected theme drilldown sheet after tapping a row."
        )
        XCTAssertTrue(
            app.staticTexts["Entries and categories"].waitForExistence(timeout: 5),
            "Expected drilldown evidence section."
        )
        app.buttons["Done"].tap()

        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.swipeUp()
        XCTAssertTrue(list.exists, "Most Recurring list should remain available after scrolling.")
    }
}
