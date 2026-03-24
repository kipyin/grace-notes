import Foundation

extension ProcessInfo {
    /// True when the app runs under UI tests: UITest bundle path from XCTest, or `-ui-testing` launch argument.
    static var graceNotesIsRunningUITests: Bool {
        let processInfo = Self.processInfo
        let isUITestBundle = processInfo.environment["XCTestBundlePath"]?.contains("UITests") == true
        let hasUITestLaunchArgument = processInfo.arguments.contains("-ui-testing")
        return isUITestBundle || hasUITestLaunchArgument
    }
}
