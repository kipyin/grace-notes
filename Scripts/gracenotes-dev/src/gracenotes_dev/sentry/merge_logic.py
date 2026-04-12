"""Merge gate: CI + Copilot threads + Cursor review state + optional ``/sentry-approve``."""

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

    ``cursor_ok`` means Cursor’s review cycle is done **and** merge-safe (no
    ``CHANGES_REQUESTED``, no unresolved Cursor threads) when Cursor is configured.

    Approve overrides stuck Copilot threads and Cursor gates (emergency escape hatch).
    """
    if not ci_ok:
        return False
    if approve_phrase_present:
        return True
    return copilot_ok and cursor_ok
