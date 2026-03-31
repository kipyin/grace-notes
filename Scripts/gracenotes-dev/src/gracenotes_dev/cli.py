"""Typer entrypoint for the ``grace`` console script."""

from __future__ import annotations

import importlib.metadata
import json
import io
import os
import shlex
import shutil
import subprocess
import sys
import time
from contextlib import redirect_stderr
from dataclasses import dataclass
from pathlib import Path
from typing import Annotated, Callable, TypeVar

import questionary
import tomlkit
import typer
from rich.console import Console, Group
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn, TimeElapsedColumn
from rich.syntax import Syntax
from rich.table import Table
from rich.text import Text

from gracenotes_dev import cli_rich
from gracenotes_dev import config
from gracenotes_dev import simulator
from gracenotes_dev import simulator_runtime
from gracenotes_dev import xcode as xcode_helpers

app = typer.Typer(
    no_args_is_help=True,
    rich_markup_mode="rich",
    help="Grace Notes developer CLI — doctor, simulator helpers, build, clean, test, CI, interactive, and run.",
    epilog=(
        "Examples:\n"
        "  grace doctor\n"
        "  grace build --clean\n"
        '  grace test --kind unit --destination "iPhone 17 Pro@latest"\n'
        '  grace run --destination "iPhone 17 Pro@latest" -- -reset-journal-tutorial\n'
        "\nTip: run `grace --version` to confirm your installed CLI release."
    ),
)
sim_app = typer.Typer(
    help="Simulator destination helpers (xcrun simctl).",
    invoke_without_command=True,
)
app.add_typer(sim_app, name="sim")
runtime_app = typer.Typer(
    help="Manage installed simulator runtimes.",
    epilog=(
        "Examples:\n"
        "  grace sim runtime install\n"
        "  grace sim runtime install --build-version 18.5\n"
        "  grace sim runtime list --json\n"
        "  grace sim runtime delete <runtime-identifier> --dry-run"
    ),
)
sim_app.add_typer(runtime_app, name="runtime")
config_app = typer.Typer(help="Inspect and edit gracenotes-dev.toml.")
app.add_typer(config_app, name="config")

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


def _version_callback(value: bool) -> None:
    if not value:
        return
    _stdout_console().print(_cli_version())
    raise typer.Exit(code=0)


