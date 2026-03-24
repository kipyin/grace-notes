import Foundation

enum JournalTutorialUnlockEvaluator {
    struct Outcome: Equatable {
        let recordFirstSeedCelebrated: Bool
        let recordFirstHarvestCelebrated: Bool
        let milestoneHighlight: JournalUnlockMilestoneHighlight

        static let neutral = Outcome(
            recordFirstSeedCelebrated: false,
            recordFirstHarvestCelebrated: false,
            milestoneHighlight: .none
        )
    }

    /// Computes milestone recording and toast highlight when completion rank increases.
    static func outcome(
        previousRank: Int,
        newRank: Int,
        newLevel: JournalCompletionLevel,
        hasCelebratedFirstSeed: Bool,
        hasCelebratedFirstHarvest: Bool
    ) -> Outcome {
        guard newRank > previousRank, newLevel != .soil else {
            return .neutral
        }

        let seedRank = JournalCompletionLevel.seed.tutorialCompletionRank
        let harvestRank = JournalCompletionLevel.harvest.tutorialCompletionRank

        let crossedSeedTier = previousRank < seedRank && newRank >= seedRank
        let crossedHarvestTier = previousRank < harvestRank && newRank >= harvestRank

        let recordSeed = crossedSeedTier && !hasCelebratedFirstSeed
        let recordHarvest = crossedHarvestTier && !hasCelebratedFirstHarvest

        let highlight: JournalUnlockMilestoneHighlight
        switch newLevel {
        case .seed where recordSeed:
            highlight = .firstSeed
        case .harvest where recordHarvest:
            highlight = .firstFifteenChipHarvest
        case .abundance where recordHarvest:
            highlight = .firstFifteenChipHarvestWithFullRhythm
        default:
            highlight = .none
        }

        return Outcome(
            recordFirstSeedCelebrated: recordSeed,
            recordFirstHarvestCelebrated: recordHarvest,
            milestoneHighlight: highlight
        )
    }
}
