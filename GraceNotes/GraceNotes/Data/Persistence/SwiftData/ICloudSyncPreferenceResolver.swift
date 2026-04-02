import Foundation

enum ICloudSyncPreferenceResolver {
    private static let legacyTutorialKeys = [
        JournalTutorialStorageKeys.dismissedSeedGuidance,
        JournalTutorialStorageKeys.dismissedHarvestGuidance,
        JournalTutorialStorageKeys.celebratedFirstSeed,
        JournalTutorialStorageKeys.celebratedFirstBalanced,
        JournalTutorialStorageKeys.celebratedFirstHarvest
    ]

    private static let onboardingKeys = [
        GraceNotesLaunchStorageKeys.lastLaunchedMarketingVersion,
        JournalOnboardingStorageKeys.completedGuidedJournal,
        JournalOnboardingStorageKeys.legacy051GuidedBranchResolution,
        JournalOnboardingStorageKeys.hasSeenAppTour,
        JournalOnboardingStorageKeys.dismissedRemindersSuggestion,
        JournalOnboardingStorageKeys.dismissedICloudSuggestion,
        JournalOnboardingStorageKeys.openedRemindersSuggestion,
        JournalOnboardingStorageKeys.openedICloudSuggestion
    ]

    static func resolvedCloudSyncEnabled(using defaults: UserDefaults = .standard) -> Bool {
        if let storedPreference = defaults.object(forKey: PersistenceController.iCloudSyncEnabledKey) as? Bool {
            return storedPreference
        }

        let resolvedPreference = shouldPreserveExistingInstallAsEnabled(using: defaults)
        defaults.set(resolvedPreference, forKey: PersistenceController.iCloudSyncEnabledKey)
        return resolvedPreference
    }

    static func shouldPreserveExistingInstallAsEnabled(using defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: FirstRunOnboardingStorageKeys.completed) as? Bool == true {
            return true
        }

        if defaults.object(forKey: ReminderSettings.timeIntervalKey) != nil {
            return true
        }

        if defaults.object(forKey: ReviewInsightsProvider.legacyAIFeaturesUserDefaultsKey) != nil {
            return true
        }

        let continuityKeys = legacyTutorialKeys + onboardingKeys
        return continuityKeys.contains { defaults.object(forKey: $0) != nil }
    }
}
