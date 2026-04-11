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

**`grace sentry` (macOS)** expects `gh` on `PATH` and a clean git working tree. **TUI:** default interactive UI uses **Textual** (`--no-tui` for plain stderr lines only). Each iteration **fast-forwards local `main` from `origin`** (override name with **`main_branch`** in TOML or **`SENTRY_MAIN_BRANCH`**) and **cuts the sentry branch from that tip**, then restores your previous branch when the run finishes. **Non-secret defaults** can live under **`[sentry]`** in the repo root [`gracenotes-dev.toml`](../../gracenotes-dev.toml); **environment variables override** the file. **Never** put API keys in TOML — use env for secrets (e.g. `OPENAI_API_KEY`). **Fix source:** default is an OpenAI-compatible HTTP API, or set **`fix_provider = "cursor_agent"`** in TOML / **`SENTRY_FIX_PROVIDER=cursor_agent`** for the local **`agent`** CLI — see [Cursor CLI](https://cursor.com/docs/cli/overview). Override binary/args via `agent_bin`, `agent_prefix_args`, `agent_extra_args` in TOML or matching `SENTRY_*` env vars. PR titles and bodies are drafted by the **same provider family** (second LLM or `agent` call) from the before/after Swift; see `.grace/sentry/events.jsonl` for `fix_invoke`, `fix_result`, and `pr_draft` steps. **Daemon** mode (no `--once`) appends **`loop_wait`** after each iteration and sleeps **`interval_seconds`** (default **60**; set `SENTRY_INTERVAL_SEC` / `interval_seconds`) before the next pass—otherwise the log looks idle after a merge. **Multi-PR sweep:** With merge enabled, each iteration lists open PRs into **`main_branch`** whose head ref starts with **`sentry_branch_prefix`** (default **`sentry/auto-`**; override with **`SENTRY_BRANCH_PREFIX`** / TOML) and runs the same merge gates, squash merge, and conflict repair in **ascending PR number** before picking a new random file—so earlier PRs can still merge after **`/sentry-approve`** while sentry explores elsewhere. If the **only** remaining gate on a high-touch PR is allowlisted approval, the merge poll **yields** by default (**`yield_on_approval_pending`**; set **`SENTRY_YIELD_ON_APPROVAL_PENDING=false`** to block until timeout instead). **Merge conflicts:** with **`fix_provider = "cursor_agent"`**, when GitHub reports the PR as merge-conflicting, sentry merges `origin/main_branch` into the PR head locally, runs the **`agent`** CLI once per conflicted file to strip markers and produce a resolved file, then commits and pushes so the next squash merge can succeed. With HTTP-only fix providers, conflicts are not auto-resolved—fix on GitHub or switch to `cursor_agent`, or sentry keeps polling until the branch is mergeable. Also set `copilot_login`, `approval_users`, and optional `ci_profile` in TOML or env. State logs to `.grace/sentry/` (gitignored). Use `grace sentry report` for a briefing.

Global flags (before the subcommand): `grace --repo-root /path/to/grace-notes …` uses that directory as the start of repo discovery; same via `GRACE_REPO_ROOT`.

`--dry-run` / `--print-command` on `build`, `clean`, `test`, `run`, and `ci` prints the argv for each workflow step (build, test, install, reset, etc.) without executing those steps. **Simulator discovery** (`xcrun simctl list` and similar) may still run so resolved destinations match a normal run.

## Shell completion (optional)

[Typer](https://typer.tiangolo.com/) supports shell completion for CLI apps; see Typer’s “CLI Options” / completion docs if you want to install completion for `grace` in your shell.
