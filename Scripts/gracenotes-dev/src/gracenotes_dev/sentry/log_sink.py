"""Optional logging surface for sentry (TUI or plain stderr)."""

from __future__ import annotations

import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Protocol, runtime_checkable


def format_sentry_log_line(message: str) -> str:
    """Prefix a line with UTC ISO-8601 time for stderr / TUI logs."""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return f"{ts} {message}"


@runtime_checkable
class SentryLogSink(Protocol):
    def set_step(self, step: str) -> None: ...

    def set_branch(self, branch: str | None) -> None: ...

    def set_pr(self, pr: str | None) -> None: ...

    def set_target_file(self, path: str | None) -> None: ...

    def log(self, line: str) -> None: ...


@dataclass
class NullSentryLogSink:
    """No-op sink for tests and ``--no-tui`` without plain lines."""

    def set_step(self, step: str) -> None:
        pass

    def set_branch(self, branch: str | None) -> None:
        pass

    def set_pr(self, pr: str | None) -> None:
        pass

    def set_target_file(self, path: str | None) -> None:
        pass

    def log(self, line: str) -> None:
        pass


@dataclass
class PlainStderrSink:
    """One line per message to stderr (scripts / no Rich)."""

    def set_step(self, step: str) -> None:
        print(format_sentry_log_line(f"[sentry] step: {step}"), file=sys.stderr)

    def set_branch(self, branch: str | None) -> None:
        print(format_sentry_log_line(f"[sentry] branch: {branch or '—'}"), file=sys.stderr)

    def set_pr(self, pr: str | None) -> None:
        print(format_sentry_log_line(f"[sentry] pr: {pr or '—'}"), file=sys.stderr)

    def set_target_file(self, path: str | None) -> None:
        print(format_sentry_log_line(f"[sentry] file: {path or '—'}"), file=sys.stderr)

    def log(self, line: str) -> None:
        print(format_sentry_log_line(line), file=sys.stderr)
