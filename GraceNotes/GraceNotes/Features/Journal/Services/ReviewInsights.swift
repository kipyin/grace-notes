import Foundation

enum ReviewInsightSource: String, Sendable, Codable {
    case deterministic

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? ""

        switch rawValue {
        case Self.deterministic.rawValue, "cloudAI":
            self = .deterministic
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

    /// User-visible section name for journal surfaces (chips, reading notes, reflections).
    var localizedJournalSurfaceTitle: String {
        switch self {
        case .gratitudes:
            return String(localized: "journal.section.gratitudesTitle")
        case .needs:
            return String(localized: "journal.section.needsTitle")
        case .people:
            return String(localized: "journal.section.peopleTitle")
        case .readingNotes:
            return String(localized: "journal.section.readingNotesShort")
        case .reflections:
            return String(localized: "journal.section.reflectionsTitle")
        }
    }
}

enum ReviewThemeTrend: String, Equatable, Hashable, Sendable, Codable {
    case new
    case rising
    case down
    case stable
}

/// Backward-compatibility payload for previously cached evidence rows.
struct ReviewThemeEvidence: Equatable, Hashable, Sendable, Codable {
    let date: Date
    let sources: [ReviewThemeSourceCategory]
}

struct ReviewThemeSurfaceEvidence: Equatable, Hashable, Sendable, Codable, Identifiable {
    let entryDate: Date
    let source: ReviewThemeSourceCategory
    let content: String

    var id: String {
        "\(entryDate.timeIntervalSince1970)|\(source.rawValue)|\(content)"
    }
}

struct ReviewMostRecurringTheme: Equatable, Hashable, Sendable, Codable, Identifiable {
    let label: String
    let totalCount: Int
    let dayCount: Int
    let currentWeekCount: Int
    let previousWeekCount: Int
    let evidence: [ReviewThemeSurfaceEvidence]

    var id: String { label }

    private enum CodingKeys: String, CodingKey {
        case label
        case totalCount
        case dayCount
        case currentWeekCount
        case previousWeekCount
        case evidence
    }

    init(
        label: String,
        totalCount: Int,
        dayCount: Int,
        currentWeekCount: Int,
        previousWeekCount: Int,
        evidence: [ReviewThemeSurfaceEvidence]
    ) {
        self.label = label
        self.totalCount = totalCount
        self.dayCount = dayCount
        self.currentWeekCount = currentWeekCount
        self.previousWeekCount = previousWeekCount
        self.evidence = evidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        totalCount = try container.decode(Int.self, forKey: .totalCount)
        dayCount = try container.decode(Int.self, forKey: .dayCount)
        currentWeekCount = try container.decode(Int.self, forKey: .currentWeekCount)
        previousWeekCount = try container.decode(Int.self, forKey: .previousWeekCount)
        evidence = try Self.decodeEvidence(from: container)
    }

