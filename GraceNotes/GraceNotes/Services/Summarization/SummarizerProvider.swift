import Foundation

/// Provides the current summarizer based on user settings.
/// For testing, pass a fixed summarizer; otherwise reads UserDefaults.
struct SummarizerProvider: Sendable {
    /// UserDefaults key for cloud summarization setting. Exposed for tests to avoid key drift.
    static let useCloudUserDefaultsKey = AIFeaturesSettings.enabledUserDefaultsKey

    private static let useCloudKey = useCloudUserDefaultsKey
    private let fixedSummarizer: (any Summarizer)?
    /// When set, forces `effectiveUsesCloudForChips()` for unit tests that inject a fixed summarizer (spy).
    private let effectiveUsesCloudForChipsOverride: Bool?

    init(
        fixedSummarizer: (any Summarizer)? = nil,
        effectiveUsesCloudForChipsOverride: Bool? = nil
    ) {
        self.fixedSummarizer = fixedSummarizer
        self.effectiveUsesCloudForChipsOverride = effectiveUsesCloudForChipsOverride
    }

    /// Returns the summarizer to use.
    /// Uses cloud when enabled and a valid API key is configured; otherwise deterministic fallback labels.
    func currentSummarizer() -> any Summarizer {
        if let fixed = fixedSummarizer {
            return fixed
        }
        let useCloud = AIFeaturesSettings.isEnabled()
        if useCloud, ApiSecrets.isCloudApiKeyConfigured {
            return CloudSummarizer(apiKey: ApiSecrets.cloudApiKey)
        }
        return DeterministicChipLabelSummarizer()
    }

    /// Matches whether chip truncation should follow the cloud summarizer path (toggle + configured key),
    /// not live connectivity. When a fixed summarizer is injected (tests), returns false so truncation
    /// stays on-device unless `effectiveUsesCloudForChipsOverride` is set.
    func effectiveUsesCloudForChips(userDefaults: UserDefaults = .standard) -> Bool {
        if let override = effectiveUsesCloudForChipsOverride {
            return override
        }
        if fixedSummarizer != nil {
            return false
        }
        let useCloud = AIFeaturesSettings.isEnabled(using: userDefaults)
        return useCloud && ApiSecrets.isCloudApiKeyConfigured
    }

    nonisolated(unsafe) static let shared = SummarizerProvider()
}
