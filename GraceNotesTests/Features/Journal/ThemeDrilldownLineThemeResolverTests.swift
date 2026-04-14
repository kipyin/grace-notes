import XCTest
@testable import GraceNotes

final class ThemeDrilldownLineThemeResolverTests: XCTestCase {
    func test_maximumConceptCount_chipSectionsUseThree() {
        XCTAssertEqual(ThemeDrilldownLineThemeResolver.maximumConceptCount(for: .gratitudes), 3)
        XCTAssertEqual(ThemeDrilldownLineThemeResolver.maximumConceptCount(for: .needs), 3)
        XCTAssertEqual(ThemeDrilldownLineThemeResolver.maximumConceptCount(for: .people), 3)
    }

    func test_maximumConceptCount_noteBlocksUseFour() {
        XCTAssertEqual(ThemeDrilldownLineThemeResolver.maximumConceptCount(for: .readingNotes), 4)
        XCTAssertEqual(ThemeDrilldownLineThemeResolver.maximumConceptCount(for: .reflections), 4)
    }

    func test_sortChipsDrilldownFirst_putsMatchingCanonicalFirst() {
        let chips: [(concept: ReviewDistilledConcept, isManualAdd: Bool)] = [
            (ReviewDistilledConcept(canonicalConcept: "b", displayLabel: "B", score: 1), false),
            (ReviewDistilledConcept(canonicalConcept: "a", displayLabel: "A", score: 1), false)
        ]
        let sorted = ThemeDrilldownLineThemeResolver.sortChipsDrilldownFirst(
            chips: chips,
            drilldownCanonical: "a"
        )
        XCTAssertEqual(sorted.map(\.concept.canonicalConcept), ["a", "b"])
    }

    func test_ensureDrilldownChipIfMissing_insertsWhenAbsent() {
        let evidence = ReviewThemeSurfaceEvidence(
            entryDate: Date(timeIntervalSince1970: 0),
            source: .gratitudes,
            content: "x",
            journalId: UUID(),
            entryLineId: UUID()
        )
        let surfaceKey = evidence.surfaceLineKey!.storageKey
        let empty: [(ReviewDistilledConcept, Bool)] = []
        let filled = ThemeDrilldownLineThemeResolver.ensureDrilldownChipIfMissing(
            chips: empty,
            fallback: ThemeDrilldownFallbackParams(
                drilldownCanonical: "dad",
                drilldownDefaultLabel: "Dad",
                surfaceKey: surfaceKey,
                themeOverridePolicy: .empty,
                surfaceThemePolicy: .empty
            )
        )
        XCTAssertEqual(filled.count, 1)
        XCTAssertEqual(filled[0].concept.canonicalConcept, "dad")
        XCTAssertFalse(filled[0].isManualAdd)
    }

    func test_ensureDrilldownChipIfMissing_skipsWhenAlreadyPresent() {
        let chips: [(concept: ReviewDistilledConcept, isManualAdd: Bool)] = [
            (ReviewDistilledConcept(canonicalConcept: "dad", displayLabel: "Dad", score: 1), false)
        ]
        let out = ThemeDrilldownLineThemeResolver.ensureDrilldownChipIfMissing(
            chips: chips,
            fallback: ThemeDrilldownFallbackParams(
                drilldownCanonical: "dad",
                drilldownDefaultLabel: "Dad",
                surfaceKey: "k",
                themeOverridePolicy: .empty,
                surfaceThemePolicy: .empty
            )
        )
        XCTAssertEqual(out.count, 1)
    }
}
