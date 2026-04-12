"""Single merge gate + squash attempt (used by poll loop and sweep)."""

from __future__ import annotations

import time
from enum import Enum
from pathlib import Path

from gracenotes_dev.sentry import github as gh_api
from gracenotes_dev.sentry.ci_fix import (
    ci_fix_mark_attempt,
    ci_fix_should_attempt,
    try_fix_ci_with_agent,
)
from gracenotes_dev.sentry.cursor_review_fix import (
    cursor_fix_mark_attempt,
    cursor_fix_should_attempt,
    try_address_cursor_review_with_agent,
)
from gracenotes_dev.sentry.log_sink import SentryLogSink
from gracenotes_dev.sentry.merge_conflict import try_resolve_merge_conflicts_with_agent
from gracenotes_dev.sentry.merge_logic import can_merge
from gracenotes_dev.sentry.review_comment import (
    auth_user_has_sentry_marker_comment,
    reviewers_clear_from_sentry_comment,
)
from gracenotes_dev.sentry.review_gates import review_wait_satisfied
from gracenotes_dev.sentry.settings import SentrySettings


class MergePollOutcome(str, Enum):
    """Result of one merge poll cycle."""

    MERGED = "merged"
    CONTINUE_LOOP = "continue_loop"
    WAIT_FOR_GATES = "wait_for_gates"
    TERMINAL_FAIL = "terminal_fail"


def merge_poll_once(
    repo_root: Path,
    settings: SentrySettings,
    owner: str,
    repo: str,
    pr_number: int,
    allow: set[str],
    main_branch: str,
    *,
    sink: SentryLogSink | None,
    git_cwd: Path | None = None,
) -> MergePollOutcome:
    """
    One CI / allowlisted reviewers (issue comments + PR reviews) / approval check.

    ``git_cwd`` is the directory for git commands when the PR head only exists in a sentry
    worktree (otherwise defaults to ``repo_root``).
    """
    if sink is not None:
        sink.set_step("merge gates (poll)")
    ci_ok = gh_api.pr_checks_passed(repo_root, pr_number)
    threads = gh_api.graphql_review_threads(repo_root, owner, repo, pr_number)

    comments = gh_api.issue_comments(repo_root, owner, repo, pr_number)
    reviews = gh_api.pr_reviews(repo_root, owner, repo, pr_number)
    approve = gh_api.has_approval_phrase(
        comments,
        settings.approval_phrase,
        allow,
    )

    created_at = gh_api.pr_created_at_utc(repo_root, pr_number)
    if sink is not None and settings.reviewer_logins and created_at is None:
        sink.log(
            f"merge poll: pr={pr_number} createdAt unavailable from gh; "
            "reviewer wait gate cannot use silence timeout until metadata is readable."
        )
    wait_ok = review_wait_satisfied(
        pr_created_at=created_at,
        review_silence_timeout_seconds=settings.review_silence_timeout_seconds,
        comments=comments,
        pr_reviews=reviews,
        reviewer_logins=settings.reviewer_logins,
        start_phrases=settings.cursor_start_phrases,
    )
    if not settings.reviewer_logins:
        reviewers_clear = True
    elif settings.review_clear_mode == "comment":
        auth_login = gh_api.gh_authenticated_login(repo_root)
        github_clear = gh_api.reviewers_merge_clear(
            review_thread_nodes=threads,
            pr_reviews=reviews,
            reviewer_logins=settings.reviewer_logins,
        )
        # Marker-only mode applies after the gh user has posted at least one
        # <!-- sentry-review: … --> comment (e.g. review-fix). Until then, use the
        # same thread/review rules as ``github`` so CI-green exploratory PRs can merge
        # without a manual marker or /sentry-approve.
        if auth_login is None:
            if sink is not None:
                sink.log(
                    f"merge poll: pr={pr_number} review_clear_mode=comment but gh user login "
                    "unavailable; using GitHub review/thread state for review clearance."
                )
            reviewers_clear = github_clear
        elif auth_user_has_sentry_marker_comment(comments, auth_login):
            reviewers_clear = reviewers_clear_from_sentry_comment(
                comments=comments,
                authenticated_login=auth_login,
                block_outcomes=settings.review_clear_block_outcomes,
                max_age_seconds=settings.review_clear_comment_max_age_seconds,
            )
        else:
            if sink is not None:
                sink.log(
                    f"merge poll: pr={pr_number} review_clear_mode=comment, "
                    "no sentry marker from gh user; using GitHub review/thread state."
                )
            reviewers_clear = github_clear
    else:
        reviewers_clear = gh_api.reviewers_merge_clear(
            review_thread_nodes=threads,
            pr_reviews=reviews,
            reviewer_logins=settings.reviewer_logins,
        )
    reviewers_ok = wait_ok and reviewers_clear

    if sink is not None:
        sink.log(
            f"merge poll: pr={pr_number} ci_ok={ci_ok} "
            f"review_wait_ok={wait_ok} reviewers_clear={reviewers_clear} "
            f"review_clear_mode={settings.review_clear_mode} approve={approve}"
        )

    merge_allowed = can_merge(
        ci_ok=ci_ok,
        reviewers_ok=reviewers_ok,
        approve_phrase_present=approve,
    )

    if not merge_allowed and not ci_ok and settings.fix_provider == "cursor_agent":
        if ci_fix_should_attempt(
            repo_root,
            pr_number,
            settings.ci_fix_cooldown_seconds,
        ):
            ci_fix_mark_attempt(repo_root, pr_number)
            if try_fix_ci_with_agent(
                repo_root,
                settings,
                pr_number,
                main_branch,
                sink=sink,
                git_cwd=git_cwd,
            ):
                time.sleep(5.0)
                return MergePollOutcome.CONTINUE_LOOP

    if not merge_allowed and wait_ok and not reviewers_clear:
        if ci_ok and cursor_fix_should_attempt(
            repo_root,
            pr_number,
            settings.cursor_review_fix_cooldown_seconds,
        ):
            feedback = gh_api.reviewers_feedback_digest(
                review_thread_nodes=threads,
                pr_reviews=reviews,
                reviewer_logins=settings.reviewer_logins,
            )
            if feedback.strip() and settings.fix_provider == "cursor_agent":
                cursor_fix_mark_attempt(repo_root, pr_number)
                if try_address_cursor_review_with_agent(
                    repo_root,
                    settings,
                    owner,
                    repo,
                    pr_number,
                    main_branch,
                    feedback_text=feedback,
                    sink=sink,
                    git_cwd=git_cwd,
                ):
                    time.sleep(5.0)
                    return MergePollOutcome.CONTINUE_LOOP

    if merge_allowed:
        if sink is not None:
            sink.set_step("squash merge")
        merged = gh_api.pr_merge_squash(repo_root, pr_number)
        if merged:
            return MergePollOutcome.MERGED
        if gh_api.pr_merge_is_conflicting(repo_root, pr_number):
            if settings.fix_provider == "cursor_agent":
                if try_resolve_merge_conflicts_with_agent(
                    repo_root,
                    settings,
                    pr_number,
                    main_branch,
                    sink,
                    git_cwd=git_cwd,
                ):
                    time.sleep(5.0)
                    return MergePollOutcome.CONTINUE_LOOP
                return MergePollOutcome.TERMINAL_FAIL
            return MergePollOutcome.WAIT_FOR_GATES
        return MergePollOutcome.TERMINAL_FAIL

    return MergePollOutcome.WAIT_FOR_GATES
