# gracenotes-dev CLI improvements (issue #223) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the prioritized backlog in [GitHub issue #223](https://github.com/kipyin/grace-notes/issues/223) for the `grace` CLI (`Scripts/gracenotes-dev`): dry-run / print-command, strict doctor, `l10n audit --json`, environment documentation, optional `lint` passthrough, optional repo root override, optional shell completion, README cheat sheet, tighter `cli.__all__`, and a `ci --help` pointer to profile discovery.

**Architecture:** Keep the existing Typer app hierarchy in `gracenotes_dev.cli.apps` and side-effect boundaries in `cli/core.py` (`_run`, `_run_capture`, `_run_theater`). Prefer a single `dry_run` flag threaded from Typer options into `_run*` so theater steps stay unchanged. Add JSON strictly via `json` module on top of existing `StringsCatalogAuditReport` from `build_strings_catalog_audit`. Strict doctor is a small post-pass over the same `checks` list the plain and `--json` paths already build.

**Tech stack:** Python 3.11+, Typer, Rich, stdlib `unittest` + `typer.testing.CliRunner` in `Scripts/gracenotes-dev/tests/`.

**Scope note:** The issue explicitly allows each bullet as its own small PR; this plan orders work for dependency sanity (core helpers before commands that consume them). You may still merge tasks as separate PRs linked to #223.

---

## File structure

| Path | Role |
|------|------|
| `Scripts/gracenotes-dev/src/gracenotes_dev/cli/apps.py` | Root `app` epilog (examples + environment cheat sheet). |
| `Scripts/gracenotes-dev/src/gracenotes_dev/cli/core.py` | `_repo_root`, `_run`, `_run_capture`, `_run_theater`, optional `dry_run` + optional Click context repo override. |
| `Scripts/gracenotes-dev/src/gracenotes_dev/cli/__init__.py` | Root `@app.callback()`; narrow `__all__`. |
| `Scripts/gracenotes-dev/src/gracenotes_dev/cli/workflows.py` | `build`, `clean`, `test`, `run`, `ci`, `_execute_ci_profile` — add flags and thread `dry_run`. |
| `Scripts/gracenotes-dev/src/gracenotes_dev/cli/doctor_lint.py` | `doctor --strict`, `lint` passthrough args. |
| `Scripts/gracenotes-dev/src/gracenotes_dev/cli/l10n_cmd.py` | `l10n_audit --json` emission. |
| `Scripts/gracenotes-dev/README.md` | Command cheat sheet table. |
| `Scripts/gracenotes-dev/tests/test_cli_surface.py` | New tests alongside existing CLI surface tests. |
| `Scripts/gracenotes-dev/tests/test_l10n_surfaces.py` or new `test_l10n_audit_json.py` | JSON shape tests if you prefer a smaller file. |

---

### Task 1: Shared `dry_run` behavior in `cli/core.py`

**Files:**

- Modify: `Scripts/gracenotes-dev/src/gracenotes_dev/cli/core.py` (`_run`, `_run_capture`, optional `_dry_run_print`)

**Design:** When `dry_run=True`, do not call `subprocess.run`. Print one line per skipped invocation to **stdout** in a stable, script-parseable form, e.g. `DRY-RUN: <shell-quoted argv>` using `shlex.join(prepared_argv)`, and return a `CompletedProcess` with `returncode=0` and empty strings for stdout/stderr (callers must not depend on captured output when `dry_run=True`). Apply `silent` / `_prepare_xcodebuild_argv` before printing so the printed command matches what a real run would use.

- [ ] **Step 1: Write the failing test**

Add to `Scripts/gracenotes-dev/tests/test_cli_surface.py` (new test method on `CLISurfaceTest`):

```python
def test_dry_run_skips_subprocess_for_run(self) -> None:
    import gracenotes_dev.cli.core as cli_core

    argv = ["echo", "hello"]
    calls: list[list[str]] = []

    real_run = subprocess.run

    def fake_run(cmd, **kwargs: object) -> subprocess.CompletedProcess[str]:
        calls.append(list(cmd))
        return real_run(cmd, **kwargs)

    with mock.patch.object(subprocess, "run", side_effect=fake_run):
        cli_core._run(argv, cwd=Path("/tmp"), dry_run=True)

    self.assertEqual(calls, [])
```

