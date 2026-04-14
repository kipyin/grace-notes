import Foundation

/// UserDefaults keys for optional Today tutorial hints. Values migrate once from legacy Harvest/Seed spellings (#144).
enum JournalTutorialStorageKeys {
    static let dismissedSproutGuidance = "journalTutorial.dismissedSproutGuidance"
    static let dismissedBloomGuidance = "journalTutorial.dismissedBloomGuidance"
    /// First time each Section had at least one Entry (1/1/1).
    static let celebratedFirstSprout = "journalTutorial.celebratedFirstSprout"
    /// First time all three Sections reached Leaf (balanced grid).
    static let celebratedFirstLeaf = "journalTutorial.celebratedFirstLeaf"
    /// First time all fifteen Entries were filled (Bloom).
    static let celebratedFirstBloom = "journalTutorial.celebratedFirstBloom"

    private static let currentKeys: [String] = [
        dismissedSproutGuidance,
        dismissedBloomGuidance,
        celebratedFirstSprout,
        celebratedFirstLeaf,
        celebratedFirstBloom
    ]

    /// Copies legacy keys into the keys above, then removes legacy entries.
    /// Call early at launch before CloudKit continuity checks.
    static func migrateLegacyKeysIfNeeded(using defaults: UserDefaults = .standard) {
        migrateBool(from: Legacy.dismissedSeedGuidance, to: dismissedSproutGuidance, defaults: defaults)
        migrateBool(from: Legacy.dismissedHarvestGuidance, to: dismissedBloomGuidance, defaults: defaults)
        migrateBool(from: Legacy.celebratedFirstSeed, to: celebratedFirstSprout, defaults: defaults)
        migrateBool(from: Legacy.celebratedFirstBalanced, to: celebratedFirstLeaf, defaults: defaults)
        migrateBool(from: Legacy.celebratedFirstHarvest, to: celebratedFirstBloom, defaults: defaults)
    }

    /// Removes current and legacy tutorial keys (e.g. UI test reset, debug tooling).
    static func removeAllStoredKeys(in defaults: UserDefaults) {
        for key in currentKeys + Legacy.allKeyStrings {
            defaults.removeObject(forKey: key)
        }
    }

    private static func migrateBool(from legacyKey: String, to key: String, defaults: UserDefaults) {
        guard defaults.object(forKey: legacyKey) != nil else { return }
        if defaults.object(forKey: key) == nil {
            defaults.set(defaults.bool(forKey: legacyKey), forKey: key)
        }
        defaults.removeObject(forKey: legacyKey)
    }

    private enum Legacy {
        static let dismissedSeedGuidance = "journalTutorial.dismissedSeedGuidance"
        static let dismissedHarvestGuidance = "journalTutorial.dismissedHarvestGuidance"
        static let celebratedFirstSeed = "journalTutorial.celebratedFirstSeed"
        static let celebratedFirstBalanced = "journalTutorial.celebratedFirstBalanced"
        static let celebratedFirstHarvest = "journalTutorial.celebratedFirstHarvest"

        static let allKeyStrings: [String] = [
            dismissedSeedGuidance,
            dismissedHarvestGuidance,
            celebratedFirstSeed,
            celebratedFirstBalanced,
            celebratedFirstHarvest
        ]
    }
}

/// Per-install tutorial flags (UserDefaults). Not CloudKit-synced.
final class JournalTutorialProgress {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasDismissedSproutGuidance: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.dismissedSproutGuidance) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.dismissedSproutGuidance) }
    }

    var hasDismissedBloomGuidance: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.dismissedBloomGuidance) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.dismissedBloomGuidance) }
    }

    /// First celebration of 1/1/1 Entries across Gratitudes, Needs, and People in Mind.
    var hasCelebratedFirstTripleOne: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.celebratedFirstSprout) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.celebratedFirstSprout) }
    }

    var hasCelebratedFirstLeaf: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.celebratedFirstLeaf) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.celebratedFirstLeaf) }
    }

    /// First celebration of Bloom (all fifteen Entries).
    var hasCelebratedFirstBloom: Bool {
        get { defaults.bool(forKey: JournalTutorialStorageKeys.celebratedFirstBloom) }
        set { defaults.set(newValue, forKey: JournalTutorialStorageKeys.celebratedFirstBloom) }
    }

    func applyRecording(from outcome: JournalTutorialUnlockEvaluator.MilestoneOutcome) {
        if outcome.recordFirstTripleOneCelebrated {
            hasCelebratedFirstTripleOne = true
        }
        if outcome.recordFirstLeafCelebrated {
            hasCelebratedFirstLeaf = true
        }
        if outcome.recordFirstBloomCelebrated {
            hasCelebratedFirstBloom = true
        }
    }

    static func resetAll(in defaults: UserDefaults = .standard) {
        JournalTutorialStorageKeys.removeAllStoredKeys(in: defaults)
    }
}
