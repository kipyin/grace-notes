import XCTest

/// UI tests use `-ui-testing`. To reset journal tutorial flags (issue #60), add
/// `-reset-journal-tutorial` to `launchArguments` before `launch()`.
final class JournalUITests: XCTestCase {
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
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
        gratitudeField.typeText(text)

        // Prefer tapping an explicit return key because newline typing can be flaky
        // under some simulator keyboard configurations.
        let returnKey = app.keyboards.buttons["Return"]
        if returnKey.exists {
            returnKey.tap()
        } else {
            gratitudeField.typeText("\n")
        }
    }

    @MainActor
    private func openReviewTimeline(in app: XCUIApplication) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let maxCandidates = min(tabBar.buttons.count, 4)
        for index in 0..<maxCandidates {
            let candidate = tabBar.buttons.element(boundBy: index)
            guard candidate.exists else { continue }
            candidate.tap()
            if app.otherElements["ReviewModePicker"].waitForExistence(timeout: 2) ||
                app.staticTexts["Review"].waitForExistence(timeout: 2) {
                return
            }
        }

        // Final fallback for English localization.
        let namedReviewTab = tabBar.buttons["Review"]
        if namedReviewTab.exists {
            namedReviewTab.tap()
        }
    }

    @MainActor
    private func firstTimelineEntryButton(in app: XCUIApplication) -> XCUIElement {
        let identifiedElement = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "ReviewTimelineEntry.")
        ).firstMatch
        if identifiedElement.exists {
            return identifiedElement
        }

        // Fallback: first timeline entry usually appears after the mode picker row.
        let firstCellFallback = app.cells.element(boundBy: 1)
        if firstCellFallback.exists {
            return firstCellFallback
        }
        return app.cells.firstMatch
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
    func test_historyScreen_navigatesToPastEntry() throws {
        throw XCTSkip("Temporarily skipped: timeline list rows are not reliably exposed to XCUITest in current simulator runtime.")
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
    func test_pastEntryScreen_shareButtonIsVisibleAfterNavigatingFromHistory() throws {
        throw XCTSkip("Temporarily skipped: timeline list rows are not reliably exposed to XCUITest in current simulator runtime.")
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

        let addButton = app.buttons["Add new item in Gratitudes"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let fieldValue = gratitudeField.value as? String
        XCTAssertTrue(
            fieldValue != "Draft gratitude in progress",
            "Expected the active draft to move into a chip and the field to reset."
        )
    }

    @MainActor
    func test_todayScreen_submitKeepsKeyboardAvailableForNextEntry() {
        let app = launchApp()
        let gratitudeField = app.textFields["Gratitude 1"]
        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 5))

        gratitudeField.tap()
        gratitudeField.typeText("First gratitude entry\n")

        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 5),
            "Keyboard should remain available after submitting an entry."
        )

        if !app.keyboards.firstMatch.exists {
            gratitudeField.tap()
        }
        gratitudeField.typeText("Second gratitude draft")
        XCTAssertEqual(gratitudeField.value as? String, "Second gratitude draft")
    }
}
