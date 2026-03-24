---
initiative_id: 014-release-0-5-0-insight-quality
role: Architect
status: complete
updated_at: 2026-03-24
related_issue: 40,80
related_pr: none
---

# Architecture — Review insight quality (#40 presentation, #80 engine)

**Release note:** Baseline below shipped in **0.5.0** (**2026-03-21**). Deeper **`#80`** iteration may continue under later roadmap items; treat this as the locked contract unless intentionally revised.

## Decision

- **Evidence gate:** Skip the cloud Review path unless the **current review period** (seven calendar days ending on the reference day) contains at least **three** `JournalEntry` rows with `hasMeaningfulContent` (completion above `.soil`). Enforced in `ReviewInsightsProvider` and defensively in `CloudReviewInsightsGenerator`.
- **Quality gate:** After `CloudReviewInsightsSanitizer`, require non-empty recurring lists and that narrative, resurfacing, and continuity each mention at least one recurring label; continuity must not match the generic-phrase list. Failure throws `CloudReviewInsightsError.failedQualityGate` so the provider falls back to deterministic insights.
- **Shared helpers:** `ReviewInsightsPeriod` defines the review window; `ReviewInsightsCloudEligibility` exposes `currentReviewPeriod` and meaningful-entry counting so provider and tests stay aligned.

## Open questions

- None for this slice.

## Next owner

None for **0.5.0** closure — routine QA and **`#80`** follow-ups use current roadmap and test plans.
