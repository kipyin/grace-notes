import Foundation

/// One searchable line or note row tied to a journal day, for Past search results.
struct JournalSearchMatch: Identifiable, Equatable {
    let id: String
    let entryDate: Date
    let source: ReviewThemeSourceCategory
    let content: String

    init(entryDate: Date, journalEntryId: UUID, item: JournalItem, source: ReviewThemeSourceCategory, content: String) {
        self.id = "\(journalEntryId.uuidString)|\(source.rawValue)|\(item.id.uuidString)"
        self.entryDate = entryDate
        self.source = source
        self.content = content
    }

    init(entryDate: Date, journalEntryId: UUID, source: ReviewThemeSourceCategory, content: String) {
        self.id = "\(journalEntryId.uuidString)|\(source.rawValue)"
        self.entryDate = entryDate
        self.source = source
        self.content = content
    }
}
