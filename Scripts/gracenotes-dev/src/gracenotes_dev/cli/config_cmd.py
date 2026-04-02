"""``grace config`` subcommands."""

from __future__ import annotations

import json
import os
import shlex
import shutil
import sys
from typing import Annotated

import typer
from rich.table import Table
from rich.text import Text

from gracenotes_dev import config
from gracenotes_dev.cli import core as cli_core
from gracenotes_dev.cli.apps import config_app


def _editable_key_help_lines() -> tuple[str, ...]:
    keys = sorted(cli_core._editable_config_keys())
    return tuple(f"  - {item}" for item in keys)


@config_app.command("list")
def config_list() -> None:
    """Show current config file path, effective values, and editable keys."""
    repo_root = cli_core._repo_root()
    cfg = cli_core._load_config(repo_root)
    cfg_path = config.config_path(repo_root)
    summary_rows = [
        ("defaults.project", cfg.project),
        ("defaults.scheme", cfg.scheme),
        ("defaults.bundle_id", cfg.bundle_id),
        ("defaults.destination", cfg.destination),
        ("defaults.default_ci_profile", cfg.default_ci_profile),
        ("defaults.ci_simulator_pro", cfg.ci_simulator_pro),
        ("defaults.ci_simulator_xr", cfg.ci_simulator_xr),
        (
            "defaults.test_destination_matrix",
            cli_core._format_config_value(cfg.test_destination_matrix),
        ),
        ("tests.unit_test_bundle", cfg.unit_test_bundle),
        ("tests.ui_test_bundle", cfg.ui_test_bundle),
        ("tests.smoke_ui_test", cfg.smoke_ui_test),
        ("tests.parallel_testing_unit", cfg.parallel_testing_unit),
        ("tests.parallel_testing_ui", cfg.parallel_testing_ui),
    ]

    cli_core._stdout_console().print(f"Config path: {cfg_path}")
    if cli_core._supports_rich_output(sys.stdout):
        table = Table(show_header=True, header_style="bold")
        table.add_column("Key")
        table.add_column("Effective value")
        for key, value in summary_rows:
            table.add_row(Text(key, style="accent"), str(value))
        cli_core._stdout_console().print(table)

        profile_table = Table(show_header=True, header_style="bold")
        profile_table.add_column("CI profiles")
        for profile_name in sorted(cfg.ci_profiles):
            profile_table.add_row(Text(profile_name, style="accent"))
        cli_core._stdout_console().print(profile_table)

        keys_table = Table(show_header=True, header_style="bold")
        keys_table.add_column("Editable key paths")
        for key in sorted(cli_core._editable_config_keys()):
            keys_table.add_row(Text(key, style="muted"))
        cli_core._stdout_console().print(keys_table)
        return

    for key, value in summary_rows:
        cli_core._stdout_console().print(f"{key} = {value}")
    cli_core._stdout_console().print(f"ci.profiles = {', '.join(sorted(cfg.ci_profiles.keys()))}")
    cli_core._stdout_console().print("editable keys:")
    for line in _editable_key_help_lines():
        cli_core._stdout_console().print(line)


@config_app.command("edit")
def config_edit() -> None:
    """Open gracenotes-dev.toml in $EDITOR / $VISUAL or a local fallback."""
    repo_root = cli_core._repo_root()
    cfg_path = config.config_path(repo_root)
    cfg_path.parent.mkdir(parents=True, exist_ok=True)
    if not cfg_path.exists():
        cfg_path.write_text("", encoding="utf-8")

    editor = os.environ.get("EDITOR") or os.environ.get("VISUAL")
    if editor:
        editor_argv = shlex.split(editor)
        if editor_argv:
            cli_core._run([*editor_argv, str(cfg_path)], cwd=repo_root, check=True)
            return

    if shutil.which("nano"):
        cli_core._run(["nano", str(cfg_path)], cwd=repo_root, check=True)
        return
    if shutil.which("vi"):
        cli_core._run(["vi", str(cfg_path)], cwd=repo_root, check=True)
        return

    cli_core._stdout_console().print(str(cfg_path))


