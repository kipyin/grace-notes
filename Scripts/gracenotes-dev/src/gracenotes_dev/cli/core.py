"""Shared CLI helpers: consoles, subprocess runners, config, destinations."""

from __future__ import annotations

import importlib.metadata
import io
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
from collections.abc import Callable
from contextlib import redirect_stderr
from dataclasses import dataclass
from pathlib import Path
from typing import TypeVar

import questionary
import tomlkit
import typer
from rich.console import Console, Group
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn, TimeElapsedColumn
from rich.syntax import Syntax
from rich.text import Text

from gracenotes_dev import cli_rich, config, simulator
from gracenotes_dev import xcode as xcode_helpers



def _supports_rich_output(stream: io.TextIOBase) -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("TERM", "").lower() == "dumb":
        return False
    return stream.isatty()


def _console(stream: io.TextIOBase, *, stderr: bool = False) -> Console:
    rich_enabled = _supports_rich_output(stream)
    return Console(
        file=stream,
        stderr=stderr,
        force_terminal=rich_enabled,
        no_color=not rich_enabled,
        theme=cli_rich.CLI_THEME,
    )


def _stderr_console() -> Console:
    return _console(sys.stderr, stderr=True)


def _stdout_console() -> Console:
    return _console(sys.stdout)


def _cli_version() -> str:
    try:
        return importlib.metadata.version("gracenotes-dev")
    except importlib.metadata.PackageNotFoundError:
        return "unknown"


def _q_select(*args: object, **kwargs: object) -> object:
    kwargs.setdefault("style", cli_rich.QUESTIONARY_STYLE)
    return questionary.select(*args, **kwargs)


def _q_confirm(*args: object, **kwargs: object) -> object:
    kwargs.setdefault("style", cli_rich.QUESTIONARY_STYLE)
    return questionary.confirm(*args, **kwargs)


def _q_text(*args: object, **kwargs: object) -> object:
    kwargs.setdefault("style", cli_rich.QUESTIONARY_STYLE)
    return questionary.text(*args, **kwargs)


def _print_error_block(
    *,
    title: str,
    problem: str,
    likely_cause: str | None = None,
    try_commands: tuple[str, ...] = (),
    retry_command: str | None = None,
) -> None:
    console = _stderr_console()
    lines = [f"Problem: {problem}"]
    if likely_cause:
        lines.append(f"Likely cause: {likely_cause}")
    if retry_command:
        lines.append(f"Copy this retry: {retry_command}")
    body = "\n".join(lines)

    if _supports_rich_output(sys.stderr):
        renderables: list[Text | Syntax] = [Text(f"Problem: {problem}")]
        if likely_cause:
            renderables.append(Text(f"Likely cause: {likely_cause}"))
        if try_commands:
            renderables.append(Text("Try:"))
            renderables.append(Syntax("\n".join(try_commands), "bash", word_wrap=False))
        if retry_command:
            renderables.append(Text(f"Copy this retry: {retry_command}"))
        console.print(Panel.fit(Group(*renderables), title=title, border_style="red"))
        return

    if try_commands:
        body = "\n".join([body, "Try:", *(f"  {command}" for command in try_commands)])
    console.print(title)
    console.print(body)


def _fail(
    *,
    code: int,
    title: str,
    problem: str,
    likely_cause: str | None = None,
    try_commands: tuple[str, ...] = (),
    retry_command: str | None = None,
) -> None:
    _print_error_block(
        title=title,
        problem=problem,
        likely_cause=likely_cause,
        try_commands=try_commands,
        retry_command=retry_command,
    )
    raise typer.Exit(code=code)


@dataclass(frozen=True)
class TheaterStep:
    title: str
    callback: Callable[[], str | None]


@dataclass(frozen=True)
class EditableConfigKey:
    dotted_path: str
    toml_path: tuple[str, ...]
    value_type: str
    group: str
    getter: Callable[[config.DevConfig], object]


T = TypeVar("T")


