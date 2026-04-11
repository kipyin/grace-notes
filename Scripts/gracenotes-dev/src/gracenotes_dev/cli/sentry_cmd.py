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
from gracenotes_dev.sentry import github as gh_sentry
from gracenotes_dev.sentry.git_remote import git_remote_owner_repo
from gracenotes_dev.sentry.log_sink import PlainStderrSink, SentryLogSink
from gracenotes_dev.sentry.runner import run_single_iteration
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import append_event, format_report, pid_path, read_recent_events
from gracenotes_dev.sentry.tui import SentryTextualApp


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


def _make_sink(tui: bool | None) -> tuple[SentryLogSink | None, bool]:
    """Return (plain stderr sink or None, use_textual). When Textual is used, sink is None."""
    if tui is True:
        return None, True
    if tui is False:
        return PlainStderrSink(), False
    if cli_core._supports_rich_output(sys.stdout):
        return None, True
    return PlainStderrSink(), False


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
    tui: Annotated[
        bool | None,
        typer.Option(
            "--tui/--no-tui",
            help="Textual status + log panel (default: on when stdout is a TTY).",
        ),
    ] = None,
) -> None:
    """Run sentry until interrupted (``--once`` = one pass). macOS + gh + HTTP or ``agent`` fix."""
    cli_core._require_macos_xcode()
    repo_root = cli_core._repo_root()
    settings = SentrySettings.from_repo(cli_core._repo_root())

    sink, use_textual = _make_sink(tui)

    def _run_one(s: SentryLogSink) -> int:
        return run_single_iteration(
            repo_root,
            settings,
            dry_run=dry_run,
            merge=not no_merge,
            sink=s,
        )

    def _sleep_until_next_iteration(s: SentryLogSink, code: int) -> None:
        """Log + JSONL between daemon iterations (long default sleep looked like a hang)."""
        next_sleep = settings.interval_seconds if code == 0 else min(settings.interval_seconds, 60)
        append_event(
            repo_root,
            {
                "kind": "loop_wait",
                "message": f"Sleeping {next_sleep}s before next iteration (last exit code {code}).",
                "exit_code": code,
                "sleep_seconds": next_sleep,
            },
        )
        s.log(f"[loop] iteration exit={code}; sleeping {next_sleep}s (SENTRY_INTERVAL_SEC)…")
        time.sleep(next_sleep)

    if use_textual:
        app = SentryTextualApp(
            repo_root=repo_root,
            settings=settings,
            dry_run=dry_run,
            merge=not no_merge,
            once=once,
        )
        if not once:
            _write_pid(repo_root)

            def _handle_term(*_a: object) -> None:
                _remove_pid(repo_root)
                sys.exit(0)

            signal.signal(signal.SIGTERM, _handle_term)
            signal.signal(signal.SIGINT, _handle_term)

        try:
            exit_code = app.run()
        finally:
            if not once:
                _remove_pid(repo_root)
        raise typer.Exit(code=exit_code if exit_code is not None else 0)

    assert sink is not None

    if once:
        code = _run_one(sink)
        raise typer.Exit(code=code)

    _write_pid(repo_root)

    def _handle_term(*_a: object) -> None:
        _remove_pid(repo_root)
        sys.exit(0)

    signal.signal(signal.SIGTERM, _handle_term)
    signal.signal(signal.SIGINT, _handle_term)

    try:
        while True:
            code = _run_one(sink)
            _sleep_until_next_iteration(sink, code)
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


@sentry_app.command("review-thread-authors")
def sentry_review_thread_authors(
    pr_number: Annotated[
        int,
        typer.Argument(help="Pull request number (e.g. 123)."),
    ],
) -> None:
    """
    Print sorted unique ``author.login`` values from PR review threads (GraphQL).

    Use this to confirm which login to set as ``copilot_login`` / ``SENTRY_COPILOT_LOGIN``
    for unresolved-thread filtering.
    """
    repo_root = cli_core._repo_root()
    remote = git_remote_owner_repo(repo_root)
    if not remote:
        _console().print("[red]Could not parse origin remote (GitHub).[/red]")
        raise typer.Exit(code=2)
    owner, name = remote
    nodes = gh_sentry.graphql_review_threads(repo_root, owner, name, pr_number)
    logins = gh_sentry.review_thread_author_logins(nodes)
    if not logins:
        _console().print(
            "(no review threads or no comments; check PR number and permissions)"
        )
        raise typer.Exit(code=0)
    for login in logins:
        print(login)
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
