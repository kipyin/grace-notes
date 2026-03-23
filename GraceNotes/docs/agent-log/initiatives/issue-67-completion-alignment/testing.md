# Issue #67 — Testing notes

## Automated (intended)

- `JournalCompletionLevelTests` — harvest vs abundance predicates on `JournalEntry`.
- `StreakCalculatorTests` — harvest-only vs abundance; legacy `completedAt` does not inflate perfect streak.
- `JournalViewModelCompletionAndLimitsTests` — existing `completedToday` / chip completion cases (unchanged expectations; `completedToday` still Abundance-only).

## Execution

- **2026-03-22 (macOS):** Focused run succeeded:

  `xcodebuild -project GraceNotes/GraceNotes.xcodeproj -scheme GraceNotes -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:GraceNotesTests/JournalCompletionLevelTests -only-testing:GraceNotesTests/StreakCalculatorTests test`

## SwiftData in unit tests

- `@Model` `JournalEntry` instances must be **inserted** into a `ModelContext` backed by a `ModelContainer` before reading or mutating persistent properties; otherwise the test host can fatal-error (`failed to find a currently active container for JournalEntry`).
- `JournalCompletionLevelTests` / `StreakCalculatorTests` use a throwaway on-disk in-memory store URL per run (same pattern as `JournalViewModelCompletionAndLimitsTests.makeInMemoryContext`).

## Risk map (focused pass)

| Area | Risk | Mitigation |
|------|------|------------|
| Completion predicates | Wrong harvest vs abundance split | `JournalCompletionLevelTests` + static `completionLevel` cases |
| Perfect streak inflation | `completedAt` without Abundance | `StreakCalculatorTests.test_staleCompletedAt_*` |
| Detached model access | Host crash, flaky “failed” tests | Persist entries in tests before `StreakCalculator.summary` |

## Coverage adequacy

- **Go** for issue #67 completion semantics in the suites above: predicates and streak rules are covered; VM paths remain on `JournalViewModelCompletionAndLimitsTests` (skipped in simulator when `skipIfKnownHostedSwiftDataCrash` applies — intentional).

## Next owner

- **QA Reviewer:** Simulator 简体中文 spot-check (pill, Review, VoiceOver) per plan.
- **Builder:** If parallel test runs flake on CI, prefer `-parallel-testing-enabled NO` for GraceNotes scheme or split UI vs unit jobs.