def _step_line(*, index: int, total: int, title: str, outcome: str, elapsed: float) -> str:
    left = f"{index}/{total}  {title}"
    dots = "." * max(2, 48 - len(left))
    return f"{left} {dots} {outcome} ({elapsed:.2f}s)"


def _step_text(*, index: int, total: int, title: str, outcome: str, elapsed: float) -> Text:
    left = f"{index}/{total}  {title}"
    dots = "." * max(2, 48 - len(left))
    line = Text(f"{left} {dots} ")
    line.append_text(cli_rich.status_text(outcome))
    line.append(f" ({elapsed:.2f}s)")
    return line


def _rich_theater_enabled() -> bool:
    return _supports_rich_output(sys.stdout) and _supports_rich_output(sys.stderr)


def _run_theater(steps: list[TheaterStep]) -> float:
    started_all = time.perf_counter()
    total = len(steps)
    use_rich_theater = _rich_theater_enabled()
    for index, step in enumerate(steps, start=1):
        started_step = time.perf_counter()
        try:
            if use_rich_theater:
                with Progress(
                    SpinnerColumn(),
                    TextColumn("[progress.description]{task.description}"),
                    TimeElapsedColumn(),
                    console=_stderr_console(),
                    transient=True,
                ) as progress:
                    progress.add_task(step.title, total=None)
                    detail = step.callback()
            else:
                detail = step.callback()
        except typer.Exit:
            elapsed = time.perf_counter() - started_step
            if use_rich_theater:
                _stdout_console().print(
                    _step_text(
                        index=index,
                        total=total,
                        title=step.title,
                        outcome="failed",
                        elapsed=elapsed,
                    ),
                )
            else:
                _stderr_console().print(
                    _step_line(
                        index=index,
                        total=total,
                        title=step.title,
                        outcome="failed",
                        elapsed=elapsed,
                    ),
                )
            raise
        elapsed = time.perf_counter() - started_step
        if use_rich_theater:
            _stdout_console().print(
                _step_text(
                    index=index, total=total, title=step.title, outcome="ok", elapsed=elapsed
                ),
            )
        else:
            _stdout_console().print(
                _step_line(
                    index=index, total=total, title=step.title, outcome="ok", elapsed=elapsed
                ),
            )
        if detail:
            _stdout_console().print(f"      {detail}")
    total_elapsed = time.perf_counter() - started_all
    _stdout_console().print(f"Done. Total wall time {total_elapsed:.2f}s")
    return total_elapsed


def _repo_root() -> Path:
    return xcode_helpers.repo_root_from(Path.cwd())


def _interactive_cli_allowed() -> bool:
    if os.environ.get("CI"):
        return False
    if os.environ.get("GRACE_NONINTERACTIVE", "").strip() == "1":
        return False
    if not sys.stdin.isatty():
        return False
    return True


def _load_config(repo_root: Path) -> config.DevConfig:
    return config.load_config(repo_root=repo_root)


def _require_prompt_answer(value: T | None) -> T:
    if value is None:
        raise typer.Exit(code=1)
    return value


def _require_interactive_cli(*, cfg: config.DevConfig, command_name: str) -> None:
    if _interactive_cli_allowed():
        return
    _fail(
        code=2,
        title="Interactive mode unavailable",
        problem=(
            f"`{command_name}` needs an interactive terminal (stdin must be a TTY), "
            "and must not run with CI=1 or GRACE_NONINTERACTIVE=1."
        ),
        likely_cause=(
            "Automation and GitHub Actions should use non-interactive commands and explicit flags."
        ),
        try_commands=(
            f"grace ci --profile {cfg.default_ci_profile}",
            "grace config list",
        ),
        retry_command=f"grace ci --profile {cfg.default_ci_profile}",
    )


