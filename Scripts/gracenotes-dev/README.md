# gracenotes-dev

Developer tooling for the Grace Notes iOS repo. Install locally:

```bash
pip install -e ./Scripts/gracenotes-dev
# or
uv tool install --editable ./Scripts/gracenotes-dev
```

The console script is `grace`. See `grace --help` after install.

Configuration lives in the repo root file [`gracenotes-dev.toml`](../../gracenotes-dev.toml).

## Command cheat sheet

| Command | Purpose | Example |
| ------- | ------- | ------- |
| `grace doctor` | Toolchain + destination preflight | `grace doctor` |
| `grace doctor --json` | Machine-readable doctor output | `grace doctor --json` |
| `grace doctor --strict` | Same as doctor, nonzero exit if any check is not ok | `grace doctor --strict` |
| `grace sim list` | Simulator destinations | `grace sim list` |
| `grace lint` | Run SwiftLint via `grace` (extra args forwarded) | `grace lint -- --fix` |
| `grace build` | xcodebuild build | `grace build --clean` |
| `grace test` | xcodebuild test (matrix supported) | `grace test --kind unit --matrix` |
| `grace run` | Build, install, launch app | `grace run --dry-run` |
| `grace ci` | Run a configured CI profile | `grace ci --profile lint-build` |
| `grace config list` | Show effective config | `grace config list` |
| `grace l10n audit` | String catalog vs Swift literals | `grace l10n audit --json` |
| `grace sentry` | macOS: exploratory LLM fix loop, PR, merge gates (see env below) | `grace sentry start --once --dry-run` |

### `grace sentry` (macOS)

Automated “try a small Swift change, run CI, open a PR” loop. Needs **`gh`** on your `PATH` and a **clean** working tree. Default UI is a **Textual** TUI; use `--no-tui` for plain stderr (lines are timestamped in UTC).

**How it stays out of your way:** work happens in a **separate git worktree** under `.grace/sentry/worktrees/` (gitignored). Your repo stays on whatever branch you had checked out. When the iteration ends (or the PR merges), that worktree is removed.

**Rough flow:** fetch latest `main` → **sweep** merge gates on open `sentry/auto-*` PRs (sequential: one PR at a time until merged or its sweep budget elapses, then rotate) → create worktree from `main` → apply fix → `grace ci` → push → open PR (adds the `no-ci` label; create that label on GitHub if needed) → **one** non-blocking merge poll if you didn’t pass `--no-merge` (further merges happen on later sweeps).

**Configuration:** non-secret options live in **`[sentry]`** inside the repo’s [`gracenotes-dev.toml`](../../gracenotes-dev.toml); env vars override. **Do not** put API keys in TOML—use environment variables.