@config_app.command("open")
def config_open() -> None:
    """Open gracenotes-dev.toml in the default macOS app."""
    if sys.platform != "darwin":
        cli_core._fail(
            code=3,
            title="Unsupported platform",
            problem="`grace config open` is only available on macOS.",
            likely_cause="`open` is a macOS-specific command.",
            try_commands=("grace config list", "grace config edit"),
        )
    repo_root = cli_core._repo_root()
    cfg_path = config.config_path(repo_root)
    cli_core._run(["open", str(cfg_path)], cwd=repo_root, check=True)


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
        cli_core._fail(
            code=2,
            title="Missing config value",
            problem="Expected a value after the dotted key.",
            try_commands=("grace config set defaults.scheme GraceNotes",),
        )
    editable = cli_core._editable_config_keys().get(dotted_key)
    if editable is None:
        cli_core._fail(
            code=2,
            title="Unknown config key",
            problem=f"`{dotted_key}` is not editable via `grace config set`.",
            likely_cause="Only a curated set of scalar/list keys is writable in v1.",
            try_commands=("grace config list", "grace config set --help"),
        )

    raw_value = " ".join(value_parts).strip()
    try:
        parsed_value = cli_core._parse_config_value(raw_value, value_type=editable.value_type)
    except (ValueError, json.JSONDecodeError) as exc:
        cli_core._fail(
            code=2,
            title="Invalid config value",
            problem=str(exc),
            try_commands=("grace config set defaults.destination 'iPhone 17 Pro@latest'",),
        )

    repo_root = cli_core._repo_root()
    effective_value = cli_core._set_config_value(
        repo_root=repo_root, key=editable, parsed_value=parsed_value
    )
    formatted = cli_core._format_config_value(effective_value)
    cli_core._stdout_console().print(f"{dotted_key} = {formatted}")


@config_app.command("interactive")
def config_interactive() -> None:
    """Interactively update curated config keys."""
    repo_root = cli_core._repo_root()
    cfg = cli_core._load_config(repo_root)
    cli_core._require_interactive_cli(cfg=cfg, command_name="grace config interactive")
    editable_map = cli_core._editable_config_keys()
    ordered_keys = sorted(
        editable_map.keys(),
        key=lambda key: (editable_map[key].group, key),
    )

    while True:
        loaded = cli_core._load_config(repo_root)
        label_to_key = {
            (
                f"[{editable_map[key].group}] {key} = "
                f"{cli_core._format_config_value(editable_map[key].getter(loaded))}"
            ): key
            for key in ordered_keys
        }
        selected = cli_core._q_select(
            "Choose config key to edit:",
            choices=[*label_to_key.keys(), "Done"],
        ).ask()
        choice = cli_core._require_prompt_answer(selected)
        if choice == "Done":
            return

        dotted_key = label_to_key[choice]
        editable = editable_map[dotted_key]
        current_value = editable.getter(loaded)

        if editable.value_type == "bool":
            raw_next_value = str(
                cli_core._require_prompt_answer(
                    cli_core._q_confirm(
                        f"Set {dotted_key}:",
                        default=bool(current_value),
                    ).ask(),
                ),
            )
        else:
            default_text = cli_core._format_config_value(current_value)
            raw_next_value = cli_core._require_prompt_answer(
                cli_core._q_text(
                    f"Set {dotted_key}:",
                    default=default_text,
                ).ask(),
            )

        try:
            parsed_value = cli_core._parse_config_value(
                raw_next_value,
                value_type=editable.value_type,
            )
        except (ValueError, json.JSONDecodeError) as exc:
            cli_core._stderr_console().print(f"Invalid value: {exc}")
            continue

        effective_value = cli_core._set_config_value(
            repo_root=repo_root, key=editable, parsed_value=parsed_value
        )
        formatted = cli_core._format_config_value(effective_value)
        cli_core._stdout_console().print(f"Updated {dotted_key} = {formatted}")
