"""Simulator and simulator-runtime commands."""

from __future__ import annotations

import io
import json
import shlex
import sys
from contextlib import redirect_stderr
from pathlib import Path
from typing import Annotated

import typer
from rich.syntax import Syntax
from rich.table import Table
from rich.text import Text

from gracenotes_dev import cli_rich, config, simulator, simulator_runtime
from gracenotes_dev.cli import core as cli_core
from gracenotes_dev.cli.apps import runtime_app, sim_app


def _sim_list_entries(rows: list[dict[str, str]]) -> list[tuple[str, str, str]]:
    """Deduplicated rows sorted by device name and OS version.

    Tuple is (xcodebuild line, device, OS).
    """
    seen: set[tuple[str, str]] = set()
    entries: list[tuple[str, str, str]] = []
    for row in sorted(
        rows, key=lambda item: (item["name"], simulator.version_tuple(item["runtime_version"]))
    ):
        key = (row["name"], row["runtime_version"])
        if key in seen:
            continue
        seen.add(key)
        line = f"platform=iOS Simulator,name={row['name']},OS={row['runtime_version']}"
        entries.append((line, row["name"], row["runtime_version"]))
    return entries


def _resolve_default_destination_line(
    cfg_destination: str, rows: list[dict[str, str]]
) -> str | None:
    """Return resolved full destination string for config default.

    Returns None if it cannot be resolved.
    """
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
    console = cli_core._stdout_console()
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
    choice = cli_core._q_select(
        message,
        choices=_destination_prompt_choices(default_destination, rows),
        default=default_destination,
    ).ask()
    return cli_core._require_prompt_answer(choice)


def _prompt_optional_text(*, message: str, default_value: str = "") -> str | None:
    value = cli_core._q_text(message, default=default_value).ask()
    text = cli_core._require_prompt_answer(value).strip()
    return text or None


def _prompt_optional_path(*, message: str, default_value: str = "") -> Path | None:
    value = _prompt_optional_text(message=message, default_value=default_value)
    if value is None:
        return None
    return Path(value)


