import XCTest
@testable import GraceNotes

final class ShareTypographyScriptTests: XCTestCase {
    func test_forLanguageCode_zhJaKo_mapsToCJKTypography() {
        XCTAssertEqual(ShareTypographyScript.forLanguageCode(.chinese), .chinese)
        XCTAssertEqual(ShareTypographyScript.forLanguageCode(.japanese), .chinese)
        XCTAssertEqual(ShareTypographyScript.forLanguageCode(.korean), .chinese)
    }

    func test_forLanguageCode_nonCJK_mapsToLatin() {
        XCTAssertEqual(ShareTypographyScript.forLanguageCode(.english), .latin)
    }

    func test_forLanguageCode_nil_mapsToLatin() {
        XCTAssertEqual(ShareTypographyScript.forLanguageCode(nil), .latin)
    }
}
