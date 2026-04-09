"""Typer entrypoint for the ``grace`` console script."""

from __future__ import annotations

import importlib  # noqa: F401 — ``cli.importlib`` (tests patch metadata.version)
from pathlib import Path
from typing import Annotated

import typer

from gracenotes_dev import simulator_runtime  # noqa: F401 — ``cli.simulator_runtime`` (tests)
from gracenotes_dev import xcode as xcode_helpers  # noqa: F401 — ``cli.xcode_helpers`` (tests)
from gracenotes_dev.cli.apps import app, config_app, runtime_app, sim_app
from gracenotes_dev.cli.core import (
    _cli_version,
    _interactive_cli_allowed,  # noqa: F401
    _prepare_xcodebuild_argv,  # noqa: F401
    _print_error_block,  # noqa: F401
    _stdout_console,
    _supports_rich_output,  # noqa: F401
)
from gracenotes_dev.cli.sim import _sim_interactive  # noqa: F401


def _version_callback(value: bool) -> None:
    if not value:
        return
    _stdout_console().print(_cli_version())
    raise typer.Exit(code=0)


@app.callback()
def app_callback(
    ctx: typer.Context,
    version: Annotated[
        bool,
        typer.Option(
            "--version",
            help="Show the installed grace CLI version and exit.",
            callback=_version_callback,
            is_eager=True,
        ),
    ] = False,
    repo_root: Annotated[
        Path | None,
        typer.Option(
            "--repo-root",
            help=(
                "Directory to start repo discovery from (walk-up finds GraceNotes/). "
                "Default: current working directory."
            ),
            envvar="GRACE_REPO_ROOT",
        ),
    ] = None,
) -> None:
    ctx.ensure_object(dict)
    if repo_root is not None:
        ctx.obj["repo_root_start"] = repo_root.resolve()


from gracenotes_dev.cli import config_cmd as _config_cmd  # noqa: E402, F401
from gracenotes_dev.cli import doctor_lint as _doctor_lint  # noqa: E402, F401
from gracenotes_dev.cli import l10n_cmd as _l10n_cmd  # noqa: E402, F401
from gracenotes_dev.cli import sim as _sim  # noqa: E402, F401
from gracenotes_dev.cli import workflows as _workflows  # noqa: E402, F401
from gracenotes_dev.cli.config_cmd import config_interactive  # noqa: E402

__all__ = [
    "app",
    "config_app",
    "config_interactive",
    "runtime_app",
    "sim_app",
]