**Fixes come from:** an OpenAI-compatible HTTP API by default, or the local Cursor **`agent`** CLI if you set `fix_provider = "cursor_agent"` (see the [Cursor CLI](https://cursor.com/docs/cli/overview) docs). PR title/body text uses the same “family” of provider.

**Merge gates:** GitHub checks must be green. **Reviewers (bots or humans):** configure **`reviewer_logins`** or **`SENTRY_REVIEWER_LOGINS`** (comma-separated). When unset, sentry merges the default GitHub Copilot PR reviewer login (`copilot-pull-request-reviewer`) with **`cursor_reviewer_logins`**. Use `grace sentry review-thread-authors <PR#>` on a real PR to see `author.login` values if you need a custom list. Sentry waits until the issue/PR review gate passes **or** **`review_silence_timeout_seconds`** has elapsed since **PR creation** (default matches `copilot_wait_seconds` when unset).

**Reviewer “cleared” source:** `review_clear_mode` (TOML or `SENTRY_REVIEW_CLEAR_MODE`) is **`comment`** (default) or **`github`**. With **`github`**, merge-safe means no **`CHANGES_REQUESTED`** on the latest submitted PR review **per** listed reviewer who has reviewed, and no **unresolved** review threads that include a comment from a listed login. With **`comment`**, once your **`gh` auth user** has posted at least one issue comment containing `<!-- sentry-review: <outcome> -->`, sentry uses the **latest** such comment as the reviewer gate: outcomes **not** listed in **`review_clear_block_outcomes`** count as cleared (defaults block `product_decision`, `no_change`, `ci_failed`, `error`, and `no_swift_files`; **`addressed`**, **`pushback`**, and **`caveat`** clear by default). **Until** any marker comment exists, sentry uses the same GitHub thread + PR-review rules as **`github`** mode so exploratory PRs are not stuck waiting for a marker. After a successful **review-fix** push, the visible comment body is **only** an agent-written summary (what changed and why); sentry appends the marker line for merge mode. Optional **`review_clear_comment_max_age_seconds`** ignores stale markers. **`review_outcome_templates`** remains for rare tooling use; review summaries are not template-driven. Set `reviewer_logins = []` to disable reviewer-based gates. After opening a PR, sentry may post `/review` once when `cursor_post_review_trigger` is true **and** a configured Cursor reviewer login appears in `reviewer_logins`.

**Review vs CI:** Applying review feedback and getting **local `grace ci` green** are separate steps. After review edits are committed, sentry runs the same **CI recovery loop** used for red GitHub checks (loop `grace ci` + agent on PR files, then push)—not a single CI run bundled into the review step.

Allowlisted users may still post the approval phrase (default `/sentry-approve`) as an **emergency** override if automation is stuck.

With `fix_provider = "cursor_agent"`, sentry may run **`agent`** to apply review feedback. Cooldown uses **`cursor_review_fix_cooldown_seconds`** (override) or **`review_fix_cooldown_seconds`** (base). When the primary checkout is not already on the PR branch, fixes run in **`.grace/sentry/worktrees/review-fix-<PR#>/`**. When **GitHub checks are red** on an open sentry PR, sentry may check out the head in **`.grace/sentry/worktrees/ci-fix-<PR#>/`**, run local **`grace ci`** (using **`ci_profile`**), feed the captured output to **`agent`** for changed Swift under `GraceNotes/` or Python under `Scripts/gracenotes-dev/`, and repeat until local CI passes (capped by **`ci_fix_max_rounds_per_poll`**) before pushing—cooldown **`ci_fix_cooldown_seconds`** (defaults to the same value as the cursor review cooldown unless set). Each open sentry PR gets up to **`merge_sweep_budget_seconds`** before rotating; the whole sweep stops after **`merge_sweep_total_budget_seconds`** (default **0** = derive from per-PR budget × open PR count, minimum 300s) so a stuck queue cannot block the rest of the sentry iteration. The older `arbitration_stuck_seconds` setting is not used for merge polling.

**Other behavior:** without `--once`, sentry sleeps between iterations (see `interval_seconds` / `SENTRY_INTERVAL_SEC`). With merge enabled, each iteration **sweeps** open `sentry/auto-*` PRs in ascending number before starting new work. If `fix_provider` is `cursor_agent` and GitHub reports conflicts, sentry may merge `main` locally and run `agent` on conflicted files.

**Where to look:** JSONL events under `.grace/sentry/`; `grace sentry report` for a short summary. Workflow and decision notes (ASCII, narrow): [`SENTRY_WORKFLOW.md`](SENTRY_WORKFLOW.md).

Global flags (before the subcommand): `grace --repo-root /path/to/grace-notes …` uses that directory as the start of repo discovery; same via `GRACE_REPO_ROOT`.

`--dry-run` / `--print-command` on `build`, `clean`, `test`, `run`, and `ci` prints the argv for each workflow step (build, test, install, reset, etc.) without executing those steps. **Simulator discovery** (`xcrun simctl list` and similar) may still run so resolved destinations match a normal run.

## Shell completion (optional)

[Typer](https://typer.tiangolo.com/) supports shell completion for CLI apps; see Typer’s “CLI Options” / completion docs if you want to install completion for `grace` in your shell.
