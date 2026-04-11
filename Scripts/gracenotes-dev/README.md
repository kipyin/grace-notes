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

**`grace sentry` (macOS)** expects `gh` on `PATH`, a clean git working tree, and an LLM key (default: `OPENAI_API_KEY`, or set `SENTRY_LLM_API_KEY_ENV`). Configure `SENTRY_COPILOT_LOGIN`, `SENTRY_APPROVAL_USERS`, and optional `SENTRY_CI_PROFILE`. State logs to `.grace/sentry/` (gitignored). Use `grace sentry report` for a briefing.

Global flags (before the subcommand): `grace --repo-root /path/to/grace-notes …` uses that directory as the start of repo discovery; same via `GRACE_REPO_ROOT`.

`--dry-run` / `--print-command` on `build`, `clean`, `test`, `run`, and `ci` prints the argv for each workflow step (build, test, install, reset, etc.) without executing those steps. **Simulator discovery** (`xcrun simctl list` and similar) may still run so resolved destinations match a normal run.

## Shell completion (optional)

[Typer](https://typer.tiangolo.com/) supports shell completion for CLI apps; see Typer’s “CLI Options” / completion docs if you want to install completion for `grace` in your shell.
