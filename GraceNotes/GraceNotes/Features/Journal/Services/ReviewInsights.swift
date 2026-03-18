import Foundation

enum ReviewInsightSource: String, Sendable {
    case deterministic
    case cloudAI
}

enum ReviewWeeklyInsightPattern: String, Sendable {
    case recurringPeople
    case recurringTheme
    case needsGratitudeGap
    case fullCompletion
    case continuityShift
    case sparseFallback
}

struct ReviewWeeklyInsight: Equatable, Sendable {
    let pattern: ReviewWeeklyInsightPattern
    let observation: String
    let action: String?
    let primaryTheme: String?
    let mentionCount: Int?
    let dayCount: Int?
}

struct ReviewInsightTheme: Equatable, Sendable {
    let label: String
    let count: Int
}

struct ReviewInsights: Equatable, Sendable {
    let source: ReviewInsightSource
    let generatedAt: Date
    let weekStart: Date
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