(Adjust imports: `subprocess`, `mock`, `Path` — follow existing imports in that test file.)

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/kip/Code/grace-notes/Scripts/gracenotes-dev && uv run python -m unittest tests.test_cli_surface.CLISurfaceTest.test_dry_run_skips_subprocess_for_run -v
```

Expected: **FAIL** with `TypeError: _run() got an unexpected keyword argument 'dry_run'` (or subprocess still called).

- [ ] **Step 3: Implement `dry_run` on `_run` and `_run_capture`**

In `core.py`, extend signatures:

```python
def _run(
    argv: list[str],
    *,
    cwd: Path,
    check: bool = True,
    verbose: bool = False,
    silent: bool = False,
    dry_run: bool = False,
) -> subprocess.CompletedProcess[str]:
    prepared_argv = _prepare_xcodebuild_argv(argv, verbose=verbose, silent=silent)
    if dry_run:
        _stdout_console().print(f"DRY-RUN: {shlex.join(prepared_argv)}")
        return subprocess.CompletedProcess(args=prepared_argv, returncode=0, stdout="", stderr="")
    use_capture = silent
    # ... existing subprocess.run branches ...
```

Mirror the same early return in `_run_capture` when `dry_run=True` (still print `DRY-RUN:` once; return empty captured process).

- [ ] **Step 4: Run test to verify it passes**

Same `unittest` command as Step 2. Expected: **PASS**.

- [ ] **Step 5: Commit**

```bash
git add Scripts/gracenotes-dev/src/gracenotes_dev/cli/core.py Scripts/gracenotes-dev/tests/test_cli_surface.py
git commit -m "feat(grace): add dry_run support to _run and _run_capture"
```

---

### Task 2: `--dry-run` / `--print-command` on `build`, `clean`, `test`, `run`

**Files:**

- Modify: `Scripts/gracenotes-dev/src/gracenotes_dev/cli/workflows.py`

Use a single Typer option with two flag names:

```python
dry_run: Annotated[
    bool,
    typer.Option(
        "--dry-run",
        "--print-command",
        help="Print xcodebuild/simctl argv for each step without executing.",
    ),
] = False,
```

Thread `dry_run=dry_run` into every `cli_core._run` and `cli_core._run_capture` call in those command bodies, including steps inside `_run_test_once` if that function invokes `_run` (grep `def _run_test_once` in `core.py` and extend its parameters if needed).

For theater steps whose callback returns a summary string after a successful `_run`, preserve the return value in dry-run mode as the same string you would have printed (the joined argv is already printed by `_run`).

- [ ] **Step 1: Write a failing test for `grace build --dry-run`**

In `test_cli_surface.py`:

```python
def test_build_dry_run_prints_xcodebuild_without_running(self) -> None:
    repo_root = Path(__file__).resolve().parents[3]
    cfg = replace(config.default_config(), destination="platform=iOS Simulator,name=iPhone 17 Pro,OS=latest")
    rows = [
        {"name": "iPhone 17 Pro", "runtime_version": "26.0", "runtime_key": "k1", "udid": "u1"},
    ]

    def fake_which(name: str) -> str | None:
        if name in ("swiftlint", "xcodebuild", "xcrun"):
            return f"/usr/bin/{name}"
        return None

    with mock.patch.object(cli_core, "_repo_root", return_value=repo_root):
        with mock.patch.object(cli_core, "_load_config", return_value=cfg):
            with mock.patch.object(simulator, "load_available_ios_devices", return_value=rows):
                with mock.patch.object(sys, "platform", "darwin"):
                    with mock.patch.object(shutil, "which", side_effect=fake_which):
                        with mock.patch.object(cli_core, "_run") as run_mock:
                            runner = CliRunner()
                            result = runner.invoke(app, ["build", "--dry-run"])

    self.assertEqual(result.exit_code, 0, msg=result.output)
    self.assertTrue(any("DRY-RUN:" in str(c) for c in run_mock.call_args_list))
