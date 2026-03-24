# Agent Log Index

`agent-log` is the canonical place for cross-role coordination.

## Active initiatives

- *No active initiatives.* Shipped or superseded work: [`initiatives/archive/README.md`](initiatives/archive/README.md). New work uses the next id in [`initiatives/README.md`](initiatives/README.md) (**019**).

## Archived initiatives

Shipped or superseded handoffs: [`initiatives/archive/`](initiatives/archive/README.md) (see table there).

## Initiative directory convention

**New initiatives** use a monotonic three-digit prefix and a short kebab-case name: `NNN-name` (example: `001-guided-onboarding`).

- `GraceNotes/docs/agent-log/initiatives/001-guided-onboarding`

Initiative directory names use the `NNN-` prefix; GitHub issue/PR numbers belong in YAML frontmatter, not as the numeric prefix.

Lifecycle scaffolding (start, index/archive upkeep, validation) is described in `.agents/skills/agent-log/SKILL.md`.

**End-to-end pipeline (Strategist → … → UAT handoff),** single chat or multi-chat relay with auto-generated next prompts: [MASTER-RUN.md](./MASTER-RUN.md).

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
