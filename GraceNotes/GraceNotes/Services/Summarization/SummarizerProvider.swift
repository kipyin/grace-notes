import Foundation

/// Provides the current summarizer based on user settings.
/// For testing, pass a fixed summarizer; otherwise reads UserDefaults.
struct SummarizerProvider: Sendable {
    /// UserDefaults key for cloud summarization setting. Exposed for tests to avoid key drift.
    static let useCloudUserDefaultsKey = "useCloudSummarization"

    private static let useCloudKey = useCloudUserDefaultsKey
    private let fixedSummarizer: (any Summarizer)?

    init(fixedSummarizer: (any Summarizer)? = nil) {
        self.fixedSummarizer = fixedSummarizer
    }

    /// Returns the summarizer to use.
    /// Uses cloud when enabled and a valid API key is configured; otherwise deterministic fallback labels.
    func currentSummarizer() -> any Summarizer {
        if let fixed = fixedSummarizer {
            return fixed
        }
        let useCloud = UserDefaults.standard.object(forKey: Self.useCloudKey) as? Bool ?? false
        if useCloud, ApiSecrets.isCloudApiKeyConfigured {
            return CloudSummarizer(apiKey: ApiSecrets.cloudApiKey)
        }
        return DeterministicChipLabelSummarizer()
    }

    /// Matches whether chip truncation should follow the cloud summarizer path (toggle + configured key), not live connectivity.
    /// When a fixed summarizer is injected (tests), returns false so truncation stays on-device.
    func effectiveUsesCloudForChips(userDefaults: UserDefaults = .standard) -> Bool {
        if fixedSummarizer != nil {
            return false
        }
        let useCloud = userDefaults.object(forKey: Self.useCloudKey) as? Bool ?? false
        return useCloud && ApiSecrets.isCloudApiKeyConfigured
    }

    nonisolated(unsafe) static let shared = SummarizerProvider()
}
