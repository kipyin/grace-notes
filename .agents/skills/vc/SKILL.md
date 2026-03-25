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

## Versioning (TestFlight default)

- **Marketing version** (`CFBundleShortVersionString` / `MARKETING_VERSION`) stays **fixed** for a roadmap **line** until product intentionally opens the next line (for example **`0.5.0`** across multiple drops, then **`0.6.0`** when that minor is declared).
- **Build** (`CFBundleVersion` / `CURRENT_PROJECT_VERSION`) **increments every** App Store Connect / TestFlight binary (**`7` → `8` → …**). Faster review cycles use same marketing + new build, not a new patch digit.
- **Git annotated tags** encode both: **`v{marketing}+{build}`** (SemVer build metadata), e.g. **`v0.5.0+7`**, **`v0.5.0+8`**. If a tool chokes on **`+`**, fallback **`v0.5.0-build8`** — prefer **`+`** when everything accepts it.
- **CHANGELOG / README:** One **`[0.5.0]`** section can accumulate several dated ship notes; call out **build** in **Developer** (and anywhere users care about “which binary”).
- **Orientation / upgrade gates** in app code must use **marketing + build** (or an explicit build threshold) when behavior must fire across **same-marketing** updates — not marketing alone.

Roadmap headings (for example **0.5.2 — …**) name **scope lanes** and GitHub milestones; they do **not** imply a new marketing patch for every lane unless product says so.

## Branch Workflow (Grace Notes default)

- **Daily work:** Commit features, fixes, and tests to **`main`**.
- **Cut for publish:** When executing a release, create **`release/<line-or-build>`** from **`main`**. Examples: reuse **`release/0.5.0`** across several builds, or a one-off **`release/0.5.0-build8`** for a single cut. Perform **release-window** edits only on that branch (bump **build**, `CHANGELOG` ship note/date, last doc alignment). **Marketing** changes only when opening a new line.
- **Finish:** Land the release work on **`main`** (squash merge per team habit, or merge commit if that is the agreed pattern), then tag **`v{marketing}+{build}`** on the release tip. Do not reuse the same tag name for a different commit.
- Escalate if the user asks for a different strategy (for example, long-lived release branches for all integration).

## Decision Checklist

- Is the base branch correct for this feature/fix and release target?
- For release execution, was a **`release/…`** branch cut from `main` and used for release-window edits (build bump, docs) before merge and **`v{marketing}+{build}`** tag?
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
