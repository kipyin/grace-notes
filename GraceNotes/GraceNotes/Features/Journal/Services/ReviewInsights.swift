import Foundation

enum ReviewInsightSource: String, Sendable, Codable {
    case deterministic
    @available(*, deprecated, message: "Deprecated legacy source, treated as deterministic.")
    case cloudAI

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? ""

        switch rawValue {
        case Self.deterministic.rawValue:
            self = .deterministic
        case Self.cloudAI.rawValue:
            self = .cloudAI
        default:
            self = .deterministic
        }
    }
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

enum ReviewThemeSourceCategory: String, CaseIterable, Equatable, Hashable, Sendable, Codable {
    case gratitudes
    case needs
    case people
    case readingNotes
    case reflections
}

enum ReviewThemeTrend: String, Equatable, Hashable, Sendable, Codable {
    case new
    case rising
    case down
    case stable
}

struct ReviewThemeEvidence: Equatable, Hashable, Sendable, Codable {
    let date: Date
    let sources: [ReviewThemeSourceCategory]
}

struct ReviewMostRecurringTheme: Equatable, Hashable, Sendable, Codable, Identifiable {
    let label: String
    let totalCount: Int
    let dayCount: Int
    let currentWeekCount: Int
    let previousWeekCount: Int
    let trend: ReviewThemeTrend
    let evidence: [ReviewThemeEvidence]

    var id: String { label }
}

struct ReviewDayActivity: Equatable, Hashable, Sendable, Codable {
    let date: Date
    let hasReflectiveActivity: Bool
    let strongestCompletionLevel: JournalCompletionLevel?
    /// True when there is a `JournalEntry` row for this calendar day (it may still be inactive for rhythm signal).
    let hasPersistedEntry: Bool

    private enum CodingKeys: String, CodingKey {
        case date
        case hasReflectiveActivity = "hasMeaningfulContent"
        case strongestCompletionLevel
        case hasPersistedEntry
    }

    init(
        date: Date,
        hasReflectiveActivity: Bool,
        strongestCompletionLevel: JournalCompletionLevel? = nil,
        hasPersistedEntry: Bool
    ) {
        self.date = date
        self.hasReflectiveActivity = hasReflectiveActivity
        self.strongestCompletionLevel = strongestCompletionLevel
        self.hasPersistedEntry = hasPersistedEntry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        hasReflectiveActivity = try container.decode(Bool.self, forKey: .hasReflectiveActivity)
        strongestCompletionLevel = try container.decodeIfPresent(
            JournalCompletionLevel.self,
            forKey: .strongestCompletionLevel
        )
        if let persisted = try container.decodeIfPresent(Bool.self, forKey: .hasPersistedEntry) {
            hasPersistedEntry = persisted
        } else {
            hasPersistedEntry = strongestCompletionLevel != nil || hasReflectiveActivity
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(hasReflectiveActivity, forKey: .hasReflectiveActivity)
        try container.encodeIfPresent(strongestCompletionLevel, forKey: .strongestCompletionLevel)
        try container.encode(hasPersistedEntry, forKey: .hasPersistedEntry)
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
    /// Longer chronological slice for the scrollable rhythm curve; `nil` when absent from cached payloads.
    let rhythmHistory: [ReviewDayActivity]?
    let sectionTotals: ReviewWeekSectionTotals
    let mostRecurringThemes: [ReviewMostRecurringTheme]

    init(
        reflectionDays: Int,
        meaningfulEntryCount: Int,
        completionMix: ReviewWeekCompletionMix,
        activity: [ReviewDayActivity],
        rhythmHistory: [ReviewDayActivity]?,
        sectionTotals: ReviewWeekSectionTotals,
        mostRecurringThemes: [ReviewMostRecurringTheme] = []
    ) {
        self.reflectionDays = reflectionDays
        self.meaningfulEntryCount = meaningfulEntryCount
        self.completionMix = completionMix
        self.activity = activity
        self.rhythmHistory = rhythmHistory
        self.sectionTotals = sectionTotals
        self.mostRecurringThemes = mostRecurringThemes
    }

    private enum CodingKeys: String, CodingKey {
        case reflectionDays
        case meaningfulEntryCount
        case completionMix
        case activity
        case rhythmHistory
        case sectionTotals
        case mostRecurringThemes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reflectionDays = try container.decode(Int.self, forKey: .reflectionDays)
        meaningfulEntryCount = try container.decode(Int.self, forKey: .meaningfulEntryCount)
        completionMix = try container.decode(ReviewWeekCompletionMix.self, forKey: .completionMix)
        activity = try container.decode([ReviewDayActivity].self, forKey: .activity)
        rhythmHistory = try container.decodeIfPresent([ReviewDayActivity].self, forKey: .rhythmHistory)
        sectionTotals = try container.decode(ReviewWeekSectionTotals.self, forKey: .sectionTotals)
        mostRecurringThemes =
            try container.decodeIfPresent([ReviewMostRecurringTheme].self, forKey: .mostRecurringThemes) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(reflectionDays, forKey: .reflectionDays)
        try container.encode(meaningfulEntryCount, forKey: .meaningfulEntryCount)
        try container.encode(completionMix, forKey: .completionMix)
        try container.encode(activity, forKey: .activity)
        try container.encodeIfPresent(rhythmHistory, forKey: .rhythmHistory)
        try container.encode(sectionTotals, forKey: .sectionTotals)
        try container.encode(mostRecurringThemes, forKey: .mostRecurringThemes)
    }
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
            weekStats: weekStats
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
