import Foundation

enum JournalTutorialUnlockEvaluator {
    /// Recording flags and toast highlight when a first-time milestone is crossed.
    struct MilestoneOutcome: Equatable {
        let recordFirstTripleOneCelebrated: Bool
        let recordFirstLeafCelebrated: Bool
        let recordFirstBloomCelebrated: Bool
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
        let hasCelebratedFirstLeaf: Bool
        let hasCelebratedFirstBloom: Bool
    }

    /// First-time milestones: 1/1/1, first Leaf, first Bloom.
    static func milestoneOutcome(_ input: MilestoneEvaluationInput) -> MilestoneOutcome? {
        let prevTripleOne = input.previousGratitudes >= 1 && input.previousNeeds >= 1 && input.previousPeople >= 1
        let newTripleOne = input.newGratitudes >= 1 && input.newNeeds >= 1 && input.newPeople >= 1
        let crossedTripleOne = !prevTripleOne && newTripleOne

        let crossedBalanced = input.previousLevel != .leaf && input.newLevel == .leaf
        let crossedFull = input.previousLevel != .bloom && input.newLevel == .bloom

        let shouldRecordTripleOne = crossedTripleOne && !input.hasCelebratedFirstTripleOne
        let shouldRecordLeaf = crossedBalanced && !input.hasCelebratedFirstLeaf
        let shouldRecordBloom = crossedFull && !input.hasCelebratedFirstBloom

        // Prefer the strongest growth-stage toast when several milestones cross in one update
        // (e.g. empty → balanced or Bloom in a single save); recording flags below still capture each first.
        let highlight: JournalUnlockMilestoneHighlight
        if shouldRecordBloom {
            highlight = .firstFull
        } else if shouldRecordLeaf {
            highlight = .firstBalanced
        } else if shouldRecordTripleOne {
            highlight = .firstOneOneOne
        } else {
            return nil
        }

        return MilestoneOutcome(
            recordFirstTripleOneCelebrated: shouldRecordTripleOne,
            recordFirstLeafCelebrated: shouldRecordLeaf,
            recordFirstBloomCelebrated: shouldRecordBloom,
            milestoneHighlight: highlight
        )
    }
}
