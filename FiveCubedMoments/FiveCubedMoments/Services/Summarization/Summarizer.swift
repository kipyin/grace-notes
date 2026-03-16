import Foundation

struct SummarizationResult {
    let label: String
    let isTruncated: Bool
}

enum SummarizationSection {
    case gratitude
    case need
    case person
}

protocol Summarizer {
    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult
}