def _prompt_ci_profile(*, cfg: config.DevConfig, profile: str | None) -> str:
    if profile:
        return profile
    choice = cli_core._q_select(
        "CI profile:",
        choices=sorted(cfg.ci_profiles.keys()),
        default=cfg.default_ci_profile,
    ).ask()
    return cli_core._require_prompt_answer(choice)


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
    chosen_configuration = cli_core._require_prompt_answer(
        cli_core._q_select(
            "Build configuration:",
            choices=["Debug", "Release"],
            default=configuration,
        ).ask(),
    )
    chosen_clean = cli_core._require_prompt_answer(
        cli_core._q_confirm("Run clean before build?", default=do_clean).ask(),
    )
    derived_default = str(derived_data) if derived_data is not None else ""
    chosen_derived_data = _prompt_optional_path(
        message="DerivedData path (empty for Xcode default):",
        default_value=derived_default,
    )
    chosen_verbose = cli_core._require_prompt_answer(
        cli_core._q_confirm("Show full xcodebuild logs?", default=verbose).ask(),
    )
    return (
        chosen_destination,
        chosen_configuration,
        chosen_derived_data,
        chosen_clean,
        chosen_verbose,
    )


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
    chosen_configuration = cli_core._require_prompt_answer(
        cli_core._q_select(
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
    chosen_verbose = cli_core._require_prompt_answer(
        cli_core._q_confirm("Show full xcodebuild logs?", default=verbose).ask(),
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
    chosen_kind = cli_core._require_prompt_answer(
        cli_core._q_select(
            "Test kind:",
            choices=["all", "unit", "ui", "smoke"],
            default=kind,
        ).ask(),
    )
    chosen_matrix = False
    if chosen_kind != "smoke":
        chosen_matrix = cli_core._require_prompt_answer(
            cli_core._q_confirm("Run destination matrix?", default=matrix).ask(),
        )
    chosen_destination: str | None = destination
    if not chosen_matrix:
        chosen_destination = destination or _prompt_destination_value(
            message="Test destination:",
            default_destination=cfg.destination,
            rows=rows,
        )
    chosen_isolated_dd = cli_core._require_prompt_answer(
        cli_core._q_confirm("Use isolated DerivedData?", default=isolated_dd).ask(),
    )
    chosen_no_reset = cli_core._require_prompt_answer(
        cli_core._q_confirm("Skip simulator reset?", default=no_reset_sims).ask(),
    )
    chosen_verbose = cli_core._require_prompt_answer(
        cli_core._q_confirm("Show full xcodebuild logs?", default=verbose).ask(),
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
    chosen_scheme = (
        _prompt_optional_text(
            message="Scheme:",
            default_value=scheme or cfg.scheme,
        )
        or cfg.scheme
    )
    preset_choices = ["(none)", *sorted(cfg.run_presets.keys())]
    chosen_preset = preset
    if preset is None and len(preset_choices) > 1:
        selected = cli_core._require_prompt_answer(
            cli_core._q_select("Run preset:", choices=preset_choices, default="(none)").ask(),
        )
        chosen_preset = None if selected == "(none)" else selected
    chosen_bundle = (
        _prompt_optional_text(
            message="Bundle identifier:",
            default_value=bundle_id or cfg.bundle_id,
        )
        or cfg.bundle_id
    )
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
    chosen_verbose = cli_core._require_prompt_answer(
        cli_core._q_confirm("Show full xcodebuild logs?", default=verbose).ask(),
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
    completed = cli_core._run_capture(
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
    fallback = cli_core._run_capture(
        simulator_runtime.simctl_runtime_list_argv(json_out=False),
        cwd=repo_root,
        check=True,
    )
    return simulator_runtime.parse_runtime_list_text(fallback.stdout)


def _print_runtime_list(records: list[simulator_runtime.RuntimeRecord]) -> None:
    if cli_core._supports_rich_output(sys.stdout):
        table = Table(show_header=True, header_style="bold")
        table.add_column("Platform")
        table.add_column("Version", justify="right")
        table.add_column("Build", justify="right")
        table.add_column("State")
        table.add_column("Identifier")
        for row in records:
            table.add_row(
                row.platform,
                row.version,
                row.build,
                cli_rich.status_text(row.state),
                row.identifier,
            )
        cli_core._stdout_console().print(table)
        return

    console = cli_core._stdout_console()
    console.print(f"{'Platform':<10}{'Version':<10}{'Build':<10}{'State':<12}Identifier")
    for row in records:
        console.print(
            f"{row.platform:<10}{row.version:<10}{row.build:<10}{row.state:<12}{row.identifier}"
        )


def _sim_interactive(*, cfg: config.DevConfig) -> None:
    choice = cli_core._require_prompt_answer(
        cli_core._q_select(
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
        spec = (
            _prompt_optional_text(
                message="Destination spec (device@os or platform=...):",
                default_value=cfg.destination,
            )
            or cfg.destination
        )
        sim_resolve(spec=spec)
        return
    if choice == "Reset simulators":
        confirmed = cli_core._require_prompt_answer(
            cli_core._q_confirm("Shutdown and erase all simulators?", default=False).ask(),
        )
        if confirmed:
            sim_reset()
        return
    if choice == "Install runtime":
        build_version = _prompt_optional_text(
            message="Build version (empty for default download):",
            default_value="",
        )
        run_simctl_add = cli_core._require_prompt_answer(
            cli_core._q_confirm(
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

    repo_root = cli_core._repo_root()
    records = _load_runtime_records(repo_root)
    if not records:
        cli_core._stdout_console().print("No installed simulator runtimes found.")
        return
    labels = [f"{row.platform} {row.version} ({row.build}) - {row.identifier}" for row in records]
    selected = cli_core._require_prompt_answer(
        cli_core._q_select("Runtime to delete:", choices=labels, default=labels[0]).ask(),
    )
    identifier = selected.rsplit(" - ", 1)[-1]
    confirmed = cli_core._require_prompt_answer(
        cli_core._q_confirm(f"Delete runtime {identifier}?", default=False).ask(),
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
        cli_core._fail(
            code=2,
            title="Interactive mode and subcommand conflict",
            problem=(
                "Use `grace sim --interactive` alone, or run the subcommand without "
                "`--interactive`."
            ),
            try_commands=("grace sim -i", "grace sim list"),
        )
    if interactive:
        repo_root = cli_core._repo_root()
        cfg = cli_core._load_config(repo_root)
        cli_core._require_interactive_cli(cfg=cfg, command_name="grace sim --interactive")
        import gracenotes_dev.cli as cli_pkg

        cli_pkg._sim_interactive(cfg=cfg)
        raise typer.Exit(code=0)
    if ctx.invoked_subcommand is None:
        cli_core._stdout_console().print(ctx.get_help())
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
    cli_core._require_macos_xcode()
    repo_root = cli_core._repo_root()
    if move_dmg and not simctl_add:
        cli_core._fail(
            code=2,
            title="Invalid runtime install flags",
            problem="`--move-dmg` requires `--simctl-add`.",
            try_commands=("grace sim runtime install --simctl-add --move-dmg",),
        )
    if from_dmg is not None and build_version:
        cli_core._fail(
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
            cli_core._fail(
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
        if cli_core._supports_rich_output(sys.stdout):
            console = cli_core._stdout_console()
            for index, argv in enumerate(command_plan, start=1):
                console.print(Text(f"{index}.", style="accent"))
                console.print(Syntax(shlex.join(argv), "bash", word_wrap=False))
        else:
            for argv in command_plan:
                cli_core._stdout_console().print(" ".join(shlex.quote(item) for item in argv))
        return

    if selected_dmg is None:
        download_dir.mkdir(parents=True, exist_ok=True)
        cli_core._stderr_console().print(
            f"Downloading iOS simulator runtime to {download_dir} "
            "(this may take several minutes; xcodebuild output follows)…",
        )
        if build_version:
            cli_core._stderr_console().print(f"Requested build version: {build_version}.")
        cli_core._run(command_plan[0], cwd=repo_root, check=True)
        try:
            selected_dmg = simulator_runtime.discover_downloaded_dmg(export_path=download_dir)
        except FileNotFoundError as exc:
            cli_core._fail(
                code=3,
                title="Runtime download completed but DMG was not found",
                problem=str(exc),
                try_commands=(
                    f"ls {download_dir}",
                    "grace sim runtime install --from-dmg /path/to/runtime.dmg",
                ),
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
        if len(argv) >= 2 and argv[0] == "xcodebuild" and argv[1] == "-importPlatform":
            cli_core._stderr_console().print(f"Importing simulator runtime from {selected_dmg}…")
        elif len(argv) >= 4 and argv[:4] == ["xcrun", "simctl", "runtime", "add"]:
            cli_core._stderr_console().print("Registering runtime with simctl…")
        cli_core._run(argv, cwd=repo_root, check=True)

    if selected_dmg is not None:
        cli_core._stdout_console().print(f"Installed runtime from {selected_dmg}")


@runtime_app.command("list")
def runtime_list(
    json_out: Annotated[
        bool,
        typer.Option("--json", help="Emit a JSON array of installed runtime records."),
    ] = False,
) -> None:
    """List installed simulator runtimes."""
    cli_core._require_macos_xcode()
    repo_root = cli_core._repo_root()
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
    cli_core._require_macos_xcode()
    repo_root = cli_core._repo_root()
    argv = simulator_runtime.simctl_runtime_delete_argv(
        identifier=identifier,
        dry_run=dry_run,
        keep_asset=keep_asset,
    )
    cli_core._run(argv, cwd=repo_root, check=True)


def _physical_destination_lines(rows: list[dict[str, str]]) -> list[tuple[str, str, str, str]]:
    """Rows: (xcodebuild_line, display_name, os_version, udid_or_id)."""
    out: list[tuple[str, str, str, str]] = []
    for row in rows:
        udid = (row.get("udid") or "").strip()
        ident = (row.get("identifier") or "").strip()
        device_id = udid if udid else ident
        if not device_id:
            continue
        name = row.get("name", "") or "(unnamed)"
        os_ver = row.get("os_version", "")
        line = f"platform=iOS,id={device_id}"
        out.append((line, name, os_ver, device_id))
    return sorted(out, key=lambda item: (item[1], item[2], item[3]))


@sim_app.command("list")
def sim_list(
    physical: Annotated[
        bool,
        typer.Option(
            "--physical",
            help="List connected physical iOS devices as xcodebuild platform=iOS,id=… strings.",
        ),
    ] = False,
    json_out: Annotated[
        bool,
        typer.Option("--json", help="Emit a JSON array of xcodebuild destination strings."),
    ] = False,
) -> None:
    """List installed iOS Simulator destinations, or connected devices with ``--physical``."""
    cli_core._require_macos_xcode()
    if physical:
        dev_rows = simulator.load_connected_ios_devices()
        entries = _physical_destination_lines(dev_rows)
        lines = [item[0] for item in entries]
        if json_out:
            json.dump(lines, sys.stdout, indent=2)
            sys.stdout.write("\n")
            return
        console = cli_core._stdout_console()
        if not entries:
            console.print("No physical iOS devices reported by devicectl.")
            return
        if cli_core._supports_rich_output(sys.stdout):
            table = Table(show_header=True, header_style="bold")
            table.add_column("Device")
            table.add_column("OS", justify="right")
            table.add_column("UDID / id")
            table.add_column("Destination")
            for line, name, os_version, udid in entries:
                table.add_row(
                    Text(name, style="bold"),
                    os_version,
                    Text(udid, style="dim"),
                    Text(line, style="dim"),
                )
            console.print(table)
            return
        console.print(f"{'Device':<24}{'OS':<10}{'UDID':<28}Destination")
        for line, name, os_version, udid in entries:
            console.print(f"{name:<24}{os_version:<10}{udid:<28}{line}")
        return

    rows = simulator.load_available_ios_devices()
    entries = _sim_list_entries(rows)
    lines = [item[0] for item in entries]
    if json_out:
        json.dump(lines, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return

    cfg = cli_core._load_config(cli_core._repo_root())
    default_resolved = _resolve_default_destination_line(cfg.destination, rows)

    if cli_core._supports_rich_output(sys.stdout):
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
        cli_core._stdout_console().print(table)
        return

    _print_sim_list_plain(entries, default_resolved)


@sim_app.command("add")
def sim_add(
    spec: Annotated[
        str,
        typer.Argument(help="Simulator shortcut, e.g. iPhone 17 Pro@18.5 or iPhone 17 Pro@latest."),
    ],
    dry_run: Annotated[
        bool,
        typer.Option("--dry-run", help="Print the planned simctl steps without creating a device."),
    ] = False,
) -> None:
    """Guided workflow to create a missing Simulator instance (runtime must exist)."""
    cli_core._require_macos_xcode()
    stripped = spec.strip()
    if stripped.startswith("platform="):
        cli_core._fail(
            code=2,
            title="Use a simulator shortcut",
            problem="`grace sim add` expects `device@os`, not a full platform= string.",
            try_commands=('grace sim add "iPhone 17 Pro@latest"', "grace sim list"),
        )
    if "@" not in stripped:
        cli_core._fail(
            code=2,
            title="Invalid simulator spec",
            problem=f"Expected device@os, got `{stripped}`.",
            try_commands=('grace sim add "iPhone 17 Pro@latest"',),
        )

    device_name, os_token = stripped.rsplit("@", 1)
    device_name = device_name.strip()
    os_token = os_token.strip()
    if not device_name or not os_token:
        cli_core._fail(
            code=2,
            title="Invalid simulator spec",
            problem=f"Device name and OS are required in `{stripped}`.",
            try_commands=('grace sim add "iPhone 17 Pro@latest"',),
        )

    console = cli_core._stdout_console()
    err = cli_core._stderr_console()

    err.print(
        "[bold]Step 1/4[/bold] — Check that an iOS [bold]Simulator runtime[/bold] is installed "
        f"for [accent]{os_token!r}[/accent].",
    )
    runtime_id = simulator.find_simulator_runtime_identifier_for_os(os_token)
    if not runtime_id:
        err.print(
            f"No available iOS Simulator runtime matches {os_token!r}. "
            "Install one before creating a device instance.",
        )
        cmd = (
            "grace sim runtime install"
            if os_token.lower() == "latest"
            else f"grace sim runtime install --build-version {os_token}"
        )
        cli_core._fail(
            code=3,
            title="Simulator runtime missing",
            problem=f"No installed runtime matches OS {os_token!r}.",
            likely_cause="Download/import the platform runtime, then re-run this command.",
            try_commands=(cmd, "xcodebuild -downloadPlatform iOS", "grace sim list"),
        )

    err.print(
        f"  Found runtime [accent]{runtime_id}[/accent] for this OS. "
        "This is the disk image Xcode uses for Simulator OS version matching.",
    )

    err.print(
        "[bold]Step 2/4[/bold] — Check whether a Simulator device named "
        f"[accent]{device_name!r}[/accent] already exists for that OS.",
    )
    rows = simulator.load_available_ios_devices()
    requested_full = f"platform=iOS Simulator,name={device_name},OS={os_token}"
    existing: str | None = None
    capture = io.StringIO()
    try:
        with redirect_stderr(capture):
            existing = simulator.resolve_destination(requested_full, rows)
    except SystemExit:
        existing = None
    if existing:
        err.print(
            "  A matching device is already installed. No simctl create is needed.",
        )
        err.print(f"  Resolved destination: [accent]{existing}[/accent]")
        console.print(f"grace sim resolve {shlex.quote(stripped)}")
        return

    err.print(
        "  No matching instance yet — we will pick a device type and run "
        "`simctl create` so Xcode can boot that simulator.",
    )

    err.print(
        "[bold]Step 3/4[/bold] — Map the name to a SimDeviceType id "
        "from `simctl list devicetypes`.",
    )
    type_id, ambiguous = simulator.pick_devicetype_identifier_for_device_name(device_name)
    if type_id is None:
        if ambiguous:
            preview = ", ".join(ambiguous[:12])
            more = "" if len(ambiguous) <= 12 else ", …"
            cli_core._fail(
                code=2,
                title="Ambiguous device type",
                problem=f"Several device types match {device_name!r}: {preview}{more}",
                likely_cause=(
                    "Pick the exact device name from `simctl list devicetypes` and update the spec."
                ),
                try_commands=("xcrun simctl list devicetypes", "grace sim list"),
            )
        cli_core._fail(
            code=2,
            title="Unknown device type",
            problem=f"No Simulator device type matches {device_name!r}.",
            likely_cause="Use a name from `grace sim list` / Xcode’s device list.",
            try_commands=("xcrun simctl list devicetypes", "grace sim list"),
        )

    err.print(
        f"  Using device type [accent]{type_id}[/accent] (matches “{device_name}”).",
    )

    create_cmd = ["xcrun", "simctl", "create", device_name, type_id, runtime_id]
    err.print(
        "[bold]Step 4/4[/bold] — Run `simctl create`, then verify with `grace sim resolve`.",
    )
    err.print(f"  Command: [bold]{' '.join(shlex.quote(c) for c in create_cmd)}[/bold]")
    if dry_run:
        err.print("  [dim](dry-run: not executing)[/dim]")
        q = shlex.quote(stripped)
        console.print(f"Next: run without --dry-run, then `grace sim resolve {q}`")
        return

    udid = simulator.create_simulator_device(device_name, type_id, runtime_id)
    err.print(f"  Created Simulator UDID: [accent]{udid}[/accent]")

    rows_after = simulator.load_available_ios_devices()
    resolved = cli_core._resolve_destination(stripped, rows_after)
    console.print(resolved)


@sim_app.command("resolve")
def sim_resolve(
    spec: Annotated[
        str, typer.Argument(help="Device@os shortcut or full platform=... destination.")
    ],
    json_out: Annotated[
        bool,
        typer.Option("--json", help='Emit JSON {"resolved": "..."}.'),
    ] = False,
) -> None:
    """Resolve ``@latest`` (or validate a full destination) for xcodebuild."""
    cli_core._require_macos_xcode()
    rows = simulator.load_available_ios_devices()
    resolved = cli_core._resolve_destination(spec, rows)
    if json_out:
        json.dump({"resolved": resolved}, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return
    cli_core._stdout_console().print(resolved)


@sim_app.command("reset")
def sim_reset() -> None:
    """Shutdown and erase all simulators."""
    cli_core._require_macos_xcode()
    cli_core._reset_sims(cli_core._repo_root())
