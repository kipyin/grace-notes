import XCTest
@testable import GraceNotes

final class JournalTutorialHintPresentationTests: XCTestCase {
    func test_hintKind_balancedBelowFullSlots_returnsBloom() {
        let kind = JournalTutorialHintPresentation.hintKind(
            entryDate: nil,
            completionLevel: .leaf,
            filledEntryCount: 10,
            dismissedSproutGuidance: true,
            dismissedBloomGuidance: false
        )
        XCTAssertEqual(kind, .bloom)
    }

    func test_hintKind_balancedAtFifteenEntries_returnsNil() {
        let fifteenSlots = JournalViewModel.slotCount * 3
        let kind = JournalTutorialHintPresentation.hintKind(
            entryDate: nil,
            completionLevel: .leaf,
            filledEntryCount: fifteenSlots,
            dismissedSproutGuidance: true,
            dismissedBloomGuidance: false
        )
        XCTAssertNil(kind)
    }
}
