import Foundation

enum ReviewInsightSource: String, Sendable, Codable {
    case deterministic
    case cloudAI
}

enum ReviewPresentationMode: String, Equatable, Sendable, Codable {
    case statsFirst
    case insight
}

enum ReviewStatsSectionKind: String, CaseIterable, Equatable, Sendable, Codable {
    case gratitudes
    case needs
    case people
}

struct ReviewDayActivity: Equatable, Hashable, Sendable, Codable {
    let date: Date
    let hasReflectiveActivity: Bool
    let strongestCompletionLevel: JournalCompletionLevel?

    private enum CodingKeys: String, CodingKey {
        case date
        case hasReflectiveActivity = "hasMeaningfulContent"
        case strongestCompletionLevel
    }

    init(
        date: Date,
        hasReflectiveActivity: Bool,
        strongestCompletionLevel: JournalCompletionLevel? = nil
    ) {
        self.date = date
        self.hasReflectiveActivity = hasReflectiveActivity
        self.strongestCompletionLevel = strongestCompletionLevel
    }
}

struct ReviewWeekCompletionMix: Equatable, Sendable, Codable {
    let emptyDays: Int
    let startedDays: Int
    let growingDays: Int
    let balancedDays: Int
    let fullDays: Int

    var highCompletionDays: Int {
        balancedDays + fullDays
    }

    init(emptyDays: Int, startedDays: Int, growingDays: Int, balancedDays: Int, fullDays: Int) {
        self.emptyDays = emptyDays
        self.startedDays = startedDays
        self.growingDays = growingDays
        self.balancedDays = balancedDays
        self.fullDays = fullDays
    }

    private enum CodingKeys: String, CodingKey {
        case emptyDays, startedDays, growingDays, balancedDays, fullDays
        case soilDays, seedDays, ripeningDays, harvestDays, abundanceDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.emptyDays) {
            emptyDays = try container.decode(Int.self, forKey: .emptyDays)
            startedDays = try container.decode(Int.self, forKey: .startedDays)
            growingDays = try container.decode(Int.self, forKey: .growingDays)
            balancedDays = try container.decode(Int.self, forKey: .balancedDays)
            fullDays = try container.decode(Int.self, forKey: .fullDays)
        } else {
            let soil = try container.decode(Int.self, forKey: .soilDays)
            let seed = try container.decode(Int.self, forKey: .seedDays)
            let ripening = try container.decode(Int.self, forKey: .ripeningDays)
            let harvest = try container.decode(Int.self, forKey: .harvestDays)
            let abundance = try container.decode(Int.self, forKey: .abundanceDays)
            emptyDays = soil
            startedDays = seed
            growingDays = 0
            balancedDays = ripening
            fullDays = harvest + abundance
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(emptyDays, forKey: .emptyDays)
        try container.encode(startedDays, forKey: .startedDays)
        try container.encode(growingDays, forKey: .growingDays)
        try container.encode(balancedDays, forKey: .balancedDays)
        try container.encode(fullDays, forKey: .fullDays)
    }
}

struct ReviewWeekSectionTotals: Equatable, Sendable, Codable {
    let gratitudeMentions: Int
    let needMentions: Int
    let peopleMentions: Int

    var dominantSection: ReviewStatsSectionKind? {
        let ranked = [
            (ReviewStatsSectionKind.gratitudes, gratitudeMentions),
            (ReviewStatsSectionKind.needs, needMentions),
            (ReviewStatsSectionKind.people, peopleMentions)
        ].sorted { lhs, rhs in
            if lhs.1 != rhs.1 {
                return lhs.1 > rhs.1
            }
            return lhs.0.rawValue < rhs.0.rawValue
        }
        guard let first = ranked.first, first.1 > 0 else {
            return nil
        }
        if ranked.count > 1, ranked[1].1 == first.1 {
            return nil
        }
        return first.0
    }
}

struct ReviewWeekStats: Equatable, Sendable, Codable {
    let reflectionDays: Int
    let meaningfulEntryCount: Int
    let completionMix: ReviewWeekCompletionMix
    let activity: [ReviewDayActivity]
    let sectionTotals: ReviewWeekSectionTotals
}

