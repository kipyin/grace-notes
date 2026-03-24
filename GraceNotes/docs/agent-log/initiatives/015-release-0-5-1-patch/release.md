---
initiative_id: 015-release-0-5-1-patch
role: Release Manager
status: in_progress
updated_at: 2026-03-24
related_issue: none
related_pr: none
---

# Release 0.5.1 (patch)

## Base and version check

- **Branch:** `main` (local release branch `release/0.5.1` was removed; integrate from `main`).
- **Marketing version:** `0.5.1` in Xcode (`MARKETING_VERSION`).
- **Bundle version:** `CURRENT_PROJECT_VERSION` **3** for Grace Notes app targets (Debug, Release, Demo)—CHANGELOG/README must stay in sync.

## Branch plan

- Land 0.5.1 work via **`main`** (or recreate `release/0.5.1` from `main` only if the team still uses that PR flow).

## Documentation check

- **CHANGELOG:** 0.5.1 **Unreleased** includes upgrade orientation, packaging, cloud/locale work, and post-Seed journey preview + onboarding welcome trim; bundle **3** documented in Developer section.
- **README:** “What’s new in 0.5.1” matches scope above; build **3** called out under Packaging.
- **Roadmap:** `GraceNotes/docs/07-release-roadmap.md` — **0.5.0** marked **Released (2026-03-21)**; **0.5.1** has release-status blurb (integrate from **`main`**).

## Merge / release readiness

- **Docs:** Marketing/build copy aligned with `project.pbxproj` (2026-03-24 pass).
- **Still open before “shipped”:** Set **Unreleased** to a date when tagging; run **QA Reviewer** matrix (issue-71 `qa.md` / `testing.md`); confirm team stance on **GraceNotes.xcscheme** Run = **Release**.

## Decision

**Documentation:** Ready for tag planning once QA signs off; no remaining known drift between Xcode bundle **3** and CHANGELOG/README.

## Open questions

- Keep or revert **GraceNotes.xcscheme** Run on **Release** for default ⌘R?
- **`lastLaunchedMarketingVersion`** edge cases if support reports missed upgrade orientation.

## Next owner

- **QA Reviewer** — cohort matrix and simulator/device pass for 0.5.1.
- **Test Lead** — manual rows in `011-issue-71-guided-onboarding/testing.md`.
