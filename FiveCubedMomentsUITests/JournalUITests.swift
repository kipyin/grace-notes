import XCTest

final class JournalUITests: XCTestCase {
    func test_todayScreen_persistsJournalInputAcrossRelaunch() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Gratitudes"].waitForExistence(timeout: 5))

        let gratitudeField = app.textFields["Gratitude 1"]
        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 5))
        gratitudeField.tap()
        gratitudeField.typeText("Thankful for family")

        app.terminate()
        app.launch()

        XCTAssertTrue(app.textFields["Gratitude 1"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Gratitude 1"].value as? String, "Thankful for family")
    }

    func test_historyScreen_navigatesToPastEntry() {
        let app = XCUIApplication()
        app.launch()

        // Add an entry on Today
        let gratitudeField = app.textFields["Gratitude 1"]
        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 5))
        gratitudeField.tap()
        gratitudeField.typeText("History test gratitude")

        // Switch to Review tab
        app.tabBars.buttons["Review"].tap()
        XCTAssertTrue(app.staticTexts["Review"].waitForExistence(timeout: 5))

        // Wait for at least one row (today's auto-created entry or the updated one)
        let firstRow = app.cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()

        // Verify we're on the entry screen (shows Gratitudes section)
        XCTAssertTrue(app.staticTexts["Gratitudes"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Gratitude 1"].value as? String, "History test gratitude")
    }

    func test_todayScreen_shareButtonIsVisible() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Gratitudes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 5))
    }

    func test_pastEntryScreen_shareButtonIsVisibleAfterNavigatingFromHistory() {
        let app = XCUIApplication()
        app.launch()

        let gratitudeField = app.textFields["Gratitude 1"]
        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 5))
        gratitudeField.tap()
        gratitudeField.typeText("Share test entry")

        app.tabBars.buttons["Review"].tap()
        XCTAssertTrue(app.staticTexts["Review"].waitForExistence(timeout: 5))

        let firstRow = app.cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()

        XCTAssertTrue(app.staticTexts["Gratitudes"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Gratitude 1"].value as? String, "Share test entry")
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 5))
    }
}