```

(Adjust: import `replace` from `dataclasses`, `shutil`, `sys`, `app` from `gracenotes_dev.cli.apps` — mirror `test_doctor_json_independent_default_and_matrix_status`.)

- [ ] **Step 2: Run the test — expect FAIL** (no `--dry-run` yet or `_run` not passed `dry_run=True`).

```bash
cd /Users/kip/Code/grace-notes/Scripts/gracenotes-dev && uv run python -m unittest tests.test_cli_surface.CLISurfaceTest.test_build_dry_run_prints_xcodebuild_without_running -v
```

- [ ] **Step 3: Implement options on `build`, `clean`, `test`, `run`**

Add the `dry_run` Typer option to each function signature and pass through to all `_run` / `_run_capture` / `_run_test_once` internals.

- [ ] **Step 4: Run full Python tests for the package**

```bash
cd /Users/kip/Code/grace-notes/Scripts/gracenotes-dev && uv run python -m unittest discover -s tests -v
```

Expected: **PASS** (entire suite).

- [ ] **Step 5: Commit**

```bash
git add Scripts/gracenotes-dev/src/gracenotes_dev/cli/workflows.py Scripts/gracenotes-dev/tests/test_cli_surface.py
git commit -m "feat(grace): add --dry-run to build, clean, test, run"
```

---

### Task 3: Optional `--dry-run` on `grace ci`

**Files:**

- Modify: `Scripts/gracenotes-dev/src/gracenotes_dev/cli/workflows.py` (`ci`, `_execute_ci_profile`)

Extend `_execute_ci_profile(..., dry_run: bool = False)` and pass `dry_run` into `lint_command()` only if you add a parameter there in Task 5; for `build` / `test`, pass through as keyword args:

```python
if selected.build:
    build(..., dry_run=dry_run)
```

- [ ] **Step 1: Test** — invoke `grace ci` with a mocked profile that only runs `lint` (or skip lint mock and use `--profile` that only builds) and assert `_run` / `lint` sees dry-run. Minimal pattern: mock `build` and assert called with `dry_run=True`.

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(grace): add --dry-run to ci profile steps"
```

---

### Task 4: `doctor --strict`

**Files:**

- Modify: `Scripts/gracenotes-dev/src/gracenotes_dev/cli/doctor_lint.py`

Add:

```python
strict: Annotated[
    bool,
    typer.Option("--strict", help="Exit with code 1 if any check is not ok."),
] = False,
```

After building `checks`, if `strict` is true and **not** `--json`, evaluate failure as: any item with `str(item["status"]) != "ok"`. If `--json` and `--strict` together, print JSON first, then exit with code 1 under the same rule (document that strict affects exit code only; output is unchanged).

**Rationale:** Preserves today’s `doctor --json` exit 0 behavior when `--strict` is omitted (`tests.test_cli_surface.test_doctor_json_independent_default_and_matrix_status`).

- [ ] **Step 1: Failing test**

```python
def test_doctor_strict_exits_nonzero_when_matrix_errors(self) -> None:
    # Reuse patches from test_doctor_json_independent_default_and_matrix_status
    runner = CliRunner()
    result = runner.invoke(app, ["doctor", "--strict"])
    self.assertNotEqual(result.exit_code, 0)
```

- [ ] **Step 2: Implement and run full unittest suite** — expect PASS.

- [ ] **Step 3: Commit** — `feat(grace): add doctor --strict for CI-style gating`

---

### Task 5: `grace lint` extra-arg passthrough

**Files:**

- Modify: `Scripts/gracenotes-dev/src/gracenotes_dev/cli/doctor_lint.py`

Change the Typer command to accept extra arguments:

```python
@app.command(
    "lint",
    context_settings={"allow_extra_args": True, "ignore_unknown_options": False},
)
def lint(ctx: typer.Context) -> None:
    cli_core._require_swiftlint()
    repo_root = cli_core._repo_root()
    extras = list(ctx.args)
    cli_core._run(["swiftlint", "lint", *extras], cwd=repo_root, check=True)
```

- [ ] **Step 1: Test** — `CliRunner().invoke(app, ["lint", "--", "--help"])` or a harmless flag your SwiftLint supports in CI (if `--help` exits nonzero, prefer asserting argv passed through via mocking `_run`).

