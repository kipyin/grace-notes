import XCTest
@testable import GraceNotes

final class ShareCardDraftTests: XCTestCase {
    func test_build_omitsRedactedStringFromVisibleLines() {
        let base = JournalExportPayload(
            dateFormatted: "March 15, 2025",
            gratitudes: ["Show this", "SECRET_PHRASE"],
            needs: [],
            people: [],
            readingNotes: "",
            reflections: "",
            completionLevel: .sprout
        )
        var draft = ShareCardDraft.initial(from: base)
        draft.toggleRedaction(for: .gratitude(1))
        let render = ShareRenderPayloadBuilder.build(full: base, draft: draft, includePreviewStubs: false)

        XCTAssertEqual(render.sections.count, 1)
        let lines = render.sections[0].lines
        XCTAssertEqual(lines.count, 2)
        guard case .visible(let displayText, _) = lines[0] else {
            return XCTFail("Expected first line visible")
        }
        XCTAssertTrue(displayText.contains("Show this"))
        guard case .redacted = lines[1] else {
            return XCTFail("Expected second line redacted")
        }
        let flattened = lines.compactMap { item -> String? in
            if case .visible(let visibleText, _) = item { return visibleText }
            return nil
        }.joined()
        XCTAssertFalse(flattened.contains("SECRET_PHRASE"))
    }

    func test_build_excludesSectionWhenToggledOff() {
        let base = JournalExportPayload(
            dateFormatted: "March 15, 2025",
            gratitudes: ["A"],
            needs: ["B"],
            people: [],
            readingNotes: "",
            reflections: "",
            completionLevel: .sprout
        )
        var draft = ShareCardDraft.initial(from: base)
        draft.setGratitudesIncluded(false)
        let render = ShareRenderPayloadBuilder.build(full: base, draft: draft, includePreviewStubs: false)

        XCTAssertEqual(render.sections.count, 1)
        guard case .visible(let needLine, _) = render.sections[0].lines[0] else {
            XCTFail("Expected needs line visible")
            return
        }
        XCTAssertTrue(needLine.contains("B"))
    }

    func test_build_previewStubShowsExcludedSectionInComposerOnly() {
        let base = JournalExportPayload(
            dateFormatted: "March 15, 2025",
            gratitudes: ["Only gratitude"],
            needs: [],
            people: [],
            readingNotes: "",
            reflections: "",
            completionLevel: .sprout
        )
        var draft = ShareCardDraft.initial(from: base)
        draft.setGratitudesIncluded(false)

        let preview = ShareRenderPayloadBuilder.build(full: base, draft: draft, includePreviewStubs: true)
        XCTAssertEqual(preview.sections.count, 1)
        XCTAssertTrue(preview.sections[0].isPreviewStub)
        guard case .previewStub(let message) = preview.sections[0].lines[0] else {
            return XCTFail("Expected preview stub line")
        }
        XCTAssertFalse(message.isEmpty)

        let export = ShareRenderPayloadBuilder.build(full: base, draft: draft, includePreviewStubs: false)
        XCTAssertTrue(export.sections.isEmpty)
    }
}
