import XCTest
@testable import GraceNotes

final class JournalOnboardingFlowEvaluatorTests: XCTestCase {
    func test_presentation_nonNilEntryDate_isInactive() {
        let presentation = JournalOnboardingFlowEvaluator.presentation(
            for: makeContext(
                entryDate: .now,
                gratitudes: 0,
                needs: 0,
                people: 0
            )
        )

        XCTAssertFalse(presentation.isGuidanceActive)
    }

    func test_presentation_emptyEntry_targetsGratitudeFirst() {
        let presentation = makePresentation(gratitudes: 0, needs: 0, people: 0)

        XCTAssertEqual(presentation.step, .gratitude)
        let gratitudeGuidance = presentation.sectionGuidance(for: .gratitude)
        XCTAssertEqual(gratitudeGuidance?.title, "")
        XCTAssertEqual(gratitudeGuidance?.message, String(localized: "journal.onboarding.startWithGratitude"))
        XCTAssertEqual(
            gratitudeGuidance?.messageSecondary,
            String(localized: "journal.onboarding.keyboardFinishHint")
        )
        XCTAssertEqual(presentation.state(for: .gratitude), .active)
        XCTAssertEqual(
            presentation.state(for: .need),
            .locked(reason: String(localized: "journal.onboarding.needsLockedReason"))
        )
    }

    func test_presentation_afterFirstGratitude_targetsNeed() {
        let presentation = makePresentation(gratitudes: 1, needs: 0, people: 0)

        XCTAssertEqual(presentation.step, .need)
        XCTAssertEqual(presentation.state(for: .gratitude), .available)
        XCTAssertEqual(presentation.state(for: .need), .active)
    }

    func test_presentation_afterFirstNeed_targetsPerson() {
        let presentation = makePresentation(gratitudes: 1, needs: 1, people: 0)

        XCTAssertEqual(presentation.step, .person)
        XCTAssertEqual(presentation.state(for: .person), .active)
    }

    func test_presentation_afterSeed_targetsRipening() {
        let presentation = makePresentation(gratitudes: 1, needs: 1, people: 1)

        XCTAssertEqual(presentation.step, .ripening)
        XCTAssertEqual(presentation.state(for: .gratitude), .active)
        XCTAssertEqual(presentation.state(for: .readingNotes), .active)
        XCTAssertEqual(presentation.state(for: .reflections), .active)
    }

    func test_presentation_afterThreeByThreeByThree_targetsHarvest() {
        let presentation = makePresentation(gratitudes: 3, needs: 3, people: 3)

        XCTAssertEqual(presentation.step, .harvest)
        XCTAssertEqual(presentation.state(for: .gratitude), .active)
        XCTAssertEqual(presentation.state(for: .person), .active)
        XCTAssertEqual(presentation.state(for: .readingNotes), .active)
        XCTAssertEqual(presentation.state(for: .reflections), .active)
    }

    func test_presentation_afterHarvest_isInactive() {
        let presentation = makePresentation(gratitudes: 5, needs: 5, people: 5)

        XCTAssertFalse(presentation.isGuidanceActive)
    }

    func test_presentation_completedGuidedJournal_isInactive() {
        let presentation = JournalOnboardingFlowEvaluator.presentation(
            for: makeContext(
                entryDate: nil,
                gratitudes: 0,
                needs: 0,
                people: 0,
                hasCompletedGuidedJournal: true
            )
        )

        XCTAssertFalse(presentation.isGuidanceActive)
    }

    func test_sectionGuidance_ripening_onlyOnGratitude() {
        let presentation = makePresentation(gratitudes: 1, needs: 1, people: 1)
        XCTAssertEqual(presentation.step, .ripening)
        XCTAssertNotNil(presentation.sectionGuidance(for: .gratitude))
        XCTAssertNil(presentation.sectionGuidance(for: .need))
        XCTAssertNil(presentation.sectionGuidance(for: .person))
    }

    func test_sectionGuidance_harvest_onlyOnGratitude() {
        let presentation = makePresentation(gratitudes: 3, needs: 3, people: 3)
        XCTAssertEqual(presentation.step, .harvest)
        XCTAssertNotNil(presentation.sectionGuidance(for: .gratitude))
        XCTAssertNil(presentation.sectionGuidance(for: .readingNotes))
    }
}

private extension JournalOnboardingFlowEvaluatorTests {
    func makePresentation(
        gratitudes: Int,
        needs: Int,
        people: Int
    ) -> JournalOnboardingPresentation {
        JournalOnboardingFlowEvaluator.presentation(
            for: makeContext(
                entryDate: nil,
                gratitudes: gratitudes,
                needs: needs,
                people: people
            )
        )
    }

    func makeContext(
        entryDate: Date?,
        gratitudes: Int,
        needs: Int,
        people: Int,
        hasCompletedGuidedJournal: Bool = false
    ) -> JournalOnboardingContext {
        JournalOnboardingContext(
            entryDate: entryDate,
            gratitudesCount: gratitudes,
            needsCount: needs,
            peopleCount: people,
            hasCompletedGuidedJournal: hasCompletedGuidedJournal
        )
    }
}
