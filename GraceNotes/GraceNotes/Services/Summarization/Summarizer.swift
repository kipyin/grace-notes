import Foundation

struct SummarizationResult: Sendable {
    let label: String
    let isTruncated: Bool
}

enum SummarizationSection: Sendable {
    case gratitude
    case need
    case person
}

protocol Summarizer: Sendable {
    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult
}
