import XCTest
@testable import GraceNotes

final class SectionDistributionStripLayoutTests: XCTestCase {
    func test_segmentWidths_allZero_isEqualThirds() {
        let usable: CGFloat = 99
        let widths = ReviewSectionDistributionStripLayout.segmentWidths(
            gratitudeMentions: 0,
            needMentions: 0,
            peopleMentions: 0,
            usableWidth: usable
        )
        XCTAssertEqual(widths.count, 3)
        let third = usable / 3
        for segmentWidth in widths {
            XCTAssertEqual(segmentWidth, third, accuracy: 0.02)
        }
        XCTAssertEqual(widths.reduce(0, +), usable, accuracy: 0.02)
    }

    func test_segmentWidths_proportional_6_5_5() {
        let usable: CGFloat = 160
        let widths = ReviewSectionDistributionStripLayout.segmentWidths(
            gratitudeMentions: 6,
            needMentions: 5,
            peopleMentions: 5,
            usableWidth: usable
        )
        XCTAssertEqual(widths[0], 60, accuracy: 0.5)
        XCTAssertEqual(widths[1], 50, accuracy: 0.5)
        XCTAssertEqual(widths[2], 50, accuracy: 0.5)
        XCTAssertEqual(widths.reduce(0, +), usable, accuracy: 0.02)
    }

    func test_segmentWidths_renormalizesWhenOneSectionDominates() {
        let usable: CGFloat = 100
        let widths = ReviewSectionDistributionStripLayout.segmentWidths(
            gratitudeMentions: 10,
            needMentions: 0,
            peopleMentions: 0,
            usableWidth: usable
        )
        XCTAssertGreaterThan(widths[0], widths[1])
        XCTAssertGreaterThan(widths[0], widths[2])
        XCTAssertEqual(widths.reduce(0, +), usable, accuracy: 0.02)
        // After min-width enforcement, renorm can yield sub–1pt slivers; keep a visible stub.
        XCTAssertGreaterThanOrEqual(widths[1], 0.5)
        XCTAssertGreaterThanOrEqual(widths[2], 0.5)
    }

    /// First width is gratitudes, then needs, then people (`ReviewSectionDistributionStripLayout.segmentWidths`).
    func test_segmentWidths_argumentOrder_isGratitudesThenNeedsThenPeople() {
        let usable: CGFloat = 120
        let onlyGratitude = ReviewSectionDistributionStripLayout.segmentWidths(
            gratitudeMentions: 100,
            needMentions: 0,
            peopleMentions: 0,
            usableWidth: usable
        )
        let onlyNeeds = ReviewSectionDistributionStripLayout.segmentWidths(
            gratitudeMentions: 0,
            needMentions: 100,
            peopleMentions: 0,
            usableWidth: usable
        )
        XCTAssertGreaterThan(onlyGratitude[0], onlyGratitude[1])
        XCTAssertGreaterThan(onlyNeeds[1], onlyNeeds[0])
        XCTAssertEqual(onlyGratitude.reduce(0, +), usable, accuracy: 0.02)
        XCTAssertEqual(onlyNeeds.reduce(0, +), usable, accuracy: 0.02)
    }
}
