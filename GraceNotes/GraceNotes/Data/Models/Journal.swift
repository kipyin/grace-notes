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
        switch raw.lowercased() {
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
        gratitudesCount >= slotCount &&
            needsCount >= slotCount &&
            peopleCount >= slotCount
    }

    /// Minimum count across the three chip sections (weakest section).
    static func minimumEntryCountAcrossSections(
        gratitudesCount: Int,
        needsCount: Int,
        peopleCount: Int
    ) -> Int {
        min(gratitudesCount, needsCount, peopleCount)
    }

    /// Chip-only status: Gratitudes, Needs, and People in Mind counts. Notes and reflections are ignored.
    static func completionLevel(
        gratitudesCount: Int,
        needsCount: Int,
        peopleCount: Int
    ) -> JournalCompletionLevel {
        if gratitudesCount == 0 && needsCount == 0 && peopleCount == 0 {
            return .soil
        }

        if gratitudesCount == slotCount && needsCount == slotCount && peopleCount == slotCount {
            return .bloom
        }

        if gratitudesCount >= 3 && needsCount >= 3 && peopleCount >= 3 {
            return .leaf
        }

        let hasAtLeastThree = gratitudesCount >= 3 || needsCount >= 3 || peopleCount >= 3
        let hasBelowThree = gratitudesCount < 3 || needsCount < 3 || peopleCount < 3
        if hasAtLeastThree && hasBelowThree {
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
        let gratitudesCount = (gratitudes ?? []).count
        let needsCount = (needs ?? []).count
        let peopleCount = (people ?? []).count
        return gratitudesCount >= 1 && needsCount >= 1 && peopleCount >= 1
    }

    /// Maximum number of items per chip section (gratitudes, needs, people).
    /// The journal design means each section holds at most 5 items.
    static let slotCount = 5
}

/// Code name for ``JournalEntry`` (call sites stay “Journal”; persistence stays compatible).
typealias Journal = JournalEntry
