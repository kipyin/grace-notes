import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var entryDate: Date
    var gratitudes: [JournalItem]
    var needs: [JournalItem]
    var people: [JournalItem]
    var bibleNotes: String
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
        bibleNotes: String = "",
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
        self.bibleNotes = bibleNotes
        self.reflections = reflections
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    /// Whether this entry meets completion criteria. Used by History and Journal.
    var isComplete: Bool {
        Self.criteriaMet(
            gratitudesCount: gratitudes.count,
            needsCount: needs.count,
            peopleCount: people.count,
            bibleNotes: bibleNotes,
            reflections: reflections
        )
    }

    /// Shared completion criteria used by JournalEntry and JournalViewModel.
    static func criteriaMet(
        gratitudesCount: Int,
        needsCount: Int,
        peopleCount: Int,
        bibleNotes: String,
        reflections: String
    ) -> Bool {
        let notesTrimmed = bibleNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let reflectionsTrimmed = reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        return gratitudesCount >= slotCount &&
            needsCount >= slotCount &&
            peopleCount >= slotCount &&
            !notesTrimmed.isEmpty &&
            !reflectionsTrimmed.isEmpty
    }

    static let slotCount = 5
}
