---
initiative_id: 015-release-0-5-1-patch
role: Release Manager
status: completed
updated_at: 2026-03-25
related_issue: none
related_pr: none
---

# Release 0.5.1 (patch)

## Inputs Reviewed

- `brief.md`, `architecture.md`, `testing.md`, `qa.md` (015) — QA **Pass**; Test **Go**; manual Dynamic Type (matrix B) recorded.
- `CHANGELOG.md`, `README.md`, `GraceNotes/docs/07-release-roadmap.md` — dated and aligned for ship **2026-03-24**.

## Release workflow (Grace Notes)

1. **Ongoing development:** All commits land on **`main`** (features, fixes, tests).
2. **Cut for publish:** When ready to ship this version, create **`release/0.5.1`** from **`main`** (e.g. `git checkout -b release/0.5.1 main`). Only **release-window** edits happen on this branch (final version strings if needed, `CHANGELOG` date, last doc tweaks, anything that must ship with the tag).
3. **Land and tag:** When the release branch is ready, **squash merge** it back into **`main`** (one consolidated commit on `main`), then tag **`v0.5.1`** on the resulting `main` tip. Remove the release branch after merge if you no longer need it.

This keeps day-to-day history linear on `main` while still isolating the final ship slice for review and a single squash commit.

**This ship:** Consolidated **0.5.1** work committed on **`main`** with `CHANGELOG` / README / roadmap updated here; lightweight tag on **`main`** is acceptable when the diff is already reviewed (ephemeral `release/0.5.1` optional if you prefer the strict squash slice).

## Base and version check

- **Active development branch:** **`main`**.
- **Marketing version:** `0.5.1` in Xcode (`MARKETING_VERSION`).
- **Bundle version:** `CURRENT_PROJECT_VERSION` **3** for Grace Notes app targets (Debug, Release, Demo)—CHANGELOG/README match.

## Branch plan

- **Shipped from `main`** with documentation finalization in this commit set; tag **`v0.5.1`** on the release tip.
- Remote **`origin/release/0.5.1`** may exist from earlier work—reconcile or delete after confirming it is not needed.

## Commit plan and message

- **Type:** `chore(release)` (or `docs` + `feat` split if you prefer smaller commits).
- **Subject (example):** `chore(release): ship Grace Notes 0.5.1`
- **Body:** Point to `CHANGELOG.md` `[0.5.1]`, initiative **015**, QA `qa.md` Pass.

## PR title and description

- If you open a PR instead of direct push: title **`Release 0.5.1`**; body = CHANGELOG **0.5.1** summary + test note from `testing.md`.

## Documentation check

- **CHANGELOG:** `[0.5.1] - 2026-03-24` — upgrade orientation, copy, cloud/locale, fixes, packaging; bundle **3** in Developer section.
- **README:** “What’s new in 0.5.1 **(2026-03-24)**”; build **3** under Packaging.
- **Roadmap:** `GraceNotes/docs/07-release-roadmap.md` — **0.5.1** **Released (2026-03-24)**.

## Merge / release readiness

- **QA:** **Pass** in `qa.md` (residual matrix **A** documented).
- **Testing:** **Go** in `testing.md`; automated `xcodebuild` green on recorded destination.
- **Docs / versions:** Marketing **0.5.1**, bundle **3**, CHANGELOG dated — aligned.

## Rationale

Release-window documentation and tag complete the agent-log pipeline; store submission remains a separate human step (App Store Connect, screenshots, etc.).

## Risks

- Matrix **A** (install-over-upgrade) not manually run—mitigated by unit coverage per `qa.md`; consider one smoke before App Store if not done.
- **GraceNotes.xcscheme** Run = **Release** may surprise contributors using ⌘R for Debug.

## Decision

**Ship:** **`main`** at **`0759f61`** and annotated tag **`v0.5.1`** **pushed to `origin`** (all release work on `main`, no separate release branch for this tag).

## Open Questions

- Team policy: keep **Release** as default Run in shared scheme vs document local revert only.
- Optional matrix **A** before App Store.

## Next Owner

**Human** — App Store Connect / external distribution if applicable. **agent-log:** archive initiative **015** when you want it off the active list (`GraceNotes/docs/agent-log/index.md`).