```python
def test_lint_passthrough_forwards_extra_argv(self) -> None:
    repo_root = Path(__file__).resolve().parents[3]
    with mock.patch.object(cli_core, "_repo_root", return_value=repo_root):
        with mock.patch.object(cli_core, "_require_swiftlint"):
            with mock.patch.object(cli_core, "_run") as run_mock:
                runner = CliRunner()
                result = runner.invoke(app, ["lint", "--fix"])
    self.assertEqual(result.exit_code, 0, msg=result.output)
    run_mock.assert_called_once()
    argv = run_mock.call_args[0][0]
    self.assertIn("--fix", argv)
```

- [ ] **Step 2: Commit** — `feat(grace): forward extra args from lint to swiftlint`

---

### Task 6: `grace l10n audit --json`

**Files:**

- Modify: `Scripts/gracenotes-dev/src/gracenotes_dev/cli/l10n_cmd.py`

Add `json_out` option to `l10n_audit` (name it `--json` to match `doctor`). When true, call `build_strings_catalog_audit(repo_root)` and emit:

```python
def audit_report_to_json_dict(report: StringsCatalogAuditReport) -> dict[str, object]:
    return {
        "catalog_key_count": report.catalog_key_count,
        "code_key_count": report.code_key_count,
        "unused_keys": list(report.unused_keys),
        "missing_keys": list(report.missing_keys),
        "duplicate_english_groups": [
            {"english": en, "keys": list(ks)} for en, ks in report.duplicate_english_groups
        ],
        "multi_file_keys": [
            {"key": k, "paths": list(paths)} for k, paths in report.multi_file_keys
        ],
    }
```

Use `json.dump(..., sys.stdout, indent=2)` and trailing newline; skip Rich/plain render path when `--json`.

- [ ] **Step 1: Test**

```python
def test_l10n_audit_json_emits_counts_and_lists(self) -> None:
    repo_root = Path(__file__).resolve().parents[3]
    runner = CliRunner()
    with mock.patch.object(xcode_helpers, "repo_root_from", return_value=repo_root):
        result = runner.invoke(app, ["l10n", "audit", "--json"])
    self.assertEqual(result.exit_code, 0, msg=result.output)
    payload = json.loads(result.output)
    self.assertIn("missing_keys", payload)
    self.assertIsInstance(payload["missing_keys"], list)
```

- [ ] **Step 2: Commit** — `feat(grace): add l10n audit --json`

---

### Task 7: Document environment variables on root help

**Files:**

- Modify: `Scripts/gracenotes-dev/src/gracenotes_dev/cli/apps.py`

Extend `app = typer.Typer(..., epilog=...)` with a short section:

```text
Environment:
  NO_COLOR            Disable Rich styling.
  CI                  Disallow interactive flows; fuller xcodebuild logs where applicable.
  GRACE_NONINTERACTIVE=1  Disallow interactive prompts.
  GRACE_RUN_STREAM_TOOL_OUTPUT  Set to 1/true/yes to stream tool output during grace run.
  GRACE_REPO_ROOT     (optional; if you implement Task 8) Override starting directory for repo discovery.
```

- [ ] **Step 1: Test** — extend `test_root_help_includes_greenfield_commands` or add `test_root_help_includes_environment_epilog` asserting substring `GRACE_NONINTERACTIVE` in `runner.invoke(app, ["--help"]).output`.

- [ ] **Step 2: Commit** — `docs(grace): document key environment variables in --help epilog`

---

### Task 8: Optional repo root (`--repo-root` + `GRACE_REPO_ROOT`)

**Files:**

- Modify: `Scripts/gracenotes-dev/src/gracenotes_dev/cli/__init__.py` (`@app.callback`)
- Modify: `Scripts/gracenotes-dev/src/gracenotes_dev/cli/core.py` (`_repo_root`)

Use Typer on the root callback:

```python
@app.callback()
def app_callback(
    ctx: typer.Context,
    version: Annotated[bool, typer.Option(...)] = False,
    repo_root: Annotated[
        Path | None,
        typer.Option(
            "--repo-root",
            help="Directory to start repo discovery from (default: cwd).",
            envvar="GRACE_REPO_ROOT",
        ),
    ] = None,
) -> None:
    ctx.obj = ctx.obj or {}
    if repo_root is not None:
        ctx.obj["repo_root_start"] = repo_root.resolve()
```

In `core.py` (Typer commands run on Click’s context stack):