def _editable_config_keys() -> dict[str, EditableConfigKey]:
    return {
        "defaults.project": EditableConfigKey(
            dotted_path="defaults.project",
            toml_path=("defaults", "project"),
            value_type="string",
            group="defaults",
            getter=lambda cfg: cfg.project,
        ),
        "defaults.scheme": EditableConfigKey(
            dotted_path="defaults.scheme",
            toml_path=("defaults", "scheme"),
            value_type="string",
            group="defaults",
            getter=lambda cfg: cfg.scheme,
        ),
        "defaults.bundle_id": EditableConfigKey(
            dotted_path="defaults.bundle_id",
            toml_path=("defaults", "bundle_id"),
            value_type="string",
            group="defaults",
            getter=lambda cfg: cfg.bundle_id,
        ),
        "defaults.default_ci_profile": EditableConfigKey(
            dotted_path="defaults.default_ci_profile",
            toml_path=("defaults", "default_ci_profile"),
            value_type="string",
            group="defaults",
            getter=lambda cfg: cfg.default_ci_profile,
        ),
        "defaults.destination": EditableConfigKey(
            dotted_path="defaults.destination",
            toml_path=("defaults", "destination"),
            value_type="string",
            group="defaults",
            getter=lambda cfg: cfg.destination,
        ),
        "defaults.ci_simulator_pro": EditableConfigKey(
            dotted_path="defaults.ci_simulator_pro",
            toml_path=("defaults", "ci_simulator_pro"),
            value_type="string",
            group="defaults",
            getter=lambda cfg: cfg.ci_simulator_pro,
        ),
        "defaults.ci_simulator_xr": EditableConfigKey(
            dotted_path="defaults.ci_simulator_xr",
            toml_path=("defaults", "ci_simulator_xr"),
            value_type="string",
            group="defaults",
            getter=lambda cfg: cfg.ci_simulator_xr,
        ),
        "defaults.test_destination_matrix": EditableConfigKey(
            dotted_path="defaults.test_destination_matrix",
            toml_path=("defaults", "test_destination_matrix"),
            value_type="string_list",
            group="defaults",
            getter=lambda cfg: cfg.test_destination_matrix,
        ),
        "defaults.isolated_derived_data": EditableConfigKey(
            dotted_path="defaults.isolated_derived_data",
            toml_path=("defaults", "isolated_derived_data"),
            value_type="string",
            group="defaults",
            getter=lambda cfg: cfg.isolated_derived_data,
        ),
        "tests.unit_test_bundle": EditableConfigKey(
            dotted_path="tests.unit_test_bundle",
            toml_path=("tests", "unit_test_bundle"),
            value_type="string",
            group="tests",
            getter=lambda cfg: cfg.unit_test_bundle,
        ),
        "tests.ui_test_bundle": EditableConfigKey(
            dotted_path="tests.ui_test_bundle",
            toml_path=("tests", "ui_test_bundle"),
            value_type="string",
            group="tests",
            getter=lambda cfg: cfg.ui_test_bundle,
        ),
        "tests.smoke_ui_test": EditableConfigKey(
            dotted_path="tests.smoke_ui_test",
            toml_path=("tests", "smoke_ui_test"),
            value_type="string",
            group="tests",
            getter=lambda cfg: cfg.smoke_ui_test,
        ),
        "tests.xcode_test_flags": EditableConfigKey(
            dotted_path="tests.xcode_test_flags",
            toml_path=("tests", "xcode_test_flags"),
            value_type="string_list",
            group="tests",
            getter=lambda cfg: cfg.xcode_test_flags,
        ),
        "tests.legacy_runtime_skip_flags": EditableConfigKey(
            dotted_path="tests.legacy_runtime_skip_flags",
            toml_path=("tests", "legacy_runtime_skip_flags"),
            value_type="string_list",
            group="tests",
            getter=lambda cfg: cfg.legacy_runtime_skip_flags,
        ),
    }


def _format_config_value(value: object) -> str:
    if isinstance(value, tuple):
        return ", ".join(str(item) for item in value)
    if isinstance(value, list):
        return ", ".join(str(item) for item in value)
    return str(value)


def _parse_bool(raw_value: str) -> bool:
    normalized = raw_value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    msg = f"Cannot parse boolean value from '{raw_value}'. Use true/false."
    raise ValueError(msg)


