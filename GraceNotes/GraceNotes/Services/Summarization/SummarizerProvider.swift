import Foundation

/// Provides the current summarizer.
/// For testing, pass a fixed summarizer; otherwise uses deterministic summaries.
struct SummarizerProvider: Sendable {
    /// Legacy key kept for continuity checks in migration paths.
    static let useCloudUserDefaultsKey = "useCloudSummarization"

    private let fixedSummarizer: (any Summarizer)?
    /// When set, overrides the cloud-heuristic branch for tests that verify truncation policies.
    private let effectiveUsesCloudForChipsOverride: Bool?

    init(
        fixedSummarizer: (any Summarizer)? = nil,
        effectiveUsesCloudForChipsOverride: Bool? = nil
    ) {
        self.fixedSummarizer = fixedSummarizer
        self.effectiveUsesCloudForChipsOverride = effectiveUsesCloudForChipsOverride
    }

    /// Returns the summarizer to use.
    func currentSummarizer() -> any Summarizer {
        if let fixed = fixedSummarizer {
            return fixed
        }
        return DeterministicChipLabelSummarizer()
    }

    /// Cloud summarization is no longer available, so this only honors test overrides.
    func effectiveUsesCloudForChips() -> Bool {
        if let override = effectiveUsesCloudForChipsOverride {
            return override
        }
        return false
    }

    nonisolated(unsafe) static let shared = SummarizerProvider()
}
