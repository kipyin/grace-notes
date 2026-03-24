# Agent Log Schema

This schema is intentionally lightweight. Prioritize decision quality over formatting.

## Required Sections (all role files)

- `Decision`
- `Open Questions` (use `None` if no blockers)
- `Next Owner`

## Recommended Sections

- `Inputs Reviewed`
- `Rationale`
- `Risks`

## Optional Frontmatter

Use when helpful:

```yaml
---
initiative_id: 001-guided-onboarding
role: Strategist
status: in_progress
updated_at: 2026-03-24
related_issue: 71
related_pr: 79
---
```

`initiative_id` must match the initiative directory name. Use `related_issue` / `related_pr` for GitHub numbers; the `NNN-` prefix is only the next free sequence id (see `.agents/skills/agent-log/SKILL.md`).

## Pushback Entry Schema

When documenting deferrals in `pushback.md`, include:

- `Constraint`
- `Current Impact`
- `Not-Now Decision`
- `Revisit Trigger`

## Small-Change Fast Path

For low-risk work, concise updates are acceptable as long as:

- the update has `Decision`, `Open Questions`, and `Next Owner`
- the next owner can continue without out-of-band chat context
