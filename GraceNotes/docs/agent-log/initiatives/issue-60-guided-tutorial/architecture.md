---
initiative_id: issue-60-guided-tutorial
role: Architect
status: implemented
updated_at: 2026-03-21
related_issue: 60
---

# Architecture

## Decision

- **Persistence**: `UserDefaults` keys under `journalTutorial.*` (dismiss flags + celebration flags). No SwiftData changes.
- **Rank model**: Reuse ordering consistent with `JournalScreen.rank(for:)` via `JournalCompletionLevel.tutorialCompletionRank`.
- **Unlock logic**: Pure `JournalTutorialUnlockEvaluator` computes `recordFirstSeed`, `recordFirstHarvest`, and `JournalUnlockMilestoneHighlight` from `previousRank`, `newRank`, `newLevel`, and stored flags. `JournalScreen` applies recordings after presenting toast.
- **UI**: `JournalTutorialHintView` below `DateSectionView` when `entryDate == nil` and completion state matches.

## Open Questions

None.

## Next Owner

`Test Lead` — extend UI tests if first-run flows need automation beyond launch-arg reset.

## Testing notes

- `JournalTutorialUnlockEvaluatorTests` covers rank skips and first-milestone flags.
- `UserDefaults` persistence for `JournalTutorialProgress` is thin glue; suite-based defaults are unreliable in the unit-test host, so persistence is not separately unit-tested.

## Risks (mitigated)

- **Rank skip** (`none` → `standardReflection` or `fullFiveCubed`): evaluator marks both Seed and Harvest celebrated when thresholds crossed; toast uses highest `newLevel` with appropriate first-harvest copy.
