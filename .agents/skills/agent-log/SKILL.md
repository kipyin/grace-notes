---
name: agent-log
description: Start, maintain, and close agent-log initiatives from short commands — numbering, naming, templates, index, archive, gh issue context
---

# Agent-log

## Purpose

Operate the **agent-log file system** so multi-role handoffs stay discoverable and consistent. The **user may speak in short, intent-only phrases**; you **infer and execute** the full scaffolding workflow (next id, folder name, templates, `index.md`, optional `gh` lookup, validation, archive).

- **Start**: allocate the next `NNN-…` id, derive slug, create the folder, **seed templates by default**, register in `index.md`, set frontmatter (`initiative_id`, `related_issue` / `related_pr` when known).
- **Maintain / status**: answer “what’s next” from initiative files and SCHEMA handoff fields; keep `index.md` accurate when you touch structure.
- **Close**: archive shipped or superseded initiatives, update index and archive inventory, validate.

This skill handles **scaffolding and housekeeping**. It does **not** replace product or technical judgment inside role files (Strategist brief content, Architect technical decisions, Builder code, Release Manager version policy).

## Thin user commands (you expand these fully)

The user should **not** need to spell out numbering rules, template paths, or validation commands. Treat phrases like these as **complete requests**:

| User says (examples) | You do |
|----------------------|--------|
| “Start on GitHub issue #50” / “Start working on gh issue #50” | Next `NNN`, slug from issue title (via `gh`), create `initiatives/<id>/`, seed default templates, `related_issue` in frontmatter, update `index.md`, run validate for that path, report path + suggested **Next Owner** (usually Strategist). |
| “New initiative for …” (short topic only) | Same, but slug from their topic string; no `gh` unless they give an issue number. |
| “What’s next for init 003?” / “Status of 003” | Resolve `003-*` under `initiatives/` (or say if missing / only in archive). Summarize filled vs empty role files, latest **`Next Owner`** / **`Open Questions`** from the most relevant handoff files, and minimal files the next role should read. |
| “Close off init 003” / “Archive 003” | Resolve `003-*`, move to `archive/`, update `index.md` + [archive README](GraceNotes/docs/agent-log/initiatives/archive/README.md), validate. |
| “Add testing handoff for 003” | Resolve folder, copy `testing.template.md` → `testing.md` if missing (fix frontmatter); validate. |

If the intent is ambiguous (e.g. two `003-*` folders), ask **one** clarifying question; otherwise proceed without asking the user to restate mechanics.

## Non-Purpose

- Do not write substantive **Decision** / **Rationale** / scope content in `brief.md` or `architecture.md` — that belongs to **Strategist** / **Architect**. You may fill **factual** frontmatter and template stubs (placeholders, links to `gh issue`).
- Do not change merge, release, or version policy — Release Manager owns that narrative in `release.md` and repo release docs.
- Do not rename **legacy** initiative folders (pre-`NNN-` slugs) unless the user explicitly requests a migration.

## Inputs

- [GraceNotes/docs/agent-log/index.md](GraceNotes/docs/agent-log/index.md)
- [GraceNotes/docs/agent-log/SCHEMA.md](GraceNotes/docs/agent-log/SCHEMA.md)
- [GraceNotes/docs/agent-log/initiatives/README.md](GraceNotes/docs/agent-log/initiatives/README.md)
- [GraceNotes/docs/agent-log/templates/](GraceNotes/docs/agent-log/templates/)
- [Scripts/validate-agent-log.sh](Scripts/validate-agent-log.sh) (via `make verify-agent-log` / `make verify-agent-log-strict` from repo root)
- **`gh`** (GitHub CLI): when the user references an issue or PR, run `gh issue view` / `gh pr view` to fetch **title** (for slug) and **number** (for frontmatter). If `gh` is unavailable or fails, derive slug from the user’s words and set `related_issue` only if they gave a number.

## Initiative id convention (required for new work)

