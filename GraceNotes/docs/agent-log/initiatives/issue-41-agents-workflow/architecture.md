---
initiative_id: issue-41-agents-workflow
role: Architect
status: complete
updated_at: 2026-03-18
related_issue: 41
related_pr: 49
---

# Architecture

## Inputs Reviewed

- `brief.md` in this initiative
- Existing role skills in `.agents/skills/` (formerly `.cursor/rules/`)
- Existing `AGENTS.md`

## Decision

Implement in phases:

1. Add canonical `agent-log` directories and a minimal schema.
2. Update role rules to include explicit read/write responsibilities.
3. Add optional templates for structured outputs.
4. Add warning-mode validation in local checks.

## Rationale

This sequence enforces continuity (`Decision`, `Open Questions`, `Next Owner`) while avoiding format-heavy friction.

## Risks

- Premature strict gating can reduce delivery speed.
- Missing stage-aware validation can trigger false failures.

## Open Questions

- Should warning-mode checks move to selective blocking after a time window or based on observed stability?

## Next Owner

`Test Lead` should validate that required/optional boundaries are practical and that checks target continuity-critical omissions only.
