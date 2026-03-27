import XCTest
@testable import GraceNotes

final class JournalTutorialHintPresentationTests: XCTestCase {
    func test_hintKind_balancedBelowFullSlots_returnsHarvest() {
        let kind = JournalTutorialHintPresentation.hintKind(
            entryDate: nil,
            completionLevel: .balanced,
            chipsFilledCount: 10,
            dismissedSeedGuidance: true,
            dismissedHarvestGuidance: false
        )
        XCTAssertEqual(kind, .harvest)
    }

    func test_hintKind_balancedAtFifteenChips_returnsNil() {
        let fifteenSlots = JournalViewModel.slotCount * 3
        let kind = JournalTutorialHintPresentation.hintKind(
            entryDate: nil,
            completionLevel: .balanced,
            chipsFilledCount: fifteenSlots,
            dismissedSeedGuidance: true,
            dismissedHarvestGuidance: false
        )
        XCTAssertNil(kind)
    }
}
