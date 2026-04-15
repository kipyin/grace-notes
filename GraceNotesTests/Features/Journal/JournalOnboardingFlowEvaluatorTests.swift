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
        let keyboardHint = String(localized: "journal.onboarding.keyboardFinishHint")
        XCTAssertEqual(
            gratitudeGuidance?.messageSecondary,
            JournalOnboardingPresentation.trimmedKeyboardFinishHintLine(keyboardHint)
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

    func test_presentation_afterTripleOne_isInactiveAndSectionsStandard() {
        let presentation = makePresentation(gratitudes: 1, needs: 1, people: 1)

        XCTAssertFalse(presentation.isGuidanceActive)
        XCTAssertNil(presentation.sectionGuidance(for: .gratitude))
        XCTAssertEqual(presentation.state(for: .gratitude), .standard)
        XCTAssertEqual(presentation.state(for: .need), .standard)
        XCTAssertEqual(presentation.state(for: .person), .standard)
        XCTAssertEqual(presentation.state(for: .readingNotes), .standard)
        XCTAssertEqual(presentation.state(for: .reflections), .standard)
    }

    func test_presentation_fullGrid_isInactive() {
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

    func test_presentation_whitespaceOnlyMessage_isNotGuidanceActiveAndSectionGuidanceNil() {
        let presentation = JournalOnboardingPresentation(
            step: .gratitude,
            title: nil,
            message: "  \n\t ",
            sectionStates: [.gratitude: .active]
        )

        XCTAssertFalse(presentation.isGuidanceActive)
        XCTAssertNil(presentation.sectionGuidance(for: .gratitude))
    }

    func test_trimmedKeyboardFinishHintLine_whitespaceOnly_returnsNil() {
        XCTAssertNil(JournalOnboardingPresentation.trimmedKeyboardFinishHintLine("  \n  "))
    }

    func test_trimmedKeyboardFinishHintLine_surroundingWhitespace_returnsTrimmed() {
        XCTAssertEqual(
            JournalOnboardingPresentation.trimmedKeyboardFinishHintLine("  \n hint \t "),
            "hint"
        )
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