/// Set when the user enabled Cloud AI but this digest still used the on-device path (see issue #83).
enum ReviewCloudInsightSkipReason: String, Equatable, Sendable, Codable {
    /// Fewer than the minimum meaningful reflections for cloud generation this review week.
    case insufficientEvidenceThisWeek
    /// Enough entries existed for cloud, but the week still lacked a clear recurring pattern worth narrative insight.
    case insufficientPatternSignalThisWeek
    /// No cloud generator (for example, missing API key in this build).
    case cloudMisconfigured
    /// Device offline, DNS failure, or connection lost before a response.
    case cloudNetworkUnavailable
    /// Request timed out (client or HTTP 408).
    case cloudRequestTimedOut
    /// HTTP 401 / 403 / 429 or equivalent access or rate limiting.
    case cloudServiceAuthOrQuota
    /// HTTP 5xx or service temporarily unavailable.
    case cloudServiceTemporarilyUnavailable
    /// Unreadable HTTP response, empty model content, or JSON that could not be parsed.
    case cloudResponseNotUsable
    /// Model output failed the grounded-quality gate after sanitization.
    case cloudInsightQualityCheckFailed
    /// Unknown error or legacy cached value.
    case cloudGenerationFailed
}

extension ReviewCloudInsightSkipReason {
    // Long user-facing sentences; keys match `Localizable.xcstrings`.
    // swiftlint:disable line_length
    /// Short explanation for the review-source info affordance.
    var localizedExplanation: String {
        switch self {
        case .insufficientEvidenceThisWeek:
            String(
                localized: "Cloud insights need at least three meaningful reflections in this review week. With lighter weeks, Grace Notes keeps this digest on your device."
            )
        case .insufficientPatternSignalThisWeek:
            String(
                localized: "This week had enough to summarize, but not enough repetition for a clear cloud insight. Grace Notes kept this review on your device."
            )
        case .cloudMisconfigured:
            String(
                localized: "Cloud AI isn't available in this build (for example, no API key). This digest stayed on your device."
            )
        case .cloudNetworkUnavailable:
            String(
                localized: "Grace Notes couldn't reach Cloud AI. Check your connection and try again when you're online."
            )
        case .cloudRequestTimedOut:
            String(
                localized: "The Cloud AI request timed out. Grace Notes used your on-device summary; try again in a moment."
            )
        case .cloudServiceAuthOrQuota:
            String(
                localized: "Cloud AI couldn't complete this request (access or rate limiting). Check your Cloud AI setup in Settings, or try again later."
            )
        case .cloudServiceTemporarilyUnavailable:
            String(
                localized: "Cloud AI is temporarily unavailable. Grace Notes used your on-device summary for now; try again later."
            )
        case .cloudResponseNotUsable:
            String(
                localized: "Cloud AI sent a response Grace Notes couldn't turn into a weekly digest. Your on-device summary is shown instead."
            )
        case .cloudInsightQualityCheckFailed:
            String(
                localized: "To keep this digest close to what you wrote, Grace Notes skipped Cloud AI's draft and showed your on-device summary instead."
            )
        case .cloudGenerationFailed:
            String(
                localized: "Something went wrong with Cloud AI. Grace Notes used your on-device summary instead."
            )
        }
    }

    // swiftlint:enable line_length
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
    let presentationMode: ReviewPresentationMode
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
    let weekStats: ReviewWeekStats
    /// Present when Cloud AI was enabled at generation time but the digest used the on-device path.
    let cloudSkippedReason: ReviewCloudInsightSkipReason?
}

extension ReviewInsights {
    func withPresentationMode(_ mode: ReviewPresentationMode) -> ReviewInsights {
        ReviewInsights(
            source: source,
            presentationMode: mode,
            generatedAt: generatedAt,
            weekStart: weekStart,
            weekEnd: weekEnd,
            weeklyInsights: weeklyInsights,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople,
            resurfacingMessage: resurfacingMessage,
            continuityPrompt: continuityPrompt,
            narrativeSummary: narrativeSummary,
            weekStats: weekStats,
            cloudSkippedReason: cloudSkippedReason
        )
    }

    func withCloudSkippedReason(_ reason: ReviewCloudInsightSkipReason?) -> ReviewInsights {
        ReviewInsights(
            source: source,
            presentationMode: presentationMode,
            generatedAt: generatedAt,
            weekStart: weekStart,
            weekEnd: weekEnd,
            weeklyInsights: weeklyInsights,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople,
            resurfacingMessage: resurfacingMessage,
            continuityPrompt: continuityPrompt,
            narrativeSummary: narrativeSummary,
            weekStats: weekStats,
            cloudSkippedReason: reason
        )
    }
}

protocol ReviewInsightsGenerating: Sendable {
    func generateInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar
    ) async throws -> ReviewInsights
}