@app.callback()
def app_callback(
    version: Annotated[
        bool,
        typer.Option(
            "--version",
            help="Show the installed grace CLI version and exit.",
            callback=_version_callback,
            is_eager=True,
        ),
    ] = False,
) -> None:
    _ = version


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
                    _step_text(index=index, total=total, title=step.title, outcome="failed", elapsed=elapsed),
                )
            else:
                _stderr_console().print(
                    _step_line(index=index, total=total, title=step.title, outcome="failed", elapsed=elapsed),
                )
            raise
        elapsed = time.perf_counter() - started_step
        if use_rich_theater:
            _stdout_console().print(
                _step_text(index=index, total=total, title=step.title, outcome="ok", elapsed=elapsed),
            )
        else:
            _stdout_console().print(
                _step_line(index=index, total=total, title=step.title, outcome="ok", elapsed=elapsed),
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
        likely_cause="Automation and GitHub Actions should use non-interactive commands and explicit flags.",
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
            likely_cause="Xcode is not installed or xcode-select is pointing at the wrong developer directory.",
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
            likely_cause="Homebrew install is missing or shell startup files are not loaded in this terminal.",
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
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
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
    likely_cause = detail[0] if detail else "No installed simulator matches the requested device/runtime pair."
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
    likely_cause = detail[0] if detail else "One or more configured matrix destinations are invalid."
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


def _doctor_default_destination_check(destination: str, rows: list[dict[str, str]]) -> dict[str, object]:
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


@app.command("doctor")
def doctor(
    json_out: Annotated[
        bool,
        typer.Option("--json", help="Emit machine-readable health checks."),
    ] = False,
) -> None:
    """Preflight check for local toolchain and configured simulator defaults."""
    repo_root = _repo_root()
    cfg = _load_config(repo_root)

    checks: list[dict[str, object]] = []

    swiftlint_path = shutil.which("swiftlint")
    checks.append(
        {
            "name": "swiftlint",
            "status": "ok" if swiftlint_path else "missing",
            "detail": swiftlint_path or "Install with brew install swiftlint",
        },
    )

    xcodebuild_path = shutil.which("xcodebuild")
    checks.append(
        {
            "name": "xcodebuild",
            "status": "ok" if xcodebuild_path else "missing",
            "detail": xcodebuild_path or "Install Xcode and select it with xcode-select",
        },
    )

    xcrun_path = shutil.which("xcrun")
    checks.append(
        {
            "name": "xcrun simctl",
            "status": "ok" if xcrun_path else "missing",
            "detail": xcrun_path or "Requires Xcode command line tools",
        },
    )

    destination_check: dict[str, object] = {
        "name": "default destination",
        "status": "skipped",
        "detail": "xcode tools not available",
    }
    matrix_check: dict[str, object] = {
        "name": "matrix destinations",
        "status": "skipped",
        "detail": "xcode tools not available",
    }

    if sys.platform == "darwin" and xcodebuild_path and xcrun_path:
        try:
            rows = simulator.load_available_ios_devices()
        except (SystemExit, typer.Exit):
            load_detail = "Could not list simulators (simctl failed); run `grace sim list` after fixing Xcode."
            destination_check = {
                "name": "default destination",
                "status": "error",
                "detail": load_detail,
            }
            matrix_check = {
                "name": "matrix destinations",
                "status": "error",
                "detail": load_detail,
            }
        else:
            destination_check = _doctor_default_destination_check(cfg.destination, rows)
            matrix_check = _doctor_matrix_check(cfg.test_destination_matrix, rows)

    checks.extend([destination_check, matrix_check])

    if json_out:
        json.dump({"checks": checks, "config": str(config.config_path(repo_root))}, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return

    table = Table(show_header=True, header_style="bold")
    table.add_column("Check")
    table.add_column("Status")
    table.add_column("Detail")
    for item in checks:
        table.add_row(str(item["name"]), cli_rich.status_text(str(item["status"])), str(item["detail"]))
    _stdout_console().print(table)


@app.command("lint")
def lint() -> None:
    """Run swiftlint from repository root."""
    _require_swiftlint()
    repo_root = _repo_root()
    _run(["swiftlint", "lint"], cwd=repo_root, check=True)


def _sim_list_entries(rows: list[dict[str, str]]) -> list[tuple[str, str, str]]:
    """Deduplicated rows sorted by device name and OS version. Tuple is (xcodebuild line, device, OS)."""
    seen: set[tuple[str, str]] = set()
    entries: list[tuple[str, str, str]] = []
    for row in sorted(rows, key=lambda item: (item["name"], simulator.version_tuple(item["runtime_version"]))):
        key = (row["name"], row["runtime_version"])
        if key in seen:
            continue
        seen.add(key)
        line = f"platform=iOS Simulator,name={row['name']},OS={row['runtime_version']}"
        entries.append((line, row["name"], row["runtime_version"]))
    return entries


def _resolve_default_destination_line(cfg_destination: str, rows: list[dict[str, str]]) -> str | None:
    """Return resolved full destination string for config default, or None if it cannot be resolved."""
    with redirect_stderr(io.StringIO()):
        try:
            return simulator.resolve_destination(cfg_destination, rows)
        except SystemExit:
            return None


def _print_sim_list_plain(
    entries: list[tuple[str, str, str]],
    default_resolved: str | None,
) -> None:
    """Log-friendly lines when stdout is not a TTY or color is disabled."""
    console = _stdout_console()
    console.print(f"{'Default':<8}{'Device':<42}{'OS':<8}Availability")
    for line, name, os_version in entries:
        mark = "*" if default_resolved is not None and line == default_resolved else ""
        console.print(f"{mark:<8}{name:<42}{os_version:<8}available")


def _destination_prompt_choices(default_destination: str, rows: list[dict[str, str]]) -> list[str]:
    shortcuts = [f"{name}@{runtime}" for _, name, runtime in _sim_list_entries(rows)]
    ordered = [default_destination]
    for item in shortcuts:
        if item not in ordered:
            ordered.append(item)
    return ordered


def _prompt_destination_value(
    *,
    message: str,
    default_destination: str,
    rows: list[dict[str, str]],
) -> str:
    choice = _q_select(
        message,
        choices=_destination_prompt_choices(default_destination, rows),
        default=default_destination,
    ).ask()
    return _require_prompt_answer(choice)


def _prompt_optional_text(*, message: str, default_value: str = "") -> str | None:
    value = _q_text(message, default=default_value).ask()
    text = _require_prompt_answer(value).strip()
    return text or None


def _prompt_optional_path(*, message: str, default_value: str = "") -> Path | None:
    value = _prompt_optional_text(message=message, default_value=default_value)
    if value is None:
        return None
    return Path(value)


def _prompt_ci_profile(*, cfg: config.DevConfig, profile: str | None) -> str:
    if profile:
        return profile
    choice = _q_select(
        "CI profile:",
        choices=sorted(cfg.ci_profiles.keys()),
        default=cfg.default_ci_profile,
    ).ask()
    return _require_prompt_answer(choice)


def _prompt_build_options(
    *,
    cfg: config.DevConfig,
    rows: list[dict[str, str]],
    destination: str | None,
    configuration: str,
    derived_data: Path | None,
    do_clean: bool,
    verbose: bool,
) -> tuple[str, str, Path | None, bool, bool]:
    chosen_destination = destination or _prompt_destination_value(
        message="Build destination:",
        default_destination=cfg.destination,
        rows=rows,
    )
    chosen_configuration = _require_prompt_answer(
        _q_select(
            "Build configuration:",
            choices=["Debug", "Release"],
            default=configuration,
        ).ask(),
    )
    chosen_clean = _require_prompt_answer(
        _q_confirm("Run clean before build?", default=do_clean).ask(),
    )
    derived_default = str(derived_data) if derived_data is not None else ""
    chosen_derived_data = _prompt_optional_path(
        message="DerivedData path (empty for Xcode default):",
        default_value=derived_default,
    )
    chosen_verbose = _require_prompt_answer(
        _q_confirm("Show full xcodebuild logs?", default=verbose).ask(),
    )
    return chosen_destination, chosen_configuration, chosen_derived_data, chosen_clean, chosen_verbose


def _prompt_clean_options(
    *,
    cfg: config.DevConfig,
    rows: list[dict[str, str]],
    destination: str | None,
    configuration: str,
    derived_data: Path | None,
    verbose: bool,
) -> tuple[str, str, Path | None, bool]:
    chosen_destination = destination or _prompt_destination_value(
        message="Clean destination:",
        default_destination=cfg.destination,
        rows=rows,
    )
    chosen_configuration = _require_prompt_answer(
        _q_select(
            "Build configuration:",
            choices=["Debug", "Release"],
            default=configuration,
        ).ask(),
    )
    derived_default = str(derived_data) if derived_data is not None else ""
    chosen_derived_data = _prompt_optional_path(
        message="DerivedData path (empty for Xcode default):",
        default_value=derived_default,
    )
    chosen_verbose = _require_prompt_answer(
        _q_confirm("Show full xcodebuild logs?", default=verbose).ask(),
    )
    return chosen_destination, chosen_configuration, chosen_derived_data, chosen_verbose


def _prompt_test_options(
    *,
    cfg: config.DevConfig,
    rows: list[dict[str, str]],
    kind: str,
    destination: str | None,
    matrix: bool,
    isolated_dd: bool,
    no_reset_sims: bool,
    verbose: bool,
) -> tuple[str, str | None, bool, bool, bool, bool]:
    chosen_kind = _require_prompt_answer(
        _q_select(
            "Test kind:",
            choices=["all", "unit", "ui", "smoke"],
            default=kind,
        ).ask(),
    )
    chosen_matrix = False
    if chosen_kind != "smoke":
        chosen_matrix = _require_prompt_answer(
            _q_confirm("Run destination matrix?", default=matrix).ask(),
        )
    chosen_destination: str | None = destination
    if not chosen_matrix:
        chosen_destination = destination or _prompt_destination_value(
            message="Test destination:",
            default_destination=cfg.destination,
            rows=rows,
        )
    chosen_isolated_dd = _require_prompt_answer(
        _q_confirm("Use isolated DerivedData?", default=isolated_dd).ask(),
    )
    chosen_no_reset = _require_prompt_answer(
        _q_confirm("Skip simulator reset?", default=no_reset_sims).ask(),
    )
    chosen_verbose = _require_prompt_answer(
        _q_confirm("Show full xcodebuild logs?", default=verbose).ask(),
    )
    return (
        chosen_kind,
        chosen_destination,
        chosen_matrix,
        chosen_isolated_dd,
        chosen_no_reset,
        chosen_verbose,
    )


def _prompt_run_options(
    *,
    cfg: config.DevConfig,
    rows: list[dict[str, str]],
    scheme: str | None,
    destination: str | None,
    preset: str | None,
    bundle_id: str | None,
    derived_data: Path | None,
    app_args: list[str] | None,
    verbose: bool,
) -> tuple[str, str, str | None, str, Path | None, list[str], bool]:
    chosen_destination = destination or _prompt_destination_value(
        message="Run destination:",
        default_destination=cfg.destination,
        rows=rows,
    )
    chosen_scheme = _prompt_optional_text(
        message="Scheme:",
        default_value=scheme or cfg.scheme,
    ) or cfg.scheme
    preset_choices = ["(none)", *sorted(cfg.run_presets.keys())]
    chosen_preset = preset
    if preset is None and len(preset_choices) > 1:
        selected = _require_prompt_answer(
            _q_select("Run preset:", choices=preset_choices, default="(none)").ask(),
        )
        chosen_preset = None if selected == "(none)" else selected
    chosen_bundle = _prompt_optional_text(
        message="Bundle identifier:",
        default_value=bundle_id or cfg.bundle_id,
    ) or cfg.bundle_id
    derived_default = str(derived_data) if derived_data is not None else ""
    chosen_derived_data = _prompt_optional_path(
        message="DerivedData path (empty for default):",
        default_value=derived_default,
    )
    default_args = " ".join(app_args or [])
    raw_args = _prompt_optional_text(
        message="Extra app args (space-separated, empty for none):",
        default_value=default_args,
    )
    chosen_args = shlex.split(raw_args) if raw_args else list(app_args or [])
    chosen_verbose = _require_prompt_answer(
        _q_confirm("Show full xcodebuild logs?", default=verbose).ask(),
    )
    return (
        chosen_scheme,
        chosen_destination,
        chosen_preset,
        chosen_bundle,
        chosen_derived_data,
        chosen_args,
        chosen_verbose,
    )


def _load_runtime_records(repo_root: Path) -> list[simulator_runtime.RuntimeRecord]:
    completed = _run_capture(
        simulator_runtime.simctl_runtime_list_argv(json_out=True),
        cwd=repo_root,
        check=True,
    )
    try:
        records = simulator_runtime.parse_runtime_list_json(completed.stdout)
        if records:
            return records
    except json.JSONDecodeError:
        pass
    fallback = _run_capture(
        simulator_runtime.simctl_runtime_list_argv(json_out=False),
        cwd=repo_root,
        check=True,
    )
    return simulator_runtime.parse_runtime_list_text(fallback.stdout)


def _print_runtime_list(records: list[simulator_runtime.RuntimeRecord]) -> None:
    if _supports_rich_output(sys.stdout):
        table = Table(show_header=True, header_style="bold")
        table.add_column("Platform")
        table.add_column("Version", justify="right")
        table.add_column("Build", justify="right")
        table.add_column("State")
        table.add_column("Identifier")
        for row in records:
            table.add_row(row.platform, row.version, row.build, cli_rich.status_text(row.state), row.identifier)
        _stdout_console().print(table)
        return

    console = _stdout_console()
    console.print(f"{'Platform':<10}{'Version':<10}{'Build':<10}{'State':<12}Identifier")
    for row in records:
        console.print(f"{row.platform:<10}{row.version:<10}{row.build:<10}{row.state:<12}{row.identifier}")


def _sim_interactive(*, cfg: config.DevConfig) -> None:
    choice = _require_prompt_answer(
        _q_select(
            "Simulator action:",
            choices=[
                "List destinations",
                "Resolve destination",
                "Reset simulators",
                "Install runtime",
                "List runtimes",
                "Delete runtime",
                "Exit",
            ],
            default="List destinations",
        ).ask(),
    )
    if choice == "Exit":
        return
    if choice == "List destinations":
        sim_list()
        return
    if choice == "Resolve destination":
        spec = _prompt_optional_text(
            message="Destination spec (device@os or platform=...):",
            default_value=cfg.destination,
        ) or cfg.destination
        sim_resolve(spec=spec)
        return
    if choice == "Reset simulators":
        confirmed = _require_prompt_answer(
            _q_confirm("Shutdown and erase all simulators?", default=False).ask(),
        )
        if confirmed:
            sim_reset()
        return
    if choice == "Install runtime":
        build_version = _prompt_optional_text(
            message="Build version (empty for default download):",
            default_value="",
        )
        run_simctl_add = _require_prompt_answer(
            _q_confirm(
                "Also run `xcrun simctl runtime add` after import?",
                default=False,
            ).ask(),
        )
        runtime_install(
            build_version=build_version,
            export_path=None,
            from_dmg=None,
            simctl_add=run_simctl_add,
            move_dmg=False,
            dry_run=False,
        )
        return
    if choice == "List runtimes":
        runtime_list()
        return

    repo_root = _repo_root()
    records = _load_runtime_records(repo_root)
    if not records:
        _stdout_console().print("No installed simulator runtimes found.")
        return
    labels = [f"{row.platform} {row.version} ({row.build}) - {row.identifier}" for row in records]
    selected = _require_prompt_answer(
        _q_select("Runtime to delete:", choices=labels, default=labels[0]).ask(),
    )
    identifier = selected.rsplit(" - ", 1)[-1]
    confirmed = _require_prompt_answer(
        _q_confirm(f"Delete runtime {identifier}?", default=False).ask(),
    )
    if confirmed:
        runtime_delete(identifier=identifier, dry_run=False, keep_asset=False)


@sim_app.callback()
def sim_callback(
    ctx: typer.Context,
    interactive: Annotated[
        bool,
        typer.Option("--interactive", "-i", help="Prompt for simulator helpers interactively."),
    ] = False,
) -> None:
    if interactive and ctx.invoked_subcommand is not None:
        _fail(
            code=2,
            title="Interactive mode and subcommand conflict",
            problem="Use `grace sim --interactive` alone, or run the subcommand without `--interactive`.",
            try_commands=("grace sim -i", "grace sim list"),
        )
    if interactive:
        repo_root = _repo_root()
        cfg = _load_config(repo_root)
        _require_interactive_cli(cfg=cfg, command_name="grace sim --interactive")
        _sim_interactive(cfg=cfg)
        raise typer.Exit(code=0)
    if ctx.invoked_subcommand is None:
        _stdout_console().print(ctx.get_help())
        raise typer.Exit(code=0)


@runtime_app.command("install")
def runtime_install(
    build_version: Annotated[
        str | None,
        typer.Option(
            "--build-version",
            help="Optional runtime build version (maps to `xcodebuild -buildVersion`).",
        ),
    ] = None,
    export_path: Annotated[
        Path | None,
        typer.Option(
            "--export-path",
            help="Directory used for downloaded runtime DMGs.",
        ),
    ] = None,
    from_dmg: Annotated[
        Path | None,
        typer.Option(
            "--from-dmg",
            help="Import an existing runtime DMG (skip download).",
        ),
    ] = None,
    simctl_add: Annotated[
        bool,
        typer.Option(
            "--simctl-add/--no-simctl-add",
            help="Also run `xcrun simctl runtime add` after xcodebuild import.",
        ),
    ] = False,
    move_dmg: Annotated[
        bool,
        typer.Option(
            "--move-dmg",
            help="With `--simctl-add`, move the DMG into simulator runtime storage.",
        ),
    ] = False,
    dry_run: Annotated[
        bool,
        typer.Option("--dry-run", help="Print commands without executing."),
    ] = False,
) -> None:
    """Download and install an iOS simulator runtime."""
    _require_macos_xcode()
    repo_root = _repo_root()
    if move_dmg and not simctl_add:
        _fail(
            code=2,
            title="Invalid runtime install flags",
            problem="`--move-dmg` requires `--simctl-add`.",
            try_commands=("grace sim runtime install --simctl-add --move-dmg",),
        )
    if from_dmg is not None and build_version:
        _fail(
            code=2,
            title="Invalid runtime install flags",
            problem="`--from-dmg` cannot be combined with `--build-version`.",
            try_commands=("grace sim runtime install --from-dmg /path/to/runtime.dmg",),
        )

    download_dir = (export_path or (repo_root / ".grace" / "sim-runtime-downloads")).expanduser()
    selected_dmg = from_dmg.expanduser() if from_dmg is not None else None
    command_plan: list[list[str]] = []

    if selected_dmg is None:
        command_plan.append(
            simulator_runtime.xcode_download_platform_argv(
                export_path=download_dir,
                build_version=build_version,
            ),
        )
        import_target = download_dir / "<downloaded-runtime>.dmg"
    else:
        if not dry_run and not selected_dmg.is_file():
            _fail(
                code=2,
                title="Runtime DMG not found",
                problem=f"No file exists at `{selected_dmg}`.",
                try_commands=("grace sim runtime install",),
            )
        import_target = selected_dmg
    command_plan.append(simulator_runtime.xcode_import_platform_argv(dmg_path=import_target))
    if simctl_add:
        command_plan.append(
            simulator_runtime.simctl_runtime_add_argv(
                dmg_path=import_target,
                move=move_dmg,
                async_mode=False,
            ),
        )

    needs_download = selected_dmg is None

    if dry_run:
        if _supports_rich_output(sys.stdout):
            console = _stdout_console()
            for index, argv in enumerate(command_plan, start=1):
                console.print(Text(f"{index}.", style="accent"))
                console.print(Syntax(shlex.join(argv), "bash", word_wrap=False))
        else:
            for argv in command_plan:
                _stdout_console().print(" ".join(shlex.quote(item) for item in argv))
        return

    if selected_dmg is None:
        download_dir.mkdir(parents=True, exist_ok=True)
        _run(command_plan[0], cwd=repo_root, check=True)
        try:
            selected_dmg = simulator_runtime.discover_downloaded_dmg(export_path=download_dir)
        except FileNotFoundError as exc:
            _fail(
                code=3,
                title="Runtime download completed but DMG was not found",
                problem=str(exc),
                try_commands=(f"ls {download_dir}", "grace sim runtime install --from-dmg /path/to/runtime.dmg"),
            )
        command_plan[1] = simulator_runtime.xcode_import_platform_argv(dmg_path=selected_dmg)
        if simctl_add:
            command_plan[2] = simulator_runtime.simctl_runtime_add_argv(
                dmg_path=selected_dmg,
                move=move_dmg,
                async_mode=False,
            )

    start_index = 1 if needs_download else 0
    for argv in command_plan[start_index:]:
        _run(argv, cwd=repo_root, check=True)

    if selected_dmg is not None:
        _stdout_console().print(f"Installed runtime from {selected_dmg}")


@runtime_app.command("list")
def runtime_list(
    json_out: Annotated[
        bool,
        typer.Option("--json", help="Emit a JSON array of installed runtime records."),
    ] = False,
) -> None:
    """List installed simulator runtimes."""
    _require_macos_xcode()
    repo_root = _repo_root()
    records = _load_runtime_records(repo_root)
    if json_out:
        payload = [simulator_runtime.runtime_record_to_dict(row) for row in records]
        json.dump(payload, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return
    _print_runtime_list(records)


@runtime_app.command("delete")
def runtime_delete(
    identifier: Annotated[
        str,
        typer.Argument(help="Runtime identifier from `grace sim runtime list`."),
    ],
    dry_run: Annotated[
        bool,
        typer.Option("--dry-run", help="Preview delete without removing runtimes."),
    ] = False,
    keep_asset: Annotated[
        bool,
        typer.Option("--keep-asset", help="Keep the underlying mobile asset while deleting."),
    ] = False,
) -> None:
    """Delete one simulator runtime by identifier (or `all`)."""
    _require_macos_xcode()
    repo_root = _repo_root()
    argv = simulator_runtime.simctl_runtime_delete_argv(
        identifier=identifier,
        dry_run=dry_run,
        keep_asset=keep_asset,
    )
    _run(argv, cwd=repo_root, check=True)


@sim_app.command("list")
def sim_list(
    json_out: Annotated[
        bool,
        typer.Option("--json", help="Emit a JSON array of xcodebuild destination strings."),
    ] = False,
) -> None:
    """List installed iOS Simulator destinations."""
    _require_macos_xcode()
    rows = simulator.load_available_ios_devices()
    entries = _sim_list_entries(rows)
    lines = [item[0] for item in entries]
    if json_out:
        json.dump(lines, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return

    cfg = _load_config(_repo_root())
    default_resolved = _resolve_default_destination_line(cfg.destination, rows)

    if _supports_rich_output(sys.stdout):
        table = Table(show_header=True, header_style="bold")
        table.add_column("Default", justify="center", min_width=3)
        table.add_column("Device")
        table.add_column("OS", justify="right")
        table.add_column("Availability")
        for line, name, os_version in entries:
            is_default = default_resolved is not None and line == default_resolved
            mark = Text("*", style="accent") if is_default else Text("")
            device_name = Text(name, style="bold" if is_default else "")
            table.add_row(mark, device_name, os_version, "available")
        _stdout_console().print(table)
        return

    _print_sim_list_plain(entries, default_resolved)


@sim_app.command("resolve")
def sim_resolve(
    spec: Annotated[str, typer.Argument(help="Device@os shortcut or full platform=... destination.")],
    json_out: Annotated[
        bool,
        typer.Option("--json", help="Emit JSON {\"resolved\": \"...\"}."),
    ] = False,
) -> None:
    """Resolve ``@latest`` (or validate a full destination) for xcodebuild."""
    _require_macos_xcode()
    rows = simulator.load_available_ios_devices()
    resolved = _resolve_destination(spec, rows)
    if json_out:
        json.dump({"resolved": resolved}, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return
    _stdout_console().print(resolved)


@sim_app.command("reset")
def sim_reset() -> None:
    """Shutdown and erase all simulators."""
    _require_macos_xcode()
    _reset_sims(_repo_root())


@app.command("build")
def build(
    destination: Annotated[
        str | None,
        typer.Option(
            "--destination",
            "-d",
            help="Destination spec (platform=... or device@os). Defaults to config.",
        ),
    ] = None,
    configuration: Annotated[
        str,
        typer.Option(
            "--configuration",
            help="Build configuration.",
        ),
    ] = "Debug",
    derived_data: Annotated[
        Path | None,
        typer.Option("--derived-data", help="Custom DerivedData path."),
    ] = None,
    do_clean: Annotated[
        bool,
        typer.Option(
            "--clean",
            help="Run xcodebuild clean for this scheme/destination before building.",
        ),
    ] = False,
    interactive: Annotated[
        bool,
        typer.Option("--interactive", "-i", help="Prompt for build inputs interactively."),
    ] = False,
    verbose: Annotated[
        bool,
        typer.Option("--verbose", "-v", help="Show full xcodebuild logs."),
    ] = False,
) -> None:
    """Build the Grace Notes app for an iOS Simulator destination."""
    _require_macos_xcode()
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    rows = simulator.load_available_ios_devices()
    if interactive:
        _require_interactive_cli(cfg=cfg, command_name="grace build --interactive")
        destination, configuration, derived_data, do_clean, verbose = _prompt_build_options(
            cfg=cfg,
            rows=rows,
            destination=destination,
            configuration=configuration,
            derived_data=derived_data,
            do_clean=do_clean,
            verbose=verbose,
        )
    resolved_destination = _resolve_destination(destination or cfg.destination, rows)
    clean_argv = xcode_helpers.clean_argv(
        project=repo_root / cfg.project,
        scheme=cfg.scheme,
        resolved_destination=resolved_destination,
        configuration=configuration,
        derived_data_path=derived_data,
    )
    build_argv = xcode_helpers.build_argv(
        project=repo_root / cfg.project,
        scheme=cfg.scheme,
        resolved_destination=resolved_destination,
        configuration=configuration,
        derived_data_path=derived_data,
    )

    def resolve_step() -> str:
        return resolved_destination

    def clean_step() -> str:
        _run(clean_argv, cwd=repo_root, check=True, verbose=verbose)
        return " ".join(clean_argv)

    def build_step() -> str:
        _run(build_argv, cwd=repo_root, check=True, verbose=verbose)
        return " ".join(build_argv)

    steps = [
        TheaterStep("Resolve destination", resolve_step),
    ]
    if do_clean:
        steps.append(TheaterStep(f"Clean ({configuration}, {cfg.scheme})", clean_step))
    steps.append(TheaterStep(f"Build ({configuration}, {cfg.scheme})", build_step))
    _run_theater(steps)


@app.command("clean")
def clean(
    destination: Annotated[
        str | None,
        typer.Option(
            "--destination",
            "-d",
            help="Destination spec (platform=... or device@os). Defaults to config.",
        ),
    ] = None,
    configuration: Annotated[
        str,
        typer.Option(
            "--configuration",
            help="Build configuration.",
        ),
    ] = "Debug",
    derived_data: Annotated[
        Path | None,
        typer.Option("--derived-data", help="Custom DerivedData path."),
    ] = None,
    interactive: Annotated[
        bool,
        typer.Option("--interactive", "-i", help="Prompt for clean inputs interactively."),
    ] = False,
    verbose: Annotated[
        bool,
        typer.Option("--verbose", "-v", help="Show full xcodebuild logs."),
    ] = False,
) -> None:
    """Run xcodebuild clean for the Grace Notes scheme (Xcode Clean Build Folder scope)."""
    _require_macos_xcode()
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    rows = simulator.load_available_ios_devices()
    if interactive:
        _require_interactive_cli(cfg=cfg, command_name="grace clean --interactive")
        destination, configuration, derived_data, verbose = _prompt_clean_options(
            cfg=cfg,
            rows=rows,
            destination=destination,
            configuration=configuration,
            derived_data=derived_data,
            verbose=verbose,
        )
    resolved_destination = _resolve_destination(destination or cfg.destination, rows)
    argv = xcode_helpers.clean_argv(
        project=repo_root / cfg.project,
        scheme=cfg.scheme,
        resolved_destination=resolved_destination,
        configuration=configuration,
        derived_data_path=derived_data,
    )

    def resolve_step() -> str:
        return resolved_destination

    def clean_step() -> str:
        _run(argv, cwd=repo_root, check=True, verbose=verbose)
        return " ".join(argv)

    _run_theater(
        [
            TheaterStep("Resolve destination", resolve_step),
            TheaterStep(f"Clean ({configuration}, {cfg.scheme})", clean_step),
        ],
    )


@app.command("test")
def test(
    kind: Annotated[
        str,
        typer.Option(
            "--kind",
            help="Test kind: all, unit, ui, or smoke.",
            case_sensitive=False,
        ),
    ] = "all",
    destination: Annotated[
        str | None,
        typer.Option(
            "--destination",
            "-d",
            help="Destination spec for non-matrix runs.",
        ),
    ] = None,
    matrix: Annotated[
        bool,
        typer.Option("--matrix", help="Run across configured test destination matrix."),
    ] = False,
    isolated_dd: Annotated[
        bool,
        typer.Option("--isolated-dd", help="Use isolated DerivedData for tests."),
    ] = False,
    no_reset_sims: Annotated[
        bool,
        typer.Option("--no-reset-sims", help="Skip simulator reset before matrix/smoke runs."),
    ] = False,
    interactive: Annotated[
        bool,
        typer.Option("--interactive", "-i", help="Prompt for test inputs interactively."),
    ] = False,
    verbose: Annotated[
        bool,
        typer.Option("--verbose", "-v", help="Show full xcodebuild logs."),
    ] = False,
) -> None:
    """Run xcodebuild tests (single destination or matrix)."""
    _require_macos_xcode()
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    rows = simulator.load_available_ios_devices()
    if interactive:
        _require_interactive_cli(cfg=cfg, command_name="grace test --interactive")
        kind, destination, matrix, isolated_dd, no_reset_sims, verbose = _prompt_test_options(
            cfg=cfg,
            rows=rows,
            kind=kind,
            destination=destination,
            matrix=matrix,
            isolated_dd=isolated_dd,
            no_reset_sims=no_reset_sims,
            verbose=verbose,
        )

    selected_kind = kind.lower()
    if selected_kind not in {"all", "unit", "ui", "smoke"}:
        _fail(
            code=2,
            title="Invalid test kind",
            problem=f"`{kind}` is not one of all, unit, ui, or smoke.",
            try_commands=("grace test --help",),
            retry_command="grace test --kind all",
        )
    if matrix and selected_kind == "smoke":
        _fail(
            code=2,
            title="Unsupported flag combination",
            problem="Smoke tests run against one simulator and cannot use --matrix.",
            try_commands=("grace test --kind smoke", "grace test --kind all --matrix"),
        )

    reset_before_run = not no_reset_sims and (matrix or selected_kind == "smoke")
    test_started = time.perf_counter()

    if matrix:
        resolved_destinations = _resolved_destinations_for_matrix(cfg.test_destination_matrix, rows)
        steps: list[TheaterStep] = []
        for resolved_destination in resolved_destinations:
            if reset_before_run:
                steps.append(
                    TheaterStep(
                        "Reset simulators",
                        lambda: (_reset_sims(repo_root) or "shutdown all + erase all"),
                    ),
                )
            steps.append(
                TheaterStep(
                    f"Run {selected_kind} tests",
                    lambda resolved_destination=resolved_destination: (
                        _run_test_once(
                            cfg=cfg,
                            repo_root=repo_root,
                            resolved_destination=resolved_destination,
                            kind=selected_kind,
                            isolated_dd=isolated_dd,
                            verbose=verbose,
                        )
                        or resolved_destination
                    ),
                ),
            )
        _run_theater(steps)
        _stdout_console().print(
            "Tests finished: "
            f"kind={selected_kind}, destinations={len(resolved_destinations)}, "
            f"wall time {time.perf_counter() - test_started:.2f}s",
        )
        return

    resolved_destination = _resolve_destination(destination or cfg.destination, rows)

    steps = []
    if reset_before_run:
        steps.append(
            TheaterStep(
                "Reset simulators",
                lambda: (_reset_sims(repo_root) or "shutdown all + erase all"),
            ),
        )
    steps.append(TheaterStep("Resolve destination", lambda: resolved_destination))
    if selected_kind == "smoke":
        simulator_name = xcode_helpers.resolved_name_for_smoke(resolved_destination)
        boot, bootstatus = xcode_helpers.simctl_boot_sequence_argv(simulator_name)
        steps.append(
            TheaterStep(
                "Boot simulator",
                lambda: (_run(boot, cwd=repo_root, check=False), _run(bootstatus, cwd=repo_root, check=False))
                and simulator_name,
            ),
        )

    steps.append(
        TheaterStep(
            f"Run {selected_kind} tests",
            lambda: (
                _run_test_once(
                    cfg=cfg,
                    repo_root=repo_root,
                    resolved_destination=resolved_destination,
                    kind=selected_kind,
                    isolated_dd=isolated_dd,
                    verbose=verbose,
                )
                or resolved_destination
            ),
        ),
    )
    _run_theater(steps)
    _stdout_console().print(
        f"Tests finished: kind={selected_kind}, destination={resolved_destination}, "
        f"wall time {time.perf_counter() - test_started:.2f}s",
    )


def _execute_ci_profile(cfg: config.DevConfig, profile: str, *, verbose: bool = False) -> None:
    """Run lint / build / test / smoke gates for a configured CI profile name."""
    selected = cfg.ci_profiles.get(profile)
    if selected is None:
        _fail(
            code=2,
            title="Unknown CI profile",
            problem=f"`{profile}` is not defined in {config.DEFAULT_CONFIG_FILENAME}.",
            likely_cause="The profile name is misspelled or the profile has not been configured.",
            try_commands=(f"grace ci --profile {cfg.default_ci_profile}",),
            retry_command=f"grace ci --profile {cfg.default_ci_profile}",
        )
        return

    if selected.lint:
        lint()

    needs_xcode = selected.build or selected.test or selected.smoke
    if needs_xcode:
        _require_macos_xcode()

    if selected.build:
        build(destination=selected.build_destination or cfg.ci_simulator_pro, verbose=verbose)

    if selected.test:
        test(
            kind=selected.test_kind,
            destination=selected.test_destination,
            matrix=selected.matrix,
            isolated_dd=selected.isolated_dd,
            no_reset_sims=not selected.reset_simulators_before_test,
            verbose=verbose,
        )

    if selected.smoke:
        test(
            kind="smoke",
            destination=selected.smoke_destination or cfg.ci_simulator_xr,
            matrix=False,
            isolated_dd=selected.isolated_dd,
            no_reset_sims=False,
            verbose=verbose,
        )


@app.command("ci")
def ci(
    profile: Annotated[
        str | None,
        typer.Option(
            "--profile",
            help=(
                "CI profile from config (for example: lint-build-test, lint-build, test-all, full). "
                "When omitted, uses defaults.default_ci_profile from gracenotes-dev.toml."
            ),
        ),
    ] = None,
    interactive: Annotated[
        bool,
        typer.Option("--interactive", "-i", help="Prompt for CI inputs interactively."),
    ] = False,
    verbose: Annotated[
        bool,
        typer.Option("--verbose", "-v", help="Show full xcodebuild logs."),
    ] = False,
) -> None:
    """Run a CI profile from ``gracenotes-dev.toml`` (default: ``defaults.default_ci_profile``)."""
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    if interactive:
        _require_interactive_cli(cfg=cfg, command_name="grace ci --interactive")
        profile = _prompt_ci_profile(cfg=cfg, profile=profile)
    resolved = (profile or "").strip() or cfg.default_ci_profile
    _execute_ci_profile(cfg, resolved, verbose=verbose)


@app.command("interactive")
def interactive() -> None:
    """Interactive hub for CI, build/test/run, and maintenance commands."""
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    _require_interactive_cli(cfg=cfg, command_name="grace interactive")
    rows: list[dict[str, str]] = []

    action = _q_select(
        "Choose command:",
        choices=[
            "CI",
            "Build",
            "Test",
            "Run",
            "Lint",
            "Clean",
            "Doctor",
            "Config (interactive)",
            "Exit",
        ],
    ).ask()
    choice = _require_prompt_answer(action)
    if choice == "Exit":
        return
    if choice == "CI":
        profile = _prompt_ci_profile(cfg=cfg, profile=None)
        show_verbose = _require_prompt_answer(
            _q_confirm("Show full xcodebuild logs?", default=False).ask(),
        )
        _execute_ci_profile(cfg, profile, verbose=show_verbose)
        return
    if choice == "Build":
        _require_macos_xcode()
        rows = simulator.load_available_ios_devices()
        destination, configuration, derived_data, do_clean, verbose = _prompt_build_options(
            cfg=cfg,
            rows=rows,
            destination=None,
            configuration="Debug",
            derived_data=None,
            do_clean=False,
            verbose=False,
        )
        build(
            destination=destination,
            configuration=configuration,
            derived_data=derived_data,
            do_clean=do_clean,
            verbose=verbose,
        )
        return
    if choice == "Test":
        _require_macos_xcode()
        rows = simulator.load_available_ios_devices()
        kind, destination, matrix, isolated_dd, no_reset_sims, verbose = _prompt_test_options(
            cfg=cfg,
            rows=rows,
            kind="all",
            destination=None,
            matrix=False,
            isolated_dd=False,
            no_reset_sims=False,
            verbose=False,
        )
        test(
            kind=kind,
            destination=destination,
            matrix=matrix,
            isolated_dd=isolated_dd,
            no_reset_sims=no_reset_sims,
            verbose=verbose,
        )
        return
    if choice == "Run":
        _require_macos_xcode()
        rows = simulator.load_available_ios_devices()
        (
            scheme,
            destination,
            preset,
            bundle_id,
            derived_data,
            app_args,
            verbose,
        ) = _prompt_run_options(
            cfg=cfg,
            rows=rows,
            scheme=None,
            destination=None,
            preset=None,
            bundle_id=None,
            derived_data=None,
            app_args=None,
            verbose=False,
        )
        run(
            scheme=scheme,
            destination=destination,
            preset=preset,
            bundle_id=bundle_id,
            derived_data=derived_data,
            app_args=app_args,
            verbose=verbose,
        )
        return
    if choice == "Lint":
        lint()
        return
    if choice == "Clean":
        _require_macos_xcode()
        rows = simulator.load_available_ios_devices()
        destination, configuration, derived_data, verbose = _prompt_clean_options(
            cfg=cfg,
            rows=rows,
            destination=None,
            configuration="Debug",
            derived_data=None,
            verbose=False,
        )
        clean(
            destination=destination,
            configuration=configuration,
            derived_data=derived_data,
            verbose=verbose,
        )
        return
    if choice == "Doctor":
        doctor()
        return
    config_interactive()


@app.command(
    "run",
    epilog=(
        "Examples:\n"
        '  grace run --destination "iPhone 17 Pro@latest"\n'
        '  grace run --preset tutorial-reset -- -reset-journal-tutorial'
    ),
)
def run(
    scheme: Annotated[
        str | None,
        typer.Option("--scheme", "-s", help="Xcode scheme. Defaults to config value."),
    ] = None,
    destination: Annotated[
        str | None,
        typer.Option("--destination", "-d", help="Destination spec (platform=... or device@os)."),
    ] = None,
    preset: Annotated[
        str | None,
        typer.Option("--preset", help="Named app-argument preset from config."),
    ] = None,
    bundle_id: Annotated[
        str | None,
        typer.Option("--bundle-id", help="Bundle identifier to launch."),
    ] = None,
    derived_data: Annotated[
        Path | None,
        typer.Option("--derived-data", help="DerivedData path used for build and app lookup."),
    ] = None,
    app_args: Annotated[
        list[str] | None,
        typer.Argument(help="App launch arguments (use -- before args that start with -)."),
    ] = None,
    interactive: Annotated[
        bool,
        typer.Option("--interactive", "-i", help="Prompt for run inputs interactively."),
    ] = False,
    verbose: Annotated[
        bool,
        typer.Option("--verbose", "-v", help="Show full xcodebuild logs."),
    ] = False,
) -> None:
    """Build, install, and launch Grace Notes on a Simulator."""
    _require_macos_xcode()
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    rows = simulator.load_available_ios_devices()
    if interactive:
        _require_interactive_cli(cfg=cfg, command_name="grace run --interactive")
        (
            scheme,
            destination,
            preset,
            bundle_id,
            derived_data,
            app_args,
            verbose,
        ) = _prompt_run_options(
            cfg=cfg,
            rows=rows,
            scheme=scheme,
            destination=destination,
            preset=preset,
            bundle_id=bundle_id,
            derived_data=derived_data,
            app_args=app_args,
            verbose=verbose,
        )

    resolved_destination = _resolve_destination(destination or cfg.destination, rows)
    resolved_scheme = scheme or cfg.scheme
    resolved_bundle_id = bundle_id or cfg.bundle_id
    derived_data_path = derived_data or (repo_root / ".grace-derived-data" / "run")
    derived_data_path.mkdir(parents=True, exist_ok=True)

    expanded_args = list(app_args or [])
    if preset:
        if preset not in cfg.run_presets:
            available = ", ".join(sorted(cfg.run_presets.keys())) or "(none configured)"
            _fail(
                code=2,
                title="Unknown run preset",
                problem=f"`{preset}` is not configured under [run.presets].",
                likely_cause=f"Available presets: {available}.",
                try_commands=(
                    f"open {config.config_path(repo_root)}",
                    "grace run --help",
                ),
            )
        expanded_args = [*cfg.run_presets[preset], *expanded_args]

    xcodeproj = (repo_root / cfg.project).resolve()
    try:
        launch_configuration, product_stem = xcode_helpers.run_launch_metadata_from_scheme(
            xcodeproj=xcodeproj,
            scheme=resolved_scheme,
        )
    except ValueError as exc:
        _fail(
            code=2,
            title="Scheme metadata unreadable",
            problem=str(exc),
            likely_cause="The scheme may be missing from the Xcode project or the .xcscheme XML is unexpected.",
            try_commands=(
                f"ls {xcodeproj / 'xcshareddata/xcschemes'}",
                "grace run --help",
            ),
        )

    device_row = simulator.row_for_resolved_destination(resolved_destination, rows)
    udid = (device_row or {}).get("udid", "").strip()
    if not udid:
        _fail(
            code=3,
            title="Cannot resolve simulator UDID",
            problem=f"No simulator UDID matches `{resolved_destination}` in the current device list.",
            likely_cause="simctl list changed between destination resolution and run, or device data is incomplete.",
            try_commands=("grace sim list", "xcrun simctl list devices available"),
        )

    steps: list[TheaterStep] = []

    def resolve_step() -> str:
        return resolved_destination

    def boot_step() -> str:
        boot, bootstatus = xcode_helpers.simctl_boot_sequence_argv_udid(udid)
        _run(boot, cwd=repo_root, check=False)
        _run(bootstatus, cwd=repo_root, check=False)
        return udid

    def build_step() -> str:
        argv = xcode_helpers.build_argv(
            project=repo_root / cfg.project,
            scheme=resolved_scheme,
            resolved_destination=resolved_destination,
            configuration=launch_configuration,
            derived_data_path=derived_data_path,
        )
        _run(argv, cwd=repo_root, check=True, verbose=verbose)
        return " ".join(argv)

    def install_step() -> str:
        app_path = xcode_helpers.built_app_path(
            derived_data_path,
            configuration=launch_configuration,
            product_stem=product_stem,
        )
        _run(
            xcode_helpers.simctl_install_argv(app_path=app_path, device=udid),
            cwd=repo_root,
            check=True,
        )
        return f"{app_path.name} -> {udid}"

    def launch_step() -> str | None:
        completed = _run_capture(
            xcode_helpers.simctl_launch_argv(
                bundle_id=resolved_bundle_id,
                app_args=expanded_args,
                device=udid,
            ),
            cwd=repo_root,
            check=True,
        )
        detail = completed.stdout.strip() if completed.stdout else ""
        if expanded_args:
            suffix = f"args: {' '.join(expanded_args)}"
            merged = f"{detail} | {suffix}" if detail else suffix
            return merged
        return detail or None

    steps.extend(
        [
            TheaterStep("Resolve destination", resolve_step),
            TheaterStep("Boot simulator", boot_step),
            TheaterStep(f"Build ({launch_configuration}, {resolved_scheme})", build_step),
            TheaterStep("Install", install_step),
            TheaterStep(f"Launch {resolved_bundle_id}", launch_step),
        ],
    )
    _run_theater(steps)


def _editable_key_help_lines() -> tuple[str, ...]:
    keys = sorted(_editable_config_keys())
    return tuple(f"  - {item}" for item in keys)


@config_app.command("list")
def config_list() -> None:
    """Show current config file path, effective values, and editable keys."""
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    cfg_path = config.config_path(repo_root)
    summary_rows = [
        ("defaults.project", cfg.project),
        ("defaults.scheme", cfg.scheme),
        ("defaults.bundle_id", cfg.bundle_id),
        ("defaults.destination", cfg.destination),
        ("defaults.default_ci_profile", cfg.default_ci_profile),
        ("defaults.ci_simulator_pro", cfg.ci_simulator_pro),
        ("defaults.ci_simulator_xr", cfg.ci_simulator_xr),
        ("defaults.test_destination_matrix", _format_config_value(cfg.test_destination_matrix)),
        ("tests.unit_test_bundle", cfg.unit_test_bundle),
        ("tests.ui_test_bundle", cfg.ui_test_bundle),
        ("tests.smoke_ui_test", cfg.smoke_ui_test),
    ]

    _stdout_console().print(f"Config path: {cfg_path}")
    if _supports_rich_output(sys.stdout):
        table = Table(show_header=True, header_style="bold")
        table.add_column("Key")
        table.add_column("Effective value")
        for key, value in summary_rows:
            table.add_row(Text(key, style="accent"), str(value))
        _stdout_console().print(table)

        profile_table = Table(show_header=True, header_style="bold")
        profile_table.add_column("CI profiles")
        for profile_name in sorted(cfg.ci_profiles):
            profile_table.add_row(Text(profile_name, style="accent"))
        _stdout_console().print(profile_table)

        keys_table = Table(show_header=True, header_style="bold")
        keys_table.add_column("Editable key paths")
        for key in sorted(_editable_config_keys()):
            keys_table.add_row(Text(key, style="muted"))
        _stdout_console().print(keys_table)
        return

    for key, value in summary_rows:
        _stdout_console().print(f"{key} = {value}")
    _stdout_console().print(f"ci.profiles = {', '.join(sorted(cfg.ci_profiles.keys()))}")
    _stdout_console().print("editable keys:")
    for line in _editable_key_help_lines():
        _stdout_console().print(line)


@config_app.command("edit")
def config_edit() -> None:
    """Open gracenotes-dev.toml in $EDITOR / $VISUAL or a local fallback."""
    repo_root = _repo_root()
    cfg_path = config.config_path(repo_root)
    cfg_path.parent.mkdir(parents=True, exist_ok=True)
    if not cfg_path.exists():
        cfg_path.write_text("", encoding="utf-8")

    editor = os.environ.get("EDITOR") or os.environ.get("VISUAL")
    if editor:
        editor_argv = shlex.split(editor)
        if editor_argv:
            _run([*editor_argv, str(cfg_path)], cwd=repo_root, check=True)
            return

    if shutil.which("nano"):
        _run(["nano", str(cfg_path)], cwd=repo_root, check=True)
        return
    if shutil.which("vi"):
        _run(["vi", str(cfg_path)], cwd=repo_root, check=True)
        return

    _stdout_console().print(str(cfg_path))


@config_app.command("open")
def config_open() -> None:
    """Open gracenotes-dev.toml in the default macOS app."""
    if sys.platform != "darwin":
        _fail(
            code=3,
            title="Unsupported platform",
            problem="`grace config open` is only available on macOS.",
            likely_cause="`open` is a macOS-specific command.",
            try_commands=("grace config list", "grace config edit"),
        )
    repo_root = _repo_root()
    cfg_path = config.config_path(repo_root)
    _run(["open", str(cfg_path)], cwd=repo_root, check=True)


@config_app.command("set")
def config_set(
    dotted_key: Annotated[str, typer.Argument(help="Editable dotted config path.")],
    value_parts: Annotated[
        list[str],
        typer.Argument(help="Value to set (quote to preserve spaces)."),
    ],
) -> None:
    """Set one editable key in gracenotes-dev.toml while preserving TOML formatting."""
    if not value_parts:
        _fail(
            code=2,
            title="Missing config value",
            problem="Expected a value after the dotted key.",
            try_commands=("grace config set defaults.scheme GraceNotes",),
        )
    editable = _editable_config_keys().get(dotted_key)
    if editable is None:
        _fail(
            code=2,
            title="Unknown config key",
            problem=f"`{dotted_key}` is not editable via `grace config set`.",
            likely_cause="Only a curated set of scalar/list keys is writable in v1.",
            try_commands=("grace config list", "grace config set --help"),
        )

    raw_value = " ".join(value_parts).strip()
    try:
        parsed_value = _parse_config_value(raw_value, value_type=editable.value_type)
    except (ValueError, json.JSONDecodeError) as exc:
        _fail(
            code=2,
            title="Invalid config value",
            problem=str(exc),
            try_commands=("grace config set defaults.destination 'iPhone 17 Pro@latest'",),
        )

    repo_root = _repo_root()
    effective_value = _set_config_value(repo_root=repo_root, key=editable, parsed_value=parsed_value)
    _stdout_console().print(f"{dotted_key} = {_format_config_value(effective_value)}")


@config_app.command("interactive")
def config_interactive() -> None:
    """Interactively update curated config keys."""
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    _require_interactive_cli(cfg=cfg, command_name="grace config interactive")
    editable_map = _editable_config_keys()
    ordered_keys = sorted(
        editable_map.keys(),
        key=lambda key: (editable_map[key].group, key),
    )

    while True:
        loaded = _load_config(repo_root)
        label_to_key = {
            f"[{editable_map[key].group}] {key} = {_format_config_value(editable_map[key].getter(loaded))}": key
            for key in ordered_keys
        }
        selected = _q_select(
            "Choose config key to edit:",
            choices=[*label_to_key.keys(), "Done"],
        ).ask()
        choice = _require_prompt_answer(selected)
        if choice == "Done":
            return

        dotted_key = label_to_key[choice]
        editable = editable_map[dotted_key]
        current_value = editable.getter(loaded)

        if editable.value_type == "bool":
            raw_next_value = str(
                _require_prompt_answer(
                    _q_confirm(
                        f"Set {dotted_key}:",
                        default=bool(current_value),
                    ).ask(),
                ),
            )
        else:
            default_text = _format_config_value(current_value)
            raw_next_value = _require_prompt_answer(
                _q_text(
                    f"Set {dotted_key}:",
                    default=default_text,
                ).ask(),
            )

        try:
            parsed_value = _parse_config_value(raw_next_value, value_type=editable.value_type)
        except (ValueError, json.JSONDecodeError) as exc:
            _stderr_console().print(f"Invalid value: {exc}")
            continue

        effective_value = _set_config_value(repo_root=repo_root, key=editable, parsed_value=parsed_value)
        _stdout_console().print(f"Updated {dotted_key} = {_format_config_value(effective_value)}")


@app.command("xcode")
def xcode() -> None:
    """Open the configured Xcode project in Xcode."""
    if sys.platform != "darwin":
        _fail(
            code=3,
            title="Unsupported platform",
            problem="`grace xcode` is only available on macOS.",
            likely_cause="`open` is a macOS-specific command.",
            try_commands=("grace config list",),
        )
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    project_path = (repo_root / cfg.project).resolve()
    if not project_path.exists():
        _fail(
            code=2,
            title="Project path missing",
            problem=f"Configured project path does not exist: {project_path}",
            likely_cause="defaults.project in gracenotes-dev.toml points to a missing file.",
            try_commands=("grace config list", "grace config edit"),
        )
    _run(["open", str(project_path)], cwd=repo_root, check=True)
