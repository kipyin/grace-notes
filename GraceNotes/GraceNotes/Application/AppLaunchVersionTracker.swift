import Foundation

enum GraceNotesLaunchStorageKeys {
    static let lastLaunchedMarketingVersion = "graceNotes.lastLaunchedMarketingVersion"
}

/// Persists last launched marketing version. Flags one-time 0.5.1+ upgrade orientation when crossing from older builds.
enum AppLaunchVersionTracker {
    /// Call once per process launch before resolving guided-journal migration.
    /// - Parameter currentMarketingVersionOverride: Tests inject a version string instead of reading the host bundle.
    static func applyLaunch(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        currentMarketingVersionOverride: String? = nil
    ) {
        let current = currentMarketingVersionOverride ?? bundle.graceNotesMarketingVersion ?? "0"
        let previous = defaults.string(forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)

        if !ProcessInfo.graceNotesIsRunningUITests,
           let previous,
           MarketingVersion.compare(previous, MarketingVersion.orientationReleaseAnchor) == .orderedAscending,
           MarketingVersion.compare(current, MarketingVersion.orientationReleaseAnchor) != .orderedAscending {
            defaults.set(true, forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation)
            defaults.removeObject(forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        }

        defaults.set(current, forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
    }

    static func resetLaunchTracking(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
        defaults.removeObject(forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation)
        defaults.removeObject(forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution)
    }
}
