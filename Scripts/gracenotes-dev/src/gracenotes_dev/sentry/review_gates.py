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
) -> bool:
    """
    True when sentry may proceed past “waiting for reviewers” (merge gating still applies).

    Exits when the issue/PR review gate passes, or when ``review_silence_timeout_seconds``
    has elapsed since PR creation (``createdAt``), or when reviewer logins are empty.
    If ``pr_created_at`` is unknown, does not block on silence (treats as satisfied for
    the timeout leg only when gate fails).
    """
    if not reviewer_logins:
        return True
    if gh_api.reviewer_merge_gate_ok(
        comments=comments,
        pr_reviews=pr_reviews,
        reviewer_logins=reviewer_logins,
        start_phrases=start_phrases,
    ):
        return True
    if review_silence_timeout_seconds <= 0:
        return True
    if pr_created_at is None:
        return True
    created = pr_created_at
    if created.tzinfo is None:
        created = created.replace(tzinfo=timezone.utc)
    deadline = created + timedelta(seconds=review_silence_timeout_seconds)
    return datetime.now(timezone.utc) >= deadline
