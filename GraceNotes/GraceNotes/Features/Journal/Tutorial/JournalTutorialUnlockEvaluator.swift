import Foundation

enum JournalTutorialUnlockEvaluator {
    /// Recording flags and toast highlight when a first-time milestone is crossed.
    struct MilestoneOutcome: Equatable {
        let recordFirstTripleOneCelebrated: Bool
        let recordFirstBalancedCelebrated: Bool
        let recordFirstFullCelebrated: Bool
        let milestoneHighlight: JournalUnlockMilestoneHighlight
    }

    struct MilestoneEvaluationInput: Equatable {
        let previousLevel: JournalCompletionLevel
        let newLevel: JournalCompletionLevel
        let previousGratitudes: Int
        let previousNeeds: Int
        let previousPeople: Int
        let newGratitudes: Int
        let newNeeds: Int
        let newPeople: Int
        let hasCelebratedFirstTripleOne: Bool
        let hasCelebratedFirstBalanced: Bool
        let hasCelebratedFirstFull: Bool
    }

    /// First-time milestones: 1/1/1, first Balanced, first Full.
    static func milestoneOutcome(_ input: MilestoneEvaluationInput) -> MilestoneOutcome? {
        let prevTripleOne = input.previousGratitudes >= 1 && input.previousNeeds >= 1 && input.previousPeople >= 1
        let newTripleOne = input.newGratitudes >= 1 && input.newNeeds >= 1 && input.newPeople >= 1
        let crossedTripleOne = !prevTripleOne && newTripleOne

        let crossedBalanced = input.previousLevel != .leaf && input.newLevel == .leaf
        let crossedFull = input.previousLevel != .bloom && input.newLevel == .bloom

        let shouldRecordTripleOne = crossedTripleOne && !input.hasCelebratedFirstTripleOne
        let shouldRecordBalanced = crossedBalanced && !input.hasCelebratedFirstBalanced
        let shouldRecordFull = crossedFull && !input.hasCelebratedFirstFull

        let highlight: JournalUnlockMilestoneHighlight
        if shouldRecordTripleOne {
            highlight = .firstOneOneOne
        } else if shouldRecordBalanced {
            highlight = .firstBalanced
        } else if shouldRecordFull {
            highlight = .firstFull
        } else {
            return nil
        }

        return MilestoneOutcome(
            recordFirstTripleOneCelebrated: shouldRecordTripleOne,
            recordFirstBalancedCelebrated: shouldRecordBalanced,
            recordFirstFullCelebrated: shouldRecordFull,
            milestoneHighlight: highlight
        )
    }
}
