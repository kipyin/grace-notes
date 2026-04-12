"""Apply Cursor PR review feedback using the local ``agent`` CLI (macOS)."""

from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

from gracenotes_dev.sentry import github as gh_api
from gracenotes_dev.sentry.agent_client import address_cursor_feedback_file_via_agent
from gracenotes_dev.sentry.branch_ops import remove_sentry_worktree, sentry_worktrees_dir
from gracenotes_dev.sentry.log_sink import SentryLogSink
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import append_event


def _cooldown_path(repo_root: Path) -> Path:
    return repo_root / ".grace" / "sentry" / "cursor_fix_last.json"


def _pushback_marker_path(repo_root: Path, pr_number: int) -> Path:
    return repo_root / ".grace" / "sentry" / f"review_pushback_{pr_number}.txt"


def _maybe_post_review_pushback(repo_root: Path, pr_number: int, body: str) -> None:
    path = _pushback_marker_path(repo_root, pr_number)
    if path.is_file():
        return
    if gh_api.pr_comment(repo_root, pr_number, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("1\n", encoding="utf-8")


def _prepare_review_fix_worktree(
    repo_root: Path,
    pr_number: int,
    head_ref: str,
) -> tuple[Path, str]:
    worktree_path = sentry_worktrees_dir(repo_root) / f"review-fix-{pr_number}"
    if worktree_path.is_dir():
        remove_sentry_worktree(repo_root, worktree_path, None)
    local_branch = f"sentry-review-fix-{pr_number}"
    fetch = subprocess.run(
        ["git", "fetch", "origin", head_ref],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if fetch.returncode != 0:
        raise RuntimeError((fetch.stderr or fetch.stdout or "git fetch failed").strip())
    wt = subprocess.run(
        [
            "git",
            "worktree",
            "add",
            str(worktree_path),
            "-b",
            local_branch,
            f"origin/{head_ref}",
        ],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if wt.returncode != 0:
        raise RuntimeError((wt.stderr or wt.stdout or "git worktree add failed").strip())
    return worktree_path, local_branch


def cursor_fix_should_attempt(
    repo_root: Path,
    pr_number: int,
    cooldown_sec: int,
) -> bool:
    """True if we may run another agent pass for this PR (cooldown since last attempt)."""
    if cooldown_sec <= 0:
        return True
    path = _cooldown_path(repo_root)
    if not path.is_file():
        return True
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return True
    if not isinstance(raw, dict):
        return True
    key = str(pr_number)
    last = raw.get(key)
    if last is None:
        return True
    try:
        t = float(last)
    except (TypeError, ValueError):
        return True
    return (time.time() - t) >= float(cooldown_sec)


def cursor_fix_mark_attempt(repo_root: Path, pr_number: int) -> None:
    """Record wall time of a fix attempt (used for cooldown across restarts)."""
    path = _cooldown_path(repo_root)
    path.parent.mkdir(parents=True, exist_ok=True)
    data: dict[str, float] = {}
    if path.is_file():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                for k, v in loaded.items():
                    try:
                        data[str(k)] = float(v)
                    except (TypeError, ValueError):
                        continue
        except (OSError, json.JSONDecodeError):
            pass
    data[str(pr_number)] = time.time()
    path.write_text(json.dumps(data, indent=0) + "\n", encoding="utf-8")


def _run_grace_ci(work_root: Path, settings: SentrySettings) -> bool:
    argv = [sys.executable, "-m", "gracenotes_dev", "ci"]
    if settings.ci_profile:
        argv.extend(["--profile", settings.ci_profile])
    proc = subprocess.run(argv, cwd=work_root)
    return proc.returncode == 0


def try_address_cursor_review_with_agent(
    repo_root: Path,
    settings: SentrySettings,
    owner: str,
    repo: str,
    pr_number: int,
    main_branch: str,
    *,
    feedback_text: str,
    sink: SentryLogSink | None = None,
    git_cwd: Path | None = None,
) -> bool:
    """
    Check out the PR head, run ``agent`` on changed ``GraceNotes/**/*.swift`` files, ``grace ci``,
    commit, push. Returns True if push succeeded so merge gates can be re-checked.

    When ``git_cwd`` is ``None``, uses a dedicated worktree under ``.grace/sentry/worktrees/``
    so the primary checkout stays untouched.
    """
    if settings.fix_provider != "cursor_agent":
        return False
    ft = feedback_text.strip()
    if not ft:
        append_event(
            repo_root,
            {
                "kind": "cursor_review_fix_skip",
                "message": "No review feedback text to apply.",
                "pr": pr_number,
            },
        )
        return False

    append_event(
        repo_root,
        {
            "kind": "cursor_review_fix_attempt",
            "message": f"Addressing PR review feedback on PR #{pr_number}",
            "pr": pr_number,
        },
    )
    if sink is not None:
        sink.set_step("address PR review (agent)")
        sink.log(f"PR #{pr_number}: applying review feedback via agent …")

    worktree_path: Path | None = None
    worktree_branch: str | None = None
    git_root = git_cwd or repo_root

    fetch_main = subprocess.run(
        ["git", "fetch", "origin", main_branch],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if fetch_main.returncode != 0:
        append_event(
            repo_root,
            {
                "kind": "cursor_review_fix_error",
                "message": (fetch_main.stderr or fetch_main.stdout or "").strip(),
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
                "kind": "cursor_review_fix_error",
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
            {"kind": "cursor_review_fix_error", "message": f"headRefName: {exc}", "pr": pr_number},
        )
        return False

    if git_cwd is None:
        try:
            worktree_path, worktree_branch = _prepare_review_fix_worktree(
                repo_root,
                pr_number,
                str(head_ref),
            )
            git_root = worktree_path
        except RuntimeError as exc:
            append_event(
                repo_root,
                {
                    "kind": "cursor_review_fix_error",
                    "message": str(exc),
                    "pr": pr_number,
                },
            )
            return False
    else:
        fetch = subprocess.run(
            ["git", "fetch", "origin", main_branch],
            cwd=git_root,
            capture_output=True,
            text=True,
        )
        if fetch.returncode != 0:
            append_event(
                repo_root,
                {
                    "kind": "cursor_review_fix_error",
                    "message": (fetch.stderr or fetch.stdout or "").strip(),
                    "pr": pr_number,
                },
            )
            return False

        co = subprocess.run(
            ["git", "checkout", head_ref],
            cwd=git_root,
            capture_output=True,
            text=True,
        )
        if co.returncode != 0:
            append_event(
                repo_root,
                {
                    "kind": "cursor_review_fix_error",
                    "message": (co.stderr or co.stdout or "").strip(),
                    "pr": pr_number,
                },
            )
            return False

    try:
        return _try_address_review_in_git_root(
            repo_root=repo_root,
            settings=settings,
            pr_number=pr_number,
            git_root=git_root,
            feedback_text=ft,
            sink=sink,
        )
    finally:
        if worktree_path is not None:
            remove_sentry_worktree(repo_root, worktree_path, worktree_branch)


def _try_address_review_in_git_root(
    repo_root: Path,
    settings: SentrySettings,
    pr_number: int,
    git_root: Path,
    *,
    feedback_text: str,
    sink: SentryLogSink | None,
) -> bool:
    paths = [
        p
        for p in gh_api.pr_changed_file_paths(repo_root, pr_number)
        if p.endswith(".swift") and p.startswith("GraceNotes/")
    ]
    if not paths:
        append_event(
            repo_root,
            {
                "kind": "cursor_review_fix_skip",
                "message": "No GraceNotes Swift files in PR diff to edit.",
                "pr": pr_number,
            },
        )
        return False

    max_files = 15
    paths = paths[:max_files]
    changed_any = False
    try:
        for rel in paths:
            fp = git_root / rel
            if not fp.is_file():
                continue
            raw = fp.read_text(encoding="utf-8")
            new_src = address_cursor_feedback_file_via_agent(
                repo_root=git_root,
                agent_bin=settings.agent_bin,
                prefix_args=settings.agent_prefix_args,
                extra_args=settings.agent_extra_args,
                relative_path=rel,
                file_content=raw,
                feedback_text=feedback_text,
                timeout_sec=settings.agent_timeout_sec,
            )
            if not new_src.strip():
                continue
            if new_src == raw:
                continue
            fp.write_text(new_src, encoding="utf-8")
            subprocess.run(["git", "add", rel], cwd=git_root, capture_output=True, text=True)
            changed_any = True
            append_event(
                repo_root,
                {
                    "kind": "cursor_review_fix_file",
                    "message": f"Updated {rel} from review feedback",
                    "pr": pr_number,
                },
            )

        if not changed_any:
            append_event(
                repo_root,
                {
                    "kind": "cursor_review_fix_skip",
                    "message": "Agent returned NO_CHANGE for all files.",
                    "pr": pr_number,
                },
            )
            _maybe_post_review_pushback(
                repo_root,
                pr_number,
                (
                    "Sentry: could not apply automated fixes for this review feedback "
                    "(no substantive source changes produced). Merge may still proceed when CI is "
                    "green and reviews are addressed, or via the configured approval override."
                ),
            )
            return False

        if not _run_grace_ci(git_root, settings):
            append_event(
                repo_root,
                {
                    "kind": "cursor_review_fix_error",
                    "message": "grace ci failed after review feedback edits",
                    "pr": pr_number,
                },
            )
            if sink is not None:
                sink.log(f"PR #{pr_number}: grace ci failed after review fixes; not pushing.")
            subprocess.run(["git", "reset", "--hard", "HEAD"], cwd=git_root, capture_output=True)
            _maybe_post_review_pushback(
                repo_root,
                pr_number,
                "Sentry: automated edits failed `grace ci` after review feedback; changes were not "
                "pushed. Please address manually or use the approval override if appropriate.",
            )
            return False

        commit = subprocess.run(
            ["git", "commit", "-m", "sentry: address PR review feedback"],
            cwd=git_root,
            capture_output=True,
            text=True,
        )
        if commit.returncode != 0:
            err = (commit.stderr or commit.stdout or "").strip()
            append_event(
                repo_root,
                {
                    "kind": "cursor_review_fix_error",
                    "message": f"git commit failed: {err}",
                    "pr": pr_number,
                },
            )
            return False

        push = subprocess.run(
            ["git", "push", "origin", "HEAD"],
            cwd=git_root,
            capture_output=True,
            text=True,
        )
        if push.returncode != 0:
            append_event(
                repo_root,
                {
                    "kind": "cursor_review_fix_error",
                    "message": (push.stderr or push.stdout or "").strip(),
                    "pr": pr_number,
                },
            )
            return False

        append_event(
            repo_root,
            {
                "kind": "cursor_review_fix_pushed",
                "message": f"Pushed review-feedback commit for PR #{pr_number}",
                "pr": pr_number,
            },
        )
        if sink is not None:
            sink.log(f"PR #{pr_number}: review feedback fixes pushed.")
        return True
    except (OSError, RuntimeError, UnicodeError) as exc:
        append_event(
            repo_root,
            {
                "kind": "cursor_review_fix_error",
                "message": str(exc),
                "pr": pr_number,
            },
        )
        if sink is not None:
            sink.log(f"PR #{pr_number}: review feedback fix failed: {exc}")
        return False
