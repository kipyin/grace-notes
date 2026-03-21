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
        guard newRank > previousRank, newLevel != .none else {
            return .neutral
        }

        let crossedSeedTier = previousRank < JournalCompletionLevel.quickCheckIn.tutorialCompletionRank
            && newRank >= JournalCompletionLevel.quickCheckIn.tutorialCompletionRank
        let crossedHarvestTier = previousRank < JournalCompletionLevel.standardReflection.tutorialCompletionRank
            && newRank >= JournalCompletionLevel.standardReflection.tutorialCompletionRank

        let recordSeed = crossedSeedTier && !hasCelebratedFirstSeed
        let recordHarvest = crossedHarvestTier && !hasCelebratedFirstHarvest

        let highlight: JournalUnlockMilestoneHighlight
        switch newLevel {
        case .quickCheckIn where recordSeed:
            highlight = .firstSeed
        case .standardReflection where recordHarvest:
            highlight = .firstFifteenChipHarvest
        case .fullFiveCubed where recordHarvest:
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
