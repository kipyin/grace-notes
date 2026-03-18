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
initiative_id: issue-41-agents-workflow
role: Strategist
status: in_progress
updated_at: 2026-03-18
related_issue: 41
related_pr: 49
---
```

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
