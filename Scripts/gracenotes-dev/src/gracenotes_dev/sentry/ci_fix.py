"""Repair red GitHub PR checks using local ``grace ci`` + Cursor ``agent`` (macOS)."""

from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

from gracenotes_dev.sentry import github as gh_api
from gracenotes_dev.sentry.agent_client import address_ci_failure_file_via_agent
from gracenotes_dev.sentry.branch_ops import remove_sentry_worktree, sentry_worktrees_dir
from gracenotes_dev.sentry.log_sink import SentryLogSink
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import append_event
from gracenotes_dev.sentry.text_compare import text_effectively_same


def _ci_fix_cooldown_path(repo_root: Path) -> Path:
    return repo_root / ".grace" / "sentry" / "ci_fix_last.json"


def _ci_pushback_marker_path(repo_root: Path, pr_number: int) -> Path:
    return repo_root / ".grace" / "sentry" / f"ci_pushback_{pr_number}.txt"


def _maybe_post_ci_pushback(repo_root: Path, pr_number: int, body: str) -> None:
    path = _ci_pushback_marker_path(repo_root, pr_number)
    if path.is_file():
        return
    if gh_api.pr_comment(repo_root, pr_number, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("1\n", encoding="utf-8")


def _prepare_ci_fix_worktree(
    repo_root: Path,
    pr_number: int,
    head_ref: str,
) -> tuple[Path, str]:
    worktree_path = sentry_worktrees_dir(repo_root) / f"ci-fix-{pr_number}"
    local_branch = f"sentry-ci-fix-{pr_number}"
    if worktree_path.is_dir():
        remove_sentry_worktree(repo_root, worktree_path, local_branch)
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


def ci_fix_should_attempt(
    repo_root: Path,
    pr_number: int,
    cooldown_sec: int,
) -> bool:
    """True if we may run another CI-fix pass for this PR (cooldown since last attempt)."""
    if cooldown_sec <= 0:
        return True
    path = _ci_fix_cooldown_path(repo_root)
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


def ci_fix_mark_attempt(repo_root: Path, pr_number: int) -> None:
    """Record wall time of a CI-fix attempt (used for cooldown across restarts)."""
    path = _ci_fix_cooldown_path(repo_root)
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


def _run_grace_ci_capture(work_root: Path, settings: SentrySettings) -> tuple[bool, str]:
    argv = [sys.executable, "-m", "gracenotes_dev", "ci"]
    if settings.ci_profile:
        argv.extend(["--profile", settings.ci_profile])
    proc = subprocess.run(argv, cwd=work_root, capture_output=True, text=True)
    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    return proc.returncode == 0, combined


def _is_ci_fix_candidate(relative_path: str) -> bool:
    if relative_path.endswith(".swift") and relative_path.startswith("GraceNotes/"):
        return True
    if relative_path.endswith(".py") and relative_path.startswith("Scripts/gracenotes-dev/"):
        return True
    return False


def _git_has_uncommitted_changes(git_root: Path) -> bool:
    st = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=git_root,
        capture_output=True,
        text=True,
    )
    if st.returncode != 0:
        return False
    return bool((st.stdout or "").strip())


def _git_push_origin_head_to_branch(
    git_root: Path, remote_branch: str
) -> subprocess.CompletedProcess[str]:
    """
    Push ``HEAD`` to ``origin``'s branch ``remote_branch`` (GitHub PR ``headRefName``).

    Sentry worktrees use local names like ``sentry-review-fix-N``; a plain ``git push origin HEAD``
    would update the wrong remote branch without this refspec.
    """
    refspec = f"HEAD:refs/heads/{remote_branch}"
    return subprocess.run(
        ["git", "push", "origin", refspec],
        cwd=git_root,
        capture_output=True,
        text=True,
    )


