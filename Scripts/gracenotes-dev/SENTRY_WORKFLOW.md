# `grace sentry` — workflow and decisions

Narrow ASCII; wrap your editor to ~76 cols for readable diagrams.

## Roles (three concerns)

1. **Exploratory fix** — new worktree from `main`, touch code, `grace ci`, open PR.
2. **CI recovery** — local `grace ci` red (GitHub or after edits): loop agent on
   PR-touched files until green, then push.
3. **Review recovery** — reviewer feedback pending: agent applies Swift edits,
   then **same CI recovery subsystem** (not a single one-off `grace ci`).

Review **comments** (merge gate `comment` mode) are **agent prose only** +
`<!-- sentry-review: addressed -->`. No canned outcome templates in that
comment body.

---

## Top-level loop

```
+-------------+
| sentry start|  (or --once: one pass then exit)
+------+------+
       |
       v
+------+------+     +------------------+
| sweep merge|---->| next sentry/auto-|
| open PRs   |     | * PR or budget   |
+------+------+     +------------------+
       |
       |  (budget / queue)
       v
+------+------+
| new fix iter|
| worktree    |
+------+------+
       |
       v
   (LLM HTTP or agent) -> grace ci -> push -> gh pr create
       |
       v
+------+------+
| merge poll  |  if --no-merge: skip merge
| (per PR)    |
+-------------+
```

---

## Merge poll (one PR, one visit)

Inputs: `ci_ok`, `wait_ok`, `reviewers_clear`, optional `/sentry-approve`.

```
                    +----------+
               +--->| ci_ok?   |
               |    +----+-----+
               |         | no
               |         v
               |    +----+---------+
               |    | fix_provider |
               |    | cursor_agent?|
               |    +----+---------+
               |         | yes
               |         v
               |    +----+---------+
               |    | ci_fix loop  |  (see ci_fix.py)
               |    | grace ci +   |
               |    | agent rounds |
               |    +----+---------+
               |         |
               |         v (push ok -> re-poll later)
               |
    +----------+----------+
    |                     |
    v                     v
wait_ok              reviewers_clear
(from silence /       (see below)
 issue+PR gate)
    |                     |
    +---------+-----------+
              |
              v
    reviewers_ok = wait_ok AND reviewers_clear
              |
              v
    +---------+---------+
    | can_merge?        |
    | ci && (approve || |
    |      reviewers_ok)|
    +---------+---------+
              | yes
              v
         gh pr merge --squash
```

If **not** mergeable but `wait_ok` and **not** `reviewers_clear` and
`fix_provider=cursor_agent`: **review recovery** may run (`cursor_review_fix`).

---

## `reviewers_clear` (two modes)

| Mode | Source |
|------|--------|
| `comment` (default) | Latest issue comment **from `gh` auth user** with
| | `<!-- sentry-review: X -->`; `X` not in `review_clear_block_outcomes`. |
| `github` | GraphQL: no unresolved threads with allowlisted reviewer
| | comments; REST: latest non-pending review per allowlisted login not
| | `CHANGES_REQUESTED`. |

Default block list includes `product_decision`, `no_change`, `ci_failed`,
`error`, `no_swift_files`. **`addressed`**, **`pushback`**, **`caveat`**
clear when not blocked.

Emergency: allowlisted users post `approval_phrase` (e.g. `/sentry-approve`)
→ merge if CI green, bypassing `reviewers_ok`.

---

## Review recovery (after merge poll triggers it)

```
+------+------+
| digest of |
| reviewer   |
| feedback   |
+------+-----+
       |
       v
+------+------+
| agent per   |
| GraceNotes/ |
| *.swift     |
+------+------+
       |
       v
+------+------+
| git commit  |
| sentry:     |
| address PR… |
+------+------+
       |
       v
+------+------+
| run_ci_     |
| recovery_   |
| loop_in_    |  same core as GitHub-red CI fix
| worktree    |  (grace ci <-> agent on PR files)
+------+------+
       |
       v (push ok)
+------+------+
| agent: PR   |
| summary only|
| + marker    |
| gh pr comment|
+-------------+
```

If the CI loop never goes green, JSONL / logs record failure; **no** templated
review-outcome PR comment for that path.

---

## CI recovery (shared)

File: `ci_fix.py`. Loops up to `ci_fix_max_rounds_per_poll`:

1. Run `grace ci` (capture log).
2. Green + **dirty** tree → commit `sentry: fix CI failures` + push.
3. Green + **clean** tree → **push** only if `push_when_ci_green_clean`
   (true after a review commit waiting to publish).
4. Red → agent on candidate paths (`GraceNotes/**/*.swift`,
   `Scripts/gracenotes-dev/**/*.py`), then next round.

Cooldowns: `ci_fix_cooldown_seconds`, `cursor_review_fix_cooldown_seconds`
(separate knobs for which gate fired).

---

## Quick decision table

| Situation | Typical action |
|-----------|----------------|
| GitHub checks red | CI recovery loop (if `cursor_agent`) |
| Review gate stuck, digest non-empty | Review recovery (if cooldown ok) |
| Both red + review | Merge poll orders: try CI fix first, then review branch
| | when gates say so (see `merge_poll.py`) |
| Merge conflicts on PR | Optional merge-conflict agent path |
| `review_clear_mode=github` | Threads + PR review state |
| `review_clear_mode=comment` (default) | Marker + blocklist on **your** issue comments |

---

## Where to read code

| Area | Module |
|------|--------|
| Merge orchestration | `sentry/merge_poll.py`, `merge_logic.py` |
| CI loop | `sentry/ci_fix.py` |
| Review edits + summary comment | `sentry/cursor_review_fix.py` |
| Comment marker / clear | `sentry/review_comment.py` |
| Settings | `sentry/settings.py`, `[sentry]` in `gracenotes-dev.toml` |
| Events | `.grace/sentry/*.jsonl`, `grace sentry report` |
