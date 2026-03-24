---
initiative_id: 020-issue-84-settings-section-headers
role: Strategist
status: in_progress
updated_at: 2026-03-24
related_issue: 84
related_pr: none
---

# Brief

## Inputs Reviewed

- GitHub [#84](https://github.com/kipyin/grace-notes/issues/84) — Settings section headers appear ALL CAPS; Help already uses `.textCase(nil)`.
- Milestone: 0.5.2 — Settings cohesion.

## Decision

Ship consistent **title case** (or catalog-defined casing) for all **Settings** `List` section headers by opting out of SwiftUI’s default uppercase header styling everywhere those headers are defined, matching the existing Help section pattern. Keep string catalog source strings authoritative; do not rely on automatic capitalization.

## Rationale

All-caps section labels feel shouty and inconsistent next to Help. Aligning presentation improves readability and Settings cohesion with minimal product risk.

## Risks

- Low: purely presentational; wrong file missed leaves one section still all-caps (mitigate by checklist in architecture close criteria).

## Open Questions

- None.

## Next Owner

**Architect** — produce `architecture.md` with goals, non-goals, affected files, and testable close criteria; then **Builder**.
