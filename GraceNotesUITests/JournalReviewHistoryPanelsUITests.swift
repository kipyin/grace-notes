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
        XCTAssertTrue(
            distribution.waitForExistence(timeout: 15),
            "Expected Section Distribution panel UITest identifier."
        )
        let sectionCardTitle = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Section Distribution")
        ).firstMatch
        XCTAssertTrue(sectionCardTitle.exists, "Expected Section Distribution card title on Past.")
    }
}
