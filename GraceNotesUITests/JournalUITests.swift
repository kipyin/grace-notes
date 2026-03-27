import XCTest

/// UI tests use `-ui-testing`. To reset journal tutorial flags (issue #60), add
/// `-reset-journal-tutorial` to `launchArguments` before `launch()`.
final class JournalUITests: XCTestCase {
    /// `JournalViewModel` debounces SwiftData saves (`-grace-notes-uitest-short-autosave` → 50ms in UI tests).
    private func waitForDebouncedJournalSave() {
        Thread.sleep(forTimeInterval: 0.25)
    }

    @MainActor
    private func launchApp(resetUITestStore: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.configureGraceNotesUITestLaunch(resetUITestStore: resetUITestStore)
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Gratitudes"].waitForExistence(timeout: 5),
            "Expected UI test launch to bypass onboarding and open Today screen."
        )
        return app
    }

    /// Today’s journal composers use `UITextView`; XCUI exposes them as TextView, not TextField.
    private func journalTextView(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.textViews[identifier]
    }

    @MainActor
    private func submitEntry(
        fieldIdentifier: String,
        stripIdentifier: String,
        addButtonIdentifier: String?,
        text: String,
        in app: XCUIApplication
    ) {
        let field = journalTextView(fieldIdentifier, in: app)
        if !field.waitForExistence(timeout: 2), let addButtonIdentifier {
            let addButton = app.buttons[addButtonIdentifier].firstMatch
            XCTAssertTrue(
                addButton.waitForExistence(timeout: 5),
                "Expected add button before attempting to reveal input."
            )
            addButton.tap()
        }
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)

        // Prefer tapping an explicit return key because newline typing can be flaky
        // under some simulator keyboard configurations.
        let returnKey = app.keyboards.buttons["Return"]
        if returnKey.exists, returnKey.isHittable {
            returnKey.tap()
        } else {
            field.typeText("\n")
        }

        XCTAssertTrue(
            app.buttons[stripIdentifier].waitForExistence(timeout: 15),
            "Expected submitted strip before continuing."
        )
    }

    @MainActor
    private func addGratitude(_ text: String, in app: XCUIApplication) {
        submitEntry(
            fieldIdentifier: "Gratitude 1",
            stripIdentifier: "JournalGratitudeStrip.0",
            addButtonIdentifier: "JournalSectionAdd.gratitude",
            text: text,
            in: app
        )
    }

    @MainActor
    private func addNeed(_ text: String, in app: XCUIApplication) {
        submitEntry(
            fieldIdentifier: "Need 1",
            stripIdentifier: "JournalNeedStrip.0",
            addButtonIdentifier: "JournalSectionAdd.need",
            text: text,
            in: app
        )
    }

    @MainActor
    private func addPerson(_ text: String, in app: XCUIApplication) {
        submitEntry(
            fieldIdentifier: "Person 1",
            stripIdentifier: "JournalPersonStrip.0",
            addButtonIdentifier: "JournalSectionAdd.person",
            text: text,
            in: app
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
        let gratitudeStrip = app.buttons["JournalGratitudeStrip.0"]
        XCTAssertTrue(
            gratitudeStrip.waitForExistence(timeout: 12),
            "Expected submitted gratitude strip before relaunch."
        )

        app.terminate()
        app.configureGraceNotesUITestLaunch(resetUITestStore: false)
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Gratitudes"].waitForExistence(timeout: 10),
            "Expected relaunch to land on Today with journal UI ready."
        )

        XCTAssertTrue(
            app.buttons["JournalGratitudeStrip.0"].waitForExistence(timeout: 12),
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
        let gratitudeField = journalTextView("Gratitude 1", in: app)
        let addForFirstField = app.buttons["JournalSectionAdd.gratitude"].firstMatch
        XCTAssertTrue(addForFirstField.waitForExistence(timeout: 5))
        addForFirstField.tap()
        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 5))

        // Add first strip so (+) button remains available for a second entry.
        addGratitude("First chip", in: app)

        let addButton = app.buttons["JournalSectionAdd.gratitude"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 5))
        gratitudeField.tap()
        gratitudeField.typeText("Draft gratitude in progress")

        let returnKey = app.keyboards.buttons["Return"]
        if returnKey.exists, returnKey.isHittable {
            returnKey.tap()
        } else {
            gratitudeField.typeText("\n")
        }

        XCTAssertTrue(
            app.buttons["JournalGratitudeStrip.1"].waitForExistence(timeout: 8),
            "Expected active draft to submit into a new strip."
        )
    }

    @MainActor
    func test_todayScreen_submitKeepsKeyboardAvailableForNextEntry() {
        let app = launchApp()
        let gratitudeField = journalTextView("Gratitude 1", in: app)
        let addForFirstField = app.buttons["JournalSectionAdd.gratitude"].firstMatch
        XCTAssertTrue(addForFirstField.waitForExistence(timeout: 5))
        addForFirstField.tap()
        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 5))

        gratitudeField.tap()
        gratitudeField.typeText("First gratitude entry\n")

        XCTAssertTrue(
            app.buttons["JournalGratitudeStrip.0"].waitForExistence(timeout: 8),
            "Expected first gratitude to appear as a strip after submit."
        )

        let addButton = app.buttons["JournalSectionAdd.gratitude"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 2))
        gratitudeField.tap()
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 5),
            "Keyboard should show when focusing the composer for the next entry."
        )
        gratitudeField.typeText("Second gratitude draft")
        XCTAssertEqual(gratitudeField.value as? String, "Second gratitude draft")
    }

    @MainActor
    func test_todayScreen_needsAndPeopleExposeStripIdentifiers() {
        let app = launchApp()

        // The onboarding progression unlocks Needs/People after at least one gratitude entry.
        addGratitude("Starter gratitude", in: app)
        addNeed("Need rest after work", in: app)
        addPerson("Thinking of Amy", in: app)

        XCTAssertTrue(app.buttons["JournalNeedStrip.0"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["JournalPersonStrip.0"].waitForExistence(timeout: 8))
    }

    @MainActor
    func test_todayScreen_tappingStripLoadsSentenceIntoEditor() {
        let app = launchApp()
        let sentence = "I am grateful for an unhurried walk after lunch."
        addGratitude(sentence, in: app)

        let strip = app.buttons["JournalGratitudeStrip.0"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        strip.tap()

        let gratitudeEditor = journalTextView("JournalGratitudeStrip.0.editor", in: app)
        XCTAssertTrue(gratitudeEditor.waitForExistence(timeout: 5))
        XCTAssertEqual(gratitudeEditor.value as? String, sentence)
    }

    @MainActor
    func test_todayScreen_longStripShowsExpandablePreviewControl() {
        let app = launchApp()
        let longSentence =
            "I am grateful for a long, quiet evening where I could slow down, breathe, and write with clarity."
        addGratitude(longSentence, in: app)

        let showMore = app.buttons["JournalGratitudeStrip.0.more"]
        XCTAssertTrue(showMore.waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.staticTexts[longSentence].exists,
            "Expected the full long sentence not to be visible as a single static text before expansion."
        )
        showMore.tap()
        XCTAssertTrue(
            app.staticTexts["Show less"].waitForExistence(timeout: 8),
            "Expected expanded preview to expose Show less."
        )
    }

    @MainActor
    func test_todayScreen_inlineEditor_commitsOnScrimTap() {
        let app = launchApp()
        addGratitude("I am grateful for a calm start.", in: app)

        let strip = app.buttons["JournalGratitudeStrip.0"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        strip.tap()

        let gratitudeEditor = journalTextView("JournalGratitudeStrip.0.editor", in: app)
        XCTAssertTrue(gratitudeEditor.waitForExistence(timeout: 5))
        gratitudeEditor.tap()
        gratitudeEditor.typeText(" Added detail")

        app.staticTexts["Gratitudes"].tap()

        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        strip.tap()

        let reopenedEditor = journalTextView("JournalGratitudeStrip.0.editor", in: app)
        XCTAssertTrue(reopenedEditor.waitForExistence(timeout: 5))
        let updatedValue = reopenedEditor.value as? String
        XCTAssertTrue(
            updatedValue?.contains("Added detail") == true,
            "Expected scrim tap to commit inline edits before exiting."
        )
    }

    @MainActor
    func test_todayScreen_inlineEditor_emptyDraftOnScrimTap_deletesStrip() {
        let app = launchApp()

        let addForFirstField = app.buttons["JournalSectionAdd.gratitude"].firstMatch
        XCTAssertTrue(addForFirstField.waitForExistence(timeout: 5))
        addForFirstField.tap()

        let gratitudeField = app.textViews["Gratitude 1"]
        XCTAssertTrue(gratitudeField.waitForExistence(timeout: 5))
        gratitudeField.tap()
        gratitudeField.typeText("I am grateful for a calm start.")
        let returnKey = app.keyboards.buttons["Return"]
        if returnKey.exists, returnKey.isHittable {
            returnKey.tap()
        } else {
            gratitudeField.typeText("\n")
        }

        let strip = app.buttons["JournalGratitudeStrip.0"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        strip.tap()

        let gratitudeEditor = app.textViews["JournalGratitudeStrip.0.editor"]
        XCTAssertTrue(gratitudeEditor.waitForExistence(timeout: 5))
        gratitudeEditor.tap()

        let originalValue = gratitudeEditor.value as? String ?? ""
        if !originalValue.isEmpty {
            let deleteSequence = String(repeating: XCUIKeyboardKey.delete.rawValue, count: originalValue.count)
            gratitudeEditor.typeText(deleteSequence)
        }
        XCTAssertEqual(gratitudeEditor.value as? String, "")

        app.staticTexts["Gratitudes"].tap()

        XCTAssertTrue(
            strip.waitForNonExistence(timeout: 5),
            "Expected empty inline draft to delete the strip on dismiss."
        )
    }

    @MainActor
    func test_todayScreen_inlineEditor_canSwitchBetweenRowsSameSection() {
        let app = launchApp()
        addGratitude("First gratitude sentence", in: app)
        addGratitude("Second gratitude sentence", in: app)

        let firstStrip = app.buttons["JournalGratitudeStrip.0"]
        let secondStrip = app.buttons["JournalGratitudeStrip.1"]
        XCTAssertTrue(firstStrip.waitForExistence(timeout: 5))
        XCTAssertTrue(secondStrip.waitForExistence(timeout: 5))

        firstStrip.tap()
        let firstEditor = journalTextView("JournalGratitudeStrip.0.editor", in: app)
        XCTAssertTrue(firstEditor.waitForExistence(timeout: 5))
        firstEditor.typeText(" UPDATED")

        secondStrip.tap()
        let secondEditor = journalTextView("JournalGratitudeStrip.1.editor", in: app)
        XCTAssertTrue(secondEditor.waitForExistence(timeout: 5))
        XCTAssertEqual(secondEditor.value as? String, "Second gratitude sentence")

        firstStrip.tap()
        let firstEditorReopened = journalTextView("JournalGratitudeStrip.0.editor", in: app)
        XCTAssertTrue(firstEditorReopened.waitForExistence(timeout: 5))
        let firstValue = firstEditorReopened.value as? String ?? ""
        XCTAssertTrue(
            firstValue.contains("UPDATED"),
            "Expected first strip edits to persist after focusing another strip."
        )
    }
}