**Pattern:** three-digit zero-padded sequence, hyphen, short kebab-case name:

- `001-guided-onboarding`
- `002-release-0-5-2-widget`

**Rules:**

- Use exactly **three digits** (`001`–`999`). Numbers are **monotonic** across the repo: consider both `initiatives/*` and `initiatives/archive/*`.
- After the first hyphen, use **lowercase** `a-z`, **digits**, and **hyphens** only; keep the suffix **short** (roughly ≤ 40 characters after `NNN-`; shorten long issue titles).
- **GitHub issue / PR numbers** go in YAML frontmatter (`related_issue`, `related_pr`). The **`NNN-` prefix is never the issue number** — it is only the next free sequence.

**Choosing the next number:**

1. Collect every **immediate child directory** of `GraceNotes/docs/agent-log/initiatives/` and `.../initiatives/archive/` whose name matches `^[0-9]{3}-`.
2. Parse the leading three digits as integers; `next = max + 1` (zero-padded). If none match, use `001`.

**Slug from GitHub issue title:** normalize title to kebab-case; drop filler words if needed; no leading/trailing hyphens; collapse repeated hyphens.

**Resolve “init NNN”:** find **exactly one** directory named `NNN-*` under `initiatives/` for active work. If closing and only an archive match exists, report that it is already archived.

**Legacy folders** (e.g. `issue-71-guided-onboarding`, `release-0-5-1-patch`) remain valid paths; do not renumber them in normal stewardship.

## Default template seed (on start)

Unless the user explicitly asks for a **minimal** scaffold (e.g. “empty folder only”), **automatically** copy all of these from [templates/](GraceNotes/docs/agent-log/templates/) into the new initiative directory, renaming `*.template.md` → `*.md`:

- `brief.template.md` → `brief.md`
- `architecture.template.md` → `architecture.md`
- `qa.template.md` → `qa.md`
- `testing.template.md` → `testing.md`
- `release.template.md` → `release.md`
- `pushback.template.md` → `pushback.md`

In **every** seeded file:

- Replace placeholder `NNN-short-topic` in frontmatter with the **full directory name** (e.g. `007-insight-empty-state`).
- Set `related_issue` / `related_pr` when known; set `updated_at` to the current date; use a sensible `status` (e.g. `in_progress`).

Leave body sections as template placeholders for Strategist/Architect/etc. — do not invent product decisions.

## Output Format

### After start

- Report: **full path**, **initiative id**, **`related_issue` / `related_pr`** if set, **index.md** updated (confirm line).
- Run `./Scripts/validate-agent-log.sh <initiative-dir>` and summarize warnings (if any).
- State **Next Owner** for substantive work (default **Strategist** → `brief.md`).

### After status / “what’s next”

- Report: initiative path, which role files exist and whether they look **filled vs stub**, last explicit **`Next Owner`** / blockers from **`Open Questions`**, and **2–4 file paths** the next agent should open.

### After close / archive

- Confirm move, index + archive table updates, validation result, and that links to the old active path are gone from `index.md`.

## Decision Checklist

- Is the new `initiative_id` unique and following `NNN-kebab-name`?
- Is `index.md` updated so active vs archived is obvious?
- After moves, do links still resolve?
- Did validation run for the touched initiative?

## Stop Conditions and Escalation

Stop and hand off when the task requires **scope or acceptance** decisions → **Strategist** or **Architect**; **implementation** → **Builder**; **release line / version** → **Release Manager**.

## Handoff Contract

When this skill finishes a **start** or **structural** change, end with a compact handoff:

- `Context`: initiative path and what was created or moved.
- `Decision`: structural outcome (e.g. “Created `008-issue-50-chip-bug` and seeded templates”).
- `Open Questions`: naming conflicts, missing `gh`, or user ambiguity (`None` if clear).
- `Next Owner`: who should write the next substantive role file (usually **Strategist**).
