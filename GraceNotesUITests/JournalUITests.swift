import XCTest

/// UI tests use `-ui-testing`. To reset journal tutorial flags (issue #60), add
/// `-reset-journal-tutorial` to `launchArguments` before `launch()`.
final class JournalUITests: XCTestCase {
    /// `JournalViewModel` debounces SwiftData saves; allow persistence to finish before relaunch.
    private func waitForDebouncedJournalSave() {
        Thread.sleep(forTimeInterval: 1.0)
    }

    /// Apply before every `launch()`; a bare `launch()` after `terminate()` can drop arguments on some OS versions.
    private func configureUITestLaunch(
        _ app: XCUIApplication,
        resetUITestStore: Bool = true
    ) {
        var args = [
            "-ui-testing",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        if resetUITestStore {
            args.append("-grace-notes-reset-uitest-store")
        }
        app.launchArguments = args
    }

    @MainActor
    private func launchApp(resetUITestStore: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        configureUITestLaunch(app, resetUITestStore: resetUITestStore)
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
        if returnKey.exists, returnKey.isHittable {
            returnKey.tap()
        } else {
            gratitudeField.typeText("\n")
        }

        XCTAssertTrue(
            app.buttons["JournalGratitudeChip.0"].waitForExistence(timeout: 15),
            "Expected submitted gratitude chip before continuing."
        )
    }

    @MainActor
    private func openReviewTimeline(in app: XCUIApplication) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        if app.segmentedControls.firstMatch.waitForExistence(timeout: 2) {
            return
        }

        let reviewByLabel = tabBar.buttons["Review"]
        if reviewByLabel.waitForExistence(timeout: 3) {
            reviewByLabel.tap()
        } else {
            tabBar.buttons.element(boundBy: 1).tap()
        }

        XCTAssertTrue(
            app.segmentedControls.firstMatch.waitForExistence(timeout: 15),
            "Expected Review mode segmented control."
        )
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
        waitForDebouncedJournalSave()
        let gratitudeChip = app.buttons["JournalGratitudeChip.0"]
        XCTAssertTrue(
            gratitudeChip.waitForExistence(timeout: 12),
            "Expected submitted gratitude chip before relaunch."
        )

        app.terminate()
        configureUITestLaunch(app, resetUITestStore: false)
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Gratitudes"].waitForExistence(timeout: 10),
            "Expected relaunch to land on Today with journal UI ready."
        )

        XCTAssertTrue(
            app.buttons["JournalGratitudeChip.0"].waitForExistence(timeout: 12),
            "Expected gratitude to persist across relaunch."
        )
    }

    @MainActor
    func test_historyScreen_navigatesToPastEntry() throws {
        throw XCTSkip(
            "Temporarily skipped: timeline list rows are not reliably exposed to XCUITest in current simulator runtime."
        )
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
        throw XCTSkip(
            "Temporarily skipped: timeline list rows are not reliably exposed to XCUITest in current simulator runtime."
        )
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

        let addButton = app.buttons["JournalSectionAdd.gratitude"].firstMatch
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

        gratitudeField.tap()
        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 2))
        gratitudeField.typeText("Second gratitude draft")
        XCTAssertEqual(gratitudeField.value as? String, "Second gratitude draft")
    }
}