def _parse_string_list(raw_value: str) -> list[str]:
    candidate = raw_value.strip()
    if not candidate:
        return []
    if candidate.startswith("[") and candidate.endswith("]"):
        parsed = json.loads(candidate)
        if not isinstance(parsed, list):
            msg = "JSON list value must decode to an array."
            raise ValueError(msg)
        return [str(item).strip() for item in parsed if str(item).strip()]
    separator = ";" if ";" in candidate else ","
    return [item.strip() for item in candidate.split(separator) if item.strip()]


def _parse_config_value(raw_value: str, *, value_type: str) -> object:
    if value_type == "string":
        return raw_value
    if value_type == "bool":
        return _parse_bool(raw_value)
    if value_type == "int":
        return int(raw_value.strip())
    if value_type == "string_list":
        return _parse_string_list(raw_value)
    msg = f"Unsupported config value type: {value_type}"
    raise ValueError(msg)


def _read_config_document(path: Path) -> tomlkit.TOMLDocument:
    if not path.is_file():
        return tomlkit.document()
    return tomlkit.parse(path.read_text(encoding="utf-8"))


def _write_config_document(path: Path, document: tomlkit.TOMLDocument) -> None:
    rendered = tomlkit.dumps(document)
    path.write_text(rendered, encoding="utf-8")


def _set_toml_path_value(
    document: tomlkit.TOMLDocument,
    *,
    path: tuple[str, ...],
    value: object,
) -> None:
    table_obj: tomlkit.items.Item | tomlkit.TOMLDocument = document
    for key in path[:-1]:
        existing = table_obj.get(key) if hasattr(table_obj, "get") else None
        if existing is None or not isinstance(existing, tomlkit.items.Table):
            existing = tomlkit.table()
            table_obj[key] = existing
        table_obj = existing
    table_obj[path[-1]] = value


def _set_config_value(
    *,
    repo_root: Path,
    key: EditableConfigKey,
    parsed_value: object,
) -> object:
    cfg_path = config.config_path(repo_root)
    document = _read_config_document(cfg_path)
    _set_toml_path_value(document, path=key.toml_path, value=parsed_value)
    _write_config_document(cfg_path, document)
    loaded = _load_config(repo_root)
    return key.getter(loaded)


def _require_macos_xcode() -> None:
    if sys.platform != "darwin":
        _fail(
            code=3,
            title="Xcode tooling required",
            problem="This command depends on iOS Simulator tooling that only exists on macOS.",
            likely_cause="The command is running on Linux or another non-macOS host.",
            try_commands=("grace doctor",),
        )
        return
    if shutil.which("xcodebuild") is None or shutil.which("xcrun") is None:
        _fail(
            code=3,
            title="Xcode tools missing",
            problem="Could not find `xcodebuild` and `xcrun` on PATH.",
            likely_cause=(
                "Xcode is not installed or xcode-select is pointing at the wrong "
                "developer directory."
            ),
            try_commands=(
                "xcode-select -p",
                "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer",
                "grace doctor",
            ),
        )
        return


def _require_swiftlint() -> None:
    if shutil.which("swiftlint") is None:
        _fail(
            code=1,
            title="SwiftLint unavailable",
            problem="`swiftlint` is not installed or not on PATH.",
            likely_cause=(
                "Homebrew install is missing or shell startup files are not loaded "
                "in this terminal."
            ),
            try_commands=("brew install swiftlint", "grace doctor"),
            retry_command="grace lint",
        )


def _xcodebuild_show_full_logs(*, verbose: bool) -> bool:
    if verbose:
        return True
    if os.environ.get("CI"):
        return True
    return not sys.stdout.isatty()


def _prepare_xcodebuild_argv(argv: list[str], *, verbose: bool) -> list[str]:
    if _xcodebuild_show_full_logs(verbose=verbose):
        return list(argv)
    if len(argv) >= 2 and argv[0] == "xcodebuild":
        if "-downloadPlatform" in argv or "-importPlatform" in argv:
            return list(argv)
    return xcode_helpers.with_quiet_flag(argv, quiet=True)


