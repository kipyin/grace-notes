import XCTest

/// Single CI smoke: launch with the same UITest contract as `JournalUITests`, then assert a stable root UI hook.
final class GraceNotesSmokeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSmokeLaunch() throws {
        let app = XCUIApplication()
        app.configureGraceNotesUITestLaunch()
        app.launch()

        XCTAssertTrue(
            app.buttons["Share"].waitForExistence(timeout: 15),
            "Expected Today screen Share control (accessibility id Share) after UITest launch."
        )
    }
}
