"""``grace sentry`` — exploratory automation loop (macOS)."""

from __future__ import annotations

import os
import signal
import sys
import time
from pathlib import Path
from typing import Annotated

import typer
from rich.console import Console

from gracenotes_dev.cli import core as cli_core
from gracenotes_dev.cli.apps import sentry_app
from gracenotes_dev.sentry.runner import run_single_iteration
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import format_report, pid_path, read_recent_events


def _console() -> Console:
    return Console()


def _write_pid(repo_root: Path) -> None:
    from gracenotes_dev.sentry.state import ensure_sentry_dir

    ensure_sentry_dir(repo_root)
    pid_path(repo_root).write_text(str(os.getpid()), encoding="utf-8")


def _remove_pid(repo_root: Path) -> None:
    p = pid_path(repo_root)
    if p.is_file():
        p.unlink()


def _read_pid(repo_root: Path) -> int | None:
    p = pid_path(repo_root)
    if not p.is_file():
        return None
    try:
        return int(p.read_text(encoding="utf-8").strip())
    except ValueError:
        return None


@sentry_app.command("start")
def sentry_start(
    once: Annotated[
        bool,
        typer.Option("--once", help="Run a single iteration then exit (no daemon loop)."),
    ] = False,
    dry_run: Annotated[
        bool,
        typer.Option("--dry-run", help="Log actions only; no git/LLM/PR."),
    ] = False,
    no_merge: Annotated[
        bool,
        typer.Option("--no-merge", help="Create PR but do not poll for squash merge."),
    ] = False,
) -> None:
    """Run sentry until interrupted (``--once`` = one pass). macOS + gh + HTTP or ``agent`` fix."""
    cli_core._require_macos_xcode()
    repo_root = cli_core._repo_root()
    settings = SentrySettings.from_repo(cli_core._repo_root())

    if once:
        code = run_single_iteration(repo_root, settings, dry_run=dry_run, merge=not no_merge)
        raise typer.Exit(code=code)

    _write_pid(repo_root)

    def _handle_term(*_a: object) -> None:
        _remove_pid(repo_root)
        sys.exit(0)

    signal.signal(signal.SIGTERM, _handle_term)
    signal.signal(signal.SIGINT, _handle_term)

    try:
        while True:
            code = run_single_iteration(repo_root, settings, dry_run=dry_run, merge=not no_merge)
            if code != 0:
                time.sleep(min(settings.interval_seconds, 60))
            else:
                time.sleep(settings.interval_seconds)
    finally:
        _remove_pid(repo_root)


@sentry_app.command("stop")
def sentry_stop() -> None:
    """Send SIGTERM to the process recorded in ``.grace/sentry/sentry.pid`` (if any)."""
    repo_root = cli_core._repo_root()
    pid = _read_pid(repo_root)
    if pid is None:
        _console().print("[yellow]No sentry PID file; nothing to stop.[/yellow]")
        raise typer.Exit(code=1)
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        _console().print(f"[yellow]Process {pid} not running; removing stale PID file.[/yellow]")
        _remove_pid(repo_root)
        raise typer.Exit(code=1)
    _console().print(f"Sent SIGTERM to sentry pid {pid}.")
    raise typer.Exit(code=0)


@sentry_app.command("status")
def sentry_status() -> None:
    """Show whether a PID file exists and whether that process is alive."""
    repo_root = cli_core._repo_root()
    pid = _read_pid(repo_root)
    if pid is None:
        _console().print("sentry: not running (no PID file)")
        raise typer.Exit(code=1)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        _console().print(f"sentry: stale PID file ({pid} not running)")
        raise typer.Exit(code=1)
    _console().print(f"sentry: running (pid {pid})")
    raise typer.Exit(code=0)


@sentry_app.command("report")
def sentry_report(
    json_out: Annotated[
        bool,
        typer.Option("--json", help="Print recent raw events as JSON lines."),
    ] = False,
    limit: Annotated[
        int,
        typer.Option("--limit", help="Max events to show.", min=1, max=500),
    ] = 50,
) -> None:
    """Summarize recent sentry activity from ``.grace/sentry/events.jsonl``."""
    repo_root = cli_core._repo_root()
    events = read_recent_events(repo_root, limit=limit)
    if json_out:
        import json

        for ev in events:
            print(json.dumps(ev, ensure_ascii=False))
        raise typer.Exit(code=0)
    text = format_report(events)
    _console().print(text)
    raise typer.Exit(code=0)
