import Foundation

struct SummarizationResult {
    let label: String
    let isTruncated: Bool
}

protocol Summarizer {
    func summarize(_ sentence: String) async throws -> SummarizationResult
}
