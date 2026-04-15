import CryptoKit
import Foundation

/// One searchable line or note row tied to a journal day, for Past search results.
struct JournalSearchMatch: Identifiable, Equatable, Sendable {
    let id: String
    let entryDate: Date
    let source: ReviewThemeSourceCategory
    let content: String

    init(entryDate: Date, journalEntryId: UUID, item: Entry, source: ReviewThemeSourceCategory, content: String) {
        self.id = "\(journalEntryId.uuidString)|\(source.rawValue)|\(item.id.uuidString)"
        self.entryDate = entryDate
        self.source = source
        self.content = content
    }

    init(entryDate: Date, journalEntryId: UUID, source: ReviewThemeSourceCategory, content: String) {
        self.id = Self.fieldMatchId(journalEntryId: journalEntryId, source: source, content: content)
        self.entryDate = entryDate
        self.source = source
        self.content = content
    }

    /// Stable identity for whole-field matches (reading notes, reflections) without storing full text in `id`.
    private static func fieldMatchId(
        journalEntryId: UUID,
        source: ReviewThemeSourceCategory,
        content: String
    ) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        // Use the full digest so truncated-hash collisions cannot map two different bodies of text to one `id`.
        let fingerprint = digest.map { String(format: "%02x", $0) }.joined()
        return "\(journalEntryId.uuidString)|\(source.rawValue)|\(fingerprint)"
    }
}
