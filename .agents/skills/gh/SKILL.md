---
name: gh
description: Runs the Grace Notes GitHub issue and pull request lifecycle with the gh CLI—branch naming (fix/feat/chore), labels (bug/feat/chore, areas, p1–p3, full-ci/no-ci), milestones, plain-language PR bodies via explain, merge hygiene via vc, and interview-gated issue creation. Use when opening or updating issues/PRs, shipping agent-driven work, posting review summaries, or merging on GitHub.
user-invokable: true
---

# gh (GitHub issue + PR lifecycle)

## Purpose

Orchestrate **Grace Notes** GitHub work using **`gh`**: issues, branches, PRs, labels, comments, review summaries, and merge—without duplicating the skills this composes.

## Non-purpose

- Does not replace [**interview**](../interview/SKILL.md), [**explain**](../explain/SKILL.md), [**vc**](../vc/SKILL.md), or Cursor’s **new-branch-and-pr**—apply those behaviors when this skill points there.

## When to use

- User asks to create/triage/update an **issue** or **PR**, set labels, attach a milestone, comment, summarize reviews, or merge/close.
- User invokes **`/gh`** or attaches this skill for the session.

## Composition map

| Step | Follow |
|------|--------|
| Lock intent **before** `gh issue create` | [**interview**](../interview/SKILL.md)—do **not** create until user confirms after echo-back (e.g. “create issue”). |
| PR description in plain language | [**explain**](../explain/SKILL.md)—headline → user impact → behavioral narrative; appendix only if needed. |
| Branch names, commits, `Closes #n`, release/merge tone | [**vc**](../vc/SKILL.md). |
| Clean tree → branch from `main` → commit → push → open PR | **new-branch-and-pr** (Cursor team skill). |

## Repo label catalog (`gh label list`)

Use **only** these names unless the user adds new ones in GitHub:

- **Type:** `bug`, `feat`, `chore` (**not** `feature`).
- **Priority:** `p1`, `p2`, `p3`.
- **Product area:** `onboarding`, `today`, `past`, `settings`.
- **Infra / tooling:** `infra`.
- **CI on PRs:** `full-ci`, `no-ci` (when they apply—see [AGENTS.md](../../../AGENTS.md)).

**PR labels:** When type, area, or priority are inferable, apply the **full set** (`bug`/`feat`/`chore` + area + `p1`/`p2`/`p3`). If area or priority is unclear, **ask**—do not guess. Mirror labels from a linked issue when it already has them.

## Branch naming

- `fix/…` → type label **`bug`**
- `feat/…` → **`feat`**
- `chore/…` → **`chore`**

Use a short **kebab-case** slug (optional issue number in the slug if helpful). Prefer **one focused change set** per branch.

## Milestones

- **No default.** Ask whether to attach a milestone; repo often uses **weekly** milestones (e.g. `2026-W17`). Only set after user confirms title or number.

## Issue body (after interview)

Draft from **interview** output:

- **Problem**
- **Success criteria**
- **Out of scope**
- **Assumptions**
- **Open questions**

Keep plain language; see [AGENTS.md](../../../AGENTS.md) for issue tone.

## PR body

Use **explain** order:

1. **Headline** (product terms)
2. **User impact**
3. **What changed** (behavioral, not diff-centric)
4. **Verification** (e.g. `grace ci`; note `full-ci` if labeled)
5. **`Fixes #n` / `Closes #n`** when applicable

## Push / update comment

When new commits land, add a short PR comment: **≤3 bullets**—what changed, what to re-review, blockers or asks.

## Review handling

Use `gh` to fetch review threads/comments; summarize in **explain** style for the user (impact first, optional technical appendix).

## Merge policy

- Default **squash merge** to `main` unless the user explicitly wants to preserve separate commits on `main`.
- Squash title/body per **vc**; body should include **`Closes #n`** / **`Fixes #n`** when issues should auto-close.

## `vc` vs agent-driven flow

**Human daily commits** may match **vc**’s “land on `main`” habit; **agent-driven shipping** uses **topic branches + PR** as in this skill.

## Safety

- Do **not** merge, close issues, or delete branches without **explicit** user go-ahead unless they already waived for this task.
- Do **not** invent label names outside the catalog above.

## Further examples

See [reference.md](reference.md) for `gh` command patterns.
