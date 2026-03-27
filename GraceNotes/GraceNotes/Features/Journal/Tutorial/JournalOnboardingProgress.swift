import Foundation

enum JournalOnboardingSuggestion: CaseIterable {
    case reminders
    case aiFeatures
    case iCloudSync
}

enum JournalOnboardingStorageKeys {
    static let completedGuidedJournal = "journalOnboarding.completedGuidedJournal"
    /// Legacy upgrade cohort: Today clears this after one branch resolution. Listed for iCloud continuity.
    static let legacy051GuidedBranchResolution = "journalOnboarding.pending051GuidedJournalBranchResolution"
    static let hasSeenPostSeedJourney = "journalOnboarding.hasSeenPostSeedJourney"
    static let dismissedRemindersSuggestion = "journalOnboarding.dismissedRemindersSuggestion"
    static let dismissedAISuggestion = "journalOnboarding.dismissedAISuggestion"
    static let dismissedICloudSuggestion = "journalOnboarding.dismissedICloudSuggestion"
    static let openedRemindersSuggestion = "journalOnboarding.openedRemindersSuggestion"
    static let openedAISuggestion = "journalOnboarding.openedAISuggestion"
    static let openedICloudSuggestion = "journalOnboarding.openedICloudSuggestion"
}

private enum LegacyJournalOnboardingStorageKeys {
    static let pending051UpgradeOrientation = "journalOnboarding.pending051UpgradeOrientation"
}

/// Per-install onboarding flags for the behavior-first journal path and optional feature suggestions.
final class JournalOnboardingProgress {
    private let defaults: UserDefaults

    private static let legacyTutorialKeys = [
        JournalTutorialStorageKeys.dismissedSeedGuidance,
        JournalTutorialStorageKeys.dismissedHarvestGuidance,
        JournalTutorialStorageKeys.celebratedFirstSeed,
        JournalTutorialStorageKeys.celebratedFirstBalanced,
        JournalTutorialStorageKeys.celebratedFirstHarvest
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedGuidedJournal: Bool {
        get { defaults.bool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal) }
        set { defaults.set(newValue, forKey: JournalOnboardingStorageKeys.completedGuidedJournal) }
    }

    func hasDismissedSuggestion(_ suggestion: JournalOnboardingSuggestion) -> Bool {
        defaults.bool(forKey: dismissedKey(for: suggestion))
    }

    func setDismissed(_ dismissed: Bool, for suggestion: JournalOnboardingSuggestion) {
        defaults.set(dismissed, forKey: dismissedKey(for: suggestion))
    }

    func hasOpenedSuggestion(_ suggestion: JournalOnboardingSuggestion) -> Bool {
        defaults.bool(forKey: openedKey(for: suggestion))
    }

    func setOpened(_ opened: Bool, for suggestion: JournalOnboardingSuggestion) {
        defaults.set(opened, forKey: openedKey(for: suggestion))
    }

    static func resolvedHasCompletedGuidedJournal(using defaults: UserDefaults = .standard) -> Bool {
        if let storedValue = defaults.object(forKey: JournalOnboardingStorageKeys.completedGuidedJournal) as? Bool {
            return storedValue
        }

        let migratedValue = shouldTreatInstallAsPreviouslyOnboarded(using: defaults)
        defaults.set(migratedValue, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        return migratedValue
    }

    /// Normalizes legacy `pending051*` state from older builds. Drops the upgrade flag; keeps branch
    /// resolution until Today runs `resolvePending051GuidedJournalBranch`.
    static func migrateLegacyPostSeedOrientationFlagsIfNeeded(using defaults: UserDefaults = .standard) {
        let upgradeKey = LegacyJournalOnboardingStorageKeys.pending051UpgradeOrientation
        let branchKey = JournalOnboardingStorageKeys.legacy051GuidedBranchResolution

        if defaults.bool(forKey: upgradeKey) {
            defaults.set(false, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
            defaults.set(true, forKey: branchKey)
        }

        if defaults.bool(forKey: branchKey),
           defaults.object(forKey: JournalOnboardingStorageKeys.completedGuidedJournal) as? Bool == nil {
            defaults.set(false, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        }

        defaults.removeObject(forKey: upgradeKey)
    }

    /// After Today’s entry loads, finalize legacy upgrade cohort branch for `completedGuidedJournal`.
    static func resolvePending051GuidedJournalBranch(
        todayCompletionLevel: JournalCompletionLevel,
        using defaults: UserDefaults = .standard
    ) {
        guard defaults.bool(forKey: JournalOnboardingStorageKeys.legacy051GuidedBranchResolution) else {
            return
        }

        let startedRank = JournalCompletionLevel.started.tutorialCompletionRank
        if todayCompletionLevel.tutorialCompletionRank >= startedRank {
            defaults.set(true, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        }

        defaults.removeObject(forKey: JournalOnboardingStorageKeys.legacy051GuidedBranchResolution)
    }

    static func resetAll(in defaults: UserDefaults = .standard) {
        let keys = [
            JournalOnboardingStorageKeys.completedGuidedJournal,
            LegacyJournalOnboardingStorageKeys.pending051UpgradeOrientation,
            JournalOnboardingStorageKeys.legacy051GuidedBranchResolution,
            JournalOnboardingStorageKeys.hasSeenPostSeedJourney,
            JournalOnboardingStorageKeys.dismissedRemindersSuggestion,
            JournalOnboardingStorageKeys.dismissedAISuggestion,
            JournalOnboardingStorageKeys.dismissedICloudSuggestion,
            JournalOnboardingStorageKeys.openedRemindersSuggestion,
            JournalOnboardingStorageKeys.openedAISuggestion,
            JournalOnboardingStorageKeys.openedICloudSuggestion
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        AppLaunchVersionTracker.resetLaunchTracking(in: defaults)
    }

    private static func shouldTreatInstallAsPreviouslyOnboarded(using defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: FirstRunOnboardingStorageKeys.completed) as? Bool == true {
            return true
        }

        if defaults.object(forKey: ReminderSettings.timeIntervalKey) != nil {
            return true
        }

        if defaults.object(forKey: SummarizerProvider.useCloudUserDefaultsKey) != nil {
            return true
        }

        if defaults.object(forKey: ReviewInsightsProvider.legacyAIFeaturesUserDefaultsKey) != nil {
            return true
        }

        return legacyTutorialKeys.contains { defaults.object(forKey: $0) != nil }
    }

    private func dismissedKey(for suggestion: JournalOnboardingSuggestion) -> String {
        switch suggestion {
        case .reminders:
            return JournalOnboardingStorageKeys.dismissedRemindersSuggestion
        case .aiFeatures:
            return JournalOnboardingStorageKeys.dismissedAISuggestion
        case .iCloudSync:
            return JournalOnboardingStorageKeys.dismissedICloudSuggestion
        }
    }

    private func openedKey(for suggestion: JournalOnboardingSuggestion) -> String {
        switch suggestion {
        case .reminders:
            return JournalOnboardingStorageKeys.openedRemindersSuggestion
        case .aiFeatures:
            return JournalOnboardingStorageKeys.openedAISuggestion
        case .iCloudSync:
            return JournalOnboardingStorageKeys.openedICloudSuggestion
        }
    }
}
