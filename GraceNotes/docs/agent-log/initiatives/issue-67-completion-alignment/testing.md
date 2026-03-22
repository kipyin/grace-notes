# Issue #67 — Testing notes

## Automated (intended)

- `JournalCompletionLevelTests` — harvest vs abundance predicates on `JournalEntry`.
- `StreakCalculatorTests` — harvest-only vs abundance; legacy `completedAt` does not inflate perfect streak.
- `JournalViewModelCompletionAndLimitsTests` — existing `completedToday` / chip completion cases (unchanged expectations; `completedToday` still Abundance-only).

## Execution

- Not run in Cursor Cloud (Linux); run `xcodebuild test` on macOS per `AGENTS.md`.