def _run(
    argv: list[str],
    *,
    cwd: Path,
    check: bool = True,
    verbose: bool = False,
) -> subprocess.CompletedProcess[str]:
    prepared_argv = _prepare_xcodebuild_argv(argv, verbose=verbose)
    try:
        completed = subprocess.run(prepared_argv, cwd=str(cwd), check=False, text=True)
    except FileNotFoundError:
        _fail(
            code=3,
            title="Command not found",
            problem=f"Executable is unavailable: {' '.join(prepared_argv)}",
            likely_cause="The command is not installed or not available in PATH for this shell.",
        )
    if check and completed.returncode != 0:
        raise typer.Exit(code=completed.returncode)
    return completed


def _run_capture(
    argv: list[str],
    *,
    cwd: Path,
    check: bool = True,
    verbose: bool = False,
) -> subprocess.CompletedProcess[str]:
    prepared_argv = _prepare_xcodebuild_argv(argv, verbose=verbose)
    try:
        completed = subprocess.run(
            prepared_argv,
            cwd=str(cwd),
            check=False,
            text=True,
            capture_output=True,
        )
    except FileNotFoundError:
        _fail(
            code=3,
            title="Command not found",
            problem=f"Executable is unavailable: {' '.join(prepared_argv)}",
            likely_cause="The command is not installed or not available in PATH for this shell.",
        )
    if check and completed.returncode != 0:
        if completed.stderr:
            _stderr_console().print(completed.stderr.strip())
        raise typer.Exit(code=completed.returncode)
    return completed


def _to_destination_spec(value: str) -> str:
    if value.startswith("platform="):
        return value
    if "@" not in value:
        _fail(
            code=2,
            title="Cannot parse destination",
            problem=f"Destination '{value}' is missing '@os' and is not a full platform= string.",
            likely_cause="Shortcut syntax expects `device@os` such as `iPhone 17 Pro@latest`.",
            try_commands=("grace sim list",),
            retry_command='grace run --destination "iPhone 17 Pro@latest"',
        )
    name, os_value = value.rsplit("@", 1)
    return f"platform=iOS Simulator,name={name.strip()},OS={os_value.strip()}"


def _resolve_destination(value: str, rows: list[dict[str, str]]) -> str:
    requested = _to_destination_spec(value)
    with redirect_stderr(io.StringIO()) as captured:
        try:
            return simulator.resolve_destination(requested, rows)
        except SystemExit:
            detail = captured.getvalue().strip().splitlines()
    likely_cause = (
        detail[0] if detail else "No installed simulator matches the requested device/runtime pair."
    )
    _fail(
        code=3,
        title="Cannot resolve destination",
        problem=f"No simulator matches `{value}` on this machine.",
        likely_cause=likely_cause,
        try_commands=(
            "grace sim list",
            "grace sim runtime install",
            "xcodebuild -downloadPlatform iOS",
        ),
        retry_command='grace run --destination "iPhone 17 Pro@latest"',
    )
    return ""


def _resolved_destinations_for_matrix(
    specs: tuple[str, ...],
    rows: list[dict[str, str]],
) -> list[str]:
    joined = ";".join(specs)
    with redirect_stderr(io.StringIO()) as captured:
        try:
            return simulator.matrix_destinations_lines(joined, rows)
        except SystemExit:
            detail = captured.getvalue().strip().splitlines()
    likely_cause = (
        detail[0] if detail else "One or more configured matrix destinations are invalid."
    )
    _fail(
        code=3,
        title="Cannot resolve destination matrix",
        problem="At least one matrix destination from config does not match installed simulators.",
        likely_cause=likely_cause,
        try_commands=("grace sim list", f"open {config.config_path(_repo_root())}"),
    )
    return []


def _destination_os_value(spec: str) -> str | None:
    if spec.startswith("platform="):
        fields = simulator.parse_destination(spec)
        value = fields.get("OS", "").strip()
        return value or None
    if "@" not in spec:
        return None
    _, os_value = spec.rsplit("@", 1)
    value = os_value.strip()
    return value or None


def _runtime_install_command_for_os_value(os_value: str) -> str:
    if os_value.lower() == "latest":
        return "grace sim runtime install"
    return f"grace sim runtime install --build-version {os_value}"


