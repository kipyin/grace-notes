import Foundation

private let placeholderApiKey = "YOUR_KEY_HERE"

/// Provides the current summarizer based on user settings.
/// For testing, pass a fixed summarizer; otherwise reads UserDefaults.
struct SummarizerProvider: Sendable {
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
        let useCloud = AIFeaturesSettings.isEnabled()
        if useCloud, ApiSecrets.cloudApiKey != placeholderApiKey {
            return CloudSummarizer(apiKey: ApiSecrets.cloudApiKey)
        }
        return DeterministicChipLabelSummarizer()
    }

    nonisolated(unsafe) static let shared = SummarizerProvider()
}
