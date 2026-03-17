import XCTest
@testable import FiveCubedMoments

final class JournalDataExportServiceTests: XCTestCase {
    private var service: JournalDataExportService!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        service = JournalDataExportService()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func test_makeArchive_sortsEntriesByDateAscending() {
        let later = makeEntry(on: date(year: 2026, month: 3, day: 20), gratitude: "Later")
        let earlier = makeEntry(on: date(year: 2026, month: 3, day: 18), gratitude: "Earlier")

        let archive = service.makeArchive(
            from: [later, earlier],
            exportedAt: date(year: 2026, month: 3, day: 21)
        )

        XCTAssertEqual(archive.entries.count, 2)
        XCTAssertEqual(archive.entries[0].gratitudes.first?.fullText, "Earlier")
        XCTAssertEqual(archive.entries[1].gratitudes.first?.fullText, "Later")
    }

    func test_makeArchiveData_encodesSchemaAndEntryFields() throws {
        let entry = makeEntry(on: date(year: 2026, month: 3, day: 19), gratitude: "Family")
        let exportDate = date(year: 2026, month: 3, day: 21)

        let data = try service.makeArchiveData(from: [entry], exportedAt: exportDate)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(JournalDataExportArchive.self, from: data)

        XCTAssertEqual(archive.schemaVersion, 1)
        XCTAssertEqual(archive.exportedAt, exportDate)
        XCTAssertEqual(archive.entries.count, 1)
        XCTAssertEqual(archive.entries[0].gratitudes.first?.chipLabel, "Family")
        XCTAssertEqual(archive.entries[0].needs.first?.fullText, "Rest")
        XCTAssertEqual(archive.entries[0].people.first?.fullText, "Alex")
        XCTAssertEqual(archive.entries[0].readingNotes, "Reading")
        XCTAssertEqual(archive.entries[0].reflections, "Reflection")
    }

    private func makeEntry(on date: Date, gratitude: String) -> JournalEntry {
        JournalEntry(
            entryDate: date,
            gratitudes: [JournalItem(fullText: gratitude, chipLabel: gratitude)],
            needs: [JournalItem(fullText: "Rest", chipLabel: "Rest")],
            people: [JournalItem(fullText: "Alex", chipLabel: "Alex")],
            readingNotes: "Reading",
            reflections: "Reflection",
            createdAt: date,
            updatedAt: date
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}
