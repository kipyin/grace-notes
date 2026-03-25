import Foundation

enum GraceNotesLaunchStorageKeys {
    static let lastLaunchedMarketingVersion = "graceNotes.lastLaunchedMarketingVersion"
    static let lastLaunchedBundleVersion = "graceNotes.lastLaunchedBundleVersion"
}

/// Persists last launched marketing and bundle. Flags one-time upgrade orientation when crossing onto `OrientationReleaseGate`.
enum AppLaunchVersionTracker {
    /// Call once per process launch before resolving guided-journal migration.
    /// - Parameters:
    ///   - currentMarketingVersionOverride: Tests inject a version string instead of reading the host bundle.
    ///   - currentBundleVersionOverride: Tests inject a build number instead of reading the host bundle.
    static func applyLaunch(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        currentMarketingVersionOverride: String? = nil,
        currentBundleVersionOverride: Int? = nil
    ) {
        let currentMarketing = currentMarketingVersionOverride ?? bundle.graceNotesMarketingVersion ?? "0"
        let currentBundle = currentBundleVersionOverride ?? bundle.graceNotesBundleVersion

        let previousMarketing = defaults.string(forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
        let previousBundle = defaults.object(forKey: GraceNotesLaunchStorageKeys.lastLaunchedBundleVersion) as? Int

        if !ProcessInfo.graceNotesIsRunningUITests,
           let previousMarketing,
           OrientationReleaseGate.isPriorLaunchBeforeRelease(
            marketing: previousMarketing,
            storedBundle: previousBundle
           ),
           OrientationReleaseGate.isCurrentLaunchAtOrAfterRelease(
            marketing: currentMarketing,
            bundle: currentBundle
           ) {
            defaults.set(true, forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation)
            defaults.removeObject(forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        }

        defaults.set(currentMarketing, forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
        if let currentBundle {
            defaults.set(currentBundle, forKey: GraceNotesLaunchStorageKeys.lastLaunchedBundleVersion)
        } else {
            defaults.removeObject(forKey: GraceNotesLaunchStorageKeys.lastLaunchedBundleVersion)
        }
    }

    static func resetLaunchTracking(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion)
        defaults.removeObject(forKey: GraceNotesLaunchStorageKeys.lastLaunchedBundleVersion)
        defaults.removeObject(forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation)
        defaults.removeObject(forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution)
    }
}
