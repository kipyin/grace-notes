"""One iteration and merge polling (macOS + real ``grace ci``)."""

from __future__ import annotations

import json
import random
import secrets
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from gracenotes_dev.sentry import github as gh_api
from gracenotes_dev.sentry.agent_client import (
    propose_pr_material_via_agent,
    propose_swift_fix_via_agent,
)
from gracenotes_dev.sentry.branch_ops import (
    add_sentry_worktree,
    current_branch,
    fetch_origin_branch,
    remove_sentry_worktree,
    restore_branch,
    sentry_worktrees_dir,
)
from gracenotes_dev.sentry.classify import classify_paths
from gracenotes_dev.sentry.git_remote import git_remote_owner_repo
from gracenotes_dev.sentry.llm_client import (
    api_key_from_env,
    propose_pr_material_http,
    propose_swift_fix,
)
from gracenotes_dev.sentry.log_sink import SentryLogSink
from gracenotes_dev.sentry.merge_poll import MergePollOutcome, merge_poll_once
from gracenotes_dev.sentry.pr_template import (
    PrMaterial,
    build_pr_body_from_material,
    fallback_pr_material,
    risk_label_for_touch,
)
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import append_event


def _emit(repo_root: Path, sink: SentryLogSink | None, event: dict) -> None:
    append_event(repo_root, event)
    if sink is None:
        return
    kind = str(event.get("kind", "?"))
    msg = str(event.get("message", ""))
    extra = {k: v for k, v in event.items() if k not in ("kind", "message")}
    line = f"[{kind}] {msg}"
    if extra:
        line += " " + " ".join(f"{k}={v}" for k, v in extra.items())
    sink.log(line)


def _git_output(repo_root: Path, *args: str, check: bool = True) -> str:
    p = subprocess.run(
        ["git", *args],
        cwd=repo_root,
        check=check,
        capture_output=True,
        text=True,
    )
    return p.stdout.strip()


def working_tree_clean(repo_root: Path) -> bool:
    out = _git_output(repo_root, "status", "--porcelain", check=False)
    return out == ""


