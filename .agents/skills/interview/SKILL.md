---
name: interview
description: Lock requirements before a large or ambiguous change—clarify until the problem and acceptance bar are understood with high confidence
user-invokable: true
---

# Interview (pre-implementation gate)

## Purpose

Reduce “implementation of the wrong thing” by forcing clarification until you have **roughly 95% confidence** you understand what the user actually wants—not a plausible guess. Use **before** drafting a multi-step plan or writing substantial code for a non-trivial or ambiguous request.

## Non-Purpose

- Do not replace open-ended ideation. For creative exploration, use brainstorming-oriented skills or free-form discussion; **interview** is for **locking requirements** when the user already has a direction (or once direction is chosen).
- Do not use this skill on every small, obvious fix or one-file tweak—keep it **high-signal** for non-trivial features, refactors, or ambiguous “big moves.”
- Do not treat the structured questions as a rigid form: adapt to context, but cover the intent of each topic.

## When to use

- The user asks for a **non-trivial feature**, **refactor**, or ambiguous **big move**.
- You would otherwise start a **multi-step plan** without confirmed constraints.
- Acceptance criteria, scope boundaries, or tradeoffs are **unclear or assumed**.

**Invocation:** The user may attach this skill explicitly. The agent should also consider it **without** user invocation when the task is large or ambiguous—optional, not mandatory on every change.

## Inputs

- The user’s stated goal and any constraints already given
- Repo context (`AGENTS.md`, linked issue/PR) when relevant
- Optional: prior brainstorm or Strategist/Architect output—**compose** with those; do not re-run a full ideation pass unless the user wants more options

## Mandatory workflow

1. **Name uncertainties** briefly (what you would guess vs what you need to know).
2. Use the **AskQuestion** tool (structured multiple-choice plus optional free-text follow-up in chat) to surface at least:
   - **Success criteria** and **explicitly out-of-scope** items
   - **UX**, **performance**, and **compatibility** constraints that matter for this change
   - **Preferred tradeoffs** (e.g. speed vs cleanliness, scope vs polish)
   - Whether the user wants **minimal change** vs **intentional redesign** in the affected area
3. **Iterate** until each major uncertainty is either **resolved** or **explicitly accepted** as a documented assumption (you state the assumption back; the user confirms or corrects).
4. **Echo back** a short summary: problem statement, acceptance bar, non-goals, and assumptions—**before** you draft the implementation plan.

## Stop conditions

- **Proceed** when you have **~95% confidence** on the **problem** and **acceptance bar** (what “done” means and what is excluded), with assumptions either eliminated or explicitly accepted.
- **Pause** and ask again if new contradictions appear (e.g. scope vs timeline).
- **Do not** start heavy implementation until the stop condition is met, unless the user explicitly waives clarification for a thin slice (record that waiver in your summary).

## Output format

- `Uncertainties addressed` (bullet list)
- `Agreed success criteria`
- `Out of scope`
- `Constraints and tradeoffs`
- `Assumptions accepted` (or `None`)
- `Ready for plan` (yes/no)

## Handoff contract

- **Context:** what was unclear and what was confirmed
- **Decision:** whether to proceed to planning/build
- **Open questions:** anything still fuzzy that should live in the **GitHub issue or PR** for the next contributor
- **Next owner:** whoever implements—capture load-bearing detail in the issue/PR, not only chat

## Coordination

- Pairs with **`strategize`** / **`architect`** after requirements are solid: Strategist/Architect turn intent into scope and close criteria; **interview** ensures intent is not guessed.
- Does **not** duplicate wide brainstorming; if the user is still exploring directions, clarify whether they want more options first, then interview to lock the chosen path.
