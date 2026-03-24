---
initiative_id: 014-release-0-5-0-insight-quality
role: Builder
status: complete
updated_at: 2026-03-24
related_issue: 40,80
---

# Testing notes — Review insights (#40 presentation, #80 engine)

**Release note:** Covers verification for insight work that shipped in **0.5.0** (**2026-03-21**). Re-run `make test` after material changes to Review cloud paths.

## Automated (macOS + Xcode)

- `GraceNotesTests/Features/Journal/ReviewInsightsProviderTests.swift` — provider skips cloud when `<3` meaningful rows; cloud path when `≥3` stubs.
- `GraceNotesTests/Features/Journal/CloudReviewInsightsGeneratorTests.swift` — generator requires `≥3` meaningful rows; empty recurring lists fail quality gate; success paths use three in-week entries.

## Execution attempts

- **2026-03-23:** `xcodebuild test` for `ReviewInsightsProviderTests`, `CloudReviewInsightsGeneratorTests`, and `DeterministicReviewInsightsTests` — **app target built**, but the Simulator failed to launch the test host (`FBSOpenApplicationServiceErrorDomain` / `RequestDenied`). Re-run locally after resetting or picking a healthy simulator (`make test` or Xcode).
- **2026-03-23:** `make test` (GraceNotes scheme, iOS Simulator) — **passed** after UI-test store reset between methods, stable add-chip accessibility identifiers, and `ApiSecrets.cloudApiKeyOverrideForTesting` in `SummarizerProviderTests`.

## Not run in CI (Linux)

- XCTest — not available per `AGENTS.md`.