def list_gracenotes_swift_files(repo_root: Path) -> list[str]:
    out = subprocess.run(
        ["git", "ls-files"],
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    paths: list[str] = []
    for line in out.splitlines():
        p = line.strip()
        if not p.endswith(".swift"):
            continue
        if not p.startswith("GraceNotes/"):
            continue
        paths.append(p)
    return paths


def list_gracenotes_swift_files_at_ref(repo_root: Path, ref: str) -> list[str]:
    """Paths under ``GraceNotes/`` at ``ref`` (e.g. ``origin/main``) without checkout."""
    p = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", ref],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if p.returncode != 0:
        err = (p.stderr or p.stdout or "").strip()
        msg = f"git ls-tree failed for ref {ref!r} (exit {p.returncode})"
        if err:
            msg = f"{msg}: {err}"
        raise RuntimeError(msg)
    paths: list[str] = []
    for line in p.stdout.splitlines():
        path = line.strip()
        if not path.endswith(".swift"):
            continue
        if not path.startswith("GraceNotes/"):
            continue
        paths.append(path)
    return paths


def run_grace_ci(repo_root: Path, settings: SentrySettings) -> bool:
    argv = [sys.executable, "-m", "gracenotes_dev", "ci"]
    if settings.ci_profile:
        argv.extend(["--profile", settings.ci_profile])
    proc = subprocess.run(argv, cwd=repo_root)
    return proc.returncode == 0


def _pick_random(paths: list[str]) -> str | None:
    if not paths:
        return None
    return random.choice(paths)


def _line_delta(old: str, new: str) -> dict[str, int]:
    o, n = old.splitlines(), new.splitlines()
    return {"old_lines": len(o), "new_lines": len(n), "delta_lines": len(n) - len(o)}


def _draft_pr_material(
    state_repo_root: Path,
    settings: SentrySettings,
    rel: str,
    old_content: str,
    new_content: str,
    sink: SentryLogSink | None,
    *,
    agent_repo_root: Path | None = None,
) -> PrMaterial:
    """
    LLM or second agent call for gh-style PR title/body; falls back to template on failure.

    ``state_repo_root`` is the primary clone (JSONL events). ``agent_repo_root`` is the cwd for
    the Cursor ``agent`` subprocess when fixes ran in a worktree; defaults to ``state_repo_root``.
    """
    agent_root = agent_repo_root or state_repo_root
    if sink is not None:
        sink.set_step("PR description (LLM/agent)")
        sink.log("Drafting PR title and body from the code change …")
    _emit(
        state_repo_root,
        sink,
        {
            "kind": "pr_draft_invoke",
            "path": rel,
            "message": "Starting PR description step (same provider family as the fix).",
        },
    )
    try:
        if settings.fix_provider == "cursor_agent":
            material = propose_pr_material_via_agent(
                repo_root=agent_root,
                agent_bin=settings.agent_bin,
                prefix_args=settings.agent_prefix_args,
                extra_args=settings.agent_extra_args,
                relative_path=rel,
                old_content=old_content,
                new_content=new_content,
                timeout_sec=settings.agent_timeout_sec,
            )
        else:
            base_url = settings.llm_base_url or "https://api.openai.com/v1"
            api_key = api_key_from_env(settings.llm_api_key_env)
            if not api_key:
                raise RuntimeError("no LLM API key for PR description step")
            material = propose_pr_material_http(
                base_url=base_url,
                api_key=api_key,
                model=settings.llm_model,
                relative_path=rel,
                old_content=old_content,
                new_content=new_content,
            )
    except (RuntimeError, ValueError, OSError) as exc:
        _emit(
            state_repo_root,
            sink,
            {
                "kind": "note",
                "message": f"PR description used fallback template: {exc}",
                "path": rel,
            },
        )
        material = fallback_pr_material(rel)
    _emit(
        state_repo_root,
        sink,
        {
            "kind": "pr_draft",
            "path": rel,
            "title": material.title,
            "headline": material.headline[:500],
            "user_impact": material.user_impact[:1200],
            "what_changed": material.what_changed[:1200],
            "verification": material.verification[:500],
        },
    )
    return material


def run_single_iteration(
    repo_root: Path,
    settings: SentrySettings,
    *,
    dry_run: bool,
    merge: bool,
    sink: SentryLogSink | None = None,
) -> int:
    """Return process exit code (0 ok)."""
    if sys.platform != "darwin":
        _emit(
            repo_root,
            sink,
            {"kind": "error", "message": "grace sentry requires macOS (iOS/Xcode toolchain)."},
        )
        return 2

    if not working_tree_clean(repo_root):
        _emit(
            repo_root,
            sink,
            {"kind": "skip", "message": "Working tree not clean; commit or stash before sentry."},
        )
        return 1

    start_branch = current_branch(repo_root)
    main_branch = settings.main_branch

    try:
        fetch_origin_branch(repo_root, main_branch, sink=sink)
    except RuntimeError as exc:
        _emit(repo_root, sink, {"kind": "error", "message": str(exc)})
        restore_branch(repo_root, start_branch, main_branch)
        return 1

    _emit(
        repo_root,
        sink,
        {
            "kind": "sync_main",
            "message": (
                f"Fetched origin/{main_branch}; primary checkout unchanged (was {start_branch})."
            ),
            "main_branch": main_branch,
            "previous_branch": start_branch,
        },
    )

    if merge and not dry_run:
        remote = git_remote_owner_repo(repo_root)
        if remote:
            owner, gh_repo = remote
            reconcile_open_sentry_prs(
                repo_root,
                settings,
                owner,
                gh_repo,
                main_branch,
                sink=sink,
            )

    ref = f"origin/{main_branch}"
    if dry_run:
        try:
            paths = list_gracenotes_swift_files_at_ref(repo_root, ref)
        except RuntimeError as exc:
            _emit(repo_root, sink, {"kind": "error", "message": str(exc)})
            return 1
        rel = _pick_random(paths)
        if not rel:
            if sink is not None:
                sink.set_step("pick file")
            _emit(
                repo_root,
                sink,
                {"kind": "skip", "message": "No GraceNotes Swift files found."},
            )
            return 1
        if sink is not None:
            sink.set_step("pick file")
            sink.set_target_file(rel)
        mode = settings.fix_provider
        _emit(
            repo_root,
            sink,
            {
                "kind": "dry_run",
                "message": (
                    f"Would run fix on {rel} from {main_branch} tip (provider={mode}); "
                    "would draft PR via same provider after a change."
                ),
                "path": rel,
            },
        )
        return 0

    try:
        paths = list_gracenotes_swift_files_at_ref(repo_root, ref)
    except RuntimeError as exc:
        _emit(repo_root, sink, {"kind": "error", "message": str(exc)})
        return 1
    rel = _pick_random(paths)
    if not rel:
        if sink is not None:
            sink.set_step("pick file")
        _emit(repo_root, sink, {"kind": "skip", "message": "No GraceNotes Swift files found."})
        return 1

    if sink is not None:
        sink.set_step("pick file")
        sink.set_target_file(rel)
        sink.set_branch(None)
        sink.set_pr(None)

    now = datetime.now(timezone.utc)
    ts = now.strftime("%Y%m%d-%H%M%S")
    unique = f"{ts}-{secrets.token_hex(3)}"
    branch = f"sentry/auto-{unique}"
    worktree_path = sentry_worktrees_dir(repo_root) / f"wt-{unique}"
    work_branch = branch

    try:
        try:
            add_sentry_worktree(repo_root, worktree_path, branch, main_branch, sink=sink)
        except RuntimeError as exc:
            _emit(repo_root, sink, {"kind": "error", "message": str(exc)})
            return 1
        work_root = worktree_path

        file_path = work_root / rel
        content = file_path.read_text(encoding="utf-8")

        _emit(
            repo_root,
            sink,
            {
                "kind": "fix_invoke",
                "path": rel,
                "provider": settings.fix_provider,
                "message": (
                    "Invoking fix provider (cursor agent or HTTP LLM) with the Swift file from "
                    f"{main_branch} (sentry worktree)."
                ),
            },
        )
        if settings.fix_provider == "cursor_agent":
            if sink is not None:
                sink.set_step("fix (cursor agent)")
                sink.log("Invoking local `agent` CLI for Swift fix (see events.jsonl: fix_invoke).")
            try:
                new_src = propose_swift_fix_via_agent(
                    repo_root=work_root,
                    agent_bin=settings.agent_bin,
                    prefix_args=settings.agent_prefix_args,
                    extra_args=settings.agent_extra_args,
                    relative_path=rel,
                    file_content=content,
                    timeout_sec=settings.agent_timeout_sec,
                )
            except (FileNotFoundError, OSError, RuntimeError) as exc:
                _emit(repo_root, sink, {"kind": "error", "message": str(exc), "path": rel})
                return 1
        else:
            if sink is not None:
                sink.set_step("fix (LLM)")
                sink.log("Invoking HTTP LLM for Swift fix (see events.jsonl: fix_invoke).")
            base_url = settings.llm_base_url or "https://api.openai.com/v1"
            api_key = api_key_from_env(settings.llm_api_key_env)
            if not api_key:
                _emit(
                    repo_root,
                    sink,
                    {
                        "kind": "error",
                        "message": (
                            f"Set {settings.llm_api_key_env} (SENTRY_LLM_API_KEY_ENV) "
                            "for LLM access, or SENTRY_FIX_PROVIDER=cursor_agent for local `agent`."
                        ),
                    },
                )
                return 2
            try:
                new_src = propose_swift_fix(
                    base_url=base_url,
                    api_key=api_key,
                    model=settings.llm_model,
                    relative_path=rel,
                    file_content=content,
                )
            except RuntimeError as exc:
                _emit(repo_root, sink, {"kind": "error", "message": str(exc), "path": rel})
                return 1

        if not new_src.strip():
            _emit(
                repo_root,
                sink,
                {"kind": "skip", "message": "Fix step returned NO_CHANGE", "path": rel},
            )
            return 0

        stats = _line_delta(content, new_src)
        _emit(
            repo_root,
            sink,
            {
                "kind": "fix_result",
                "path": rel,
                "message": "Fix provider returned new Swift source (see pr_draft for narrative).",
                **stats,
            },
        )

        material = _draft_pr_material(
            repo_root,
            settings,
            rel,
            content,
            new_src,
            sink,
            agent_repo_root=work_root,
        )

        touch = classify_paths([rel])
        title = material.title
        body = build_pr_body_from_material(
            material,
            risk=risk_label_for_touch(touch),
            touch=touch,
            needs_human_line=False,
            approval_phrase=settings.approval_phrase,
        )

        if sink is not None:
            sink.set_step("commit & branch")
            sink.set_branch(branch)

        try:
            file_path.write_text(new_src, encoding="utf-8")
            _git_output(work_root, "add", rel)
            _git_output(work_root, "commit", "-m", f"sentry: refine {rel}")
        except subprocess.CalledProcessError as exc:
            _emit(repo_root, sink, {"kind": "error", "message": f"git commit failed: {exc}"})
            return 1

        if sink is not None:
            sink.set_step("grace ci")
            sink.log("Running `grace ci` (this may take several minutes)…")

        if not run_grace_ci(work_root, settings):
            _emit(
                repo_root,
                sink,
                {
                    "kind": "error",
                    "message": "grace ci failed; dropping sentry worktree",
                    "branch": branch,
                },
            )
            return 1

        if sink is not None:
            sink.set_step("git push")

        try:
            _git_output(work_root, "push", "-u", "origin", branch)
        except subprocess.CalledProcessError as exc:
            _emit(repo_root, sink, {"kind": "error", "message": f"git push failed: {exc}"})
            return 1

        if sink is not None:
            sink.set_step("create PR")

        proc = subprocess.run(
            [
                "gh",
                "pr",
                "create",
                "--title",
                title,
                "--body",
                body,
                "--base",
                main_branch,
                "--label",
                "no-ci",
            ],
            cwd=work_root,
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            _emit(
                repo_root,
                sink,
                {
                    "kind": "error",
                    "message": f"gh pr create failed: {proc.stderr or proc.stdout}",
                    "branch": branch,
                },
            )
            return 1

        view = subprocess.run(
            ["gh", "pr", "view", "--json", "number,url"],
            cwd=work_root,
            capture_output=True,
            text=True,
        )
        if view.returncode != 0:
            _emit(
                repo_root,
                sink,
                {
                    "kind": "error",
                    "message": (
                        "gh pr create succeeded but could not read PR metadata: "
                        f"{view.stderr or view.stdout}"
                    ),
                    "branch": branch,
                },
            )
            return 1

        pr_meta = json.loads(view.stdout)
        pr_number = int(pr_meta["number"])
        pr_url = pr_meta.get("url", "")
        if sink is not None:
            sink.set_pr(pr_url or f"#{pr_number}")
        _emit(
            repo_root,
            sink,
            {
                "kind": "pr_created",
                "message": pr_url,
                "branch": branch,
                "pr": pr_number,
                "touch": touch.value,
                "pr_title": title,
            },
        )

        cursor_ids = {x.strip().lower() for x in settings.cursor_reviewer_logins if x.strip()}
        reviewer_ids = {x.strip().lower() for x in settings.reviewer_logins if x.strip()}
        post_review = (
            settings.cursor_post_review_trigger
            and bool(cursor_ids & reviewer_ids)
        )
        if post_review:
            if gh_api.pr_comment(repo_root, pr_number, "/review"):
                _emit(
                    repo_root,
                    sink,
                    {
                        "kind": "note",
                        "message": f"Posted `/review` on PR #{pr_number} (Cursor reviewer).",
                        "pr": pr_number,
                    },
                )
            else:
                _emit(
                    repo_root,
                    sink,
                    {
                        "kind": "error",
                        "message": f"Could not post `/review` comment on PR #{pr_number}.",
                        "pr": pr_number,
                    },
                )

        if not merge:
            _emit(repo_root, sink, {"kind": "note", "message": "Skipping merge (--no-merge)."})
            return 0

        remote = git_remote_owner_repo(repo_root)
        if not remote:
            _emit(
                repo_root,
                sink,
                {"kind": "error", "message": "Could not parse origin remote (GitHub)."},
            )
            return 1

        owner, repo = remote
        allow = set(settings.approval_users)
        outcome = merge_poll_once(
            repo_root,
            settings,
            owner,
            repo,
            pr_number,
            allow,
            main_branch,
            sink=sink,
            git_cwd=work_root,
        )
        if outcome == MergePollOutcome.MERGED:
            _emit(repo_root, sink, {"kind": "merged", "message": f"PR #{pr_number} squash-merged"})
        else:
            _emit(
                repo_root,
                sink,
                {
                    "kind": "note",
                    "message": (
                        f"Merge gates not ready for PR #{pr_number} (or will retry in sweep); "
                        "not blocking sentry."
                    ),
                },
            )

        try:
            _git_output(repo_root, "fetch", "origin", main_branch)
        except subprocess.CalledProcessError:
            pass

        return 0
    finally:
        if worktree_path.is_dir():
            remove_sentry_worktree(repo_root, worktree_path, work_branch)


def reconcile_open_sentry_prs(
    repo_root: Path,
    settings: SentrySettings,
    owner: str,
    gh_repo: str,
    main_branch: str,
    *,
    sink: SentryLogSink | None = None,
) -> None:
    """
    Merge or repair open PRs whose head matches ``sentry_branch_prefix`` (ascending PR #).

    Runs after syncing ``main`` and before picking a new file so approved PRs are not
    starved behind new exploratory work.
    """
    pr_numbers = gh_api.list_open_sentry_pr_numbers(
        repo_root,
        main_branch,
        settings.sentry_branch_prefix,
    )
    if not pr_numbers:
        return
    _emit(
        repo_root,
        sink,
        {
            "kind": "sweep_reconcile",
            "message": f"Sweeping {len(pr_numbers)} open sentry PR(s) (ascending #).",
            "prs": pr_numbers,
        },
    )
    allow = set(settings.approval_users)
    poll_interval = 30.0
    queue: list[int] = sorted(pr_numbers)

    while queue:
        pr_number = queue[0]
        pr_deadline = time.monotonic() + float(settings.merge_sweep_budget_seconds)
        announced = False
        finished = False
        while time.monotonic() < pr_deadline and not finished:
            if not announced:
                announced = True
                paths = gh_api.pr_changed_file_paths(repo_root, pr_number)
                touch = classify_paths(paths)
                _emit(
                    repo_root,
                    sink,
                    {
                        "kind": "sweep_pr",
                        "message": f"Sweep PR #{pr_number}",
                        "pr": pr_number,
                        "touch": touch.value,
                    },
                )
            while True:
                outcome = merge_poll_once(
                    repo_root,
                    settings,
                    owner,
                    gh_repo,
                    pr_number,
                    allow,
                    main_branch,
                    sink=sink,
                )
                if outcome == MergePollOutcome.MERGED:
                    _emit(
                        repo_root,
                        sink,
                        {
                            "kind": "sweep_merged",
                            "message": f"PR #{pr_number} squash-merged",
                            "pr": pr_number,
                        },
                    )
                    queue.pop(0)
                    finished = True
                    break
                if outcome == MergePollOutcome.TERMINAL_FAIL:
                    _emit(
                        repo_root,
                        sink,
                        {
                            "kind": "sweep_merge_fail",
                            "message": f"PR #{pr_number}: merge attempt failed",
                            "pr": pr_number,
                        },
                    )
                    queue.pop(0)
                    finished = True
                    break
                if outcome == MergePollOutcome.CONTINUE_LOOP:
                    continue
                break

            if finished:
                break

            try:
                _git_output(repo_root, "fetch", "origin", main_branch)
            except subprocess.CalledProcessError:
                pass

            if not queue:
                break
            time.sleep(min(poll_interval, pr_deadline - time.monotonic()))

        if finished:
            continue
        if queue and queue[0] == pr_number:
            queue.append(queue.pop(0))
            _emit(
                repo_root,
                sink,
                {
                    "kind": "sweep_rotate",
                    "message": (
                        f"PR #{pr_number}: merge sweep budget elapsed; rotating to next open PR."
                    ),
                    "pr": pr_number,
                },
            )
