import XCTest

// swiftlint:disable type_body_length
/// UI tests use `-ui-testing`. To reset journal tutorial flags (issue #60), add
/// `-reset-journal-tutorial` to `launchArguments` before `launch()`.
final class JournalUITests: XCTestCase {
    /// `JournalViewModel` debounces SwiftData saves (`-grace-notes-uitest-short-autosave` → 50ms in UI tests).
    private func waitForDebouncedJournalSave() {
        Thread.sleep(forTimeInterval: 0.25)
    }

    private func waitForLabel(
        _ expectedLabel: String,
        on element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// After chip submit, the software keyboard can stay up and bury lower sections on small simulators (CI parity).
    @MainActor
    private func dismissSoftwareKeyboardForJournalIfPresent(in app: XCUIApplication) {
        guard app.keyboards.firstMatch.waitForExistence(timeout: 0.5) else { return }
        let anchor = app.staticTexts["Gratitudes"].firstMatch
        if anchor.waitForExistence(timeout: 1) {
            anchor.tap()
        } else {
            app.swipeDown()
        }
    }

    /// Scrolls until the section add chip is hittable so `tap()` reaches the morph control, not the keyboard chrome.
    @MainActor
    private func ensureJournalAddButtonReady(_ addButtonIdentifier: String, in app: XCUIApplication) {
        let addButton = app.buttons[addButtonIdentifier].firstMatch
        for _ in 0..<10 {
            if addButton.waitForExistence(timeout: 0.6), addButton.isHittable {
                return
            }
            app.swipeUp()
        }
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

    /// XCTest does not expose `hasKeyboardFocus` on `XCUIElement` for iOS targets; KVC matches
    /// the accessibility value when the software keyboard UI is absent (e.g. hardware keyboard).
    private func hasVisibleKeyboardOrFocusedEditor(_ editor: XCUIElement, in app: XCUIApplication) -> Bool {
        if app.keyboards.firstMatch.exists { return true }
        return (editor.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    @MainActor
    private func openInlineEditor(
        stripId: String,
        editorId: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        let strip = app.buttons[stripId]
        XCTAssertTrue(strip.waitForExistence(timeout: 6), "Expected strip \(stripId) to exist.")
        let editor = journalTextView(editorId, in: app)
        for attempt in 0..<3 {
            if !strip.isHittable {
                app.swipeUp()
            }
            strip.tap()
            if editor.waitForExistence(timeout: attempt == 0 ? 2 : 4) {
                return editor
            }
        }
        XCTFail("Expected inline editor \(editorId) after tapping strip \(stripId).")
        return editor
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
            dismissSoftwareKeyboardForJournalIfPresent(in: app)
            ensureJournalAddButtonReady(addButtonIdentifier, in: app)
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
            stripIdentifier: "JournalGratitudeEntry.0",
            addButtonIdentifier: "JournalSectionAdd.gratitude",
            text: text,
            in: app
        )
    }

    @MainActor
    private func addNeed(_ text: String, in app: XCUIApplication) {
        submitEntry(
            fieldIdentifier: "Need 1",
            stripIdentifier: "JournalNeedEntry.0",
            addButtonIdentifier: "JournalSectionAdd.need",
            text: text,
            in: app
        )
    }

    @MainActor
    private func addPerson(_ text: String, in app: XCUIApplication) {
        submitEntry(
            fieldIdentifier: "Person 1",
            stripIdentifier: "JournalPersonEntry.0",
            addButtonIdentifier: "JournalSectionAdd.person",
            text: text,
            in: app
        )
    }

    @MainActor
    func test_todayScreen_persistsJournalInputAcrossRelaunch() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Gratitudes"].waitForExistence(timeout: 5))
        addGratitude("Thankful for family", in: app)
        waitForDebouncedJournalSave()
        let gratitudeStrip = app.buttons["JournalGratitudeEntry.0"]
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
            app.buttons["JournalGratitudeEntry.0"].waitForExistence(timeout: 12),
            "Expected gratitude to persist across relaunch."
        )
    }

    @MainActor
    func test_reviewScreen_rhythmDrillInOpensJournalWithShare() {
        let app = launchApp()
        addGratitude("Review rhythm drill-in test", in: app)
        waitForDebouncedJournalSave()

        app.tabBars.buttons["Past"].tap()

        // Catalog key is "Reflection rhythm"; en value is "Days you wrote" (UI tests force English).
        XCTAssertTrue(
            app.graceNotesReflectionRhythmTitleReady.waitForExistence(timeout: 20),
            "Expected Past tab insights to finish loading (rhythm section title)."
        )

        let dayStart = Calendar.current.startOfDay(for: Date())
        let rhythmId = "ReviewRhythmDay.\(Int(dayStart.timeIntervalSince1970))"
        let rhythmPredicate = NSPredicate(format: "identifier == %@", rhythmId)
        let rhythmControl = app.descendants(matching: .any).matching(rhythmPredicate).firstMatch
        XCTAssertTrue(
            rhythmControl.waitForExistence(timeout: 15),
            "Expected rhythm column for today after saving a gratitude entry."
        )
        rhythmControl.tap()

        XCTAssertTrue(
            app.buttons["Share"].waitForExistence(timeout: 8),
            "Expected journal screen with Share after drilling in from Past tab rhythm."
        )
        let doneButton = app.navigationBars.buttons["Done"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 5),
            "Expected Done in the journal sheet toolbar."
        )
        doneButton.tap()
        XCTAssertTrue(
            app.graceNotesReflectionRhythmTitleReady.waitForExistence(timeout: 8),
            "Expected Past tab after dismissing the journal sheet."
        )
    }

