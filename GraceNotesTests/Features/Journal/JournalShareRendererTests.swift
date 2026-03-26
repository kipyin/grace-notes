import UIKit
import XCTest
@testable import GraceNotes

@MainActor
final class JournalShareRendererTests: XCTestCase {
    func test_renderImage_producesNonEmptyBitmap() {
        let payload = JournalExportPayload(
            dateFormatted: "March 15, 2025",
            gratitudes: ["Family", "Health"],
            needs: ["Rest"],
            people: ["Alex"],
            readingNotes: "A short reading note.",
            reflections: "End of day reflection."
        )

        guard let image = JournalShareRenderer.renderImage(from: payload) else {
            XCTFail("Expected share card image; ImageRenderer returned nil.")
            return
        }

        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }
}
