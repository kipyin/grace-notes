import Foundation

extension ProcessInfo {
    /// Seeds many past-day journal rows so Review’s reflection rhythm strip is wider than the phone (#131 UI tests).
    static let graceNotesUITestWideReviewRhythmArgument = "-grace-notes-uitest-wide-review-rhythm"

    /// True when the app runs under UI tests: UITest bundle path from XCTest, or `-ui-testing` launch argument.
    static var graceNotesIsRunningUITests: Bool {
        let processInfo = Self.processInfo
        let isUITestBundle = processInfo.environment["XCTestBundlePath"]?.contains("UITests") == true
        let hasUITestLaunchArgument = processInfo.arguments.contains("-ui-testing")
        return isUITestBundle || hasUITestLaunchArgument
    }

    /// True when XCTest hosts the app for **unit** tests (not UI tests): blank root and no global `UIAppearance`.
    ///
    /// Keep in sync with `GraceNotesApp.init` and `GraceNotesAppDelegate`—single definition of “hosted unit tests.”
    static var graceNotesIsRunningHostedUnitTests: Bool {
        let processInfo = Self.processInfo
        let isXCTestSession = processInfo.environment["XCTestConfigurationFilePath"] != nil
        return isXCTestSession && !graceNotesIsRunningUITests
    }

    /// True when UI tests request the wide Review rhythm seed (ignored unless
    /// `graceNotesIsRunningUITests` is also true).
    static var graceNotesUITestWideReviewRhythmSeed: Bool {
        guard graceNotesIsRunningUITests else { return false }
        return Self.processInfo.arguments.contains(Self.graceNotesUITestWideReviewRhythmArgument)
    }
}
