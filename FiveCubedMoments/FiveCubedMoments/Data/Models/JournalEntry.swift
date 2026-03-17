import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var entryDate: Date
    var gratitudes: [JournalItem]
    var needs: [JournalItem]
    var people: [JournalItem]
    @Attribute(originalName: "bibleNotes") var readingNotes: String
    var reflections: String
    var createdAt: Date
    var updatedAt: Date
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

    /// Whether this entry meets completion criteria. Used by History and Journal.
    var isComplete: Bool {
        Self.criteriaMet(
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

    /// Maximum number of items per chip section (gratitudes, needs, people).
    /// The "5³" design means each section holds at most 5 items.
    static let slotCount = 5
}
