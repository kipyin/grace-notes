"""Merge gate: CI + Copilot threads + allowlisted reviewers + optional ``/sentry-approve``."""

from __future__ import annotations


def can_merge(
    *,
    ci_ok: bool,
    copilot_ok: bool,
    reviewers_ok: bool,
    approve_phrase_present: bool,
) -> bool:
    """
    merge_ok = ci && (approve || (copilot_ok && reviewers_ok)).

    ``reviewers_ok`` means the review wait phase is over and merge-safe for configured
    reviewers (no ``CHANGES_REQUESTED`` on their latest review, no unresolved threads).

    Approve overrides stuck Copilot threads and reviewer gates (emergency escape hatch).
    """
    if not ci_ok:
        return False
    if approve_phrase_present:
        return True
    return copilot_ok and reviewers_ok