def try_fix_ci_with_agent(
    repo_root: Path,
    settings: SentrySettings,
    pr_number: int,
    main_branch: str,
    *,
    sink: SentryLogSink | None = None,
    git_cwd: Path | None = None,
) -> bool:
    """
    Check out the PR head, loop ``grace ci`` + ``agent`` on candidate PR files until local CI
    passes, then commit and push. Returns True if push succeeded so merge gates can be re-checked.
    """
    if settings.fix_provider != "cursor_agent":
        return False

    append_event(
        repo_root,
        {
            "kind": "ci_fix_attempt",
            "message": f"Addressing failing CI on PR #{pr_number}",
            "pr": pr_number,
        },
    )
    if sink is not None:
        sink.set_step("fix CI (agent)")
        sink.log(f"PR #{pr_number}: attempting local grace ci + agent …")

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
                "kind": "ci_fix_error",
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
                "kind": "ci_fix_error",
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
            {"kind": "ci_fix_error", "message": f"headRefName: {exc}", "pr": pr_number},
        )
        return False

    if git_cwd is None:
        try:
            worktree_path, worktree_branch = _prepare_ci_fix_worktree(
                repo_root,
                pr_number,
                str(head_ref),
            )
            git_root = worktree_path
        except RuntimeError as exc:
            append_event(
                repo_root,
                {
                    "kind": "ci_fix_error",
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
                    "kind": "ci_fix_error",
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
                    "kind": "ci_fix_error",
                    "message": (co.stderr or co.stdout or "").strip(),
                    "pr": pr_number,
                },
            )
            return False

    try:
        return _try_fix_ci_in_git_root(
            repo_root=repo_root,
            settings=settings,
            pr_number=pr_number,
            git_root=git_root,
            push_remote_branch=str(head_ref),
            sink=sink,
        )
    finally:
        if worktree_path is not None:
            remove_sentry_worktree(repo_root, worktree_path, worktree_branch)


def _push_git_head(
    repo_root: Path,
    git_root: Path,
    pr_number: int,
    push_remote_branch: str,
    *,
    sink: SentryLogSink | None,
) -> bool:
    """Push ``HEAD`` to ``origin``'s PR head branch (e.g. after local ``grace ci`` passed)."""
    push = _git_push_origin_head_to_branch(git_root, push_remote_branch)
    if push.returncode != 0:
        append_event(
            repo_root,
            {
                "kind": "ci_fix_error",
                "message": (push.stderr or push.stdout or "").strip(),
                "pr": pr_number,
            },
        )
        return False
    append_event(
        repo_root,
        {
            "kind": "ci_fix_pushed",
            "message": f"Pushed branch for PR #{pr_number} after green local grace ci",
            "pr": pr_number,
        },
    )
    if sink is not None:
        sink.log(f"PR #{pr_number}: pushed after green local grace ci.")
    return True


def run_ci_recovery_loop_in_worktree(
    repo_root: Path,
    settings: SentrySettings,
    pr_number: int,
    git_root: Path,
    head_ref: str,
    *,
    sink: SentryLogSink | None,
) -> bool:
    """
    Loop ``grace ci`` + CI agent until local CI passes, then ``git push``.

    Use after a **local commit** exists in ``git_root`` (e.g. review feedback applied) so a
    green run with a clean tree still pushes that commit.

    ``head_ref`` is the PR's ``headRefName``; pushes target ``origin``'s branch of that name.
    """
    return _try_fix_ci_in_git_root(
        repo_root,
        settings,
        pr_number,
        git_root,
        push_remote_branch=head_ref,
        sink=sink,
        push_when_ci_green_clean=True,
    )