    @MainActor
    func test_todayScreen_shareButtonIsVisible() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Gratitudes"].waitForExistence(timeout: 5))
        let shareButton = app.buttons["Share"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5))
        shareButton.tap()
        XCTAssertTrue(
            app.buttons["ShareComposerConfirm"].waitForExistence(timeout: 5),
            "Expected share composer after tapping Share."
        )
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
            app.buttons["JournalGratitudeEntry.1"].waitForExistence(timeout: 8),
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
            app.buttons["JournalGratitudeEntry.0"].waitForExistence(timeout: 8),
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

        XCTAssertTrue(app.buttons["JournalNeedEntry.0"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["JournalPersonEntry.0"].waitForExistence(timeout: 8))
    }

    @MainActor
    func test_todayScreen_tappingStripLoadsSentenceIntoEditor() {
        let app = launchApp()
        let sentence = "I am grateful for an unhurried walk after lunch."
        addGratitude(sentence, in: app)

        let strip = app.buttons["JournalGratitudeEntry.0"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        strip.tap()

        let gratitudeEditor = journalTextView("JournalGratitudeEntry.0.editor", in: app)
        XCTAssertTrue(gratitudeEditor.waitForExistence(timeout: 5))
        XCTAssertEqual(gratitudeEditor.value as? String, sentence)
    }

    @MainActor
    func test_todayScreen_longStripShowsExpandablePreviewControl() {
        let app = launchApp()
        let longSentence =
            "I am grateful for a long, quiet evening where I could slow down, breathe, and write with clarity."
        addGratitude(longSentence, in: app)

        // Submitting can leave the composer focused with keyboard present.
        // Defocus before tapping strip controls so taps are not consumed by focus changes.
        if app.keyboards.firstMatch.exists {
            app.staticTexts["Gratitudes"].tap()
        }

        let updatingIndicator = app.otherElements["Gratitudes section is updating."]
        if updatingIndicator.exists {
            XCTAssertTrue(
                updatingIndicator.waitForNonExistence(timeout: 10),
                "Expected section update overlay to finish before interacting with preview toggle."
            )
        }

        let expandToggle = app.buttons["JournalGratitudeEntry.0.more"]
        XCTAssertTrue(expandToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(expandToggle.label, "Show more")
        XCTAssertFalse(
            app.staticTexts[longSentence].exists,
            "SentenceStripView ignores child accessibility; the full line is not a standalone StaticText."
        )
        expandToggle.tap()
        let collapseToggle = app.buttons["JournalGratitudeEntry.0.more"]
        XCTAssertTrue(collapseToggle.waitForExistence(timeout: 5))
        if !waitForLabel("Show less", on: collapseToggle, timeout: 1.5) {
            // First tap can clear lingering focus from the composer before the
            // toggle receives activation.
            collapseToggle.tap()
        }
        XCTAssertTrue(
            waitForLabel("Show less", on: collapseToggle, timeout: 5),
            "Expected the preview toggle to reflect expanded state."
        )
        let strip = app.buttons["JournalGratitudeEntry.0"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        XCTAssertEqual(
            strip.value as? String,
            longSentence,
            "Expected the strip accessibility value to carry the full sentence."
        )
    }

    @MainActor
    func test_todayScreen_inlineEditor_commitsOnScrimTap() {
        let app = launchApp()
        addGratitude("I am grateful for a calm start.", in: app)

        let strip = app.buttons["JournalGratitudeEntry.0"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        strip.tap()

        let gratitudeEditor = journalTextView("JournalGratitudeEntry.0.editor", in: app)
        XCTAssertTrue(gratitudeEditor.waitForExistence(timeout: 5))
        gratitudeEditor.tap()
        gratitudeEditor.typeText(" Added detail")

        app.staticTexts["Gratitudes"].tap()

        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        strip.tap()

        let reopenedEditor = journalTextView("JournalGratitudeEntry.0.editor", in: app)
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

        let strip = app.buttons["JournalGratitudeEntry.0"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        strip.tap()

        let gratitudeEditor = app.textViews["JournalGratitudeEntry.0.editor"]
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

        let firstStrip = app.buttons["JournalGratitudeEntry.0"]
        let secondStrip = app.buttons["JournalGratitudeEntry.1"]
        XCTAssertTrue(firstStrip.waitForExistence(timeout: 5))
        XCTAssertTrue(secondStrip.waitForExistence(timeout: 5))

        let firstEditor = openInlineEditor(
            stripId: "JournalGratitudeEntry.0",
            editorId: "JournalGratitudeEntry.0.editor",
            in: app
        )
        firstEditor.typeText(" UPDATED")

        let secondEditor = openInlineEditor(
            stripId: "JournalGratitudeEntry.1",
            editorId: "JournalGratitudeEntry.1.editor",
            in: app
        )
        XCTAssertEqual(secondEditor.value as? String, "Second gratitude sentence")

        let firstEditorReopened = openInlineEditor(
            stripId: "JournalGratitudeEntry.0",
            editorId: "JournalGratitudeEntry.0.editor",
            in: app
        )
        let firstValue = firstEditorReopened.value as? String ?? ""
        XCTAssertTrue(
            firstValue.contains("UPDATED"),
            "Expected first strip edits to persist after focusing another strip."
        )
    }

    @MainActor
    func test_todayScreen_needInlineEditor_canSwitchBetweenRowsWithKeyboard() {
        let app = launchApp()
        addGratitude("Starter for needs keyboard test", in: app)
        addNeed("First need line", in: app)

        let addNeedBtn = app.buttons["JournalSectionAdd.need"].firstMatch
        XCTAssertTrue(addNeedBtn.waitForExistence(timeout: 6))
        addNeedBtn.tap()

        let needField = journalTextView("Need 1", in: app)
        XCTAssertTrue(needField.waitForExistence(timeout: 5))
        needField.tap()
        needField.typeText("Second need draft")
        let returnKey = app.keyboards.buttons["Return"]
        if returnKey.exists, returnKey.isHittable {
            returnKey.tap()
        } else {
            needField.typeText("\n")
        }
        XCTAssertTrue(
            app.buttons["JournalNeedEntry.1"].waitForExistence(timeout: 10),
            "Expected second need strip after submitting draft."
        )

        let firstEditor = openInlineEditor(
            stripId: "JournalNeedEntry.0",
            editorId: "JournalNeedEntry.0.editor",
            in: app
        )
        firstEditor.typeText(" edited")

        _ = openInlineEditor(
            stripId: "JournalNeedEntry.1",
            editorId: "JournalNeedEntry.1.editor",
            in: app
        )

        let firstReopened = openInlineEditor(
            stripId: "JournalNeedEntry.0",
            editorId: "JournalNeedEntry.0.editor",
            in: app
        )
        XCTAssertTrue(
            (firstReopened.value as? String)?.contains("edited") == true,
            "Expected first need edits after focusing another strip."
        )
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 4),
            "Keyboard should stay available when switching need rows during inline editing."
        )
    }

    @MainActor
    func test_todayScreen_gratitudeInlineEditor_longMultilineInput_staysEditable() {
        let app = launchApp()
        addGratitude("Seed for long multiline test", in: app)

        let editor = openInlineEditor(
            stripId: "JournalGratitudeEntry.0",
            editorId: "JournalGratitudeEntry.0.editor",
            in: app
        )
        let chunk = "One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen. "
        var body = ""
        for _ in 0 ..< 12 {
            body += chunk
        }
        editor.typeText(body)

        let value = editor.value as? String ?? ""
        XCTAssertGreaterThan(
            value.count,
            400,
            "Expected long wrapped input to remain in the inline editor."
        )
        XCTAssertTrue(
            editor.waitForExistence(timeout: 2),
            "Inline editor should remain on-screen after long input."
        )
        XCTAssertTrue(
            hasVisibleKeyboardOrFocusedEditor(editor, in: app),
            "Expected keyboard or focused editor after long multiline input."
        )
    }
}

// swiftlint:enable type_body_length
