"""GitHub via ``gh`` CLI (GraphQL + REST)."""

from __future__ import annotations

import json
import subprocess
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


def unresolved_copilot_threads(
    nodes: list[dict[str, Any]],
    copilot_login: str | None,
) -> int:
    """Count unresolved threads that include a comment from ``copilot_login`` (if set)."""
    if not copilot_login:
        return 0
    login_l = copilot_login.strip().lower()
    count = 0
    for node in nodes:
        if node.get("isResolved"):
            continue
        comments = (node.get("comments") or {}).get("nodes") or []
        for c in comments:
            author = (c or {}).get("author") or {}
            alogin = (author.get("login") or "").lower()
            if alogin == login_l:
                count += 1
                break
    return count


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
