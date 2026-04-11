"""Single merge gate + squash attempt (used by poll loop and sweep)."""

from __future__ import annotations

import time
from enum import Enum
from pathlib import Path

from gracenotes_dev.sentry import github as gh_api
from gracenotes_dev.sentry.log_sink import SentryLogSink
from gracenotes_dev.sentry.merge_conflict import try_resolve_merge_conflicts_with_agent
from gracenotes_dev.sentry.merge_logic import approval_only_pending, can_merge
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import append_event


class MergePollOutcome(str, Enum):
    """Result of one merge poll cycle."""

    MERGED = "merged"
    CONTINUE_LOOP = "continue_loop"
    WAIT_FOR_GATES = "wait_for_gates"
    YIELD_APPROVAL = "yield_approval"
    TERMINAL_FAIL = "terminal_fail"


def merge_poll_once(
    repo_root: Path,
    settings: SentrySettings,
    owner: str,
    repo: str,
    pr_number: int,
    high_touch: bool,
    allow: set[str],
    main_branch: str,
    *,
    sink: SentryLogSink | None,
    poll_yield_for_approval: bool,
) -> MergePollOutcome:
    """
    One CI / Copilot / approval check and optional squash + conflict repair.

    When ``poll_yield_for_approval`` is True (merge poll after opening a PR), honor
    ``yield_on_approval_pending`` and return ``YIELD_APPROVAL`` if only allowlisted
    approval is missing. Sweep passes False so those PRs are re-checked later.
    """
    if sink is not None:
        sink.set_step("merge gates (poll)")
    ci_ok = gh_api.pr_checks_passed(repo_root, pr_number)
    threads = gh_api.graphql_review_threads(repo_root, owner, repo, pr_number)
    if settings.copilot_login:
        unresolved = gh_api.unresolved_copilot_threads(threads, settings.copilot_login)
    else:
        unresolved = 0

    comments = gh_api.issue_comments(repo_root, owner, repo, pr_number)
    approve = gh_api.has_approval_phrase(
        comments,
        settings.approval_phrase,
        allow,
    )

    copilot_ok = unresolved == 0

    if sink is not None:
        sink.log(
            f"merge poll: pr={pr_number} ci_ok={ci_ok} high_touch={high_touch} "
            f"copilot_unresolved={unresolved} approve={approve}"
        )

    if (
        poll_yield_for_approval
        and settings.yield_on_approval_pending
        and approval_only_pending(
            ci_ok=ci_ok,
            copilot_ok=copilot_ok,
            high_touch=high_touch,
            approve_phrase_present=approve,
        )
        and not gh_api.pr_merge_is_conflicting(repo_root, pr_number)
    ):
        append_event(
            repo_root,
            {
                "kind": "merge_poll_yield_approval_pending",
                "message": (
                    f"PR #{pr_number}: only allowlisted approval pending; "
                    "yielding to next iteration."
                ),
                "pr": pr_number,
            },
        )
        return MergePollOutcome.YIELD_APPROVAL

    if can_merge(
        ci_ok=ci_ok,
        high_touch=high_touch,
        copilot_ok=copilot_ok,
        approve_phrase_present=approve,
    ):
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
                ):
                    time.sleep(5.0)
                    return MergePollOutcome.CONTINUE_LOOP
                return MergePollOutcome.TERMINAL_FAIL
            return MergePollOutcome.WAIT_FOR_GATES
        return MergePollOutcome.TERMINAL_FAIL

    return MergePollOutcome.WAIT_FOR_GATES
