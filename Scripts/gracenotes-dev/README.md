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

**Rough flow:** fetch latest `main` → optionally merge older sentry PRs first → create worktree from `main` → apply fix → `grace ci` → push → open PR (adds the `no-ci` label; create that label on GitHub if needed) → poll merge gates if you didn’t pass `--no-merge`.

**Configuration:** non-secret options live in **`[sentry]`** inside the repo’s [`gracenotes-dev.toml`](../../gracenotes-dev.toml); env vars override. **Do not** put API keys in TOML—use environment variables.

**Fixes come from:** an OpenAI-compatible HTTP API by default, or the local Cursor **`agent`** CLI if you set `fix_provider = "cursor_agent"` (see the [Cursor CLI](https://cursor.com/docs/cli/overview) docs). PR title/body text uses the same “family” of provider.

**Merge gates:** GitHub checks must be green. Unresolved **Copilot** review threads block the merge unless you configure `copilot_login` to match the bot’s `author.login` in the API (use `grace sentry review-thread-authors <PR#>` on a real PR to see those logins). Allowlisted users can still post the approval phrase (default `/sentry-approve`) to unblock if Copilot is stuck.

**Other behavior:** without `--once`, sentry sleeps between iterations (see `interval_seconds` / `SENTRY_INTERVAL_SEC`). With merge enabled, it can **sweep** open `sentry/auto-*` PRs in ascending number before starting new work. If `fix_provider` is `cursor_agent` and GitHub reports conflicts, sentry may merge `main` locally and run `agent` on conflicted files.

**Where to look:** JSONL events under `.grace/sentry/`; `grace sentry report` for a short summary.

Global flags (before the subcommand): `grace --repo-root /path/to/grace-notes …` uses that directory as the start of repo discovery; same via `GRACE_REPO_ROOT`.

`--dry-run` / `--print-command` on `build`, `clean`, `test`, `run`, and `ci` prints the argv for each workflow step (build, test, install, reset, etc.) without executing those steps. **Simulator discovery** (`xcrun simctl list` and similar) may still run so resolved destinations match a normal run.

## Shell completion (optional)

[Typer](https://typer.tiangolo.com/) supports shell completion for CLI apps; see Typer’s “CLI Options” / completion docs if you want to install completion for `grace` in your shell.
