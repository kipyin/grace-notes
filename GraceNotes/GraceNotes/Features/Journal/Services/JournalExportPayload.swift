import Foundation

struct JournalExportSnapshotSource {
    let entryDate: Date
    let gratitudes: [JournalItem]
    let needs: [JournalItem]
    let people: [JournalItem]
    let readingNotes: String
    let reflections: String
}

struct JournalExportPayload {
    let dateFormatted: String
    let gratitudes: [String]
    let needs: [String]
    let people: [String]
    let readingNotes: String
    let reflections: String

    static func make(from source: JournalExportSnapshotSource) -> JournalExportPayload {
        JournalExportPayload(
            dateFormatted: source.entryDate.formatted(date: .long, time: .omitted),
            gratitudes: source.gratitudes.map(\.fullText),
            needs: source.needs.map(\.fullText),
            people: source.people.map(\.fullText),
            readingNotes: source.readingNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            reflections: source.reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
