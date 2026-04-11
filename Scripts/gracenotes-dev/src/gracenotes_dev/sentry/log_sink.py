"""Optional logging surface for sentry (TUI or plain stderr)."""

from __future__ import annotations

import sys
from dataclasses import dataclass
from typing import Protocol, runtime_checkable


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
        print(f"[sentry] step: {step}", file=sys.stderr)

    def set_branch(self, branch: str | None) -> None:
        print(f"[sentry] branch: {branch or '—'}", file=sys.stderr)

    def set_pr(self, pr: str | None) -> None:
        print(f"[sentry] pr: {pr or '—'}", file=sys.stderr)

    def set_target_file(self, path: str | None) -> None:
        print(f"[sentry] file: {path or '—'}", file=sys.stderr)

    def log(self, line: str) -> None:
        print(line, file=sys.stderr)
