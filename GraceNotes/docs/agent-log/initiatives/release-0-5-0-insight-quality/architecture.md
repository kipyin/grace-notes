---
initiative_id: release-0-5-0-insight-quality
role: Architect
status: in_progress
updated_at: 2026-03-23
related_issue: 40
related_pr: none
---

# Architecture — Issue #40 (Review insight quality)

## Decision

- **Evidence gate:** Skip the cloud Review path unless the current ISO week contains at least **three** `JournalEntry` rows with `hasMeaningfulContent` (completion above `.soil`). Enforced in `ReviewInsightsProvider` and defensively in `CloudReviewInsightsGenerator`.
- **Quality gate:** After `CloudReviewInsightsSanitizer`, require non-empty recurring lists and that narrative, resurfacing, and continuity each mention at least one recurring label; continuity must not match the generic-phrase list. Failure throws `CloudReviewInsightsError.failedQualityGate` so the provider falls back to deterministic insights.
- **Shared helper:** `ReviewInsightsCloudEligibility` centralizes week range and meaningful-entry counting so provider and tests stay aligned.

## Open questions

- None for this slice.

## Next owner

- **QA Reviewer:** Simulator pass with AI on/off and weeks with 0–2 vs 3+ meaningful entries; confirm source chip matches path.
- **Test Lead:** Run `GraceNotesTests` on macOS (`make test`); Linux agents cannot run XCTest.
