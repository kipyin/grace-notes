"""Merge gate: CI + Copilot threads + optional ``/sentry-approve``."""

from __future__ import annotations


def can_merge(
    *,
    ci_ok: bool,
    high_touch: bool,
    copilot_ok: bool,
    approve_phrase_present: bool,
) -> bool:
    """merge_ok = ci && (copilot_ok || approve) && (!high_touch || approve)."""
    if not ci_ok:
        return False
    if not (copilot_ok or approve_phrase_present):
        return False
    if high_touch and not approve_phrase_present:
        return False
    return True


def approval_only_pending(
    *,
    ci_ok: bool,
    copilot_ok: bool,
    high_touch: bool,
    approve_phrase_present: bool,
) -> bool:
    """True when CI and Copilot are satisfied but high-touch still needs allowlisted approval."""
    return ci_ok and copilot_ok and high_touch and not approve_phrase_present
