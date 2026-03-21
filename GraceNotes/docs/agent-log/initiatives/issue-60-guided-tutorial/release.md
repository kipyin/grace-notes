---
initiative_id: issue-60-guided-tutorial
role: Release Manager
status: complete
updated_at: 2026-03-21
related_issue: 60
---

# Release Handoff

## Base and Version Check

- **Target release branch:** `release/0.5.0`
- **Version intent:** first-run Today tutorial (Seed/Harvest hints and one-time toasts) ships under the existing `0.5.0` line alongside roadmap insight-quality work.

## Branch Plan

- All tutorial implementation, tests, app icon packaging tweak, agent-log, and user-facing docs were committed on `release/0.5.0`.

## Commit Plan and Message (executed)

1. `chore: app icon dark/tinted variants and catalog build flag` — App Icon assets + `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS=NO`.
2. `feat: first-run Today tutorial for Seed and Harvest` — `Features/Journal/Tutorial/*`, `JournalScreen`, `JournalUnlockToastView`, `GraceNotesApp`, `Localizable.xcstrings` (`Closes #60`).
3. `test: journal tutorial unlock evaluation and UI test support` — `JournalTutorialUnlockEvaluatorTests`, `JournalUITests`.
4. `docs: agent-log for issue-60 guided tutorial` — initiative brief/architecture/design + `index.md`.
5. `docs: readme and changelog for guided tutorial (0.5.0)` — root `README.md`, `CHANGELOG.md`.

## PR Title and Description

- **PR title:** `release: 0.5.0 — guided journal tutorial (#60)`
- **PR description:** Summarize first-run Seed/Harvest hints, one-time unlock toasts, per-install persistence, UI-test reset argument, and app icon catalog flag; point to `CHANGELOG.md` and `GraceNotes/docs/agent-log/initiatives/issue-60-guided-tutorial/`.

## Documentation Check

- `README.md` “What’s new in 0.5.0” includes the first-run tutorial bullet.
- `CHANGELOG.md` `[0.5.0] — Unreleased` **Added** includes the tutorial entry (`#60`).
- Initiative `brief.md` / `architecture.md` / `design.md` present and linked from `docs/agent-log/index.md`.

## Merge/Release Readiness

- **Decision:** Documentation matches committed behavior; branch is ready for PR and QA verification on Simulator/device.
- **Open Questions:** None for release packaging; confirm zh copy polish with Translator if desired.
- **Next Owner:** `QA Reviewer` — intent vs. implementation and UI test pass on macOS/Xcode.
