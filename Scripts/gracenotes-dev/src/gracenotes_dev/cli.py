"""Typer entrypoint for the ``grace`` console script."""

from __future__ import annotations

import json
import io
import os
import shutil
import subprocess
import sys
import time
from contextlib import redirect_stderr
from dataclasses import dataclass
from pathlib import Path
from typing import Annotated, Callable

import typer
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from gracenotes_dev import config
from gracenotes_dev import simulator
from gracenotes_dev import xcode as xcode_helpers

app = typer.Typer(
    no_args_is_help=True,
    rich_markup_mode="rich",
    help="Grace Notes developer CLI — doctor, simulator helpers, build, test, CI, and run.",
    epilog=(
        "Examples:\n"
        "  grace doctor\n"
        '  grace test --kind unit --destination "iPhone 17 Pro@latest"\n'
        '  grace run --destination "iPhone 17 Pro@latest" -- -reset-journal-tutorial'
    ),
)
sim_app = typer.Typer(help="Simulator destination helpers (xcrun simctl).")
app.add_typer(sim_app, name="sim")

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
    )


_stderr_console = _console(sys.stderr, stderr=True)


def _stdout_console() -> Console:
    return _console(sys.stdout)


def _print_error_block(
    *,
    title: str,
    problem: str,
    likely_cause: str | None = None,
    try_commands: tuple[str, ...] = (),
    retry_command: str | None = None,
) -> None:
    lines = [f"Problem: {problem}"]
    if likely_cause:
        lines.append(f"Likely cause: {likely_cause}")
    if try_commands:
        lines.append("Try:")
        lines.extend(f"  {command}" for command in try_commands)
    if retry_command:
        lines.append(f"Copy this retry: {retry_command}")
    body = "\n".join(lines)

    if _supports_rich_output(sys.stderr):
        _stderr_console.print(Panel.fit(body, title=title, border_style="red"))
        return

    _stderr_console.print(title)
    _stderr_console.print(body)


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


def _step_line(*, index: int, total: int, title: str, outcome: str, elapsed: float) -> str:
    left = f"{index}/{total}  {title}"
    dots = "." * max(2, 48 - len(left))
    return f"{left} {dots} {outcome} ({elapsed:.2f}s)"


def _run_theater(steps: list[TheaterStep]) -> float:
    started_all = time.perf_counter()
    total = len(steps)
    for index, step in enumerate(steps, start=1):
        started_step = time.perf_counter()
        try:
            detail = step.callback()
        except typer.Exit:
            elapsed = time.perf_counter() - started_step
            _stderr_console.print(
                _step_line(index=index, total=total, title=step.title, outcome="failed", elapsed=elapsed),
            )
            raise
        elapsed = time.perf_counter() - started_step
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


def _load_config(repo_root: Path) -> config.DevConfig:
    return config.load_config(repo_root=repo_root)


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


