---
initiative_id: release-0-5-0-insight-quality
role: Builder
status: in_progress
updated_at: 2026-03-23
related_issue: 40
---

# Testing notes — #40 Review cloud eligibility and quality gate

## Automated (macOS + Xcode)

- `GraceNotesTests/Features/Journal/ReviewInsightsProviderTests.swift` — provider skips cloud when `<3` meaningful rows; cloud path when `≥3` stubs.
- `GraceNotesTests/Features/Journal/CloudReviewInsightsGeneratorTests.swift` — generator requires `≥3` meaningful rows; empty recurring lists fail quality gate; success paths use three in-week entries.

## Execution attempts

- **2026-03-23:** `xcodebuild test` for `ReviewInsightsProviderTests`, `CloudReviewInsightsGeneratorTests`, and `DeterministicReviewInsightsTests` — **app target built**, but the Simulator failed to launch the test host (`FBSOpenApplicationServiceErrorDomain` / `RequestDenied`). Re-run locally after resetting or picking a healthy simulator (`make test` or Xcode).

## Not run in CI (Linux)

- XCTest — not available per `AGENTS.md`.
