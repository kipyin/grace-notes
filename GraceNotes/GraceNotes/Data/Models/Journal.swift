import Foundation
import SwiftData

/// Chip-section completion status (Gratitudes, Needs, People in Mind only). Reading notes and reflections are excluded.
/// Raw values match localized growth-stage naming (Soil → Bloom).
enum JournalCompletionLevel: String, Equatable, Hashable, Sendable {
    case soil
    case sprout
    case twig
    case leaf
    case bloom
}

extension JournalCompletionLevel: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self(decodingLegacyRawValue: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = try encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Maps persisted raw strings from older app versions and unknown values.
    init(decodingLegacyRawValue raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "soil", "empty":
            self = .soil
        case "sprout", "started", "seed":
            self = .sprout
        case "twig", "growing":
            self = .twig
        case "leaf", "balanced", "ripening":
            self = .leaf
        case "bloom", "full", "harvest", "abundance":
            self = .bloom
        default:
            self = .soil
        }
    }
}

/// Persisted name must stay ``JournalEntry`` so existing stores and CloudKit keep the same entity identity.
@Model
final class JournalEntry {
    // CloudKit: non-optional transformable arrays do not get a recognized default in
    // the Core Data stack; use optional (`nil` = empty) so the store can load.
    var id: UUID = UUID()
    var entryDate: Date = Date.now
    var gratitudes: [Entry]?
    var needs: [Entry]?
    var people: [Entry]?
    @Attribute(originalName: "bibleNotes") var readingNotes: String = ""
    var reflections: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        entryDate: Date = .now,
        gratitudes: [Entry] = [],
        needs: [Entry] = [],
        people: [Entry] = [],
        readingNotes: String = "",
        reflections: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.entryDate = entryDate // Callers must pass start-of-day
        self.gratitudes = gratitudes
        self.needs = needs
        self.people = people
        self.readingNotes = readingNotes
        self.reflections = reflections
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    /// All chip slots filled (5 gratitudes, 5 needs, 5 people). Notes and reflections do not change it.
    var hasReachedBloom: Bool {
        Self.entriesIndicateBloom(
            gratitudesCount: (gratitudes ?? []).count,
            needsCount: (needs ?? []).count,
            peopleCount: (people ?? []).count
        )
    }

    /// Same as ``hasReachedBloom``. Older call sites use this name for History and persistence.
    var isComplete: Bool { hasReachedBloom }

    var completionLevel: JournalCompletionLevel {
        Self.completionLevel(
            gratitudesCount: (gratitudes ?? []).count,
            needsCount: (needs ?? []).count,
            peopleCount: (people ?? []).count
        )
    }

    static func entriesIndicateBloom(
        gratitudesCount: Int,
        needsCount: Int,
        peopleCount: Int
    ) -> Bool {
        let counts = NonNegativeSectionCounts(
            gratitudesCount: gratitudesCount,
            needsCount: needsCount,
            peopleCount: peopleCount
        )
        return counts.minCount >= slotCount
    }

    /// Minimum count across the three chip sections (weakest section).
    static func minimumEntryCountAcrossSections(
        gratitudesCount: Int,
        needsCount: Int,
        peopleCount: Int
    ) -> Int {
        NonNegativeSectionCounts(
            gratitudesCount: gratitudesCount,
            needsCount: needsCount,
            peopleCount: peopleCount
        ).minCount
    }

    /// Chip-only status: Gratitudes, Needs, and People in Mind counts. Notes and reflections are ignored.
    static func completionLevel(
        gratitudesCount: Int,
        needsCount: Int,
        peopleCount: Int
    ) -> JournalCompletionLevel {
        let counts = NonNegativeSectionCounts(
            gratitudesCount: gratitudesCount,
            needsCount: needsCount,
            peopleCount: peopleCount
        )

        if counts.gratitudesCount == 0 && counts.needsCount == 0 && counts.peopleCount == 0 {
            return .soil
        }

        if counts.minCount >= slotCount {
            return .bloom
        }

        if counts.minCount >= leafProgressThreshold {
            return .leaf
        }

        if counts.maxCount >= leafProgressThreshold && counts.minCount < leafProgressThreshold {
            return .twig
        }

        return .sprout
    }

    /// True when chips show progress or the day has reading notes / reflections
    /// (streaks and review eligibility).
    var hasMeaningfulContent: Bool {
        if completionLevel != .soil {
            return true
        }
        let notesTrimmed = readingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let reflectionsTrimmed = reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        return !notesTrimmed.isEmpty || !reflectionsTrimmed.isEmpty
    }

    /// True when each chip section has at least one item (milestone “1/1/1”, independent of status name).
    var hasAtLeastOneEntryInEachSection: Bool {
        let counts = NonNegativeSectionCounts(
            gratitudesCount: (gratitudes ?? []).count,
            needsCount: (needs ?? []).count,
            peopleCount: (people ?? []).count
        )
        return counts.gratitudesCount >= 1 && counts.needsCount >= 1 && counts.peopleCount >= 1
    }

    /// Minimum items per section before the leaf tier when not yet at bloom (all sections must reach this).
    private static let leafProgressThreshold = 3

    /// Maximum number of items per chip section (gratitudes, needs, people).
    /// The journal design means each section holds at most 5 items.
    static let slotCount = 5

    private struct NonNegativeSectionCounts {
        let gratitudesCount: Int
        let needsCount: Int
        let peopleCount: Int

        init(gratitudesCount: Int, needsCount: Int, peopleCount: Int) {
            self.gratitudesCount = max(0, gratitudesCount)
            self.needsCount = max(0, needsCount)
            self.peopleCount = max(0, peopleCount)
        }

        var minCount: Int {
            min(gratitudesCount, needsCount, peopleCount)
        }

        var maxCount: Int {
            max(gratitudesCount, needsCount, peopleCount)
        }
    }
}

/// Code name for ``JournalEntry`` (call sites stay “Journal”; persistence stays compatible).
typealias Journal = JournalEntry
