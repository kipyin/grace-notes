"""Build, clean, test, run, and CI commands."""

from __future__ import annotations

import os
import time
from pathlib import Path
from typing import Annotated

import typer

from gracenotes_dev import config, simulator
from gracenotes_dev import xcode as xcode_helpers
from gracenotes_dev.cli import core as cli_core
from gracenotes_dev.cli.apps import app
from gracenotes_dev.cli.sim import (
    _prompt_build_options,
    _prompt_ci_profile,
    _prompt_clean_options,
    _prompt_run_options,
    _prompt_test_options,
)

DryRunOption = Annotated[
    bool,
    typer.Option(
        "--dry-run",
        "--print-command",
        help="Print xcodebuild/simctl argv for each step without executing.",
    ),
]


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
    dry_run: DryRunOption = False,
) -> None:
    """Build the Grace Notes app for a Simulator or physical device destination."""
    cli_core._require_macos_xcode()
    repo_root = cli_core._repo_root()
    cfg = cli_core._load_config(repo_root)
    rows = simulator.load_available_ios_devices()
    if interactive:
        cli_core._require_interactive_cli(cfg=cfg, command_name="grace build --interactive")
        destination, configuration, derived_data, do_clean, verbose = _prompt_build_options(
            cfg=cfg,
            rows=rows,
            destination=destination,
            configuration=configuration,
            derived_data=derived_data,
            do_clean=do_clean,
            verbose=verbose,
        )
    resolved_destination = cli_core._resolve_destination(destination or cfg.destination, rows)
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
        cli_core._run(clean_argv, cwd=repo_root, check=True, verbose=verbose, dry_run=dry_run)
        return " ".join(clean_argv)

    def build_step() -> str:
        cli_core._run(build_argv, cwd=repo_root, check=True, verbose=verbose, dry_run=dry_run)
        return " ".join(build_argv)

    steps = [
        cli_core.TheaterStep("Resolve destination", resolve_step),
    ]
    if do_clean:
        steps.append(cli_core.TheaterStep(f"Clean ({configuration}, {cfg.scheme})", clean_step))
    steps.append(cli_core.TheaterStep(f"Build ({configuration}, {cfg.scheme})", build_step))
    cli_core._run_theater(steps)


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
    dry_run: DryRunOption = False,
) -> None:
    """Run xcodebuild clean for the Grace Notes scheme (Xcode Clean Build Folder scope)."""
    cli_core._require_macos_xcode()
    repo_root = cli_core._repo_root()
    cfg = cli_core._load_config(repo_root)
    rows = simulator.load_available_ios_devices()
    if interactive:
        cli_core._require_interactive_cli(cfg=cfg, command_name="grace clean --interactive")
        destination, configuration, derived_data, verbose = _prompt_clean_options(
            cfg=cfg,
            rows=rows,
            destination=destination,
            configuration=configuration,
            derived_data=derived_data,
            verbose=verbose,
        )
    resolved_destination = cli_core._resolve_destination(destination or cfg.destination, rows)
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
        cli_core._run(argv, cwd=repo_root, check=True, verbose=verbose, dry_run=dry_run)
        return " ".join(argv)

    cli_core._run_theater(
        [
            cli_core.TheaterStep("Resolve destination", resolve_step),
            cli_core.TheaterStep(f"Clean ({configuration}, {cfg.scheme})", clean_step),
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
    dry_run: DryRunOption = False,
) -> None:
    """Run xcodebuild tests (single destination or matrix)."""
    cli_core._require_macos_xcode()
    repo_root = cli_core._repo_root()
    cfg = cli_core._load_config(repo_root)
    rows = simulator.load_available_ios_devices()
    if interactive:
        cli_core._require_interactive_cli(cfg=cfg, command_name="grace test --interactive")
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
        cli_core._fail(
            code=2,
            title="Invalid test kind",
            problem=f"`{kind}` is not one of all, unit, ui, or smoke.",
            try_commands=("grace test --help",),
            retry_command="grace test --kind all",
        )
    effective_destination = (destination or cfg.destination or "").strip()
    if simulator.user_destination_requests_physical_ios(effective_destination):
        cli_core._fail(
            code=2,
            title="Physical device unsupported for tests",
            problem="`grace test` targets the iOS Simulator only in this release.",
            likely_cause=(
                "Physical devices are supported for `grace build` and `grace run` "
                "(see README); use a `device@os` or platform=iOS Simulator destination for tests."
            ),
            try_commands=("grace sim list", "grace test --destination 'iPhone 17 Pro@latest'"),
        )
    if matrix and selected_kind == "smoke":
        cli_core._fail(
            code=2,
            title="Unsupported flag combination",
            problem="Smoke tests run against one simulator and cannot use --matrix.",
            try_commands=("grace test --kind smoke", "grace test --kind all --matrix"),
        )

    reset_before_run = not no_reset_sims and (matrix or selected_kind == "smoke")
    test_started = time.perf_counter()

    if matrix:
        resolved_destinations = cli_core._resolved_destinations_for_matrix(
            cfg.test_destination_matrix,
            rows,
        )
        steps: list[cli_core.TheaterStep] = []
        for resolved_destination in resolved_destinations:
            if reset_before_run:
                steps.append(
                    cli_core.TheaterStep(
                        "Reset simulators",
                        lambda dr=dry_run: (
                            cli_core._reset_sims(repo_root, dry_run=dr)
                            or "shutdown all + erase all"
                        ),
                    ),
                )
            steps.append(
                cli_core.TheaterStep(
                    f"Run {selected_kind} tests",
                    lambda resolved_destination=resolved_destination, dr=dry_run: (
                        cli_core._run_test_once(
                            cfg=cfg,
                            repo_root=repo_root,
                            resolved_destination=resolved_destination,
                            kind=selected_kind,
                            isolated_dd=isolated_dd,
                            verbose=verbose,
                            dry_run=dr,
                        )
                        or resolved_destination
                    ),
                ),
            )
        cli_core._run_theater(steps)
        cli_core._stdout_console().print(
            "Tests finished: "
            f"kind={selected_kind}, destinations={len(resolved_destinations)}, "
            f"wall time {time.perf_counter() - test_started:.2f}s",
        )
        return

    resolved_destination = cli_core._resolve_destination(destination or cfg.destination, rows)

    steps = []
    if reset_before_run:
        steps.append(
            cli_core.TheaterStep(
                "Reset simulators",
                lambda dr=dry_run: (
                    cli_core._reset_sims(repo_root, dry_run=dr)
                    or "shutdown all + erase all"
                ),
            ),
        )
    steps.append(cli_core.TheaterStep("Resolve destination", lambda: resolved_destination))
    if selected_kind == "smoke":
        simulator_name = xcode_helpers.resolved_name_for_smoke(resolved_destination)
        boot, bootstatus = xcode_helpers.simctl_boot_sequence_argv(simulator_name)
        steps.append(
            cli_core.TheaterStep(
                "Boot simulator",
                lambda dr=dry_run: (
                    cli_core._run(boot, cwd=repo_root, check=False, dry_run=dr),
                    cli_core._run(bootstatus, cwd=repo_root, check=False, dry_run=dr),
                )
                and simulator_name,
            ),
        )

    steps.append(
        cli_core.TheaterStep(
            f"Run {selected_kind} tests",
            lambda dr=dry_run: (
                cli_core._run_test_once(
                    cfg=cfg,
                    repo_root=repo_root,
                    resolved_destination=resolved_destination,
                    kind=selected_kind,
                    isolated_dd=isolated_dd,
                    verbose=verbose,
                    dry_run=dr,
                )
                or resolved_destination
            ),
        ),
    )
    cli_core._run_theater(steps)
    cli_core._stdout_console().print(
        f"Tests finished: kind={selected_kind}, destination={resolved_destination}, "
        f"wall time {time.perf_counter() - test_started:.2f}s",
    )


def _execute_ci_profile(
    cfg: config.DevConfig,
    profile: str,
    *,
    verbose: bool = False,
    dry_run: bool = False,
) -> None:
    """Run lint / build / test / smoke gates for a configured CI profile name."""
    selected = cfg.ci_profiles.get(profile)
    if selected is None:
        cli_core._fail(
            code=2,
            title="Unknown CI profile",
            problem=f"`{profile}` is not defined in {config.DEFAULT_CONFIG_FILENAME}.",
            likely_cause="The profile name is misspelled or the profile has not been configured.",
            try_commands=(f"grace ci --profile {cfg.default_ci_profile}",),
            retry_command=f"grace ci --profile {cfg.default_ci_profile}",
        )
        return

    if selected.lint:
        from gracenotes_dev.cli.doctor_lint import run_lint

        run_lint(dry_run=dry_run)

    needs_xcode = selected.build or selected.test or selected.smoke
    if needs_xcode:
        cli_core._require_macos_xcode()

    if selected.build:
        build(
            destination=selected.build_destination or cfg.ci_simulator_pro,
            verbose=verbose,
            dry_run=dry_run,
        )

    if selected.test:
        test(
            kind=selected.test_kind,
            destination=selected.test_destination,
            matrix=selected.matrix,
            isolated_dd=selected.isolated_dd,
            no_reset_sims=not selected.reset_simulators_before_test,
            verbose=verbose,
            dry_run=dry_run,
        )

    if selected.smoke:
        test(
            kind="smoke",
            destination=selected.smoke_destination or cfg.ci_simulator_xr,
            matrix=False,
            isolated_dd=selected.isolated_dd,
            no_reset_sims=False,
            verbose=verbose,
            dry_run=dry_run,
        )


@app.command("ci")
def ci(
    profile: Annotated[
        str | None,
        typer.Option(
            "--profile",
            help=(
                "CI profile from config (for example: lint-build, lint-build-test, "
                "test-all, full). "
                "When omitted, uses defaults.default_ci_profile from gracenotes-dev.toml. "
                "List names with `grace config list`."
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
    dry_run: DryRunOption = False,
) -> None:
    """Run a CI profile from ``gracenotes-dev.toml`` (default: ``defaults.default_ci_profile``)."""
    repo_root = cli_core._repo_root()
    cfg = cli_core._load_config(repo_root)
    if interactive:
        cli_core._require_interactive_cli(cfg=cfg, command_name="grace ci --interactive")
        profile = _prompt_ci_profile(cfg=cfg, profile=profile)
    resolved = (profile or "").strip() or cfg.default_ci_profile
    _execute_ci_profile(cfg, resolved, verbose=verbose, dry_run=dry_run)


@app.command(
    "run",
    epilog=(
        "Examples:\n"
        '  grace run --destination "iPhone 17 Pro@latest"\n'
        "  grace run --preset tutorial-reset -- -reset-journal-tutorial"
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
        typer.Option(
            "--verbose",
            help=(
                "Stream xcodebuild/simctl to the terminal (full tool logs). "
                "Default still shows step progress, but captures tool output on success. "
                "No short -v flag (avoids accidental verbose runs). "
                "You can also set GRACE_RUN_STREAM_TOOL_OUTPUT=1."
            ),
        ),
    ] = False,
    dry_run: DryRunOption = False,
) -> None:
    """Build, install, and launch Grace Notes on an iOS Simulator or connected device."""
    cli_core._require_macos_xcode()
    repo_root = cli_core._repo_root()
    cfg = cli_core._load_config(repo_root)
    rows = simulator.load_available_ios_devices()
    stream_via_env = os.environ.get("GRACE_RUN_STREAM_TOOL_OUTPUT", "").strip().lower() in (
        "1",
        "true",
        "yes",
    )
    run_quiet_output = (not verbose) and (not stream_via_env)
    if interactive:
        cli_core._require_interactive_cli(cfg=cfg, command_name="grace run --interactive")
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

    resolved_destination = cli_core._resolve_destination(destination or cfg.destination, rows)
    resolved_scheme = scheme or cfg.scheme
    resolved_bundle_id = bundle_id or cfg.bundle_id
    derived_data_path = derived_data or (repo_root / ".grace-derived-data" / "run")
    derived_data_path.mkdir(parents=True, exist_ok=True)

    expanded_args = list(app_args or [])
    if preset:
        if preset not in cfg.run_presets:
            available = ", ".join(sorted(cfg.run_presets.keys())) or "(none configured)"
            cli_core._fail(
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
        cli_core._fail(
            code=2,
            title="Scheme metadata unreadable",
            problem=str(exc),
            likely_cause=(
                "The scheme may be missing from the Xcode project or the .xcscheme "
                "XML is unexpected."
            ),
            try_commands=(
                f"ls {xcodeproj / 'xcshareddata/xcschemes'}",
                "grace run --help",
            ),
        )

    steps: list[cli_core.TheaterStep] = []

    def resolve_step() -> str:
        return resolved_destination

    def build_step() -> str:
        argv = xcode_helpers.build_argv(
            project=repo_root / cfg.project,
            scheme=resolved_scheme,
            resolved_destination=resolved_destination,
            configuration=launch_configuration,
            derived_data_path=derived_data_path,
        )
        cli_core._run(
            argv,
            cwd=repo_root,
            check=True,
            verbose=verbose,
            silent=run_quiet_output,
            dry_run=dry_run,
        )
        return " ".join(argv)

    if xcode_helpers.is_physical_ios_destination(resolved_destination):
        device_udid = simulator.physical_udid_from_resolved_destination(resolved_destination) or ""
        if not device_udid:
            cli_core._fail(
                code=3,
                title="Physical device destination incomplete",
                problem=f"Could not read device id from `{resolved_destination}`.",
                likely_cause="Expected platform=iOS,id=<UDID> after resolution.",
                try_commands=("grace sim list --physical",),
            )

        def install_device_step() -> str:
            app_path = xcode_helpers.built_app_path(
                derived_data_path,
                configuration=launch_configuration,
                product_stem=product_stem,
                resolved_destination=resolved_destination,
            )
            cli_core._run(
                xcode_helpers.devicectl_install_app_argv(device=device_udid, app_path=app_path),
                cwd=repo_root,
                check=True,
                silent=run_quiet_output,
                verbose=verbose,
                dry_run=dry_run,
            )
            return f"{app_path.name} -> {device_udid}"

        def launch_device_step() -> str | None:
            completed = cli_core._run_capture(
                xcode_helpers.devicectl_process_launch_argv(
                    device=device_udid,
                    bundle_id=resolved_bundle_id,
                    app_args=expanded_args,
                ),
                cwd=repo_root,
                check=True,
                verbose=verbose,
                silent=run_quiet_output,
                dry_run=dry_run,
            )
            detail = completed.stdout.strip() if completed.stdout else ""
            if expanded_args:
                suffix = f"args: {' '.join(expanded_args)}"
                merged = f"{detail} | {suffix}" if detail else suffix
                return merged
            return detail or None

        build_title = f"Build ({launch_configuration}, {resolved_scheme})"
        steps.extend(
            [
                cli_core.TheaterStep("Resolve destination", resolve_step),
                cli_core.TheaterStep(build_title, build_step),
                cli_core.TheaterStep("Install (device)", install_device_step),
                cli_core.TheaterStep(f"Launch {resolved_bundle_id}", launch_device_step),
            ],
        )
        cli_core._run_theater(steps)
        return

    device_row = simulator.row_for_resolved_destination(resolved_destination, rows)
    udid = (device_row or {}).get("udid", "").strip()
    if not udid:
        cli_core._fail(
            code=3,
            title="Cannot resolve simulator UDID",
            problem=(
                f"No simulator UDID matches `{resolved_destination}` in the current device list."
            ),
            likely_cause=(
                "simctl list changed between destination resolution and run, or device "
                "data is incomplete."
            ),
            try_commands=("grace sim list", "xcrun simctl list devices available"),
        )

    def boot_step() -> str:
        boot, bootstatus = xcode_helpers.simctl_boot_sequence_argv_udid(udid)
        cli_core._run(
            boot,
            cwd=repo_root,
            check=False,
            silent=run_quiet_output,
            verbose=verbose,
            dry_run=dry_run,
        )
        cli_core._run(
            bootstatus,
            cwd=repo_root,
            check=False,
            silent=run_quiet_output,
            verbose=verbose,
            dry_run=dry_run,
        )
        return udid

    def install_step() -> str:
        app_path = xcode_helpers.built_app_path(
            derived_data_path,
            configuration=launch_configuration,
            product_stem=product_stem,
            resolved_destination=resolved_destination,
        )
        cli_core._run(
            xcode_helpers.simctl_install_argv(app_path=app_path, device=udid),
            cwd=repo_root,
            check=True,
            silent=run_quiet_output,
            verbose=verbose,
            dry_run=dry_run,
        )
        return f"{app_path.name} -> {udid}"

    def launch_step() -> str | None:
        completed = cli_core._run_capture(
            xcode_helpers.simctl_launch_argv(
                bundle_id=resolved_bundle_id,
                app_args=expanded_args,
                device=udid,
            ),
            cwd=repo_root,
            check=True,
            verbose=verbose,
            silent=run_quiet_output,
            dry_run=dry_run,
        )
        detail = completed.stdout.strip() if completed.stdout else ""
        if expanded_args:
            suffix = f"args: {' '.join(expanded_args)}"
            merged = f"{detail} | {suffix}" if detail else suffix
            return merged
        return detail or None

    steps.extend(
        [
            cli_core.TheaterStep("Resolve destination", resolve_step),
            cli_core.TheaterStep("Boot simulator", boot_step),
            cli_core.TheaterStep(f"Build ({launch_configuration}, {resolved_scheme})", build_step),
            cli_core.TheaterStep("Install", install_step),
            cli_core.TheaterStep(f"Launch {resolved_bundle_id}", launch_step),
        ],
    )
    # Always show theater for `grace run`; quiet mode only captures subprocesses (no tool flood).
    cli_core._run_theater(steps)
