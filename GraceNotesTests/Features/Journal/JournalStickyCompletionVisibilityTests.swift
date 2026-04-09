import XCTest
@testable import GraceNotes

final class JournalStickyCompletionVisibilityTests: XCTestCase {
    /// Mirrors `JournalScreenLayout.stickyCompletionBarScrollRevealPoints` (iOS 17 scroll-space path).
    private let threshold: CGFloat = 0

    // MARK: - iOS 17 header minY in scroll space

    func test_headerMinY_notRevealed_staysHiddenUntilEngagePadding() {
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                headerMinYInScrollSpace: 0,
                scrollRevealThreshold: threshold,
                currentlyRevealed: false
            )
        )
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                headerMinYInScrollSpace: -5,
                scrollRevealThreshold: threshold,
                currentlyRevealed: false
            )
        )
        XCTAssertTrue(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                headerMinYInScrollSpace: -13,
                scrollRevealThreshold: threshold,
                currentlyRevealed: false
            )
        )
    }

    func test_headerMinY_revealed_hysteresisRelease() {
        XCTAssertTrue(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                headerMinYInScrollSpace: -5,
                scrollRevealThreshold: threshold,
                currentlyRevealed: true
            )
        )
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                headerMinYInScrollSpace: -2,
                scrollRevealThreshold: threshold,
                currentlyRevealed: true
            )
        )
    }

    // MARK: - iOS 18+ scroll content offset

    func test_scrollOffset_notRevealed_staysHiddenUntilEngagePadding() {
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentOffsetY: 0,
                scrollRevealThreshold: threshold,
                currentlyRevealed: false
            )
        )
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentOffsetY: 6,
                scrollRevealThreshold: threshold,
                currentlyRevealed: false
            )
        )
        XCTAssertTrue(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentOffsetY: 13,
                scrollRevealThreshold: threshold,
                currentlyRevealed: false
            )
        )
    }

    func test_scrollOffset_revealed_hysteresisRelease() {
        XCTAssertTrue(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentOffsetY: 8,
                scrollRevealThreshold: threshold,
                currentlyRevealed: true
            )
        )
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentOffsetY: 2,
                scrollRevealThreshold: threshold,
                currentlyRevealed: true
            )
        )
    }

    func test_scrollOffset_respectsNonZeroThreshold() {
        let nonZeroThreshold: CGFloat = 4
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentOffsetY: 5,
                scrollRevealThreshold: nonZeroThreshold,
                currentlyRevealed: false
            )
        )
        XCTAssertTrue(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentOffsetY: 17,
                scrollRevealThreshold: nonZeroThreshold,
                currentlyRevealed: false
            )
        )
        XCTAssertTrue(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentOffsetY: 8,
                scrollRevealThreshold: nonZeroThreshold,
                currentlyRevealed: true
            )
        )
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                scrollContentOffsetY: 6,
                scrollRevealThreshold: nonZeroThreshold,
                currentlyRevealed: true
            )
        )
    }

    func test_headerMinY_respectsNonZeroThreshold() {
        let nonZeroThreshold: CGFloat = 4
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                headerMinYInScrollSpace: -10,
                scrollRevealThreshold: nonZeroThreshold,
                currentlyRevealed: false
            )
        )
        XCTAssertTrue(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                headerMinYInScrollSpace: -17,
                scrollRevealThreshold: nonZeroThreshold,
                currentlyRevealed: false
            )
        )
        XCTAssertTrue(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                headerMinYInScrollSpace: -8,
                scrollRevealThreshold: nonZeroThreshold,
                currentlyRevealed: true
            )
        )
        XCTAssertFalse(
            JournalStickyCompletionVisibility.shouldShowBarIndicator(
                headerMinYInScrollSpace: -6,
                scrollRevealThreshold: nonZeroThreshold,
                currentlyRevealed: true
            )
        )
    }
}
