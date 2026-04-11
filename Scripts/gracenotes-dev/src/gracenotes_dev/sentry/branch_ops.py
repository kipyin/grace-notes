"""Git helpers: sync integration branch from origin, restore previous branch."""

from __future__ import annotations

import subprocess
from pathlib import Path

from gracenotes_dev.sentry.log_sink import SentryLogSink


def current_branch(repo_root: Path) -> str:
    """Return current branch name (or ``HEAD`` if detached)."""
    p = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if p.returncode != 0:
        return "main"
    return p.stdout.strip() or "main"


def sync_main_from_origin(
    repo_root: Path,
    main_branch: str,
    *,
    sink: SentryLogSink | None,
) -> None:
    """
    Fetch ``origin/{main_branch}``, check it out, and fast-forward to match origin.

    Sentry branches must be cut from this tip, not from whatever branch was checked out.
    """
    if sink is not None:
        sink.set_step(f"sync {main_branch}")
        sink.log(f"Fetching origin/{main_branch} and updating local {main_branch} …")
    fetch = subprocess.run(
        ["git", "fetch", "origin", main_branch],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if fetch.returncode != 0:
        err = (fetch.stderr or fetch.stdout or "").strip()
        raise RuntimeError(f"git fetch origin {main_branch} failed: {err}")

    checkout = subprocess.run(
        ["git", "checkout", main_branch],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if checkout.returncode != 0:
        reset = subprocess.run(
            ["git", "checkout", "-B", main_branch, f"origin/{main_branch}"],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if reset.returncode != 0:
            err = (reset.stderr or reset.stdout or "").strip()
            raise RuntimeError(
                f"Could not check out {main_branch} from origin/{main_branch}: {err}"
            )
    else:
        merge = subprocess.run(
            ["git", "merge", "--ff-only", f"origin/{main_branch}"],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if merge.returncode != 0:
            err = (merge.stderr or merge.stdout or "").strip()
            raise RuntimeError(
                f"Local {main_branch} is not a fast-forward of origin/{main_branch}. "
                f"Merge or rebase manually, then retry. {err}"
            )


def restore_branch(repo_root: Path, branch: str, main_branch: str) -> None:
    """Best-effort ``git checkout`` back to ``branch`` if it differs from ``main_branch``."""
    if branch == main_branch:
        return
    subprocess.run(
        ["git", "checkout", branch],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )


def fetch_origin_branch(
    repo_root: Path,
    main_branch: str,
    *,
    sink: SentryLogSink | None,
) -> None:
    """Fetch ``origin/{main_branch}`` without changing the current checkout."""
    if sink is not None:
        sink.set_step(f"fetch origin/{main_branch}")
        sink.log(f"Fetching origin/{main_branch} …")
    fetch = subprocess.run(
        ["git", "fetch", "origin", main_branch],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if fetch.returncode != 0:
        err = (fetch.stderr or fetch.stdout or "").strip()
        raise RuntimeError(f"git fetch origin {main_branch} failed: {err}")


def sentry_worktrees_dir(repo_root: Path) -> Path:
    """Ensure ``.grace/sentry/worktrees`` exists and return it."""
    d = repo_root / ".grace" / "sentry" / "worktrees"
    d.mkdir(parents=True, exist_ok=True)
    return d


def add_sentry_worktree(
    repo_root: Path,
    worktree_path: Path,
    new_branch: str,
    main_branch: str,
    *,
    sink: SentryLogSink | None,
) -> None:
    """Create a worktree at ``worktree_path`` with ``new_branch`` at ``origin/{main_branch}``."""
    if sink is not None:
        sink.set_step("git worktree add")
        sink.log(f"Adding worktree at {worktree_path} (branch {new_branch}) …")
    if worktree_path.exists():
        raise RuntimeError(f"worktree path already exists: {worktree_path}")
    p = subprocess.run(
        [
            "git",
            "worktree",
            "add",
            str(worktree_path),
            "-b",
            new_branch,
            f"origin/{main_branch}",
        ],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if p.returncode != 0:
        err = (p.stderr or p.stdout or "").strip()
        raise RuntimeError(f"git worktree add failed: {err}")


def remove_sentry_worktree(
    repo_root: Path,
    worktree_path: Path,
    branch_name: str | None,
) -> None:
    """Remove a linked worktree and best-effort delete the local branch name."""
    if not worktree_path.is_dir():
        return
    subprocess.run(
        ["git", "worktree", "remove", "--force", str(worktree_path)],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if branch_name:
        subprocess.run(
            ["git", "branch", "-D", branch_name],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
