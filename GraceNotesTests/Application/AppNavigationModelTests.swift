import XCTest
@testable import GraceNotes

@MainActor
final class AppNavigationModelTests: XCTestCase {
    func test_openSettings_setsSelectedTabAndTarget() {
        let model = AppNavigationModel()

        model.openSettings(target: .dataPrivacy)

        XCTAssertEqual(model.selectedTab, .settings)
        XCTAssertEqual(model.settingsScrollTarget, .dataPrivacy)
    }

    func test_clearSettingsTarget_onlyClearsMatchingTarget() {
        let model = AppNavigationModel()
        model.openSettings(target: .reminders)

        model.clearSettingsTarget(.aiFeatures)

        XCTAssertEqual(model.settingsScrollTarget, .reminders)

        model.clearSettingsTarget(.reminders)

        XCTAssertNil(model.settingsScrollTarget)
    }
}
