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

    /// Whether this entry has all 15 chip slots filled. Used by History and Journal.
    var isComplete: Bool {
        Self.hasAllFifteenChips(
            gratitudesCount: (gratitudes ?? []).count,
            needsCount: (needs ?? []).count,
            peopleCount: (people ?? []).count
        )
    }

    var completionLevel: JournalCompletionLevel {
        Self.completionLevel(
            gratitudesCount: (gratitudes ?? []).count,
            needsCount: (needs ?? []).count,
            peopleCount: (people ?? []).count,
            readingNotes: readingNotes,
            reflections: reflections
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

        if hasAllFifteenChips(
            gratitudesCount: gratitudesCount,
            needsCount: needsCount,
            peopleCount: peopleCount
        ) {
            return .standardReflection
        }

        if gratitudesCount >= 1 && needsCount >= 1 && peopleCount >= 1 {
            return .quickCheckIn
        }

        return .none
    }

    var hasMeaningfulContent: Bool {
        completionLevel != .none
    }

    /// Maximum number of items per chip section (gratitudes, needs, people).
    /// The journal design means each section holds at most 5 items.
    static let slotCount = 5
}