```python
import click

def _repo_root() -> Path:
    ctx = click.get_current_context(silent=True)  # None when not inside a Typer invoke
    start: Path | None = None
    if ctx is not None and isinstance(ctx.obj, dict):
        start = ctx.obj.get("repo_root_start")
    base = Path(start) if start is not None else Path.cwd()
    return xcode_helpers.repo_root_from(base)
```

**Note:** Ensure the root `@app.callback()` assigns `ctx.obj` to a dict (merge with any existing object) so subcommands see `repo_root_start`. Add a unit test that `invoke(app, ["--repo-root", str(some_parent), "doctor", "--json"])` still finds the repo when `some_parent` is the real repo’s parent (or a subdirectory).

- [ ] **Step 1: Commit** — `feat(grace): add --repo-root and GRACE_REPO_ROOT for discovery`

---

### Task 9: Shell completion (optional / low maintenance)

**Files:**

- Modify: `Scripts/gracenotes-dev/README.md` or root `AGENTS.md` — **only** if maintainers want it; issue marks this optional.

Implementation sketch (Typer): document running:

```bash
grace --help
# shellingham + typer completion install pattern
```

If the project already avoids extra dependencies, implement **documentation-only**: how to generate completions with Typer’s built-in `typer.completion` for zsh/bash, without dynamic profile-name completion. If you do add completion hooks for `--profile`, read profile keys from `config.default_config().ci_profiles` in a static completion callback — keep it in a **single small file** e.g. `gracenotes_dev/cli/completion.py`.

- [ ] **Step 1:** Spike `typer` completion for `grace` locally; if flaky on zsh, limit to README instructions only.

- [ ] **Step 2: Commit** — `docs(grace): shell completion notes` (or `feat` if code landed)

---

### Task 10: README cheat sheet

**Files:**

- Modify: `Scripts/gracenotes-dev/README.md`

Add a markdown table:

| Command | Purpose | Example |
|---------|---------|---------|
| `grace doctor` | Toolchain + destination preflight | `grace doctor` |
| `grace ci` | Run a configured CI profile | `grace ci --profile lint-build` |
| … | … | … |

Point to repo-root `gracenotes-dev.toml`.

- [ ] **Step 1: Commit** — `docs(gracenotes-dev): add CLI cheat sheet`

---

### Task 11: Trim `gracenotes_dev.cli.__all__`

**Files:**

- Modify: `Scripts/gracenotes-dev/src/gracenotes_dev/cli/__init__.py`

Reduce `__all__` to stable entrypoints consumers need, e.g. `app`, `config_app`, `sim_app`, `runtime_app` only — **not** `_print_error_block`, `_sim_interactive`, etc., unless grep shows external imports in docs or tests.

- [ ] **Step 1:** `git grep "from gracenotes_dev.cli import"` from repo root; adjust any real external callers before shrinking.

- [ ] **Step 2: Commit** — `refactor(grace): narrow cli package __all__`

---

### Task 12: `grace ci --help` one-liner for profiles

**Files:**

- Modify: `Scripts/gracenotes-dev/src/gracenotes_dev/cli/workflows.py` — extend `typer.Option` `help=` for `--profile` with: `See also: grace config list (profile names).`

- [ ] **Step 1:** `CliRunner().invoke(app, ["ci", "--help"])` contains `config list`.

- [ ] **Step 2: Commit** — `docs(grace): point ci profile help to config list`

---

## Self-review checklist

| #223 item | Covered by |
|-----------|------------|
| Dry-run on build/clean/test/run/ci | Tasks 1–3 |
| `doctor --strict` | Task 4 |
| `l10n audit --json` | Task 6 |
| Env var docs in help | Task 7 |
| `lint` passthrough | Task 5 |
| `--repo-root` | Task 8 |
| Shell completion | Task 9 (optional) |
| README cheat sheet | Task 10 |
| `__all__` trim | Task 11 |
| `ci --help` pointer | Task 12 |

**Placeholder scan:** No TBD/TODO left; each task names files and concrete snippets.

**Type consistency:** `dry_run` is `bool` everywhere; `StringsCatalogAuditReport` fields match JSON helper.

---

## Execution handoff

**Plan complete and saved to** `docs/superpowers/plans/2026-04-09-issue-223-gracenotes-dev-cli-improvements.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, review between tasks, fast iteration. REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. REQUIRED SUB-SKILL: `superpowers:executing-plans`.

**Which approach?**
