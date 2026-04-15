import XCTest
@testable import GraceNotes

final class WeeklyReviewAggregatesSemanticMatchTests: XCTestCase {
    private var builder: WeeklyReviewAggregatesBuilder!

    override func setUp() {
        super.setUp()
        builder = WeeklyReviewAggregatesBuilder()
    }

    func test_moderateSurfaceSemanticMatch_hanAdjacencyMatchesWhenLatinTokenPathWouldMiss() {
        // Han/kanji substring adjacency: token overlap often fails (short tokens / no spaces).
        XCTAssertTrue(builder.moderateSurfaceSemanticMatch(themeConcept: "休息", supportText: "公园休息"))
    }

    func test_moderateSurfaceSemanticMatch_latinThemeDoesNotMatchInsideLatinWordWhenMixedWithHan() {
        // Regression: a Han character must not force substring matching that revives "rest" ⊂ "forest".
        XCTAssertFalse(builder.moderateSurfaceSemanticMatch(themeConcept: "rest", supportText: "forest 公园"))
    }

    func test_moderateSurfaceSemanticMatch_mixedLatinAndHanStillUsesWordBoundaryWhenBothSidesHaveLatin() {
        XCTAssertTrue(builder.moderateSurfaceSemanticMatch(themeConcept: "rest", supportText: "deep rest 公园"))
    }
}
