"""GitHub via ``gh`` CLI (GraphQL + REST)."""

from __future__ import annotations

import json
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any

_REVIEW_THREADS_QUERY = (
    "query($owner:String!,$name:String!,$number:Int!){"
    "repository(owner:$owner,name:$name){"
    "pullRequest(number:$number){"
    "reviewThreads(first:100){nodes{isResolved comments(first:20){nodes{author{login} body}}}}"
    "}}}"
)


def _run_gh(
    repo_root: Path,
    args: list[str],
    *,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["gh", *args],
        cwd=repo_root,
        check=check,
        capture_output=True,
        text=True,
    )


def graphql_review_threads(
    repo_root: Path,
    owner: str,
    repo: str,
    pr_number: int,
) -> list[dict[str, Any]]:
    proc = _run_gh(
        repo_root,
        [
            "api",
            "graphql",
            "-f",
            f"query={_REVIEW_THREADS_QUERY}",
            "-f",
            f"owner={owner}",
            "-f",
            f"name={repo}",
            "-F",
            f"number={pr_number}",
        ],
        check=False,
    )
    if proc.returncode != 0:
        return []
    data = json.loads(proc.stdout)
    err = data.get("errors")
    if err:
        return []
    nodes = (
        data.get("data", {})
        .get("repository", {})
        .get("pullRequest", {})
        .get("reviewThreads", {})
        .get("nodes", [])
    )
    return [n for n in nodes if isinstance(n, dict)]


def review_thread_author_logins(nodes: list[dict[str, Any]]) -> list[str]:
    """Unique ``author.login`` values from review thread comments (sorted)."""
    seen: set[str] = set()
    out: list[str] = []
    for node in nodes:
        comments = (node.get("comments") or {}).get("nodes") or []
        for c in comments:
            author = (c or {}).get("author") or {}
            login = (author.get("login") or "").strip()
            if login and login not in seen:
                seen.add(login)
                out.append(login)
    return sorted(out)


def unresolved_reviewer_threads(
    nodes: list[dict[str, Any]],
    reviewer_logins: tuple[str, ...],
) -> int:
    """Count unresolved threads that include a comment from any configured reviewer login."""
    allowed = {x.strip().lower() for x in reviewer_logins if x.strip()}
    if not allowed:
        return 0
    count = 0
    for node in nodes:
        if node.get("isResolved"):
            continue
        comments = (node.get("comments") or {}).get("nodes") or []
        for c in comments:
            author = (c or {}).get("author") or {}
            alogin = (author.get("login") or "").lower()
            if alogin in allowed:
                count += 1
                break
    return count


def unresolved_cursor_threads(
    nodes: list[dict[str, Any]],
    cursor_logins: tuple[str, ...],
) -> int:
    """Deprecated alias for :func:`unresolved_reviewer_threads`."""
    return unresolved_reviewer_threads(nodes, cursor_logins)


def _cursor_reviews_newest_first(
    reviews: list[dict[str, Any]],
    cursor_logins: tuple[str, ...],
) -> list[dict[str, Any]]:
    """Non-``PENDING`` Cursor PR reviews, newest ``submitted_at`` first."""
    allowed = {x.strip().lower() for x in cursor_logins if x.strip()}
    if not allowed:
        return []
    out: list[dict[str, Any]] = []
    for r in reviews:
        user = ((r.get("user") or {}).get("login") or "").strip().lower()
        if user not in allowed:
            continue
        state = (r.get("state") or "").strip().upper()
        if state == "PENDING":
            continue
        out.append(r)
    out.sort(key=lambda x: str(x.get("submitted_at") or ""), reverse=True)
    return out


def cursor_requests_changes_latest(
    reviews: list[dict[str, Any]],
    cursor_logins: tuple[str, ...],
) -> bool:
    """True if the newest Cursor PR review is ``CHANGES_REQUESTED``."""
    newest = _cursor_reviews_newest_first(reviews, cursor_logins)
    if not newest:
        return False
    return (newest[0].get("state") or "").strip().upper() == "CHANGES_REQUESTED"


