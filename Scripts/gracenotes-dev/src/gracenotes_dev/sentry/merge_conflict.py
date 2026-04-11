"""Resolve GitHub PR merge conflicts locally using the Cursor ``agent`` CLI."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

from gracenotes_dev.sentry.agent_client import resolve_merge_conflict_file_via_agent
from gracenotes_dev.sentry.log_sink import SentryLogSink
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import append_event


def _merge_in_progress(repo_root: Path) -> bool:
    r = subprocess.run(
        ["git", "rev-parse", "-q", "--verify", "MERGE_HEAD"],
        cwd=repo_root,
        capture_output=True,
    )
    return r.returncode == 0


def _git_abort_merge(repo_root: Path) -> None:
    subprocess.run(
        ["git", "merge", "--abort"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )


def try_resolve_merge_conflicts_with_agent(
    repo_root: Path,
    settings: SentrySettings,
    pr_number: int,
    main_branch: str,
    sink: SentryLogSink | None,
) -> bool:
    """
    Merge ``origin/{main_branch}`` into the PR head, resolve conflict markers with ``agent``,
    commit, and push. Returns True if push succeeded so ``gh pr merge`` can be retried.

    Call only when ``fix_provider`` is ``cursor_agent`` (local ``agent`` CLI).
    """
    append_event(
        repo_root,
        {
            "kind": "merge_conflict_attempt",
            "message": (
                f"Merging origin/{main_branch} into PR #{pr_number} head to resolve conflicts."
            ),
            "pr": pr_number,
        },
    )
    if sink is not None:
        sink.set_step("resolve merge conflicts (agent)")
        sink.log(
            f"PR #{pr_number}: merge-conflicted with {main_branch}; "
            "running local merge + agent …"
        )

    fetch = subprocess.run(
        ["git", "fetch", "origin", main_branch],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if fetch.returncode != 0:
        err = (fetch.stderr or fetch.stdout or "").strip()
        append_event(
            repo_root,
            {
                "kind": "merge_conflict_error",
                "message": f"git fetch failed: {err}",
                "pr": pr_number,
            },
        )
        return False

    pr_view = subprocess.run(
        ["gh", "pr", "view", str(pr_number), "--json", "headRefName"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if pr_view.returncode != 0:
        append_event(
            repo_root,
            {
                "kind": "merge_conflict_error",
                "message": (pr_view.stderr or pr_view.stdout or "").strip(),
                "pr": pr_number,
            },
        )
        return False
    try:
        head_ref = json.loads(pr_view.stdout)["headRefName"]
    except (json.JSONDecodeError, KeyError, TypeError) as exc:
        append_event(
            repo_root,
            {"kind": "merge_conflict_error", "message": f"headRefName: {exc}", "pr": pr_number},
        )
        return False

    if _merge_in_progress(repo_root):
        _git_abort_merge(repo_root)

    co = subprocess.run(
        ["git", "checkout", head_ref],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if co.returncode != 0:
        err = (co.stderr or co.stdout or "").strip()
        append_event(
            repo_root,
            {
                "kind": "merge_conflict_error",
                "message": f"git checkout {head_ref}: {err}",
                "pr": pr_number,
            },
        )
        return False

    merge = subprocess.run(
        ["git", "merge", f"origin/{main_branch}"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if merge.returncode == 0:
        push = subprocess.run(
            ["git", "push", "origin", "HEAD"],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if push.returncode == 0:
            append_event(
                repo_root,
                {
                    "kind": "merge_conflict_resolved",
                    "message": f"Merged origin/{main_branch} cleanly; pushed PR head.",
                    "pr": pr_number,
                },
            )
            if sink is not None:
                sink.log(
                    f"PR #{pr_number}: merged origin/{main_branch} "
                    "without conflict markers; pushed."
                )
            return True
        err = (push.stderr or push.stdout or "").strip()
        append_event(
            repo_root,
            {"kind": "merge_conflict_error", "message": f"git push failed: {err}", "pr": pr_number},
        )
        return False

    if not _merge_in_progress(repo_root):
        err = (merge.stderr or merge.stdout or "").strip()
        append_event(
            repo_root,
            {
                "kind": "merge_conflict_error",
                "message": f"git merge failed without MERGE_HEAD: {err}",
                "pr": pr_number,
            },
        )
        return False

    unstaged = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=U"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    conflict_paths = [p.strip() for p in unstaged.stdout.splitlines() if p.strip()]
    if not conflict_paths:
        _git_abort_merge(repo_root)
        append_event(
            repo_root,
            {
                "kind": "merge_conflict_error",
                "message": "Merge failed but no unmerged paths listed; aborted merge.",
                "pr": pr_number,
            },
        )
        return False

    try:
        for rel in conflict_paths:
            fp = repo_root / rel
            if not fp.is_file():
                raise RuntimeError(f"Conflict path is not a regular file: {rel}")
            raw = fp.read_text(encoding="utf-8")
            new_src = resolve_merge_conflict_file_via_agent(
                repo_root=repo_root,
                agent_bin=settings.agent_bin,
                prefix_args=settings.agent_prefix_args,
                extra_args=settings.agent_extra_args,
                relative_path=rel,
                file_content=raw,
                timeout_sec=settings.agent_timeout_sec,
            )
            if not new_src.strip():
                raise RuntimeError(f"Agent returned NO_CHANGE for {rel}")
            fp.write_text(new_src, encoding="utf-8")
            append_event(
                repo_root,
                {
                    "kind": "merge_conflict_file",
                    "message": f"Resolved conflict markers in {rel}",
                    "pr": pr_number,
                },
            )

        add = subprocess.run(["git", "add", "-A"], cwd=repo_root, capture_output=True, text=True)
        if add.returncode != 0:
            raise RuntimeError((add.stderr or add.stdout or "").strip())

        commit = subprocess.run(
            [
                "git",
                "commit",
                "-m",
                f"sentry: resolve merge conflicts with origin/{main_branch}",
            ],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if commit.returncode != 0:
            raise RuntimeError((commit.stderr or commit.stdout or "").strip())

        push = subprocess.run(
            ["git", "push", "origin", "HEAD"],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if push.returncode != 0:
            err = (push.stderr or push.stdout or "").strip()
            append_event(
                repo_root,
                {
                    "kind": "merge_conflict_error",
                    "message": f"git push failed after resolve: {err}",
                    "pr": pr_number,
                },
            )
            return False

        append_event(
            repo_root,
            {
                "kind": "merge_conflict_resolved",
                "message": f"Agent resolved {len(conflict_paths)} file(s); pushed PR head.",
                "pr": pr_number,
            },
        )
        if sink is not None:
            sink.log(f"PR #{pr_number}: merge conflicts resolved with agent; pushed.")
        return True
    except (OSError, RuntimeError, UnicodeError) as exc:
        _git_abort_merge(repo_root)
        append_event(
            repo_root,
            {
                "kind": "merge_conflict_error",
                "message": str(exc),
                "pr": pr_number,
            },
        )
        if sink is not None:
            sink.log(f"PR #{pr_number}: merge conflict resolution failed: {exc}")
        return False
