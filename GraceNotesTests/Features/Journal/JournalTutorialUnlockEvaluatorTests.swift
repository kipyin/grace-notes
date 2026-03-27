import XCTest
@testable import GraceNotes

final class JournalTutorialUnlockEvaluatorTests: XCTestCase {
    func test_milestone_firstTripleOne() {
        let outcome = JournalTutorialUnlockEvaluator.milestoneOutcome(
            JournalTutorialUnlockEvaluator.MilestoneEvaluationInput(
                previousLevel: .empty,
                newLevel: .started,
                previousGratitudes: 0,
                previousNeeds: 0,
                previousPeople: 0,
                newGratitudes: 1,
                newNeeds: 1,
                newPeople: 1,
                hasCelebratedFirstTripleOne: false,
                hasCelebratedFirstBalanced: false,
                hasCelebratedFirstFull: false
            )
        )
        XCTAssertEqual(outcome?.milestoneHighlight, .firstOneOneOne)
        XCTAssertTrue(outcome?.recordFirstTripleOneCelebrated == true)
    }

    func test_milestone_noTripleOneWhenAlreadyHadOneEach() {
        let outcome = JournalTutorialUnlockEvaluator.milestoneOutcome(
            JournalTutorialUnlockEvaluator.MilestoneEvaluationInput(
                previousLevel: .started,
                newLevel: .started,
                previousGratitudes: 1,
                previousNeeds: 1,
                previousPeople: 1,
                newGratitudes: 2,
                newNeeds: 1,
                newPeople: 1,
                hasCelebratedFirstTripleOne: false,
                hasCelebratedFirstBalanced: false,
                hasCelebratedFirstFull: false
            )
        )
        XCTAssertNil(outcome)
    }

    func test_milestone_firstBalanced() {
        let outcome = JournalTutorialUnlockEvaluator.milestoneOutcome(
            JournalTutorialUnlockEvaluator.MilestoneEvaluationInput(
                previousLevel: .growing,
                newLevel: .balanced,
                previousGratitudes: 5,
                previousNeeds: 2,
                previousPeople: 2,
                newGratitudes: 5,
                newNeeds: 3,
                newPeople: 3,
                hasCelebratedFirstTripleOne: true,
                hasCelebratedFirstBalanced: false,
                hasCelebratedFirstFull: false
            )
        )
        XCTAssertEqual(outcome?.milestoneHighlight, .firstBalanced)
    }

    func test_milestone_firstFull() {
        let outcome = JournalTutorialUnlockEvaluator.milestoneOutcome(
            JournalTutorialUnlockEvaluator.MilestoneEvaluationInput(
                previousLevel: .balanced,
                newLevel: .full,
                previousGratitudes: 5,
                previousNeeds: 5,
                previousPeople: 4,
                newGratitudes: 5,
                newNeeds: 5,
                newPeople: 5,
                hasCelebratedFirstTripleOne: true,
                hasCelebratedFirstBalanced: true,
                hasCelebratedFirstFull: false
            )
        )
        XCTAssertEqual(outcome?.milestoneHighlight, .firstFull)
    }

    func test_milestone_nilWhenAlreadyCelebrated() {
        let outcome = JournalTutorialUnlockEvaluator.milestoneOutcome(
            JournalTutorialUnlockEvaluator.MilestoneEvaluationInput(
                previousLevel: .growing,
                newLevel: .balanced,
                previousGratitudes: 3,
                previousNeeds: 2,
                previousPeople: 2,
                newGratitudes: 3,
                newNeeds: 3,
                newPeople: 3,
                hasCelebratedFirstTripleOne: true,
                hasCelebratedFirstBalanced: true,
                hasCelebratedFirstFull: false
            )
        )
        XCTAssertNil(outcome)
    }
}
