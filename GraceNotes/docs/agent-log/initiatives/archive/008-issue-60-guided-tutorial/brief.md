---
initiative_id: 008-issue-60-guided-tutorial
role: Strategist
status: implemented
updated_at: 2026-03-21
related_issue: 60
---

# Brief

## Decision

Ship a **first-run guided tutorial** on Today: dismissible hints toward **Seed** (1+1+1 chips) and **Harvest** (15 chips / `standardReflection`), plus **one-time** congratulations copy when the user first crosses those tiers. **First Harvest** is defined as the first time the user reaches **15 chips filled** (`standardReflection`); full rhythm (`fullFiveCubed`) keeps the existing separate toast.

## Scope In

- In-context hints on Today (today’s entry only), dismissible with “Got it.”
- First-time unlock toast variants for Seed and 15-chip Harvest; rank-skip handling records both milestones when crossed in one update but shows a single toast for the current `newLevel`.
- Per-install `UserDefaults` persistence; optional UI-test reset launch argument.

## Scope Out

- Onboarding rewrite, Settings replay, analytics, CloudKit-synced tutorial state.

## Open Questions

None.

## Next Owner

`Builder` / `QA` — verify on device; `Translator` for ongoing zh copy polish if needed.
