import XCTest

final class JournalUITests: XCTestCase {
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launchEnvironment["FIVECUBED_UI_TESTING"] = "1"
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Gratitudes"].waitForExistence(timeout: 5),
            "Expected UI test launch to bypass onboarding and open Today screen."
        )
        return app
    }

    @MainActor
    private func addGratitude(_ text: String, in app: XCUIApplication) {
        let gratitudeField = app.textFields["Gratitude 1"]
        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 5))
        gratitudeField.tap()
        // Submit with return so the value is persisted as a chip.
        gratitudeField.typeText("\(text)\n")
    }

    @MainActor
    private func openReviewTimeline(in app: XCUIApplication) {
        app.tabBars.buttons["Review"].tap()
        XCTAssertTrue(app.staticTexts["Review"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Timeline"].tap()
    }

    @MainActor
    private func firstTimelineEntryButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Quick")).firstMatch
    }

    @MainActor
    func test_todayScreen_persistsJournalInputAcrossRelaunch() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Gratitudes"].waitForExistence(timeout: 5))
        addGratitude("Thankful for family", in: app)

        app.terminate()
        app.launch()

        openReviewTimeline(in: app)
        XCTAssertTrue(firstTimelineEntryButton(in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_historyScreen_navigatesToPastEntry() {
        let app = launchApp()

        // Add an entry on Today
        addGratitude("History test gratitude", in: app)

        // Switch to Review timeline
        openReviewTimeline(in: app)

        // Wait for at least one row and open the newest entry.
        let firstEntry = firstTimelineEntryButton(in: app)
        XCTAssertTrue(firstEntry.waitForExistence(timeout: 5))
        firstEntry.tap()

        // Verify we're on the entry screen.
        XCTAssertTrue(app.staticTexts["Gratitudes"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_todayScreen_shareButtonIsVisible() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Gratitudes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_pastEntryScreen_shareButtonIsVisibleAfterNavigatingFromHistory() {
        let app = launchApp()

        addGratitude("Share test entry", in: app)
        openReviewTimeline(in: app)

        let firstEntry = firstTimelineEntryButton(in: app)
        XCTAssertTrue(firstEntry.waitForExistence(timeout: 5))
        firstEntry.tap()

        XCTAssertTrue(app.staticTexts["Gratitudes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_todayScreen_addChipTap_commitsActiveDraftWithoutLoss() {
        let app = launchApp()
        let gratitudeField = app.textFields["Gratitude 1"]
        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 5))

        // Add first chip so (+) button becomes visible (showAddChip requires !items.isEmpty).
        addGratitude("First chip", in: app)

        gratitudeField.tap()
        gratitudeField.typeText("Draft gratitude in progress")

        let addButton = app.buttons["Add new"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        XCTAssertTrue(app.buttons["Draft gratitude in progress"].waitForExistence(timeout: 2))
        XCTAssertEqual(gratitudeField.value as? String, "")
    }

    @MainActor
    func test_todayScreen_submitKeepsKeyboardAvailableForNextEntry() {
        let app = launchApp()
        let gratitudeField = app.textFields["Gratitude 1"]
        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 5))

        gratitudeField.tap()
        gratitudeField.typeText("First gratitude entry\n")

        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 2),
            "Keyboard should remain available after submitting an entry."
        )

        gratitudeField.typeText("Second gratitude draft")
        XCTAssertEqual(gratitudeField.value as? String, "Second gratitude draft")
    }
}
