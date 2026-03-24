# Agent Log Index

`agent-log` is the canonical place for cross-role coordination.

## Active initiatives

- [`011-issue-71-guided-onboarding`](initiatives/011-issue-71-guided-onboarding) — PR **#79** / epic **#71** (`qa.md`, `testing.md`)
- [`015-release-0-5-1-patch`](initiatives/015-release-0-5-1-patch) — **0.5.1** patch line, integrate from **`main`** (`release.md`)

## Archived initiatives

Shipped or superseded handoffs: [`initiatives/archive/`](initiatives/archive/README.md) (see table there).

## Initiative directory convention

**New initiatives** use a monotonic three-digit prefix and a short kebab-case name: `NNN-name` (example: `001-guided-onboarding`).

- `GraceNotes/docs/agent-log/initiatives/001-guided-onboarding`

Initiative directory names use the `NNN-` prefix; GitHub issue/PR numbers belong in YAML frontmatter, not as the numeric prefix.

Lifecycle scaffolding (start, index/archive upkeep, validation) is described in `.agents/skills/agent-log/SKILL.md`.

## Fast path (small changes)

For small changes, add one concise update with:

- `Decision`
- `Open Questions` (`None` if no blockers)
- `Next Owner`

## Full path (multi-day or high-risk)

For larger efforts, keep role files in the initiative folder:

- `brief.md`
- `design.md` (optional; **Designer** output for UI-heavy work — specs and acceptance for front end)
- `architecture.md`
- `qa.md`
- `testing.md`
- `release.md`
- `pushback.md` (optional)