def cursor_merge_clear(
    *,
    review_thread_nodes: list[dict[str, Any]],
    pr_reviews: list[dict[str, Any]],
    cursor_logins: tuple[str, ...],
) -> bool:
    """
    Merge-safe Cursor state: same as :func:`reviewers_merge_clear` for ``cursor_logins``.

    If ``cursor_logins`` is empty, returns True (nothing to check).
    """
    return reviewers_merge_clear(
        review_thread_nodes=review_thread_nodes,
        pr_reviews=pr_reviews,
        reviewer_logins=cursor_logins,
    )


def cursor_feedback_digest(
    *,
    review_thread_nodes: list[dict[str, Any]],
    pr_reviews: list[dict[str, Any]],
    cursor_logins: tuple[str, ...],
) -> str:
    """Text for the fix agent; same as :func:`reviewers_feedback_digest` for ``cursor_logins``."""
    return reviewers_feedback_digest(
        review_thread_nodes=review_thread_nodes,
        pr_reviews=pr_reviews,
        reviewer_logins=cursor_logins,
    )


def latest_non_pending_review_for_login(
    reviews: list[dict[str, Any]],
    login: str,
) -> dict[str, Any] | None:
    """Newest submitted (non-``PENDING``) PR review for ``login``, by ``submitted_at``."""
    login_l = login.strip().lower()
    out: list[dict[str, Any]] = []
    for r in reviews:
        user = ((r.get("user") or {}).get("login") or "").strip().lower()
        if user != login_l:
            continue
        state = (r.get("state") or "").strip().upper()
        if state == "PENDING":
            continue
        out.append(r)
    if not out:
        return None
    out.sort(key=lambda x: str(x.get("submitted_at") or ""), reverse=True)
    return out[0]


def reviewers_merge_clear(
    *,
    review_thread_nodes: list[dict[str, Any]],
    pr_reviews: list[dict[str, Any]],
    reviewer_logins: tuple[str, ...],
) -> bool:
    """
    Merge-safe: no unresolved threads from allowlisted reviewers, and no
    ``CHANGES_REQUESTED`` on the latest submitted review per reviewer (when they reviewed).
    """
    allowed = {x.strip().lower() for x in reviewer_logins if x.strip()}
    if not allowed:
        return True
    if unresolved_reviewer_threads(review_thread_nodes, reviewer_logins) > 0:
        return False
    for login in allowed:
        latest = latest_non_pending_review_for_login(pr_reviews, login)
        if latest is None:
            continue
        if (latest.get("state") or "").strip().upper() == "CHANGES_REQUESTED":
            return False
    return True


def reviewers_feedback_digest(
    *,
    review_thread_nodes: list[dict[str, Any]],
    pr_reviews: list[dict[str, Any]],
    reviewer_logins: tuple[str, ...],
) -> str:
    """Unresolved thread bodies plus latest submitted review body per allowlisted reviewer."""
    allowed = {x.strip().lower() for x in reviewer_logins if x.strip()}
    if not allowed:
        return ""
    parts: list[str] = []
    for node in review_thread_nodes:
        if node.get("isResolved"):
            continue
        comments = (node.get("comments") or {}).get("nodes") or []
        for c in comments:
            author = (c or {}).get("author") or {}
            login = (author.get("login") or "").strip()
            if login.lower() not in allowed:
                continue
            body = (c or {}).get("body") or ""
            if body.strip():
                parts.append(f"Review thread ({login}):\n{body.strip()}")
    for login in sorted(allowed):
        latest = latest_non_pending_review_for_login(pr_reviews, login)
        if latest is None:
            continue
        body = (latest.get("body") or "").strip()
        state = (latest.get("state") or "").strip()
        if body:
            parts.append(f"PR review ({login}, {state}):\n{body}")
    return "\n\n---\n\n".join(parts)