def _run(argv: list[str], *, cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    try:
        completed = subprocess.run(argv, cwd=str(cwd), check=False, text=True)
    except FileNotFoundError:
        _fail(
            code=3,
            title="Command not found",
            problem=f"Executable is unavailable: {' '.join(argv)}",
            likely_cause="The command is not installed or not available in PATH for this shell.",
        )
    if check and completed.returncode != 0:
        raise typer.Exit(code=completed.returncode)
    return completed


def _run_capture(argv: list[str], *, cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    try:
        completed = subprocess.run(
            argv,
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
            problem=f"Executable is unavailable: {' '.join(argv)}",
            likely_cause="The command is not installed or not available in PATH for this shell.",
        )
    if check and completed.returncode != 0:
        if completed.stderr:
            _stderr_console.print(completed.stderr.strip())
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


def _doctor_default_destination_check(destination: str, rows: list[dict[str, str]]) -> dict[str, str]:
    """Resolve default destination for doctor without exiting; stderr message on failure."""
    err = io.StringIO()
    try:
        with redirect_stderr(err):
            requested = _to_destination_spec(destination)
            resolved = simulator.resolve_destination(requested, rows)
    except (SystemExit, typer.Exit):
        detail = err.getvalue().strip().splitlines()
        msg = detail[0] if detail else "Unable to resolve destination; run `grace sim list`"
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


def _doctor_matrix_check(specs: tuple[str, ...], rows: list[dict[str, str]]) -> dict[str, str]:
    """Resolve test matrix for doctor without exiting; stderr message on failure."""
    err = io.StringIO()
    joined = ";".join(specs)
    try:
        with redirect_stderr(err):
            lines = simulator.matrix_destinations_lines(joined, rows)
    except (SystemExit, typer.Exit):
        detail = err.getvalue().strip().splitlines()
        msg = detail[0] if detail else "One or more matrix entries cannot be resolved"
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
    _run(argv, cwd=repo_root, check=True)


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

    checks: list[dict[str, str]] = []

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

    destination_check = {"name": "default destination", "status": "skipped", "detail": "xcode tools not available"}
    matrix_check = {"name": "matrix destinations", "status": "skipped", "detail": "xcode tools not available"}

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
        table.add_row(item["name"], item["status"], item["detail"])
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
            mark = "*" if default_resolved is not None and line == default_resolved else ""
            table.add_row(mark, name, os_version, "available")
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
) -> None:
    """Build the Grace Notes app for an iOS Simulator destination."""
    _require_macos_xcode()
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    rows = simulator.load_available_ios_devices()
    resolved_destination = _resolve_destination(destination or cfg.destination, rows)
    argv = xcode_helpers.build_argv(
        project=repo_root / cfg.project,
        scheme=cfg.scheme,
        resolved_destination=resolved_destination,
        configuration=configuration,
        derived_data_path=derived_data,
    )

    def resolve_step() -> str:
        return resolved_destination

    def build_step() -> str:
        _run(argv, cwd=repo_root, check=True)
        return " ".join(argv)

    _run_theater(
        [
            TheaterStep("Resolve destination", resolve_step),
            TheaterStep(f"Build ({configuration}, {cfg.scheme})", build_step),
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
) -> None:
    """Run xcodebuild tests (single destination or matrix)."""
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

    _require_macos_xcode()
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    rows = simulator.load_available_ios_devices()

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


@app.command("ci")
def ci(
    profile: Annotated[
        str,
        typer.Option(
            "--profile",
            help="CI profile from config (for example: lint-build, test-all, full).",
        ),
    ],
) -> None:
    """Run a named CI profile from ``gracenotes-dev.toml``."""
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    selected = cfg.ci_profiles.get(profile)
    if selected is None:
        _fail(
            code=2,
            title="Unknown CI profile",
            problem=f"`{profile}` is not defined in {config.DEFAULT_CONFIG_FILENAME}.",
            likely_cause="The profile name is misspelled or the profile has not been configured.",
            try_commands=(f"grace ci --profile {next(iter(sorted(cfg.ci_profiles.keys())), 'full')}",),
            retry_command=f"grace ci --profile {next(iter(sorted(cfg.ci_profiles.keys())), 'full')}",
        )
        return

    if selected.lint:
        lint()

    needs_xcode = selected.build or selected.test or selected.smoke
    if needs_xcode:
        _require_macos_xcode()

    if selected.build:
        build(destination=selected.build_destination or cfg.ci_simulator_pro)

    if selected.test:
        test(
            kind=selected.test_kind,
            destination=selected.test_destination,
            matrix=selected.matrix,
            isolated_dd=selected.isolated_dd,
            no_reset_sims=not selected.reset_simulators_before_test,
        )

    if selected.smoke:
        test(
            kind="smoke",
            destination=selected.smoke_destination or cfg.ci_simulator_xr,
            matrix=False,
            isolated_dd=selected.isolated_dd,
            no_reset_sims=False,
        )


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
) -> None:
    """Build, install, and launch Grace Notes on a Simulator."""
    _require_macos_xcode()
    repo_root = _repo_root()
    cfg = _load_config(repo_root)
    rows = simulator.load_available_ios_devices()

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
        _run(argv, cwd=repo_root, check=True)
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
