import Foundation

enum ReviewInsightSource: String, Sendable, Codable {
    case deterministic
    case cloudAI
}

enum ReviewWeeklyInsightPattern: String, Sendable, Codable {
    case recurringPeople
    case recurringTheme
    case needsGratitudeGap
    case fullCompletion
    case continuityShift
    case sparseFallback
}

struct ReviewWeeklyInsight: Equatable, Hashable, Sendable, Codable {
    let pattern: ReviewWeeklyInsightPattern
    let observation: String
    let action: String?
    let primaryTheme: String?
    let mentionCount: Int?
    let dayCount: Int?
}

struct ReviewInsightTheme: Equatable, Hashable, Sendable, Codable {
    let label: String
    let count: Int
}

struct ReviewInsights: Equatable, Sendable, Codable {
    let source: ReviewInsightSource
    let generatedAt: Date
    /// Start of the review period (`ReviewInsightsPeriod`), inclusive (start of local day).
    let weekStart: Date
    /// End of the review period, exclusive (start of the day after the reference day).
    let weekEnd: Date
    let weeklyInsights: [ReviewWeeklyInsight]
    let recurringGratitudes: [ReviewInsightTheme]
    let recurringNeeds: [ReviewInsightTheme]
    let recurringPeople: [ReviewInsightTheme]
    let resurfacingMessage: String
    let continuityPrompt: String
    let narrativeSummary: String?
}

protocol ReviewInsightsGenerating: Sendable {
    func generateInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar
    ) async throws -> ReviewInsights
}