    /// When the `evidence` key is absent, decoding defaults to `[]`. When the key is present,
    /// `decodeIfPresent` throws on type mismatch, so we try structured `[ReviewThemeSurfaceEvidence]`
    /// then legacy `[ReviewThemeEvidence]` with `try? decode`; if both fail, decoding throws instead
    /// of silently producing empty evidence.
    private static func decodeEvidence(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [ReviewThemeSurfaceEvidence] {
        guard container.contains(.evidence) else {
            return []
        }
        if let structuredEvidence = try? container.decode([ReviewThemeSurfaceEvidence].self, forKey: .evidence) {
            return structuredEvidence
        }
        if let legacyEvidence = try? container.decode([ReviewThemeEvidence].self, forKey: .evidence) {
            return legacyEvidence.flatMap { row in
                var seenInRow = Set<ReviewThemeSourceCategory>()
                let uniqueSources = row.sources.filter { seenInRow.insert($0).inserted }
                return uniqueSources.map { source in
                    ReviewThemeSurfaceEvidence(entryDate: row.date, source: source, content: "")
                }
            }
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: container.codingPath + [CodingKeys.evidence],
                debugDescription: "Invalid evidence: expected [ReviewThemeSurfaceEvidence] "
                    + "or legacy [ReviewThemeEvidence]."
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encode(totalCount, forKey: .totalCount)
        try container.encode(dayCount, forKey: .dayCount)
        try container.encode(currentWeekCount, forKey: .currentWeekCount)
        try container.encode(previousWeekCount, forKey: .previousWeekCount)
        try container.encode(evidence, forKey: .evidence)
    }
}

struct ReviewMovementTheme: Equatable, Hashable, Sendable, Codable, Identifiable {
    let label: String
    let currentWeekCount: Int
    let previousWeekCount: Int
    let trend: ReviewThemeTrend
    let totalCount: Int
    let evidence: [ReviewThemeSurfaceEvidence]

    var id: String { label }

    /// Ordering for trending rows: largest week-over-week change first, then current count and label.
    static func trendingSort(lhs: ReviewMovementTheme, rhs: ReviewMovementTheme) -> Bool {
        let lhsDelta = abs(lhs.currentWeekCount - lhs.previousWeekCount)
        let rhsDelta = abs(rhs.currentWeekCount - rhs.previousWeekCount)
        if lhsDelta != rhsDelta {
            return lhsDelta > rhsDelta
        }
        if lhs.currentWeekCount != rhs.currentWeekCount {
            return lhs.currentWeekCount > rhs.currentWeekCount
        }
        if lhs.totalCount != rhs.totalCount {
            return lhs.totalCount > rhs.totalCount
        }
        return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
    }
}

/// Trending themes grouped for browse UI: new, rising, and down buckets.
struct ReviewTrendingBuckets: Equatable, Sendable, Codable {
    let newThemes: [ReviewMovementTheme]
    let upThemes: [ReviewMovementTheme]
    let downThemes: [ReviewMovementTheme]

    var flattened: [ReviewMovementTheme] {
        newThemes + upThemes + downThemes
    }

    init(newThemes: [ReviewMovementTheme], upThemes: [ReviewMovementTheme], downThemes: [ReviewMovementTheme]) {
        self.newThemes = newThemes
        self.upThemes = upThemes
        self.downThemes = downThemes
    }

    init(bucketing flat: [ReviewMovementTheme]) {
        newThemes = flat.filter { $0.trend == .new }.sorted(by: ReviewMovementTheme.trendingSort)
        upThemes = flat.filter { $0.trend == .rising }.sorted(by: ReviewMovementTheme.trendingSort)
        downThemes = flat.filter { $0.trend == .down }.sorted(by: ReviewMovementTheme.trendingSort)
    }

    private enum CodingKeys: String, CodingKey {
        case newThemes = "new"
        case upThemes = "up"
        case downThemes = "down"
    }
}

struct ReviewDayActivity: Equatable, Hashable, Sendable, Codable {
    let date: Date
    let hasReflectiveActivity: Bool
    let strongestCompletionLevel: JournalCompletionLevel?
    /// True when there is a `Journal` row for this calendar day (it may still be inactive for rhythm signal).
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
    let soilDayCount: Int
    let sproutDayCount: Int
    let twigDayCount: Int
    let leafDayCount: Int
    let bloomDayCount: Int

    var highCompletionDays: Int {
        leafDayCount + bloomDayCount
    }

    /// Sum of the five buckets: distinct calendar days with a persisted journal in the slice used to build this mix.
    var totalDaysRepresented: Int {
        soilDayCount + sproutDayCount + twigDayCount + leafDayCount + bloomDayCount
    }

    init(
        soilDayCount: Int,
        sproutDayCount: Int,
        twigDayCount: Int,
        leafDayCount: Int,
        bloomDayCount: Int
    ) {
        self.soilDayCount = soilDayCount
        self.sproutDayCount = sproutDayCount
        self.twigDayCount = twigDayCount
        self.leafDayCount = leafDayCount
        self.bloomDayCount = bloomDayCount
    }

    private enum CodingKeys: String, CodingKey {
        case soilDayCount, sproutDayCount, twigDayCount, leafDayCount, bloomDayCount
        case emptyDays, startedDays, growingDays, balancedDays, fullDays
        case soilDays, seedDays, ripeningDays, harvestDays, abundanceDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.soilDayCount) {
            soilDayCount = try container.decode(Int.self, forKey: .soilDayCount)
            sproutDayCount = try container.decode(Int.self, forKey: .sproutDayCount)
            twigDayCount = try container.decode(Int.self, forKey: .twigDayCount)
            leafDayCount = try container.decode(Int.self, forKey: .leafDayCount)
            bloomDayCount = try container.decode(Int.self, forKey: .bloomDayCount)
        } else if container.contains(.emptyDays) {
            soilDayCount = try container.decode(Int.self, forKey: .emptyDays)
            sproutDayCount = try container.decode(Int.self, forKey: .startedDays)
            twigDayCount = try container.decode(Int.self, forKey: .growingDays)
            leafDayCount = try container.decode(Int.self, forKey: .balancedDays)
            bloomDayCount = try container.decode(Int.self, forKey: .fullDays)
        } else {
            let soil = try container.decode(Int.self, forKey: .soilDays)
            let seed = try container.decode(Int.self, forKey: .seedDays)
            let ripening = try container.decode(Int.self, forKey: .ripeningDays)
            let harvest = try container.decode(Int.self, forKey: .harvestDays)
            let abundance = try container.decode(Int.self, forKey: .abundanceDays)
            soilDayCount = soil
            sproutDayCount = seed
            twigDayCount = 0
            leafDayCount = ripening
            bloomDayCount = harvest + abundance
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(soilDayCount, forKey: .soilDayCount)
        try container.encode(sproutDayCount, forKey: .sproutDayCount)
        try container.encode(twigDayCount, forKey: .twigDayCount)
        try container.encode(leafDayCount, forKey: .leafDayCount)
        try container.encode(bloomDayCount, forKey: .bloomDayCount)
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
    /// Section totals for all builder input entries (distinct from week-scoped ``sectionTotals``).
    let historySectionTotals: ReviewWeekSectionTotals
    /// Strongest completion level per calendar day across that same slice; bucket counts sum to entry-days represented.
    let historyCompletionMix: ReviewWeekCompletionMix
    let mostRecurringThemes: [ReviewMostRecurringTheme]
    /// Surfacing movement rows only (excludes stable trends), matching ``trendingBuckets``.
    let movementThemes: [ReviewMovementTheme]
    /// Grouped trending rows (new / rising / down).
    /// ``movementThemes`` is always ``trendingBuckets.flattened`` (same order as grouped UI).
    let trendingBuckets: ReviewTrendingBuckets

    init(
        reflectionDays: Int,
        meaningfulEntryCount: Int,
        completionMix: ReviewWeekCompletionMix,
        activity: [ReviewDayActivity],
        rhythmHistory: [ReviewDayActivity]?,
        sectionTotals: ReviewWeekSectionTotals,
        historySectionTotals: ReviewWeekSectionTotals = ReviewWeekSectionTotals(
            gratitudeMentions: 0,
            needMentions: 0,
            peopleMentions: 0
        ),
        historyCompletionMix: ReviewWeekCompletionMix = ReviewWeekCompletionMix(
            soilDayCount: 0,
            sproutDayCount: 0,
            twigDayCount: 0,
            leafDayCount: 0,
            bloomDayCount: 0
        ),
        mostRecurringThemes: [ReviewMostRecurringTheme] = [],
        movementThemes: [ReviewMovementTheme] = [],
        trendingBuckets: ReviewTrendingBuckets? = nil
    ) {
        self.reflectionDays = reflectionDays
        self.meaningfulEntryCount = meaningfulEntryCount
        self.completionMix = completionMix
        self.activity = activity
        self.rhythmHistory = rhythmHistory
        self.sectionTotals = sectionTotals
        self.historySectionTotals = historySectionTotals
        self.historyCompletionMix = historyCompletionMix
        self.mostRecurringThemes = mostRecurringThemes
        if let buckets = trendingBuckets {
            self.trendingBuckets = buckets
            self.movementThemes = buckets.flattened
        } else {
            let buckets = ReviewTrendingBuckets(bucketing: movementThemes)
            self.trendingBuckets = buckets
            self.movementThemes = buckets.flattened
        }
    }

    private enum CodingKeys: String, CodingKey {
        case reflectionDays
        case meaningfulEntryCount
        case completionMix
        case activity
        case rhythmHistory
        case sectionTotals
        case historySectionTotals
        case historyCompletionMix
        case mostRecurringThemes
        case movementThemes
        case trendingBuckets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reflectionDays = try container.decode(Int.self, forKey: .reflectionDays)
        meaningfulEntryCount = try container.decode(Int.self, forKey: .meaningfulEntryCount)
        completionMix = try container.decode(ReviewWeekCompletionMix.self, forKey: .completionMix)
        activity = try container.decode([ReviewDayActivity].self, forKey: .activity)
        rhythmHistory = try container.decodeIfPresent([ReviewDayActivity].self, forKey: .rhythmHistory)
        sectionTotals = try container.decode(ReviewWeekSectionTotals.self, forKey: .sectionTotals)
        if let decoded = try container.decodeIfPresent(ReviewWeekSectionTotals.self, forKey: .historySectionTotals) {
            historySectionTotals = decoded
        } else {
            historySectionTotals = ReviewWeekSectionTotals(gratitudeMentions: 0, needMentions: 0, peopleMentions: 0)
        }
        if let decoded = try container.decodeIfPresent(ReviewWeekCompletionMix.self, forKey: .historyCompletionMix) {
            historyCompletionMix = decoded
        } else {
            historyCompletionMix = ReviewWeekCompletionMix(
                soilDayCount: 0,
                sproutDayCount: 0,
                twigDayCount: 0,
                leafDayCount: 0,
                bloomDayCount: 0
            )
        }
        mostRecurringThemes =
            try container.decodeIfPresent([ReviewMostRecurringTheme].self, forKey: .mostRecurringThemes) ?? []
        let decodedMovement =
            try container.decodeIfPresent([ReviewMovementTheme].self, forKey: .movementThemes) ?? []
        if let buckets = try container.decodeIfPresent(ReviewTrendingBuckets.self, forKey: .trendingBuckets) {
            trendingBuckets = buckets
            movementThemes = buckets.flattened
        } else {
            let buckets = ReviewTrendingBuckets(bucketing: decodedMovement)
            trendingBuckets = buckets
            movementThemes = buckets.flattened
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(reflectionDays, forKey: .reflectionDays)
        try container.encode(meaningfulEntryCount, forKey: .meaningfulEntryCount)
        try container.encode(completionMix, forKey: .completionMix)
        try container.encode(activity, forKey: .activity)
        try container.encodeIfPresent(rhythmHistory, forKey: .rhythmHistory)
        try container.encode(sectionTotals, forKey: .sectionTotals)
        try container.encode(historySectionTotals, forKey: .historySectionTotals)
        try container.encode(historyCompletionMix, forKey: .historyCompletionMix)
        try container.encode(mostRecurringThemes, forKey: .mostRecurringThemes)
        try container.encode(movementThemes, forKey: .movementThemes)
        try container.encode(trendingBuckets, forKey: .trendingBuckets)
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
    /// End of the review period, exclusive (start of the day after the last day of the calendar week).
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
        from entries: [Journal],
        referenceDate: Date,
        calendar: Calendar,
        pastStatisticsInterval: PastStatisticsIntervalSelection
    ) async throws -> ReviewInsights
}
