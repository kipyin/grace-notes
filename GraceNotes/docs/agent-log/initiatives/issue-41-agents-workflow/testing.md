---
initiative_id: issue-41-agents-workflow
role: Test Lead
status: complete
updated_at: 2026-03-18
related_issue: 41
related_pr: 49
---

# Testing

## Inputs Reviewed

- `architecture.md` in this initiative
- Current `Makefile` targets
- Existing docs and rules touched by this initiative

## Decision

Use risk-based testing:

- Verify every role artifact can be created and handed off with only in-repo context.
- Verify continuity fields are present in all role outputs.
- Verify validator catches continuity omissions while keeping non-critical formatting in warning mode.

## Rationale

The primary risk is coordination failure, not algorithmic correctness. Tests should target handoff continuity and practical adoption.

## Risks

- Overly strict checks may block valid, low-risk work.
- Under-specified validator messaging may reduce adoption.

## Open Questions

- Should local warning output include optional frontmatter guidance, or stay silent unless continuity fields are missing?

## Next Owner

`QA Reviewer` should verify that this workflow satisfies strategist intent and highlights remaining quality gaps.
