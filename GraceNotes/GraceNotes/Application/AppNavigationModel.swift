import Combine
import Foundation

enum AppTab: Hashable {
    case today
    case history
    case settings
}

enum SettingsScrollTarget: Hashable {
    case reminders
    case dataPrivacy
}

@MainActor
final class AppNavigationModel: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var settingsScrollTarget: SettingsScrollTarget?

    /// Switches to Settings and requests scroll/highlight for `target`.
    /// Callers that deep-link from domain rules (e.g. journal onboarding) should validate intent before calling.
    func openSettings(target: SettingsScrollTarget) {
        selectedTab = .settings
        // If the target is unchanged, SwiftUI `onChange` may not run; nil-out first so repeat deep links still scroll.
        if settingsScrollTarget == target {
            settingsScrollTarget = nil
        }
        settingsScrollTarget = target
    }

    func clearSettingsTarget(_ target: SettingsScrollTarget) {
        guard settingsScrollTarget == target else { return }
        settingsScrollTarget = nil
    }
}
