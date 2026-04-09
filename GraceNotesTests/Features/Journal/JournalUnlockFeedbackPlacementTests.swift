import XCTest
@testable import GraceNotes

final class JournalUnlockFeedbackPlacementTests: XCTestCase {

    func test_resolve_noUnlock_none() {
        XCTAssertEqual(
            JournalUnlockFeedbackPlacement.resolve(isUnlockPresent: false, stickyCompletionRevealed: false),
            .none
        )
        XCTAssertEqual(
            JournalUnlockFeedbackPlacement.resolve(isUnlockPresent: false, stickyCompletionRevealed: true),
            .none
        )
    }

    func test_resolve_unlockNotSticky_headerRibbon() {
        XCTAssertEqual(
            JournalUnlockFeedbackPlacement.resolve(isUnlockPresent: true, stickyCompletionRevealed: false),
            .headerRibbon
        )
    }

    func test_resolve_unlockSticky_toolbarBanner() {
        XCTAssertEqual(
            JournalUnlockFeedbackPlacement.resolve(isUnlockPresent: true, stickyCompletionRevealed: true),
            .toolbarBanner
        )
    }
}
