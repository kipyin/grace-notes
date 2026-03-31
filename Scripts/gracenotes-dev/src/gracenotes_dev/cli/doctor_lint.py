"""Doctor, lint, interactive hub, and open-in-Xcode commands."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path
from typing import Annotated

import typer
from rich.table import Table

from gracenotes_dev import cli_rich, config, simulator
from gracenotes_dev.cli import config_cmd
from gracenotes_dev.cli import core as cli_core
from gracenotes_dev.cli.apps import app
from gracenotes_dev.cli.sim import (
    _prompt_build_options,
    _prompt_ci_profile,
    _prompt_clean_options,
    _prompt_run_options,
    _prompt_test_options,
)
from gracenotes_dev.cli.workflows import (
    _execute_ci_profile,
    build,
    clean,
    run,
    test,
)


@app.command("doctor")
def doctor(
    json_out: Annotated[
        bool,
        typer.Option("--json", help="Emit machine-readable health checks."),
    ] = False,
) -> None:
    """Preflight check for local toolchain and configured simulator defaults."""
    repo_root = cli_core._repo_root()
    cfg = cli_core._load_config(repo_root)

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
            load_detail = (
                "Could not list simulators (simctl failed); run `grace sim list` "
                "after fixing Xcode."
            )
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
            destination_check = cli_core._doctor_default_destination_check(cfg.destination, rows)
            matrix_check = cli_core._doctor_matrix_check(cfg.test_destination_matrix, rows)

    checks.extend([destination_check, matrix_check])

    if json_out:
        json.dump(
            {"checks": checks, "config": str(config.config_path(repo_root))},
            sys.stdout,
            indent=2,
        )
        sys.stdout.write("\n")
        return

    table = Table(show_header=True, header_style="bold")
    table.add_column("Check")
    table.add_column("Status")
    table.add_column("Detail")
    for item in checks:
        table.add_row(
            str(item["name"]), cli_rich.status_text(str(item["status"])), str(item["detail"])
        )
    cli_core._stdout_console().print(table)


@app.command("lint")
def lint() -> None:
    """Run swiftlint from repository root."""
    cli_core._require_swiftlint()
    repo_root = cli_core._repo_root()
    cli_core._run(["swiftlint", "lint"], cwd=repo_root, check=True)


@app.command("interactive")
def interactive() -> None:
    """Interactive hub for CI, build/test/run, and maintenance commands."""
    repo_root = cli_core._repo_root()
    cfg = cli_core._load_config(repo_root)
    cli_core._require_interactive_cli(cfg=cfg, command_name="grace interactive")

    action = cli_core._q_select(
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
    choice = cli_core._require_prompt_answer(action)
    if choice == "Exit":
        return
    if choice == "CI":
        profile = _prompt_ci_profile(cfg=cfg, profile=None)
        show_verbose = cli_core._require_prompt_answer(
            cli_core._q_confirm("Show full xcodebuild logs?", default=False).ask(),
        )
        _execute_ci_profile(cfg, profile, verbose=show_verbose)
        return
    if choice == "Build":
        cli_core._require_macos_xcode()
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
        cli_core._require_macos_xcode()
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
        cli_core._require_macos_xcode()
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
        cli_core._require_macos_xcode()
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
    config_cmd.config_interactive()


@app.command("xcode")
def xcode() -> None:
    """Open the configured Xcode project in Xcode."""
    if sys.platform != "darwin":
        cli_core._fail(
            code=3,
            title="Unsupported platform",
            problem="`grace xcode` is only available on macOS.",
            likely_cause="`open` is a macOS-specific command.",
            try_commands=("grace config list",),
        )
    repo_root = cli_core._repo_root()
    cfg = cli_core._load_config(repo_root)
    project_path = (repo_root / cfg.project).resolve()
    if not project_path.exists():
        cli_core._fail(
            code=2,
            title="Project path missing",
            problem=f"Configured project path does not exist: {project_path}",
            likely_cause="defaults.project in gracenotes-dev.toml points to a missing file.",
            try_commands=("grace config list", "grace config edit"),
        )
    cli_core._run(["open", str(project_path)], cwd=repo_root, check=True)
