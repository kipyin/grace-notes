"""Merge gate: CI + Copilot threads + Cursor issue comments + optional ``/sentry-approve``."""

from __future__ import annotations


def can_merge(
    *,
    ci_ok: bool,
    copilot_ok: bool,
    cursor_ok: bool,
    approve_phrase_present: bool,
) -> bool:
    """
    merge_ok = ci && (approve || (copilot_ok && cursor_ok)).

    Approve overrides stuck Copilot threads and pending Cursor review (same as Copilot).
    """
    if not ci_ok:
        return False
    if approve_phrase_present:
        return True
    return copilot_ok and cursor_ok
