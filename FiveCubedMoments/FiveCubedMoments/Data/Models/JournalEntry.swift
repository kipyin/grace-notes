import Foundation
import SwiftData

enum JournalCompletionLevel: String, Equatable {
    case none
    case quickCheckIn
    case standardReflection
    case fullFiveCubed
}

@Model
final class JournalEntry {
    // CloudKit-backed SwiftData models need declaration-time defaults
    // for every non-optional property.
    var id: UUID = UUID()
    var entryDate: Date = Date.now
    var gratitudes: [JournalItem] = []
    var needs: [JournalItem] = []
    var people: [JournalItem] = []
    @Attribute(originalName: "bibleNotes") var readingNotes: String = ""
    var reflections: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var completedAt: Date? = nil

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

    /// Whether this entry meets completion criteria. Used by History and Journal.
    var isComplete: Bool {
        completionLevel == .fullFiveCubed
    }

    var completionLevel: JournalCompletionLevel {
        Self.completionLevel(
            gratitudesCount: gratitudes.count,
            needsCount: needs.count,
            peopleCount: people.count,
            readingNotes: readingNotes,
            reflections: reflections
        )
    }

    /// Shared completion criteria used by JournalEntry and JournalViewModel.
    /// An entry is complete when it has at least `slotCount` gratitudes, needs, and people,
    /// plus non-empty (after trimming) reading notes and reflections.
    static func criteriaMet(
        gratitudesCount: Int,
        needsCount: Int,
        peopleCount: Int,
        readingNotes: String,
        reflections: String
    ) -> Bool {
        let notesTrimmed = readingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let reflectionsTrimmed = reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        return gratitudesCount >= slotCount &&
            needsCount >= slotCount &&
            peopleCount >= slotCount &&
            !notesTrimmed.isEmpty &&
            !reflectionsTrimmed.isEmpty
    }

    static func completionLevel(
        gratitudesCount: Int,
        needsCount: Int,
        peopleCount: Int,
        readingNotes: String,
        reflections: String
    ) -> JournalCompletionLevel {
        if criteriaMet(
            gratitudesCount: gratitudesCount,
            needsCount: needsCount,
            peopleCount: peopleCount,
            readingNotes: readingNotes,
            reflections: reflections
        ) {
            return .fullFiveCubed
        }

        let notesTrimmed = readingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let reflectionsTrimmed = reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasWrittenNotes = !notesTrimmed.isEmpty
        let hasWrittenReflections = !reflectionsTrimmed.isEmpty
        let totalChipCount = gratitudesCount + needsCount + peopleCount
        let isStandardBySections = gratitudesCount >= 3 && needsCount >= 3 && peopleCount >= 3
        let isStandardByMix = totalChipCount >= 6 && (hasWrittenNotes || hasWrittenReflections)
        if isStandardBySections || isStandardByMix {
            return .standardReflection
        }

        if totalChipCount > 0 || hasWrittenNotes || hasWrittenReflections {
            return .quickCheckIn
        }

        return .none
    }

    var hasMeaningfulContent: Bool {
        completionLevel != .none
    }

    /// Maximum number of items per chip section (gratitudes, needs, people).
    /// The "5³" design means each section holds at most 5 items.
    static let slotCount = 5
}
