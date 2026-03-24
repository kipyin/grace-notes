# Issue #67 — Journal completion alignment

## Decision

- **Harvest (chips only):** `JournalEntry.hasHarvestChips` / `isComplete` / `hasAllFifteenChips`. `completionLevel == .harvest` when all slots are filled and long-form text does not yet satisfy `criteriaMet`.
- **Abundance (fullness, internal):** `JournalEntry.hasAbundanceRhythm` / `criteriaMet` / `completionLevel == .abundance`. User-facing label remains **Abundance**.
- **`completedAt`:** Set on first reach of **harvest** (5/5/5 chips), cleared if chips drop below full. It does **not** mean Abundance and must not drive “perfect” streaks.
- **`JournalViewModel.completedToday`:** **Abundance** only (`criteriaMet` on current draft fields).
- **StreakCalculator:** **Basic** = `hasMeaningfulContent` (any tier above Soil). **Perfect** = `hasAbundanceRhythm` only (no `completedAt` fallback).
- **Weekly insight “full completion” candidate:** Still “all 15 chips each day” → `hasHarvestChips` (unchanged product meaning for that insight).
- **Export/import:** `completedAt` remains an opaque persisted field; correctness relies on save path and user edits, not streak logic.

## Open questions

- None for this slice; `zh-Hant` remains out of scope per issue.

## Next owner

- **QA Reviewer:** Simulator spot-check 简体中文 (pill, Review row, VoiceOver hints, unlock toasts).
- **Test Lead:** Run `GraceNotesTests` on macOS when convenient; Linux agent cannot execute XCTest.
