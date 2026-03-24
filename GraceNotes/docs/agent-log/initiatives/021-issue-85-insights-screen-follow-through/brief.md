---
initiative_id: 021-issue-85-insights-screen-follow-through
role: Strategist
status: in_progress
updated_at: 2026-03-24
related_issue: 85
related_pr: none
---

# Brief

## Inputs Reviewed

- GitHub [#85](https://github.com/kipyin/grace-notes/issues/85) — Design critique: Review Insights screen follow-through and hierarchy polish (Review > Insights, weekly summary card; `ReviewScreen`, `ReviewSummaryCard`). Milestone: 0.5.2 — Settings cohesion and insight follow-through.
- Issue proposes acceptance checks: thin-week CTA to continue journaling; top spacing rhythm; panel hierarchy (This week → thread → next step); clearer segmented-control selected state; microcopy review for “A thread” and source wording with localization.

## Decision

Deliver **Review > Insights** polish so the weekly summary screen stays calm and supportive while improving **follow-through** and **visual hierarchy**: when insight signal is thin, surface **one obvious next action** (continue journaling today); tighten **spacing above the first card** so content feels immediate; make **This week** clearly lead **A thread** and **A next step** without adding visual noise; make **Timeline vs Insights** mode **easier to read at a glance**; complete a **microcopy pass** for the thread label and source line with **English + Chinese parity**. Treat Dynamic Type and truncation as part of acceptance.

## Rationale

The screen already matches tone; the gap is behavioral and scannable structure—users should not leave low-signal weeks without a clear path to improve next week’s insight quality, and first visit should not feel like empty space or flat panels.

## Risks

Nested cards can feel repetitive if contrast and borders are pushed further; friendlier “on-device” wording must not undermine trust. Large Dynamic Type could collapse hierarchy if not verified on device.

## Open Questions

- Preferred final label for the thread panel (`A thread` vs alternatives) pending copy and localization check.
- Exact CTA string and deep-link behavior to **Today** (copy + analytics/none).

## Next Owner

**Designer** — produce `design.md` (states: thin week vs rich week, segmented control specs, panel hierarchy and spacing tokens intent, CTA placement) for handoff to **Architect**.

`Architect` should:
