import Foundation

enum JournalOnboardingSuggestion: CaseIterable {
    case reminders
    case iCloudSync
}

enum JournalOnboardingStorageKeys {
    static let completedGuidedJournal = "journalOnboarding.completedGuidedJournal"
    /// Legacy upgrade cohort: Today clears this after one branch resolution. Listed for iCloud continuity.
    static let legacy051GuidedBranchResolution = "journalOnboarding.pending051GuidedJournalBranchResolution"
    static let hasSeenAppTour = "journalOnboarding.hasSeenAppTour"
    /// Legacy key; value is copied once into ``hasSeenAppTour`` by ``migrateLegacyAppTourSeenFlagIfNeeded``, then removed.
    static let legacyHasSeenPostSeedJourney = "journalOnboarding.hasSeenPostSeedJourney"
    static let dismissedRemindersSuggestion = "journalOnboarding.dismissedRemindersSuggestion"
    static let dismissedICloudSuggestion = "journalOnboarding.dismissedICloudSuggestion"
    static let openedRemindersSuggestion = "journalOnboarding.openedRemindersSuggestion"
    static let openedICloudSuggestion = "journalOnboarding.openedICloudSuggestion"
}

private enum LegacyJournalOnboardingStorageKeys {
    static let pending051UpgradeOrientation = "journalOnboarding.pending051UpgradeOrientation"
}

/// Per-install onboarding flags for the behavior-first journal path and optional feature suggestions.
final class JournalOnboardingProgress {
    private let defaults: UserDefaults

    private static let tutorialPresenceKeys = [
        JournalTutorialStorageKeys.dismissedSproutGuidance,
        JournalTutorialStorageKeys.dismissedBloomGuidance,
        JournalTutorialStorageKeys.celebratedFirstSprout,
        JournalTutorialStorageKeys.celebratedFirstLeaf,
        JournalTutorialStorageKeys.celebratedFirstBloom
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedGuidedJournal: Bool {
        get { Self.resolvedHasCompletedGuidedJournal(using: defaults) }
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
        if let storedValue = optionalBool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal, in: defaults) {
            return storedValue
        }

        let migratedValue = shouldTreatInstallAsPreviouslyOnboarded(using: defaults)
        defaults.set(migratedValue, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        return migratedValue
    }

    /// Finishing the App Tour from Today or Settings: journey seen, guided journal complete, and milestone
    /// Settings cards (Reminders / iCloud) dismissed so they do not duplicate Tour content.
    static func applyAppTourCompletion(using defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: JournalOnboardingStorageKeys.hasSeenAppTour)
        defaults.set(true, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        defaults.set(true, forKey: JournalOnboardingStorageKeys.dismissedRemindersSuggestion)
        defaults.set(true, forKey: JournalOnboardingStorageKeys.dismissedICloudSuggestion)
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
           optionalBool(forKey: JournalOnboardingStorageKeys.completedGuidedJournal, in: defaults) == nil {
            defaults.set(false, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        }

        defaults.removeObject(forKey: upgradeKey)
    }

    /// Copies ``legacyHasSeenPostSeedJourney`` into ``hasSeenAppTour`` once so existing installs keep tour state,
    /// then removes the legacy entry (same shape as ``JournalTutorialStorageKeys`` boolean migrations).
    static func migrateLegacyAppTourSeenFlagIfNeeded(using defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: JournalOnboardingStorageKeys.hasSeenAppTour) == nil else { return }
        guard defaults.object(forKey: JournalOnboardingStorageKeys.legacyHasSeenPostSeedJourney) != nil else {
            return
        }
        defaults.set(
            defaults.bool(forKey: JournalOnboardingStorageKeys.legacyHasSeenPostSeedJourney),
            forKey: JournalOnboardingStorageKeys.hasSeenAppTour
        )
        defaults.removeObject(forKey: JournalOnboardingStorageKeys.legacyHasSeenPostSeedJourney)
    }

    /// After Today’s entry loads, finalize legacy upgrade cohort branch for `completedGuidedJournal`.
    static func resolvePending051GuidedJournalBranch(
        todayCompletionLevel: JournalCompletionLevel,
        using defaults: UserDefaults = .standard
    ) {
        guard defaults.bool(forKey: JournalOnboardingStorageKeys.legacy051GuidedBranchResolution) else {
            return
        }

        let startedRank = JournalCompletionLevel.sprout.tutorialCompletionRank
        if todayCompletionLevel.tutorialCompletionRank >= startedRank {
            defaults.set(true, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        }

        defaults.removeObject(forKey: JournalOnboardingStorageKeys.legacy051GuidedBranchResolution)
    }

    /// Clears journal onboarding keys and tutorial milestone keys, then pins ``completedGuidedJournal`` to `false`
    /// so ``resolvedHasCompletedGuidedJournal`` does not immediately re-derive `true` from first-run, reminders, or
    /// other heuristics in ``shouldTreatInstallAsPreviouslyOnboarded``.
    /// (Removing the key alone would let migration run again on the next read.)
    static func resetAll(in defaults: UserDefaults = .standard) {
        JournalTutorialStorageKeys.removeAllStoredKeys(in: defaults)

        let keys = [
            JournalOnboardingStorageKeys.completedGuidedJournal,
            LegacyJournalOnboardingStorageKeys.pending051UpgradeOrientation,
            JournalOnboardingStorageKeys.legacy051GuidedBranchResolution,
            JournalOnboardingStorageKeys.hasSeenAppTour,
            JournalOnboardingStorageKeys.legacyHasSeenPostSeedJourney,
            JournalOnboardingStorageKeys.dismissedRemindersSuggestion,
            JournalOnboardingStorageKeys.dismissedICloudSuggestion,
            JournalOnboardingStorageKeys.openedRemindersSuggestion,
            JournalOnboardingStorageKeys.openedICloudSuggestion
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        defaults.set(false, forKey: JournalOnboardingStorageKeys.completedGuidedJournal)
        AppLaunchVersionTracker.resetLaunchTracking(in: defaults)
    }

    /// Interprets stored booleans whether `UserDefaults` returns `Bool` or `NSNumber` (plist / sync).
    private static func optionalBool(forKey key: String, in defaults: UserDefaults) -> Bool? {
        guard let object = defaults.object(forKey: key) else { return nil }
        switch object {
        case let value as Bool:
            return value
        case let number as NSNumber:
            return number.boolValue
        default:
            return nil
        }
    }

    private static func shouldTreatInstallAsPreviouslyOnboarded(using defaults: UserDefaults) -> Bool {
        if optionalBool(forKey: FirstRunOnboardingStorageKeys.completed, in: defaults) == true {
            return true
        }

        if defaults.object(forKey: ReminderSettings.timeIntervalKey) != nil {
            return true
        }

        if defaults.object(forKey: ReviewInsightsProvider.legacyAIFeaturesUserDefaultsKey) != nil {
            return true
        }

        return tutorialPresenceKeys.contains { defaults.object(forKey: $0) != nil }
    }

    private func dismissedKey(for suggestion: JournalOnboardingSuggestion) -> String {
        switch suggestion {
        case .reminders:
            return JournalOnboardingStorageKeys.dismissedRemindersSuggestion
        case .iCloudSync:
            return JournalOnboardingStorageKeys.dismissedICloudSuggestion
        }
    }

    private func openedKey(for suggestion: JournalOnboardingSuggestion) -> String {
        switch suggestion {
        case .reminders:
            return JournalOnboardingStorageKeys.openedRemindersSuggestion
        case .iCloudSync:
            return JournalOnboardingStorageKeys.openedICloudSuggestion
        }
    }
}
