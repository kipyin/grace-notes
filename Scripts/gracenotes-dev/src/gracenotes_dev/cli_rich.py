"""Shared Rich and questionary presentation helpers for the grace CLI."""

from __future__ import annotations

import questionary
from rich.text import Text
from rich.theme import Theme

CLI_THEME = Theme(
    {
        "status.ok": "green",
        "status.failed": "red",
        "status.missing": "red",
        "status.error": "red",
        "status.skipped": "dim",
        "status.ready": "green",
        "status.other": "yellow",
        "accent": "cyan",
        "muted": "dim",
    },
)

STATUS_STYLES = {
    "ok": "status.ok",
    "failed": "status.failed",
    "missing": "status.missing",
    "error": "status.error",
    "skipped": "status.skipped",
    "ready": "status.ready",
}

QUESTIONARY_STYLE = questionary.Style(
    [
        ("qmark", "fg:#5FA8F5 bold"),
        ("question", "bold"),
        ("answer", "fg:#5FA8F5"),
        ("pointer", "fg:#5FA8F5 bold"),
        ("highlighted", "fg:#5FA8F5 bold"),
        ("selected", "fg:#34C759"),
        ("instruction", "fg:#9AA0A6"),
    ],
)


def status_style(status: str) -> str:
    normalized = status.strip().lower()
    if not normalized:
        return ""
    if normalized in STATUS_STYLES:
        return STATUS_STYLES[normalized]
    return "status.other"


def status_text(status: str) -> Text:
    style = status_style(status)
    if style:
        return Text(status, style=style)
    return Text(status)
