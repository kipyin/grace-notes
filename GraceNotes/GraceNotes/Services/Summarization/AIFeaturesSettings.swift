import Foundation

enum AIFeaturesSettings {
    static let enabledUserDefaultsKey = "useAIReviewInsights"
    static let legacyCloudSummarizationKey = "useCloudSummarization"

    static func isEnabled(using defaults: UserDefaults = .standard) -> Bool {
        let aiFeaturesEnabled = defaults.object(forKey: enabledUserDefaultsKey) as? Bool ?? false
        let legacyCloudEnabled = defaults.object(forKey: legacyCloudSummarizationKey) as? Bool ?? false
        return aiFeaturesEnabled || legacyCloudEnabled
    }

    static func setEnabled(_ isEnabled: Bool, using defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: enabledUserDefaultsKey)
        defaults.removeObject(forKey: legacyCloudSummarizationKey)
    }

    static func migrateLegacyCloudFlagIfNeeded(using defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: enabledUserDefaultsKey) == nil else {
            defaults.removeObject(forKey: legacyCloudSummarizationKey)
            return
        }

        guard let legacyValue = defaults.object(forKey: legacyCloudSummarizationKey) as? Bool else {
            return
        }

        defaults.set(legacyValue, forKey: enabledUserDefaultsKey)
        defaults.removeObject(forKey: legacyCloudSummarizationKey)
    }
}
