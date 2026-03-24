import Foundation

extension ProcessInfo {
    /// True when the app runs under UI tests (`-ui-testing` / env flag, or UITest bundle path visible).
    static var graceNotesIsRunningUITests: Bool {
        let processInfo = Self.processInfo
        let isUITestBundle = processInfo.environment["XCTestBundlePath"]?.contains("UITests") == true
        let hasUITestLaunchArgument = processInfo.arguments.contains("-ui-testing")
        let hasUITestEnvironmentFlag = processInfo.environment["FIVECUBED_UI_TESTING"]
            .map { value in
                let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return normalizedValue == "1" || normalizedValue == "true" || normalizedValue == "yes"
            } ?? false
        return isUITestBundle || hasUITestLaunchArgument || hasUITestEnvironmentFlag
    }
}
