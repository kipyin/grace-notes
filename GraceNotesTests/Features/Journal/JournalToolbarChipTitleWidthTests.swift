import XCTest
@testable import GraceNotes

final class JournalToolbarChipTitleWidthTests: XCTestCase {

    func test_semiboldWidth_isAtLeastRegular_forZhHansGrowthTitles() {
        let zhTitles = [
            "静待播种",
            "初露新芽",
            "枝条初成",
            "叶茂成形",
            "花开有成"
        ]
        let metrics = UIFontMetrics(forTextStyle: .body)
        let size: CGFloat = 16
        guard let regular = UIFont(name: "SourceSerif4Roman-Regular", size: size) else {
            XCTFail("SourceSerif4Roman-Regular must be present in test host")
            return
        }
        let reg = metrics.scaledFont(for: regular)

        for title in zhTitles {
            let regularW = JournalToolbarChipTitleMeasuring.singleLineTextWidth(title, font: reg)
            let semiW = JournalToolbarChipTitleMeasuring.singleLineTextWidth(
                title,
                font: JournalToolbarChipTitleMeasuring.toolbarChipTitleUIFont(forTextStyle: .body)
            )
            XCTAssertGreaterThanOrEqual(
                semiW,
                regularW,
                "Semibold should not shrink CJK vs regular for \(title)"
            )
        }
    }

    func test_longestZhHansTitle_hasNonTrivialMeasuredWidth() {
        let title = "叶茂成形"
        let measuredWidth = JournalToolbarChipTitleMeasuring.measuredToolbarChipTitleWidth(for: title)
        XCTAssertGreaterThan(measuredWidth, 52, "Expected Han glyphs to exceed 52pt at default body metrics")
    }
}