def _try_fix_ci_in_git_root(
    repo_root: Path,
    settings: SentrySettings,
    pr_number: int,
    git_root: Path,
    push_remote_branch: str,
    *,
    sink: SentryLogSink | None,
    push_when_ci_green_clean: bool = False,
) -> bool:
    paths = [
        p for p in gh_api.pr_changed_file_paths(repo_root, pr_number) if _is_ci_fix_candidate(p)
    ]
    if not paths:
        append_event(
            repo_root,
            {
                "kind": "ci_fix_skip",
                "message": "No GraceNotes Swift or gracenotes-dev Python files in PR diff to edit.",
                "pr": pr_number,
            },
        )
        return False

    max_files = 25
    paths = paths[:max_files]
    max_rounds = settings.ci_fix_max_rounds_per_poll

    def _commit_and_push() -> bool:
        commit = subprocess.run(
            ["git", "commit", "-m", "sentry: fix CI failures"],
            cwd=git_root,
            capture_output=True,
            text=True,
        )
        if commit.returncode != 0:
            err = (commit.stderr or commit.stdout or "").strip()
            append_event(
                repo_root,
                {
                    "kind": "ci_fix_error",
                    "message": f"git commit failed: {err}",
                    "pr": pr_number,
                },
            )
            return False

        push = _git_push_origin_head_to_branch(git_root, push_remote_branch)
        if push.returncode != 0:
            append_event(
                repo_root,
                {
                    "kind": "ci_fix_error",
                    "message": (push.stderr or push.stdout or "").strip(),
                    "pr": pr_number,
                },
            )
            return False

        append_event(
            repo_root,
            {
                "kind": "ci_fix_pushed",
                "message": f"Pushed CI fix commit for PR #{pr_number}",
                "pr": pr_number,
            },
        )
        if sink is not None:
            sink.log(f"PR #{pr_number}: CI fix pushed.")
        return True

    def _apply_agent_for_log(ci_log: str) -> bool:
        changed_any = False
        for rel in paths:
            fp = git_root / rel
            if not fp.is_file():
                continue
            try:
                raw = fp.read_text(encoding="utf-8")
            except OSError:
                continue
            try:
                new_src = address_ci_failure_file_via_agent(
                    repo_root=git_root,
                    agent_bin=settings.agent_bin,
                    prefix_args=settings.agent_prefix_args,
                    extra_args=settings.agent_extra_args,
                    relative_path=rel,
                    file_content=raw,
                    ci_log_text=ci_log,
                    timeout_sec=settings.agent_timeout_sec,
                )
            except (OSError, RuntimeError) as exc:
                append_event(
                    repo_root,
                    {
                        "kind": "ci_fix_error",
                        "message": f"{rel}: {exc}",
                        "pr": pr_number,
                    },
                )
                continue
            if not new_src.strip():
                continue
            if text_effectively_same(new_src, raw):
                continue
            fp.write_text(new_src, encoding="utf-8")
            subprocess.run(["git", "add", rel], cwd=git_root, capture_output=True, text=True)
            changed_any = True
            append_event(
                repo_root,
                {
                    "kind": "ci_fix_file",
                    "message": f"Updated {rel} from CI output",
                    "pr": pr_number,
                },
            )
        return changed_any

    for round_idx in range(max_rounds):
        append_event(
            repo_root,
            {
                "kind": "ci_fix_round",
                "message": f"CI fix round {round_idx + 1}/{max_rounds} for PR #{pr_number}",
                "pr": pr_number,
                "round": round_idx + 1,
            },
        )
        ok, ci_log = _run_grace_ci_capture(git_root, settings)
        if ok:
            if _git_has_uncommitted_changes(git_root):
                return _commit_and_push()
            if push_when_ci_green_clean:
                return _push_git_head(
                    repo_root,
                    git_root,
                    pr_number,
                    push_remote_branch,
                    sink=sink,
                )
            append_event(
                repo_root,
                {
                    "kind": "ci_fix_skip",
                    "message": "Local grace ci passed with a clean tree; nothing to push.",
                    "pr": pr_number,
                },
            )
            return False

        if not _apply_agent_for_log(ci_log):
            append_event(
                repo_root,
                {
                    "kind": "ci_fix_skip",
                    "message": (
                        "No automated edits produced for CI failure (or agent returned NO_CHANGE)."
                    ),
                    "pr": pr_number,
                },
            )
            _maybe_post_ci_pushback(
                repo_root,
                pr_number,
                "Sentry: could not produce automated edits for the failing CI run from the "
                "current PR file set (Swift under GraceNotes/ or Python under "
                "Scripts/gracenotes-dev/). "
                "Please fix manually or merge when CI is green.",
            )
            subprocess.run(["git", "reset", "--hard", "HEAD"], cwd=git_root, capture_output=True)
            return False

    append_event(
        repo_root,
        {
            "kind": "ci_fix_error",
            "message": (
                f"Exceeded ci_fix_max_rounds_per_poll ({max_rounds}) without a green local ci."
            ),
            "pr": pr_number,
        },
    )
    _maybe_post_ci_pushback(
        repo_root,
        pr_number,
        "Sentry: automated CI fix exceeded the configured round limit without a green local "
        "`grace ci`. Please address manually.",
    )
    subprocess.run(["git", "reset", "--hard", "HEAD"], cwd=git_root, capture_output=True)
    return False
