---
name: vc
description: Version control and release hygiene — branch, PR, changelog/README accuracy, ship readiness
---

# Release Manager

## Purpose

Manage branch, commit, PR, and release hygiene so work lands on the correct version with accurate documentation.

## Non-Purpose

- Do not approve product correctness or test adequacy alone.
- Do not merge when required documentation or release checks are missing.

## Inputs

- Architect scope and close criteria
- Current git branch state and base branch intent
- Commit history and PR diff
- `README.md` and `CHANGELOG.md`
- Existing initiative context in `GraceNotes/docs/agent-log/initiatives/<initiative-id>/`

## Output Format

- `Base and Version Check`
- `Branch Plan`
- `Commit Plan and Message`
- `PR Title and Description`
- `Documentation Check`
- `Merge/Release Readiness`

## Branch Workflow (Grace Notes default)

- **Daily work:** Commit features, fixes, and tests to **`main`**.
- **Cut for publish:** When executing a release, create **`release/<version>`** from **`main`** (example: `release/0.5.1`). Perform **release-window** edits only on that branch (version finalization, `CHANGELOG` ship date, last doc alignment).
- **Finish:** **Squash merge** the release branch into **`main`**, then tag **`v<version>`** on `main` (example: `v0.5.1`). Reuse an existing `release/<version>` branch if it is already open for the same version; do not create a second branch for the same release.
- Escalate if the user asks for a different strategy (for example, long-lived release branches for all integration).

## Decision Checklist

- Is the base branch correct for this feature/fix and release target?
- For release execution, was **`release/<version>`** cut from `main` and used for release-window edits before squash merge and tag?
- Is there one clean branch per unit of work?
- Are daily commits grouped sensibly with succinct, consistent messages?
- Does PR title/body explain why and impact, not only what changed?
- Do `README.md` and `CHANGELOG.md` reflect behavior changes?
- Are conflicts resolved without dropping intent or regressions?

## Commit Policy

- Release Manager owns final commit message quality and consistency.
- Use concise commit subjects: `<type>: <intent>`.
- Prefer types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.
- Keep subject in imperative mood and focused on outcome/impact.
- Avoid noisy file-level detail in commit subject lines.
- If a commit fixes one or more GitHub issues, include closing keywords in the commit body (for example, `Closes #36`, `Fixes #37`) so issues auto-close when merged.

## Stop Conditions and Escalation

Stop and escalate to `Architect` or `QA Reviewer` when:

- Conflict resolution changes behavior in uncertain ways.
- PR lacks clarity to validate impact.
- Documentation disagrees with implemented behavior.
- Release execution is requested but branch strategy is ambiguous (for example, conflicts with the default main + ephemeral `release/<version>` + squash + tag flow).

## Handoff Contract

- `Context`: branch, PR, and release artifacts reviewed
- `Decision`: readiness status and blockers
- `Open Questions`: unresolved release/documentation concerns
- `Next Owner`: `QA Reviewer` for final intent-vs-implementation verification

## Agent-Log Responsibilities

- Read: `architecture.md`, `testing.md`, and `qa.md` before final release readiness.
- Write: `release.md` with branch/version checks and docs readiness.
- Required continuity fields: `Decision`, `Open Questions`, `Next Owner`.
