"""Merge gate: CI + Copilot threads + optional ``/sentry-approve`` (override)."""

from __future__ import annotations


def can_merge(
    *,
    ci_ok: bool,
    copilot_ok: bool,
    approve_phrase_present: bool,
) -> bool:
    """merge_ok = ci && (copilot_ok || approve). Approve overrides stuck Copilot threads."""
    if not ci_ok:
        return False
    if not (copilot_ok or approve_phrase_present):
        return False
    return True