def pr_created_at_utc(repo_root: Path, pr_number: int) -> datetime | None:
    """PR ``createdAt`` from ``gh pr view`` (UTC)."""
    proc = _run_gh(
        repo_root,
        ["pr", "view", str(pr_number), "--json", "createdAt"],
        check=False,
    )
    if proc.returncode != 0:
        return None
    try:
        data = json.loads(proc.stdout)
        raw = data.get("createdAt")
        if not raw or not isinstance(raw, str):
            return None
        s = raw.replace("Z", "+00:00")
        return datetime.fromisoformat(s)
    except (json.JSONDecodeError, ValueError, TypeError):
        return None


def review_pending_from_allowlist(
    reviews: list[dict[str, Any]],
    reviewer_logins: tuple[str, ...],
) -> bool:
    """True if any allowlisted reviewer has a ``PENDING`` (draft) PR review."""
    allowed = {x.strip().lower() for x in reviewer_logins if x.strip()}
    for r in reviews:
        user = ((r.get("user") or {}).get("login") or "").strip().lower()
        if user not in allowed:
            continue
        if (r.get("state") or "").strip().upper() == "PENDING":
            return True
    return False


def has_non_pending_review_from_allowlist(
    reviews: list[dict[str, Any]],
    reviewer_logins: tuple[str, ...],
) -> bool:
    allowed = {x.strip().lower() for x in reviewer_logins if x.strip()}
    for r in reviews:
        user = ((r.get("user") or {}).get("login") or "").strip().lower()
        if user not in allowed:
            continue
        if (r.get("state") or "").strip().upper() != "PENDING":
            return True
    return False


def has_allowlisted_thread_comment(
    review_thread_nodes: list[dict[str, Any]],
    reviewer_logins: tuple[str, ...],
) -> bool:
    allowed = {x.strip().lower() for x in reviewer_logins if x.strip()}
    for node in review_thread_nodes:
        comments = (node.get("comments") or {}).get("nodes") or []
        for c in comments:
            author = (c or {}).get("author") or {}
            if (author.get("login") or "").strip().lower() in allowed:
                return True
    return False


def has_allowlisted_issue_comment(
    issue_comments: list[dict[str, Any]],
    reviewer_logins: tuple[str, ...],
) -> bool:
    allowed = {x.strip().lower() for x in reviewer_logins if x.strip()}
    for c in issue_comments:
        login = ((c.get("user") or {}).get("login") or "").strip().lower()
        if login in allowed:
            return True
    return False


def pr_reviews(repo_root: Path, owner: str, repo: str, pr_number: int) -> list[dict[str, Any]]:
    """Submitted PR reviews (REST). Used with issue comments for Cursor merge gating."""
    proc = _run_gh(
        repo_root,
        [
            "api",
            f"repos/{owner}/{repo}/pulls/{pr_number}/reviews",
            "--paginate",
        ],
        check=False,
    )
    if proc.returncode != 0:
        return []
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else []


def issue_comments(repo_root: Path, owner: str, repo: str, pr_number: int) -> list[dict[str, Any]]:
    proc = _run_gh(
        repo_root,
        [
            "api",
            f"repos/{owner}/{repo}/issues/{pr_number}/comments",
            "--paginate",
        ],
        check=False,
    )
    if proc.returncode != 0:
        return []
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else []


def issue_comment_user_logins(comments: list[dict[str, Any]]) -> list[str]:
    """Sorted unique ``user.login`` values from issue (PR) comments."""
    seen: set[str] = set()
    out: list[str] = []
    for c in comments:
        login = ((c.get("user") or {}).get("login") or "").strip()
        if login and login not in seen:
            seen.add(login)
            out.append(login)
    return sorted(out)


def _issue_comment_login(comment: dict[str, Any]) -> str:
    return ((comment.get("user") or {}).get("login") or "").strip()


