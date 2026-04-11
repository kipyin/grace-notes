"""Append-only JSONL state under ``.grace/sentry/``."""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def sentry_dir(repo_root: Path) -> Path:
    return repo_root / ".grace" / "sentry"


def state_path(repo_root: Path) -> Path:
    return sentry_dir(repo_root) / "events.jsonl"


def pid_path(repo_root: Path) -> Path:
    return sentry_dir(repo_root) / "sentry.pid"


def ensure_sentry_dir(repo_root: Path) -> Path:
    d = sentry_dir(repo_root)
    d.mkdir(parents=True, exist_ok=True)
    return d


def append_event(repo_root: Path, event: dict[str, Any]) -> None:
    ensure_sentry_dir(repo_root)
    line = dict(event)
    line.setdefault("ts", datetime.now(timezone.utc).isoformat())
    p = state_path(repo_root)
    with p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(line, ensure_ascii=False) + "\n")


def read_recent_events(repo_root: Path, *, limit: int = 50) -> list[dict[str, Any]]:
    p = state_path(repo_root)
    if not p.is_file():
        return []
    lines = p.read_text(encoding="utf-8").splitlines()
    out: list[dict[str, Any]] = []
    for line in lines[-limit:]:
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            out.append({"raw": line, "error": "invalid_json"})
    return out


@dataclass(frozen=True)
class SentryReport:
    lines: list[str]


def format_report(events: list[dict[str, Any]]) -> str:
    if not events:
        return "No sentry events logged yet."
    rows: list[str] = []
    for ev in events:
        ts = ev.get("ts", "?")
        kind = ev.get("kind", "?")
        msg = ev.get("message", "")
        extra = {k: v for k, v in ev.items() if k not in ("ts", "kind", "message")}
        tail = f" {extra}" if extra else ""
        rows.append(f"- {ts} [{kind}] {msg}{tail}")
    return "\n".join(rows)
