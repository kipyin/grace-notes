import XCTest
@testable import GraceNotes

final class JournalTutorialUnlockEvaluatorTests: XCTestCase {
    func test_outcome_soilToSeed_firstSeed() {
        let outcome = JournalTutorialUnlockEvaluator.outcome(
            previousRank: JournalCompletionLevel.soil.tutorialCompletionRank,
            newRank: JournalCompletionLevel.seed.tutorialCompletionRank,
            newLevel: .seed,
            hasCelebratedFirstSeed: false,
            hasCelebratedFirstHarvest: false
        )
        XCTAssertTrue(outcome.recordFirstSeedCelebrated)
        XCTAssertFalse(outcome.recordFirstHarvestCelebrated)
        XCTAssertEqual(outcome.milestoneHighlight, .firstSeed)
    }

    func test_outcome_seedToHarvest_firstHarvest() {
        let outcome = JournalTutorialUnlockEvaluator.outcome(
            previousRank: JournalCompletionLevel.seed.tutorialCompletionRank,
            newRank: JournalCompletionLevel.harvest.tutorialCompletionRank,
            newLevel: .harvest,
            hasCelebratedFirstSeed: true,
            hasCelebratedFirstHarvest: false
        )
        XCTAssertFalse(outcome.recordFirstSeedCelebrated)
        XCTAssertTrue(outcome.recordFirstHarvestCelebrated)
        XCTAssertEqual(outcome.milestoneHighlight, .firstFifteenChipHarvest)
    }

    func test_outcome_soilToHarvest_rankSkip_recordsBoth_highlightsHarvest() {
        let outcome = JournalTutorialUnlockEvaluator.outcome(
            previousRank: JournalCompletionLevel.soil.tutorialCompletionRank,
            newRank: JournalCompletionLevel.harvest.tutorialCompletionRank,
            newLevel: .harvest,
            hasCelebratedFirstSeed: false,
            hasCelebratedFirstHarvest: false
        )
        XCTAssertTrue(outcome.recordFirstSeedCelebrated)
        XCTAssertTrue(outcome.recordFirstHarvestCelebrated)
        XCTAssertEqual(outcome.milestoneHighlight, .firstFifteenChipHarvest)
    }

    func test_outcome_soilToAbundance_rankSkip_recordsBoth_highlightsHarvestWithRhythm() {
        let outcome = JournalTutorialUnlockEvaluator.outcome(
            previousRank: JournalCompletionLevel.soil.tutorialCompletionRank,
            newRank: JournalCompletionLevel.abundance.tutorialCompletionRank,
            newLevel: .abundance,
            hasCelebratedFirstSeed: false,
            hasCelebratedFirstHarvest: false
        )
        XCTAssertTrue(outcome.recordFirstSeedCelebrated)
        XCTAssertTrue(outcome.recordFirstHarvestCelebrated)
        XCTAssertEqual(outcome.milestoneHighlight, .firstFifteenChipHarvestWithFullRhythm)
    }

    func test_outcome_firstSeedAlreadyCelebrated_noDuplicateRecord() {
        let outcome = JournalTutorialUnlockEvaluator.outcome(
            previousRank: JournalCompletionLevel.soil.tutorialCompletionRank,
            newRank: JournalCompletionLevel.seed.tutorialCompletionRank,
            newLevel: .seed,
            hasCelebratedFirstSeed: true,
            hasCelebratedFirstHarvest: false
        )
        XCTAssertFalse(outcome.recordFirstSeedCelebrated)
        XCTAssertEqual(outcome.milestoneHighlight, .none)
    }

    func test_outcome_harvestToAbundance_noHarvestRecordWhenAlreadyCelebrated() {
        let outcome = JournalTutorialUnlockEvaluator.outcome(
            previousRank: JournalCompletionLevel.harvest.tutorialCompletionRank,
            newRank: JournalCompletionLevel.abundance.tutorialCompletionRank,
            newLevel: .abundance,
            hasCelebratedFirstSeed: true,
            hasCelebratedFirstHarvest: true
        )
        XCTAssertEqual(outcome, JournalTutorialUnlockEvaluator.Outcome.neutral)
    }

    func test_outcome_rankUnchanged_returnsNeutral() {
        let outcome = JournalTutorialUnlockEvaluator.outcome(
            previousRank: 1,
            newRank: 1,
            newLevel: .seed,
            hasCelebratedFirstSeed: false,
            hasCelebratedFirstHarvest: false
        )
        XCTAssertEqual(outcome, JournalTutorialUnlockEvaluator.Outcome.neutral)
    }
}