def _tail_after_first_start_phrase(body: str, start_phrases: tuple[str, ...]) -> str:
    """Text after the first case-insensitive match of any start phrase (for same-comment review)."""
    low = body.lower()
    for p in start_phrases:
        pl = (p or "").strip().lower()
        if not pl:
            continue
        i = low.find(pl)
        if i >= 0:
            return body[i + len(pl) :].strip()
    return ""


def reviewer_pr_review_finished(
    reviews: list[dict[str, Any]],
    reviewer_logins: tuple[str, ...],
) -> bool:
    """
    True if a configured reviewer account submitted a non-draft PR review.

    ``PENDING`` is GitHub’s draft / not-yet-submitted state; others count as delivered.
    """
    allowed = {x.strip().lower() for x in reviewer_logins if x.strip()}
    if not allowed:
        return False
    for r in reviews:
        user = ((r.get("user") or {}).get("login") or "").strip().lower()
        if user not in allowed:
            continue
        state = (r.get("state") or "").strip().upper()
        if state == "PENDING":
            continue
        if state in ("COMMENTED", "CHANGES_REQUESTED", "APPROVED", "DISMISSED"):
            return True
    return False


def cursor_pr_review_finished(
    reviews: list[dict[str, Any]],
    cursor_logins: tuple[str, ...],
) -> bool:
    """Deprecated alias for :func:`reviewer_pr_review_finished`."""
    return reviewer_pr_review_finished(reviews, cursor_logins)


def reviewer_issue_review_ok(
    comments: list[dict[str, Any]],
    reviewer_logins: tuple[str, ...],
    start_phrases: tuple[str, ...],
) -> bool:
    """
    Issue-comment gate for allowlisted reviewers (``/review`` flow).

    If ``reviewer_logins`` is empty, returns True (gate disabled).

    If there is no comment from a configured login that looks like a “started” message
    (e.g. “Taking a look”), returns True — nothing to wait on.

    If a reviewer posted a start phrase, returns True when either:

    * a later issue comment from that reviewer exists, or
    * the same comment contains substantive text after the start phrase (review in one comment).

    For PR reviews (inline or summary) and deleted starters, use
    :func:`reviewer_merge_gate_ok` which also consults :func:`pr_reviews`.
    """
    allowed = {x.strip().lower() for x in reviewer_logins if x.strip()}
    if not allowed:
        return True

    def _is_start(body: str) -> bool:
        b = (body or "").lower()
        return any((p or "").strip().lower() in b for p in start_phrases if (p or "").strip())

    curs: list[dict[str, Any]] = []
    for c in comments:
        if _issue_comment_login(c).lower() in allowed:
            curs.append(c)
    curs.sort(key=lambda x: str(x.get("created_at") or ""))

    if not curs:
        return True

    start_idx: int | None = None
    for i, c in enumerate(curs):
        if _is_start(c.get("body") or ""):
            start_idx = i
            break

    if start_idx is None:
        return True

    start_body = curs[start_idx].get("body") or ""
    tail = _tail_after_first_start_phrase(start_body, start_phrases)
    if len(tail) >= 10:
        return True
    if start_idx + 1 < len(curs):
        return True
    return False


def cursor_issue_review_ok(
    comments: list[dict[str, Any]],
    cursor_logins: tuple[str, ...],
    start_phrases: tuple[str, ...],
) -> bool:
    """Deprecated alias for :func:`reviewer_issue_review_ok`."""
    return reviewer_issue_review_ok(comments, cursor_logins, start_phrases)


def reviewer_merge_gate_ok(
    *,
    comments: list[dict[str, Any]],
    pr_reviews: list[dict[str, Any]],
    reviewer_logins: tuple[str, ...],
    start_phrases: tuple[str, ...],
) -> bool:
    """
    Reviewer merge gate: issue comments and/or submitted PR reviews.

    If issue-comment logic alone is satisfied, returns True. Otherwise, if a
    configured reviewer submitted a **PR review** (not ``PENDING``), returns True.
    """
    if reviewer_issue_review_ok(comments, reviewer_logins, start_phrases):
        return True
    return reviewer_pr_review_finished(pr_reviews, reviewer_logins)


