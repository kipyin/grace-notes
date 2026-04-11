"""Textual TUI for ``grace sentry start`` (status strip + log)."""

from __future__ import annotations

import time
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Vertical
from textual.widgets import RichLog, Static

from gracenotes_dev.sentry.log_sink import format_sentry_log_line
from gracenotes_dev.sentry.runner import run_single_iteration
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import append_event


class _SentryTuiSink:
    """Implements ``SentryLogSink`` without clobbering ``App.log``."""

    __slots__ = ("_app",)

    def __init__(self, app: SentryTextualApp) -> None:
        self._app = app

    def set_step(self, step: str) -> None:
        self._app._step = step
        self._app.call_from_thread(self._app._refresh_status)

    def set_branch(self, branch: str | None) -> None:
        self._app._branch = branch or "—"
        self._app.call_from_thread(self._app._refresh_status)

    def set_pr(self, pr: str | None) -> None:
        self._app._pr = pr or "—"
        self._app.call_from_thread(self._app._refresh_status)

    def set_target_file(self, path: str | None) -> None:
        self._app._target_file = path or "—"
        self._app.call_from_thread(self._app._refresh_status)

    def log(self, line: str) -> None:
        self._app.call_from_thread(self._app._append_log, line)


class SentryTextualApp(App[int | None]):
    """
    Main thread runs Textual; sentry iterations run in a worker thread.

    The worker uses a ``_SentryTuiSink`` so we do not override ``App.log``.
    """

    TITLE = "grace sentry"

    BINDINGS = [
        Binding("ctrl+c", "quit", "Quit", show=False),
        Binding("q", "quit", "Quit"),
    ]

    CSS = """
    Vertical {
        height: 100%;
    }
    #status {
        height: auto;
        border: solid $accent;
        padding: 1 2;
    }
    RichLog {
        height: 1fr;
        border: solid $accent;
        min-height: 12;
    }
    """

    def __init__(
        self,
        *,
        repo_root: Path,
        settings: SentrySettings,
        dry_run: bool,
        merge: bool,
        once: bool,
    ) -> None:
        super().__init__()
        self.repo_root = repo_root
        self.settings = settings
        self.dry_run = dry_run
        self.merge = merge
        self.once = once
        self._step = "—"
        self._branch = "—"
        self._pr = "—"
        self._target_file = "—"
        self._sink = _SentryTuiSink(self)

    def compose(self) -> ComposeResult:
        yield Vertical(
            Static(self._status_text(), id="status"),
            RichLog(id="log", max_lines=200, highlight=False, auto_scroll=True),
        )

    def _status_text(self) -> str:
        return (
            f"[bold cyan]Step[/] {self._step}\n"
            f"[bold cyan]Branch[/] {self._branch}\n"
            f"[bold cyan]PR[/] {self._pr}\n"
            f"[bold cyan]File[/] {self._target_file}"
        )

    def on_mount(self) -> None:
        self.run_worker(self._sentry_worker, thread=True, exclusive=True)

    def _sentry_worker(self) -> None:
        if self.once:
            code = run_single_iteration(
                self.repo_root,
                self.settings,
                dry_run=self.dry_run,
                merge=self.merge,
                sink=self._sink,
            )
            self.call_from_thread(self.exit, code)
            return

        while True:
            code = run_single_iteration(
                self.repo_root,
                self.settings,
                dry_run=self.dry_run,
                merge=self.merge,
                sink=self._sink,
            )
            self._sleep_until_next_iteration(code)

    def _sleep_until_next_iteration(self, code: int) -> None:
        next_sleep = (
            self.settings.interval_seconds if code == 0 else min(self.settings.interval_seconds, 60)
        )
        append_event(
            self.repo_root,
            {
                "kind": "loop_wait",
                "message": f"Sleeping {next_sleep}s before next iteration (last exit code {code}).",
                "exit_code": code,
                "sleep_seconds": next_sleep,
            },
        )
        self._sink.log(
            f"[loop] iteration exit={code}; sleeping {next_sleep}s (SENTRY_INTERVAL_SEC)…"
        )
        time.sleep(next_sleep)

    def action_quit(self) -> None:
        self.exit(0)

    def _refresh_status(self) -> None:
        self.query_one("#status", Static).update(self._status_text())

    def _append_log(self, line: str) -> None:
        self.query_one("#log", RichLog).write(format_sentry_log_line(line))


__all__ = ["SentryTextualApp"]
