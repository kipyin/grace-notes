import XCTest
@testable import GraceNotes

final class JournalStickyCompletionVisibilityTests: XCTestCase {
    /// Mirrors `JournalScreenLayout.stickyCompletionBarScrollRevealPoints` (iOS 17 scroll-space path).
    private let threshold: CGFloat = 0

    func test_barIndicatorHidden_whenScrollMinYAtZero() {
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentMinY: 0,
                scrollRevealThreshold: threshold
            )
        )
    }

    func test_barIndicatorVisible_whenScrollMinYNegative() {
        XCTAssertTrue(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentMinY: -4,
                scrollRevealThreshold: threshold
            )
        )
    }
}
