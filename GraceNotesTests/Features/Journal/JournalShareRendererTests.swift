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
            reflections: "End of day reflection.",
            completionLevel: .leaf
        )

        let draft = ShareCardDraft.initial(from: payload)
        let renderPayload = ShareRenderPayloadBuilder.build(
            full: payload,
            draft: draft,
            includePreviewStubs: false
        )
        guard let image = JournalShareRenderer.renderImage(from: renderPayload) else {
            XCTFail("Expected share card image; ImageRenderer returned nil.")
            return
        }

        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func test_renderImage_eachStyleProducesBitmap() {
        let payload = JournalExportPayload(
            dateFormatted: "March 15, 2025",
            gratitudes: ["One"],
            needs: [],
            people: [],
            readingNotes: "",
            reflections: "",
            completionLevel: .sprout
        )

        for style in ShareCardStyle.allCases {
            var draft = ShareCardDraft.initial(from: payload)
            draft.style = style
            draft.showWatermark = true
            draft.showCompletionBadge = style == .paperWarm
            let renderPayload = ShareRenderPayloadBuilder.build(
                full: payload,
                draft: draft,
                includePreviewStubs: false
            )
            guard let image = JournalShareRenderer.renderImage(from: renderPayload) else {
                XCTFail("Expected image for style \(style.rawValue)")
                return
            }
            XCTAssertGreaterThan(image.size.width, 0, style.rawValue)
        }
    }
}
