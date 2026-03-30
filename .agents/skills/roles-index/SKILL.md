---
name: roles-index
description: Index of role names, shared contract, and how role files are structured
---

# Roles Index

`.agents/skills/` is the canonical source of truth for role behavior.

## Role Names

Use short, clear role names (1–2 words, noun title):

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

When work spans sessions, end with a **short** summary: what you concluded, what is still uncertain, and what should happen next. The structured bullets below are guidance for thinking, not a form you must paste verbatim.

- **Context:** what was reviewed and why it matters
- **Decision:** recommendation and confidence
- **Open Questions:** unresolved items that block certainty (`None` if clear)
- **Next Owner:** who should act next

Prefer capturing anything load-bearing in the **GitHub PR or linked issue** so the next contributor does not depend on chat history.

## Optional process skills

These are **not** named handoff roles like Strategist or QA Reviewer; they are optional workflows for intent capture and post-delivery structure review:

- **`interview`** — `.agents/skills/interview/SKILL.md` — clarify requirements before large or ambiguous work.
- **`simplify`** — `.agents/skills/simplify/SKILL.md` — assess implementation shape after delivery (PR diff or git range); does not block merge.

Use the same spirit of clear outputs and handoffs as the sections above, without duplicating the full role contract when a skill file already defines its workflow.

## Release Quality Gates

- No merge recommendation without an explicit pass/fail checklist.
- Update `README.md` and `CHANGELOG.md` when product behavior changes.
- Confirm base branch and release/version intent before starting branch work (default: fixed marketing version + incrementing build; see `vc` skill **Versioning**).
- Evaluate testing by critical behavior and risk paths, not raw coverage percentages.
- For release-critical work, have `QA Reviewer` check requirement fit and `Test Lead` check test adequacy before a final merge recommendation.

## Coordination

- **Skill folders** use verb slugs (`strategize`, `architect`, `design`, `build`, `promote`, `test`, `vc`, …) while **handoff role titles** in conversation may stay noun-style (**Strategist**, **Architect**, **Designer**, **Builder**, …).
- Repo workflow defaults are in [AGENTS.md](../../../AGENTS.md); there is no separate initiative or agent-log directory.
