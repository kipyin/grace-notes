"""Typer application hierarchy for ``grace`` (no command handlers)."""

from __future__ import annotations

import typer

app = typer.Typer(
    no_args_is_help=True,
    rich_markup_mode="rich",
    help=(
        "Grace Notes developer CLI — doctor, simulator helpers, build, clean, test, "
        "CI, interactive, and run."
    ),
    epilog=(
        "Examples:\n"
        "  grace doctor\n"
        "  grace build --clean\n"
        '  grace test --kind unit --destination "iPhone 17 Pro@latest"\n'
        '  grace run --destination "iPhone 17 Pro@latest" -- -reset-journal-tutorial\n'
        "\nEnvironment:\n"
        "  NO_COLOR                 Disable Rich styling.\n"
        "  CI                       Disallow interactive prompts; fuller xcodebuild logs "
        "where applicable.\n"
        "  GRACE_NONINTERACTIVE=1   Disallow interactive prompts.\n"
        "  GRACE_RUN_STREAM_TOOL_OUTPUT  Set to 1/true/yes to stream tool output during "
        "``grace run``.\n"
        "  GRACE_REPO_ROOT          Optional directory for repo discovery "
        "(see ``grace --help``).\n"
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
l10n_app = typer.Typer(
    help="String catalog checks: Localizable.xcstrings vs Swift String(localized:) / localized:.",
)
app.add_typer(l10n_app, name="l10n")
sentry_app = typer.Typer(
    help=(
        "Exploratory automation (macOS): random Swift scope, LLM fix, ``grace ci``, PR, merge gates."
    ),
    no_args_is_help=True,
)
app.add_typer(sentry_app, name="sentry")
