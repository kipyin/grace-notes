import Foundation

private let placeholderApiKey = "YOUR_KEY_HERE"

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

    /// Returns the summarizer to use. Uses cloud when enabled and a valid API key is configured; otherwise NL.
    func currentSummarizer() -> any Summarizer {
        if let fixed = fixedSummarizer {
            return fixed
        }
        let useCloud = UserDefaults.standard.object(forKey: Self.useCloudKey) as? Bool ?? false
        if useCloud, ApiSecrets.cloudApiKey != placeholderApiKey {
            return CloudSummarizer(apiKey: ApiSecrets.cloudApiKey)
        }
        return NaturalLanguageSummarizer()
    }

    nonisolated(unsafe) static let shared = SummarizerProvider()
}
