"""Typer entrypoint for the ``grace`` console script."""

from __future__ import annotations

import importlib
from typing import Annotated

import typer

from gracenotes_dev import simulator_runtime
from gracenotes_dev import xcode as xcode_helpers
from gracenotes_dev.cli.apps import app, config_app, runtime_app, sim_app
from gracenotes_dev.cli.core import (
    _cli_version,
    _interactive_cli_allowed,
    _prepare_xcodebuild_argv,
    _print_error_block,
    _stdout_console,
    _supports_rich_output,
)
from gracenotes_dev.cli.sim import _sim_interactive


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


from gracenotes_dev.cli import config_cmd as _config_cmd  # noqa: E402, F401
from gracenotes_dev.cli import doctor_lint as _doctor_lint  # noqa: E402, F401
from gracenotes_dev.cli import l10n_cmd as _l10n_cmd  # noqa: E402, F401
from gracenotes_dev.cli import sim as _sim  # noqa: E402, F401
from gracenotes_dev.cli import workflows as _workflows  # noqa: E402, F401
from gracenotes_dev.cli.config_cmd import config_interactive  # noqa: E402
from gracenotes_dev.cli.workflows import _execute_ci_profile  # noqa: E402

__all__ = [
    "app",
    "config_app",
    "config_interactive",
    "importlib",
    "runtime_app",
    "sim_app",
    "simulator_runtime",
    "xcode_helpers",
    "_cli_version",
    "_execute_ci_profile",
    "_interactive_cli_allowed",
    "_prepare_xcodebuild_argv",
    "_print_error_block",
    "_sim_interactive",
    "_stdout_console",
    "_supports_rich_output",
]
