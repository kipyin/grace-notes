---
initiative_id: 020-issue-84-settings-section-headers
role: Release Manager
status: in_progress
updated_at: 2026-03-24
related_issue: 84
related_pr: none
---

# Release

## Inputs Reviewed

- `qa.md`, `testing.md`, `architecture.md`.
- [CHANGELOG.md](../../../../../CHANGELOG.md) **[0.5.2] — Unreleased** already lists: “Settings: section headers use authored title case…” (#84). No CHANGELOG edit required for this implementation.
- Default workflow: feature/fix commits to **`main`** per `.agents/skills/vc/SKILL.md`.

## Decision

Release Readiness: **Ready to commit** to `main` after your **UAT** and optional local **`xcodebuild test`** confirmation (see `testing.md`).

## Rationale

- Single cohesive change set: Swift presentation modifiers + agent-log + initiative docs.
- Version lane: **0.5.2** (milestone on issue #84).

## Risks

- Low. If `CHANGELOG` ship section for 0.5.2 is edited elsewhere, avoid duplicate bullets for the same fix.

## Open Questions

- None.

## Next Owner

**You (human)** — UAT, then commit and open PR (or push to `main` if that is your practice). Set `related_pr` in initiative frontmatter when the PR exists.

### Base and Version Check

- **Base:** `main`.
- **Marketing version:** stays on **0.5.2** unreleased until release cut; no version bump required for this fix alone.

### Branch Plan

- Optional topic branch: `fix/settings-section-header-title-case-84` or commit directly on `main`.

### Commit Plan and Message

- One commit is enough, e.g.  
  **`Settings: title-case section headers via .textCase(nil) (#84)`**

### PR Title and Description

- **Title:** `Settings: title-case list section headers (#84)`
- **Body:** Link issue #84; note `testing.md` caveat on `xcodebuild` exit 65 vs 0 failing tests in GraceNotesTests log; ask reviewer to run tests locally if needed.

### Documentation Check

- [CHANGELOG.md](../../../../../CHANGELOG.md): **already** mentions #84 under 0.5.2.
- [README.md](../../../../../README.md): no update required.

### Merge/Release Readiness

- Merge when UAT + tests (as you define) are green; update initiative YAML `related_pr` and optionally `status` after PR open/merge.
