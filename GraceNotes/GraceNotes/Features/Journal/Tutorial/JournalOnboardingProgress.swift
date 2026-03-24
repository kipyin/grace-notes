import Foundation

enum JournalOnboardingSuggestion: CaseIterable {
    case reminders
    case aiFeatures
    case iCloudSync
}

enum JournalOnboardingStorageKeys {
    static let completedGuidedJournal = "journalOnboarding.completedGuidedJournal"
    /// True until the user finishes or skips the one-time upgrade orientation (0.5.1+ cohort).
    static let pending051UpgradeOrientation = "journalOnboarding.pending051UpgradeOrientation"
    /// Upgrade cohort: defer writing `completedGuidedJournal` until Today’s completion level is known.
    static let pending051GuidedJournalBranchResolution = "journalOnboarding.pending051GuidedJournalBranchResolution"
    static let hasSeenPostSeedJourney = "journalOnboarding.hasSeenPostSeedJourney"
    static let dismissedRemindersSuggestion = "journalOnboarding.dismissedRemindersSuggestion"
    static let dismissedAISuggestion = "journalOnboarding.dismissedAISuggestion"
    static let dismissedICloudSuggestion = "journalOnboarding.dismissedICloudSuggestion"
    static let openedRemindersSuggestion = "journalOnboarding.openedRemindersSuggestion"
    static let openedAISuggestion = "journalOnboarding.openedAISuggestion"
    static let openedICloudSuggestion = "journalOnboarding.openedICloudSuggestion"
}

/// Per-install onboarding flags for the behavior-first journal path and optional feature suggestions.
final class JournalOnboardingProgress {
    private let defaults: UserDefaults

    private static let legacyTutorialKeys = [
        JournalTutorialStorageKeys.dismissedSeedGuidance,
        JournalTutorialStorageKeys.dismissedHarvestGuidance,
        JournalTutorialStorageKeys.celebratedFirstSeed,
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

        if defaults.bool(forKey: JournalOnboardingStorageKeys.pending051UpgradeOrientation) {
            defaults.set(false, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
            defaults.set(true, forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution)
            return false
        }

        let migratedValue = shouldTreatInstallAsPreviouslyOnboarded(using: defaults)
        defaults.set(migratedValue, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        return migratedValue
    }

    /// After Today’s entry loads, finalize the 0.5.1 upgrade cohort branch for `completedGuidedJournal`.
    /// At or above Seed on first load → skip chip coaching (`true`). Below Seed → keep full guided path (`false`).
    static func resolvePending051GuidedJournalBranch(
        todayCompletionLevel: JournalCompletionLevel,
        using defaults: UserDefaults = .standard
    ) {
        guard defaults.bool(forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution) else {
            return
        }

        let seedRank = JournalCompletionLevel.seed.tutorialCompletionRank
        if todayCompletionLevel.tutorialCompletionRank >= seedRank {
            defaults.set(true, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        }

        defaults.removeObject(forKey: JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution)
    }

    static func resetAll(in defaults: UserDefaults = .standard) {
        let keys = [
            JournalOnboardingStorageKeys.completedGuidedJournal,
            JournalOnboardingStorageKeys.pending051UpgradeOrientation,
            JournalOnboardingStorageKeys.pending051GuidedJournalBranchResolution,
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

        if defaults.object(forKey: "useAIReviewInsights") != nil {
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
