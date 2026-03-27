import Foundation
import SwiftData

/// Chip-section completion status (Gratitudes, Needs, People in Mind only). Reading notes and reflections are excluded.
enum JournalCompletionLevel: String, Equatable, Hashable, Sendable {
    case empty
    case started
    case growing
    case balanced
    case full
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

    /// Maps persisted raw strings from older app versions (pre–chip-status rename) and unknown values.
    init(decodingLegacyRawValue raw: String) {
        switch raw {
        case "empty", "soil":
            self = .empty
        case "started", "seed":
            self = .started
        case "growing":
            self = .growing
        case "balanced", "ripening":
            self = .balanced
        case "full", "harvest", "abundance":
            self = .full
        default:
            self = .empty
        }
    }
}

@Model
final class JournalEntry {
    // CloudKit: non-optional transformable arrays do not get a recognized default in
    // the Core Data stack; use optional (`nil` = empty) so the store can load.
    var id: UUID = UUID()
    var entryDate: Date = Date.now
    var gratitudes: [JournalItem]?
    var needs: [JournalItem]?
    var people: [JournalItem]?
    @Attribute(originalName: "bibleNotes") var readingNotes: String = ""
    var reflections: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        entryDate: Date = .now,
        gratitudes: [JournalItem] = [],
        needs: [JournalItem] = [],
        people: [JournalItem] = [],
        readingNotes: String = "",
        reflections: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.entryDate = entryDate // Callers must pass start-of-day
        self.gratitudes = Self.normalizedItems(gratitudes)
        self.needs = Self.normalizedItems(needs)
        self.people = Self.normalizedItems(people)
        self.readingNotes = readingNotes
        self.reflections = reflections
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    private static func normalizedItems(_ items: [JournalItem]) -> [JournalItem] {
        items.map { item in
            var normalized = item
            if normalized.chipLabel == nil {
                normalized.chipLabel = normalized.fullText
            }
            return normalized
        }
    }

    /// All chip slots filled (5 gratitudes, 5 needs, 5 people). Notes and reflections do not change it.
    var hasHarvestChips: Bool {
        Self.hasAllFifteenChips(
            gratitudesCount: (gratitudes ?? []).count,
            needsCount: (needs ?? []).count,
            peopleCount: (people ?? []).count
        )
    }

    /// Same as ``hasHarvestChips``. Older call sites use this name for History and persistence.
    var isComplete: Bool { hasHarvestChips }

    /// Chips plus non-empty reading notes and reflections (“full rhythm” for streaks and guided completion).
    var hasAbundanceRhythm: Bool {
        Self.criteriaMet(
            gratitudesCount: (gratitudes ?? []).count,
            needsCount: (needs ?? []).count,
            peopleCount: (people ?? []).count,
            readingNotes: readingNotes,
            reflections: reflections
        )
    }

    var completionLevel: JournalCompletionLevel {
        Self.completionLevel(
            gratitudesCount: (gratitudes ?? []).count,
            needsCount: (needs ?? []).count,
            peopleCount: (people ?? []).count
        )
    }

    /// Shared full-rhythm criteria used by JournalEntry and JournalViewModel.
    /// A full rhythm requires all chips plus non-empty notes and reflections.
    static func criteriaMet(
        gratitudesCount: Int,
        needsCount: Int,
        peopleCount: Int,
        readingNotes: String,
        reflections: String
    ) -> Bool {
        let notesTrimmed = readingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let reflectionsTrimmed = reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        return hasAllFifteenChips(
            gratitudesCount: gratitudesCount,
            needsCount: needsCount,
            peopleCount: peopleCount
        ) &&
            !notesTrimmed.isEmpty &&
            !reflectionsTrimmed.isEmpty
    }

    static func hasAllFifteenChips(
        gratitudesCount: Int,
        needsCount: Int,
        peopleCount: Int
    ) -> Bool {
        gratitudesCount >= slotCount &&
            needsCount >= slotCount &&
            peopleCount >= slotCount
    }

    /// Minimum count across the three chip sections (weakest section).
    static func minChipSectionCount(
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
            return .empty
        }

        if gratitudesCount == slotCount && needsCount == slotCount && peopleCount == slotCount {
            return .full
        }

        if gratitudesCount >= 3 && needsCount >= 3 && peopleCount >= 3 {
            return .balanced
        }

        let hasAtLeastThree = gratitudesCount >= 3 || needsCount >= 3 || peopleCount >= 3
        let hasBelowThree = gratitudesCount < 3 || needsCount < 3 || peopleCount < 3
        if hasAtLeastThree && hasBelowThree {
            return .growing
        }

        return .started
    }

    /// True when chips show progress or the day has reading notes / reflections
    /// (streaks and review eligibility).
    var hasMeaningfulContent: Bool {
        if completionLevel != .empty {
            return true
        }
        let notesTrimmed = readingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let reflectionsTrimmed = reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        return !notesTrimmed.isEmpty || !reflectionsTrimmed.isEmpty
    }

    /// True when each chip section has at least one item (milestone “1/1/1”, independent of status name).
    var hasAtLeastOneInEachChipSection: Bool {
        let gratitudesCount = (gratitudes ?? []).count
        let needsCount = (needs ?? []).count
        let peopleCount = (people ?? []).count
        return gratitudesCount >= 1 && needsCount >= 1 && peopleCount >= 1
    }

    /// Maximum number of items per chip section (gratitudes, needs, people).
    /// The journal design means each section holds at most 5 items.
    static let slotCount = 5
}
