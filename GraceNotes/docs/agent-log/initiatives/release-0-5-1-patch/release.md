---
initiative_id: release-0-5-1-patch
role: Release Manager
status: in_progress
updated_at: 2026-03-23
related_issue: none
related_pr: none
---

# Release 0.5.1 (patch)

## Base and version check

- **Branch:** `release/0.5.1` (tracks `origin/release/0.5.1`).
- **Marketing version:** `0.5.1` per project settings (see `CHANGELOG` Developer section).

## Branch plan

- Work continues on **`release/0.5.1`**; no second release branch for this patch line.

## Commit plan (landed)

- `134b236` — `feat: version-gated 0.5.1 upgrade orientation and Seed branch` (app launch version tracker, onboarding progress branch, PostSeed skip-congrats, tests, roadmap, issue-71 QA/testing).

## Inputs reviewed

- `README.md`, `CHANGELOG.md` (changelog updated for upgrade orientation)
- `GraceNotes/docs/07-release-roadmap.md` (0.5.1 orientation note)
- `GraceNotes/docs/agent-log/initiatives/issue-71-guided-onboarding/qa.md`, `testing.md`
- Base history: `release/0.5.0` at branch creation (`origin/main` may lag)

## Documentation check

- **CHANGELOG:** Added **Added** bullet for 0.5.1 upgrade orientation cohort behavior.
- **Roadmap:** Present in tree with 0.5.1 orientation scope.
- **README:** No app-facing README change required for this behavior-only patch.

## Merge / release readiness

- **Code + docs:** Orientation feature committed; changelog aligned.
- **Still open:** QA sign-off on scheme **Run = Release** (developer ergonomics); full manual cohort matrix per issue-71 `testing.md` / `qa.md` before calling the release “fully verified.”

## Decision

**Merge to main (or next integration branch):** Ready for **PR + CI** once team accepts scheme/Debug question; product verification follows issue-71 QA conditions.

## Open questions

- Revert or keep `GraceNotes.xcscheme` **Run** on **Release** for default ⌘R?
- Strategist confirmation on **missing `lastLaunchedMarketingVersion`** (upgrade cohort edge case), if support sees missed orientations.

## Next owner

- **QA Reviewer** — final intent vs. implementation on 0.5.1 cohort matrix; scheme ergonomics.
- **Test Lead** — tick manual rows in `issue-71-guided-onboarding/testing.md` after simulator/device runs.
