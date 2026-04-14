import UIKit

/// Applies global UIKit chrome after `UIApplication` launch (safer on iOS 17 than configuring from `App.init()`).
@MainActor
final class GraceNotesAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Keep this aligned with `GraceNotesApp.init`: hosted unit tests use a blank root and should not
        // mutate global `UIAppearance`; UI tests and normal launches still get chrome.
        if ProcessInfo.graceNotesIsRunningHostedUnitTests {
            return true
        }
        AppInterfaceAppearance.configure()
        return true
    }
}