def _suggested_runtime_install_commands(
    *,
    cfg_destination: str | None = None,
    matrix_specs: tuple[str, ...] | None = None,
) -> list[str]:
    commands: set[str] = set()
    values: list[str] = []
    if cfg_destination is not None:
        values.append(cfg_destination)
    if matrix_specs is not None:
        values.extend(matrix_specs)
    for spec in values:
        os_value = _destination_os_value(spec)
        if not os_value:
            continue
        commands.add(_runtime_install_command_for_os_value(os_value))
    return sorted(commands)


def _doctor_default_destination_check(
    destination: str, rows: list[dict[str, str]]
) -> dict[str, object]:
    """Resolve default destination for doctor without exiting; stderr message on failure."""
    err = io.StringIO()
    try:
        with redirect_stderr(err):
            requested = _to_destination_spec(destination)
            resolved = simulator.resolve_destination(requested, rows)
    except (SystemExit, typer.Exit):
        detail = err.getvalue().strip().splitlines()
        msg = detail[0] if detail else "Unable to resolve destination; run `grace sim list`"
        suggestions = _suggested_runtime_install_commands(cfg_destination=destination)
        if suggestions:
            msg = f"{msg} Try: {suggestions[0]}; then `grace sim list`."
            return {
                "name": "default destination",
                "status": "error",
                "detail": msg,
                "suggested_commands": suggestions,
            }
        return {
            "name": "default destination",
            "status": "error",
            "detail": msg,
        }
    return {
        "name": "default destination",
        "status": "ok",
        "detail": resolved,
    }


def _doctor_matrix_check(specs: tuple[str, ...], rows: list[dict[str, str]]) -> dict[str, object]:
    """Resolve test matrix for doctor without exiting; stderr message on failure."""
    err = io.StringIO()
    joined = ";".join(specs)
    try:
        with redirect_stderr(err):
            lines = simulator.matrix_destinations_lines(joined, rows)
    except (SystemExit, typer.Exit):
        detail = err.getvalue().strip().splitlines()
        msg = detail[0] if detail else "One or more matrix entries cannot be resolved"
        suggestions = _suggested_runtime_install_commands(matrix_specs=specs)
        if suggestions:
            joined_suggestions = "; ".join(suggestions)
            msg = (
                f"{msg} If the iOS runtime is missing, try: {joined_suggestions}; "
                "then `grace sim list` or update config."
            )
            return {
                "name": "matrix destinations",
                "status": "error",
                "detail": msg,
                "suggested_commands": suggestions,
            }
        return {
            "name": "matrix destinations",
            "status": "error",
            "detail": msg,
        }
    return {
        "name": "matrix destinations",
        "status": "ok",
        "detail": ", ".join(lines),
    }


def _test_only_filter(kind: str, cfg: config.DevConfig) -> list[str] | None:
    if kind == "all":
        return None
    if kind == "unit":
        return [cfg.unit_test_bundle]
    if kind == "ui":
        return [cfg.ui_test_bundle]
    return [cfg.smoke_ui_test]


def _run_test_once(
    *,
    cfg: config.DevConfig,
    repo_root: Path,
    resolved_destination: str,
    kind: str,
    isolated_dd: bool,
    verbose: bool,
) -> None:
    argv = xcode_helpers.test_argv(
        project=repo_root / cfg.project,
        scheme=cfg.scheme,
        resolved_destination=resolved_destination,
        only_testing=_test_only_filter(kind, cfg),
        isolated_derived_data=cfg.isolated_derived_data if isolated_dd else None,
        xcode_test_flags=cfg.xcode_test_flags,
        legacy_skip_flags=cfg.legacy_runtime_skip_flags,
    )
    _run(argv, cwd=repo_root, check=True, verbose=verbose)


def _reset_sims(repo_root: Path) -> None:
    shutdown, erase = xcode_helpers.simctl_reset_all_argv()
    _run(shutdown, cwd=repo_root, check=False)
    _run(erase, cwd=repo_root, check=False)


