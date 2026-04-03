import XCTest

/// Issue #152: Past tab history rollup panels expose stable identifiers when `-ui-testing` is active.
final class JournalReviewHistoryPanelsUITests: XCTestCase {
    private func element(app: XCUIApplication, identifier: String) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier == %@", identifier)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    @MainActor
    func test_past_historyPanels_exposeAccessibilityIdentifiers() {
        let app = XCUIApplication()
        app.configureGraceNotesUITestLaunch(resetUITestStore: true, wideReviewRhythm: true)
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Gratitudes"].waitForExistence(timeout: 5),
            "Expected UI test launch to bypass onboarding and open Today screen."
        )
        app.tabBars.buttons["Past"].tap()
        XCTAssertTrue(
            app.staticTexts["Days you wrote"].waitForExistence(timeout: 25),
            "Expected Past tab insights with wide rhythm seed."
        )

        let growth = element(app: app, identifier: "ReviewHistoryGrowthStagesPanel")
        let distribution = element(app: app, identifier: "ReviewHistorySectionDistributionPanel")
        XCTAssertTrue(
            growth.waitForExistence(timeout: 15),
            "Expected Growth stages panel UITest identifier."
        )
        // On small phones (e.g. SE), the distribution card can start below the first viewport; nudge the scroll view.
        if !distribution.waitForExistence(timeout: 2) {
            for _ in 0..<8 {
                app.swipeUp()
                if distribution.waitForExistence(timeout: 1) { break }
            }
        }
        XCTAssertTrue(
            distribution.waitForExistence(timeout: 5),
            "Expected section distribution panel UITest identifier."
        )
        let sectionCardTitle = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Section mix")
        ).firstMatch
        if !sectionCardTitle.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(sectionCardTitle.waitForExistence(timeout: 5), "Expected Section mix card title on Past.")
    }
}
