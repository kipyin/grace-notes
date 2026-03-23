import Combine
import Foundation

enum AppTab: Hashable {
    case today
    case history
    case settings
}

enum SettingsScrollTarget: Hashable {
    case aiFeatures
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
        settingsScrollTarget = target
        selectedTab = .settings
    }

    func clearSettingsTarget(_ target: SettingsScrollTarget) {
        guard settingsScrollTarget == target else { return }
        settingsScrollTarget = nil
    }
}
