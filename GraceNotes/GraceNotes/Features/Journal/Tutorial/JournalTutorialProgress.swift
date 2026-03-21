import Foundation

enum JournalTutorialStorageKeys {
    static let dismissedSeedGuidance = "journalTutorial.dismissedSeedGuidance"
    static let dismissedHarvestGuidance = "journalTutorial.dismissedHarvestGuidance"
    static let celebratedFirstSeed = "journalTutorial.celebratedFirstSeed"
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

    var hasCelebratedFirstSeed: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.celebratedFirstSeed) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.celebratedFirstSeed) }
    }

    var hasCelebratedFirstHarvest: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.celebratedFirstHarvest) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.celebratedFirstHarvest) }
    }

    func applyRecording(from outcome: JournalTutorialUnlockEvaluator.Outcome) {
        if outcome.recordFirstSeedCelebrated {
            hasCelebratedFirstSeed = true
        }
        if outcome.recordFirstHarvestCelebrated {
            hasCelebratedFirstHarvest = true
        }
    }

    static func resetAll(in defaults: UserDefaults = .standard) {
        let keys = [
            JournalTutorialStorageKeys.dismissedSeedGuidance,
            JournalTutorialStorageKeys.dismissedHarvestGuidance,
            JournalTutorialStorageKeys.celebratedFirstSeed,
            JournalTutorialStorageKeys.celebratedFirstHarvest
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }
}
