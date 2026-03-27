import Foundation

enum JournalTutorialStorageKeys {
    static let dismissedSeedGuidance = "journalTutorial.dismissedSeedGuidance"
    static let dismissedHarvestGuidance = "journalTutorial.dismissedHarvestGuidance"
    /// First time each chip section had at least one item (1/1/1). Key name retained for installs.
    static let celebratedFirstSeed = "journalTutorial.celebratedFirstSeed"
    /// First time all three sections reached three or more chips (Balanced status).
    static let celebratedFirstBalanced = "journalTutorial.celebratedFirstBalanced"
    /// First time all fifteen chip slots were filled (Full). Key name retained for installs.
    static let celebratedFirstHarvest = "journalTutorial.celebratedFirstHarvest"
}

/// Per-install tutorial flags (UserDefaults). Not CloudKit-synced.
final class JournalTutorialProgress {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasDismissedSeedGuidance: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.dismissedSeedGuidance) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.dismissedSeedGuidance) }
    }

    var hasDismissedHarvestGuidance: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.dismissedHarvestGuidance) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.dismissedHarvestGuidance) }
    }

    /// First celebration of having at least one chip in Gratitudes, Needs, and People in Mind.
    var hasCelebratedFirstTripleOne: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.celebratedFirstSeed) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.celebratedFirstSeed) }
    }

    var hasCelebratedFirstBalanced: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.celebratedFirstBalanced) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.celebratedFirstBalanced) }
    }

    /// First celebration of filling all fifteen chip slots (Full).
    var hasCelebratedFirstFull: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.celebratedFirstHarvest) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.celebratedFirstHarvest) }
    }

    func applyRecording(from outcome: JournalTutorialUnlockEvaluator.MilestoneOutcome) {
        if outcome.recordFirstTripleOneCelebrated {
            hasCelebratedFirstTripleOne = true
        }
        if outcome.recordFirstBalancedCelebrated {
            hasCelebratedFirstBalanced = true
        }
        if outcome.recordFirstFullCelebrated {
            hasCelebratedFirstFull = true
        }
    }

    static func resetAll(in defaults: UserDefaults = .standard) {
        let keys = [
            JournalTutorialStorageKeys.dismissedSeedGuidance,
            JournalTutorialStorageKeys.dismissedHarvestGuidance,
            JournalTutorialStorageKeys.celebratedFirstSeed,
            JournalTutorialStorageKeys.celebratedFirstBalanced,
            JournalTutorialStorageKeys.celebratedFirstHarvest
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }
}
