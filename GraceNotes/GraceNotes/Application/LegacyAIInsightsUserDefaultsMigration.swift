import Foundation

/// One-time migration: `useAIReviewInsights` was retired in favor of the single cloud-AI key
/// (`SummarizerProvider.useCloudUserDefaultsKey`). Runs at launch so users who never open Settings
/// keep cloud insights when they had the legacy toggle on.
enum LegacyAIInsightsUserDefaultsMigration {
    private static let legacyDefaultsKey = "useAIReviewInsights"

    static func migrateIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: legacyDefaultsKey) != nil else { return }

        let legacyEnabled = defaults.bool(forKey: legacyDefaultsKey)
        if legacyEnabled {
            let cloudKey = SummarizerProvider.useCloudUserDefaultsKey
            let currentCloud = defaults.object(forKey: cloudKey) as? Bool ?? false
            if !currentCloud {
                defaults.set(true, forKey: cloudKey)
            }
        }

        defaults.removeObject(forKey: legacyDefaultsKey)
    }
}
