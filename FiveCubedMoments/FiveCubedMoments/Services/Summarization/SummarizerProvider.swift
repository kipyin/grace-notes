import Foundation

private let useCloudKey = "useCloudSummarization"

/// Provides the current summarizer based on user settings.
/// For testing, pass a fixed summarizer; otherwise reads UserDefaults.
struct SummarizerProvider {
    private let fixedSummarizer: (any Summarizer)?

    init(fixedSummarizer: (any Summarizer)? = nil) {
        self.fixedSummarizer = fixedSummarizer
    }

    /// Returns the summarizer to use. Cloud on by default when no fixed summarizer is provided.
    func currentSummarizer() -> any Summarizer {
        if let fixed = fixedSummarizer {
            return fixed
        }
        let useCloud = UserDefaults.standard.object(forKey: useCloudKey) as? Bool ?? true
        if useCloud {
            return CloudSummarizer(apiKey: ApiSecrets.cloudApiKey)
        }
        return NaturalLanguageSummarizer()
    }

    nonisolated(unsafe) static let shared = SummarizerProvider()
}
