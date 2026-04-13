"""Blocking wait for allowlisted reviewers (silence from PR creation + issue/PR review gates)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from gracenotes_dev.sentry import github as gh_api


def review_wait_satisfied(
    *,
    pr_created_at: datetime | None,
    review_silence_timeout_seconds: int,
    comments: list[dict[str, Any]],
    pr_reviews: list[dict[str, Any]],
    reviewer_logins: tuple[str, ...],
    start_phrases: tuple[str, ...],
    review_requested_allowlisted_logins: list[str],
) -> bool:
    """
    True when sentry may proceed past “waiting for reviewers” (merge gating still applies).

    Requires:

    * :func:`~gracenotes_dev.sentry.github.reviewer_merge_gate_ok` — issue ``/review`` flow
      **or** a submitted (non-``PENDING``) PR review from an allowlisted login (so a bot that
      posts a start phrase in an issue comment but finishes only in a PR review is not stuck).
    * :func:`~gracenotes_dev.sentry.github.review_bots_quiescent` — no ``PENDING`` drafts from
      allowlisted reviewers and no outstanding **requested** reviewers (allowlisted) on the PR.

    Otherwise exits when ``review_silence_timeout_seconds`` has elapsed since PR creation,
    when ``review_silence_timeout_seconds`` is ``<= 0`` (silence disabled), or when reviewer
    logins are empty.

    If ``pr_created_at`` is unknown while the gate is still blocking, returns False so
    silence cannot be assumed (fail closed on missing metadata).
    """
    if not reviewer_logins:
        return True

    review_phase_ok = gh_api.reviewer_merge_gate_ok(
        comments=comments,
        pr_reviews=pr_reviews,
        reviewer_logins=reviewer_logins,
        start_phrases=start_phrases,
    )
    bots_ok = gh_api.review_bots_quiescent(
        pr_reviews=pr_reviews,
        reviewer_logins=reviewer_logins,
        requested_allowlisted_logins=review_requested_allowlisted_logins,
    )

    if review_phase_ok and bots_ok:
        return True

    if review_silence_timeout_seconds <= 0:
        return True
    if pr_created_at is None:
        return False
    created = pr_created_at
    if created.tzinfo is None:
        created = created.replace(tzinfo=timezone.utc)
    deadline = created + timedelta(seconds=review_silence_timeout_seconds)
    return datetime.now(timezone.utc) >= deadline
