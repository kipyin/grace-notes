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

    private func rhythmDayIds() -> (oldest: String, today: String)? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let oldestDay = calendar.date(byAdding: .day, value: -36, to: todayStart) else {
            return nil
        }
        let oldestStart = calendar.startOfDay(for: oldestDay)
        let oldestId = "ReviewRhythmDay.\(Int(oldestStart.timeIntervalSince1970))"
        let todayId = "ReviewRhythmDay.\(Int(todayStart.timeIntervalSince1970))"
        return (oldestId, todayId)
    }

    @MainActor
    func test_reviewScreen_rhythm_doesNotSnapToTodayAfterOrientationChange() {
        let app = launchAppWithWideReviewRhythm()
        app.tabBars.buttons["Review"].tap()

        XCTAssertTrue(
            app.staticTexts["Reflection rhythm"].waitForExistence(timeout: 25),
            "Expected Review insights with wide rhythm seed."
        )

        let scroll = app.scrollViews["ReviewRhythmHorizontalScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10), "Expected identified rhythm scroll view.")

        guard let ids = rhythmDayIds() else {
            XCTFail("Could not compute oldest seeded rhythm day")
            return
        }
        let oldestColumn = rhythmColumn(app: app, identifier: ids.oldest)
        let todayColumn = rhythmColumn(app: app, identifier: ids.today)

        XCTAssertTrue(oldestColumn.waitForExistence(timeout: 10), "Expected oldest rhythm column.")

        for _ in 0..<18 {
            if oldestColumn.isHittable { break }
            scroll.swipeRight()
        }

        XCTAssertTrue(oldestColumn.isHittable, "Oldest column should be on screen after swiping.")
        XCTAssertFalse(todayColumn.isHittable, "Today should be off-screen while viewing oldest in portrait.")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(scroll.waitForExistence(timeout: 3))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(scroll.waitForExistence(timeout: 3))

        let oldestAfter = rhythmColumn(app: app, identifier: ids.oldest)
        let todayAfter = rhythmColumn(app: app, identifier: ids.today)
        XCTAssertTrue(oldestAfter.waitForExistence(timeout: 5))
        XCTAssertTrue(todayAfter.waitForExistence(timeout: 5))

        if todayAfter.isHittable, !oldestAfter.isHittable {
            let message = """
            Reg #131: after orientation, only today is reachable — strip snapped to trailing \
            while user had scrolled to oldest days.
            """
            XCTFail(message)
        }
    }
}