def cursor_merge_gate_ok(
    *,
    comments: list[dict[str, Any]],
    pr_reviews: list[dict[str, Any]],
    cursor_logins: tuple[str, ...],
    start_phrases: tuple[str, ...],
) -> bool:
    """Deprecated alias for :func:`reviewer_merge_gate_ok`."""
    return reviewer_merge_gate_ok(
        comments=comments,
        pr_reviews=pr_reviews,
        reviewer_logins=cursor_logins,
        start_phrases=start_phrases,
    )


def has_approval_phrase(
    comments: list[dict[str, Any]],
    phrase: str,
    allowed_logins: set[str],
) -> bool:
    phrase_l = phrase.strip().lower()
    allow = {x.strip().lower() for x in allowed_logins if x.strip()}
    if not allow:
        return False
    for c in comments:
        user = (c.get("user") or {}).get("login") or ""
        if user.lower() not in allow:
            continue
        body = (c.get("body") or "").lower()
        if phrase_l in body:
            return True
    return False


def pr_checks_passed(repo_root: Path, pr_number: int) -> bool:
    proc = _run_gh(repo_root, ["pr", "checks", str(pr_number)], check=False)
    return proc.returncode == 0


def pr_merge_squash(repo_root: Path, pr_number: int) -> bool:
    proc = _run_gh(
        repo_root,
        ["pr", "merge", str(pr_number), "--squash", "--delete-branch"],
        check=False,
    )
    return proc.returncode == 0


def pr_merge_fields(repo_root: Path, pr_number: int) -> dict[str, Any]:
    """JSON from ``gh pr view`` (mergeable, mergeState, headRefName)."""
    proc = _run_gh(
        repo_root,
        ["pr", "view", str(pr_number), "--json", "mergeable,mergeState,headRefName"],
        check=False,
    )
    if proc.returncode != 0:
        return {}
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {}


def pr_merge_is_conflicting(repo_root: Path, pr_number: int) -> bool:
    """True when GitHub reports the PR cannot merge due to conflicts with the base branch."""
    d = pr_merge_fields(repo_root, pr_number)
    return d.get("mergeable") == "CONFLICTING"


def pr_comment(repo_root: Path, pr_number: int, body: str) -> bool:
    proc = _run_gh(repo_root, ["pr", "comment", str(pr_number), "--body", body], check=False)
    return proc.returncode == 0


def list_open_sentry_pr_numbers(
    repo_root: Path,
    main_branch: str,
    branch_prefix: str,
) -> list[int]:
    """Open PRs into ``main_branch`` whose head ref starts with ``branch_prefix`` (ascending #)."""
    proc = _run_gh(
        repo_root,
        [
            "pr",
            "list",
            "--state",
            "open",
            "--base",
            main_branch,
            "--json",
            "number,headRefName",
            "--limit",
            "200",
        ],
        check=False,
    )
    if proc.returncode != 0:
        return []
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []
    if not isinstance(data, list):
        return []
    out: list[int] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        head = str(item.get("headRefName") or "")
        if not head.startswith(branch_prefix):
            continue
        try:
            out.append(int(item["number"]))
        except (KeyError, TypeError, ValueError):
            continue
    return sorted(out)


def pr_changed_file_paths(repo_root: Path, pr_number: int) -> list[str]:
    """Paths from ``gh pr view`` ``files`` (for touch classification)."""
    proc = _run_gh(
        repo_root,
        ["pr", "view", str(pr_number), "--json", "files"],
        check=False,
    )
    if proc.returncode != 0:
        return []
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []
    files = data.get("files")
    if not isinstance(files, list):
        return []
    paths: list[str] = []
    for f in files:
        if not isinstance(f, dict):
            continue
        p = f.get("path")
        if isinstance(p, str) and p:
            paths.append(p.replace("\\", "/"))
    return paths
