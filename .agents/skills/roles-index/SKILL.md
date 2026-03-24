---
name: roles-index
description: Index of role names, shared contract, and how role files are structured
---

# Roles Index

`.agents/skills/` is the canonical source of truth for role behavior.

## Role Names

Use short, clear role names (1-2 words, noun title):

- `Strategist`
- `Architect`
- `Builder`
- `Translator`
- `Marketing`
- `Release Manager`
- `QA Reviewer`
- `Test Lead`

## Shared Contract

Every role file follows the same sections:

1. Purpose
2. Non-Purpose
3. Inputs
4. Output Format
5. Decision Checklist
6. Stop Conditions and Escalation
7. Handoff Contract

## Handoff Contract

Each role handoff must include:

- `Context`: what was reviewed and why it matters
- `Decision`: recommendation and confidence
- `Open Questions`: unresolved items that block certainty
- `Next Owner`: who acts next and what they must produce

## Release Quality Gates

- No merge recommendation without an explicit pass/fail checklist.
- Update `README.md` and `CHANGELOG.md` when product behavior changes.
- Confirm base branch and release/version intent before starting branch work.
- Evaluate testing by critical behavior and risk paths, not raw coverage percentages.
- Require `QA Reviewer` to verify requirement fit and `Test Lead` to verify test adequacy before final merge recommendation.

## Agent-Log Protocol

Treat `GraceNotes/docs/agent-log/` as canonical for role-to-role interaction.

- Read the initiative's latest role outputs before making decisions.
- Write updates to your role-owned file in `initiatives/<initiative-id>/`.
- Keep continuity fields present: `Decision`, `Open Questions`, `Next Owner`.
- Use `pushback.md` for deferrals and include a clear revisit trigger.
- Prefer substance over formatting; do not block progress on cosmetic structure.
- For **new** initiative folders, ids use `NNN-kebab-name` (monotonic three-digit prefix). Use `.agents/skills/housekeep/SKILL.md` to start, maintain index/archive, and validate — without replacing Strategist/Architect/Builder judgments.
- **Skill folders** use verb slugs (`strategize`, `build`, `promote`, `test`, `vc`, …) while **handoff role titles** in docs may stay noun-style (**Strategist**, **Builder**, **Marketing**, **Test Lead**, **Release Manager**, …).
