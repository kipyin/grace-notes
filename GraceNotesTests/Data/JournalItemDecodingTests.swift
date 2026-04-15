import XCTest
@testable import GraceNotes

final class JournalItemDecodingTests: XCTestCase {

    func test_decode_legacyJSON_emptyFullText_usesEntryLabel() throws {
        let json = #"{"fullText":"","entryLabel":"Recovered line"}"#
        let data = Data(json.utf8)

        let item = try JSONDecoder().decode(JournalItem.self, from: data)

        XCTAssertEqual(item.fullText, "Recovered line")
    }

    func test_decode_legacyJSON_emptyFullText_usesChipLabelWhenEntryLabelAbsent() throws {
        let json = #"{"fullText":"","chipLabel":"Chip fallback"}"#
        let data = Data(json.utf8)

        let item = try JSONDecoder().decode(JournalItem.self, from: data)

        XCTAssertEqual(item.fullText, "Chip fallback")
    }

    func test_decode_legacyJSON_emptyFullText_prefersEntryLabelOverChipLabel() throws {
        let json = #"{"fullText":"","entryLabel":"Primary","chipLabel":"Secondary"}"#
        let data = Data(json.utf8)

        let item = try JSONDecoder().decode(JournalItem.self, from: data)

        XCTAssertEqual(item.fullText, "Primary")
    }
}
