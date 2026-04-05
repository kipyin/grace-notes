import XCTest

/// Reflection rhythm horizontal scroll regression coverage (#131); split from `JournalUITests` for SwiftLint limits.
final class JournalReviewRhythmScrollUITests: XCTestCase {
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launchAppWithWideReviewRhythm() -> XCUIApplication {
        let app = XCUIApplication()
        app.configureGraceNotesUITestLaunch(resetUITestStore: true, wideReviewRhythm: true)
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Gratitudes"].waitForExistence(timeout: 5),
            "Expected UI test launch to bypass onboarding and open Today screen."
        )
        return app
    }

    private func rhythmColumn(app: XCUIApplication, identifier: String) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier == %@", identifier)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Oldest column is **today − 36** (wide seed). Trailing column is **today** (rhythm history does not extend
    /// past the insights reference calendar day).
    private func rhythmDayIds() -> (oldest: String, newest: String)? {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let todayStart = calendar.startOfDay(for: Date())
        guard let oldestSeededDay = calendar.date(byAdding: .day, value: -36, to: todayStart) else {
            return nil
        }
        let oldestId = "ReviewRhythmDay.\(Int(calendar.startOfDay(for: oldestSeededDay).timeIntervalSince1970))"
        let newestId = "ReviewRhythmDay.\(Int(todayStart.timeIntervalSince1970))"
        return (oldestId, newestId)
    }

    @MainActor
    func test_reviewScreen_rhythm_doesNotSnapToTodayAfterOrientationChange() {
        let app = launchAppWithWideReviewRhythm()
        app.tabBars.buttons["Past"].tap()

        // Catalog key is "Reflection rhythm"; en value is "Days you wrote" (UI tests force English).
        XCTAssertTrue(
            app.graceNotesReflectionRhythmTitleReady.waitForExistence(timeout: 25),
            "Expected Past tab insights with wide rhythm seed."
        )

        let scroll = app.scrollViews["ReviewRhythmHorizontalScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10), "Expected identified rhythm scroll view.")

        guard let ids = rhythmDayIds() else {
            XCTFail("Could not compute oldest seeded rhythm day")
            return
        }
        let oldestColumn = rhythmColumn(app: app, identifier: ids.oldest)
        let newestColumn = rhythmColumn(app: app, identifier: ids.newest)

        XCTAssertTrue(oldestColumn.waitForExistence(timeout: 10), "Expected oldest rhythm column.")

        for _ in 0..<8 {
            if oldestColumn.isHittable { break }
            scroll.swipeRight()
        }

        XCTAssertTrue(oldestColumn.isHittable, "Oldest column should be on screen after swiping.")
        XCTAssertFalse(newestColumn.isHittable, "Newest column should be off-screen while viewing oldest in portrait.")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(scroll.waitForExistence(timeout: 3))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(scroll.waitForExistence(timeout: 3))

        let oldestAfter = rhythmColumn(app: app, identifier: ids.oldest)
        let newestAfter = rhythmColumn(app: app, identifier: ids.newest)
        XCTAssertTrue(oldestAfter.waitForExistence(timeout: 5))
        XCTAssertTrue(newestAfter.waitForExistence(timeout: 5))

        if newestAfter.isHittable, !oldestAfter.isHittable {
            let message = """
            Reg #131: after orientation, only the newest day is reachable — strip snapped to trailing \
            while user had scrolled to oldest days.
            """
            XCTFail(message)
        }
    }
}
