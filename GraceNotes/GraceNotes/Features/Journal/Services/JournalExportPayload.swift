import Foundation

struct JournalExportSnapshotSource {
    let entryDate: Date
    let gratitudes: [Entry]
    let needs: [Entry]
    let people: [Entry]
    let readingNotes: String
    let reflections: String
    let completionLevel: JournalCompletionLevel
}

struct JournalExportPayload {
    let dateFormatted: String
    let gratitudes: [String]
    let needs: [String]
    let people: [String]
    let readingNotes: String
    let reflections: String
    let completionLevel: JournalCompletionLevel

    static func make(from source: JournalExportSnapshotSource) -> JournalExportPayload {
        JournalExportPayload(
            dateFormatted: source.entryDate.formatted(date: .long, time: .omitted),
            gratitudes: source.gratitudes.map { trimmed($0.fullText) },
            needs: source.needs.map { trimmed($0.fullText) },
            people: source.people.map { trimmed($0.fullText) },
            readingNotes: trimmed(source.readingNotes),
            reflections: trimmed(source.reflections),
            completionLevel: source.completionLevel
        )
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
