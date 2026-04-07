import XCTest
@testable import GraceNotes

final class JournalStickyCompletionVisibilityTests: XCTestCase {
    func test_barIndicatorHidden_whileNearTopOfContent() {
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentMinY: 0,
                hideUntilScrolledPast: 6
            )
        )
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentMinY: -4,
                hideUntilScrolledPast: 6
            )
        )
    }

    func test_barIndicatorVisible_afterScrollingPastThreshold() {
        XCTAssertTrue(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentMinY: -24,
                hideUntilScrolledPast: 6
            )
        )
    }
}
