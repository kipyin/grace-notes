import UIKit

/// Applies global UIKit chrome after `UIApplication` launch (safer on iOS 17 than configuring from `App.init()`).
final class GraceNotesAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppInterfaceAppearance.configure()
        return true
    }
}
