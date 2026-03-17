import XCTest
@testable import GraceNotes

final class ReviewInsightsRefreshPolicyTests: XCTestCase {
    func test_shouldRefresh_whenForceTrue_returnsTrue() {
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            force: true,
            hasInsights: true,
            previousKey: makeKey(),
            currentKey: makeKey()
        )

        XCTAssertTrue(result)
    }

    func test_shouldRefresh_whenNoInsights_returnsTrue() {
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            force: false,
            hasInsights: false,
            previousKey: makeKey(),
            currentKey: makeKey()
        )

        XCTAssertTrue(result)
    }

    func test_shouldRefresh_whenKeyUnchanged_returnsFalse() {
        let key = makeKey()
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            force: false,
            hasInsights: true,
            previousKey: key,
            currentKey: key
        )

        XCTAssertFalse(result)
    }

    func test_shouldRefresh_whenAISettingChanges_returnsTrue() {
        let previous = makeKey(useAIReviewInsights: false)
        let current = makeKey(useAIReviewInsights: true)
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            force: false,
            hasInsights: true,
            previousKey: previous,
            currentKey: current
        )

        XCTAssertTrue(result)
    }

    func test_shouldRefresh_whenEntrySnapshotChanges_returnsTrue() {
        let entryID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let previous = makeKey(
            snapshots: [ReviewEntrySnapshot(id: entryID, updatedAt: Date(timeIntervalSince1970: 100))]
        )
        let current = makeKey(
            snapshots: [ReviewEntrySnapshot(id: entryID, updatedAt: Date(timeIntervalSince1970: 200))]
        )
        let result = ReviewInsightsRefreshPolicy.shouldRefresh(
            force: false,
            hasInsights: true,
            previousKey: previous,
            currentKey: current
        )

        XCTAssertTrue(result)
    }

    private func makeKey(
        weekStart: Date = Date(timeIntervalSince1970: 0),
        useAIReviewInsights: Bool = false,
        snapshots: [ReviewEntrySnapshot] = []
    ) -> ReviewInsightsRefreshKey {
        ReviewInsightsRefreshKey(
            weekStart: weekStart,
            useAIReviewInsights: useAIReviewInsights,
            entrySnapshots: snapshots
        )
    }
}
