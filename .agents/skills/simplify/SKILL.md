---
name: simplify
description: After delivery, review code shape and coupling—diagnose patch-on-patch structure and optionally propose one cleaner greenfield-style design without default rewrites
user-invokable: true
---

# Simplify (post-implementation review)

## Purpose

Catch **accumulated patch-on-patch** solutions and, when helpful, propose **one** cleaner “if we designed this from scratch today” structure—smaller surface area, clearer responsibilities, fewer special-case branches—**without** rewriting everything by default.

This skill is **structural / code-shape hygiene** after implementation. It complements **`distill`** (strip UI and flow complexity) and **`qa-review`** (intent vs scope and merge readiness).

## Non-Purpose

- Do **not** rewrite unrelated code or “clean up” the whole module as part of this pass unless the user explicitly agrees.
- Do **not** block merge on speculative refactors; output is **recommendation + optional follow-up issue**, not a gate.
- Do **not** run on every tiny change—use when the diff is non-trivial or the user invokes this skill on a branch/PR.

## When to use

- Implementation is **complete and verified** (tests, lint, or other checks appropriate to the change—per project norms).
- The user explicitly invokes this skill on a **branch**, **PR**, or **revision range**.
- You notice a diff that reads like **layered fixes**, **parallel one-off branches**, or **obscured core behavior**—even if the user did not ask, you may suggest applying this skill; the user decides.

## Inputs

Prefer **concrete change scope**:

- **PR diff** or list of changed files (GitHub PR view, or local `git diff` / `git show`).
- **Git range** for multi-commit or multi-session work: e.g. `main...HEAD`, merge-base range, or explicit SHAs—state the range you reviewed so the next person can reproduce the review.

Example handoff line: “Reviewed `git diff origin/main...HEAD` (commits `abc1234..def5678`) for GraceNotes/…”

## Mandatory workflow

1. **Summarize what changed** in plain language: intent, main files, and behavioral surface.
2. **Assess shape:** coupling, naming, duplicate code paths, special cases, and indirection that exists only to patch earlier patches.
3. **Diagnose:** If the structure looks like layered fixes, say so clearly (no blame—describe the effect on future readers).
4. **Propose at most one** alternative “greenfield” shape: types, boundaries, single responsibility, fewer branches—enough to be actionable as a **follow-up**, not a full rewrite spec.
5. **Classify the proposal:** optional improvement vs worth a ticket; estimate **risk** of changing it now vs later in one sentence if useful.

## Stop conditions

- **Done** after one coherent diagnosis and **at most one** greenfield-style recommendation (or an explicit “structure is proportionate; no follow-up” conclusion).
- **Do not** expand into implementing the refactor unless the user asks.

## Output format

- `What changed` (short)
- `Structure assessment` (coupling, duplication, special cases)
- `Diagnosis` (patch-on-patch or not; why it matters for maintainability)
- `Greenfield alternative` (single proposal) or `None needed`
- `Suggested follow-up` (issue title + one paragraph, or `None`)

## Handoff contract

- **Context:** revision range or PR link reviewed
- **Decision:** whether a follow-up refactor is worth tracking
- **Open questions:** risks or product questions for an issue
- **Next owner:** `Builder` or reviewer if a follow-up issue is filed

## Coordination

- **`qa-review`:** verifies intent and scope before merge; **simplify** looks at **code shape after** the fact.
- **`distill`:** simplifies user-facing design and flows; **simplify** focuses on **implementation structure**.
- Capture durable recommendations in a **GitHub issue** or **PR comment** so multi-session handoff does not rely on chat alone.
