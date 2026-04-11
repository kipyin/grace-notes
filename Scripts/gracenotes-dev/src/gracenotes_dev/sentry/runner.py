"""One iteration and merge polling (macOS + real ``grace ci``)."""

from __future__ import annotations

import json
import random
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
from gracenotes_dev.sentry.branch_ops import current_branch, restore_branch, sync_main_from_origin
from gracenotes_dev.sentry.classify import classify_paths, is_high_touch
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


def _cleanup_failed_branch(repo_root: Path, branch: str, main_branch: str = "main") -> None:
    try:
        _git_output(repo_root, "checkout", main_branch)
    except subprocess.CalledProcessError:
        pass
    try:
        _git_output(repo_root, "branch", "-D", branch)
    except subprocess.CalledProcessError:
        pass


def _line_delta(old: str, new: str) -> dict[str, int]:
    o, n = old.splitlines(), new.splitlines()
    return {"old_lines": len(o), "new_lines": len(n), "delta_lines": len(n) - len(o)}


def _draft_pr_material(
    repo_root: Path,
    settings: SentrySettings,
    rel: str,
    old_content: str,
    new_content: str,
    sink: SentryLogSink | None,
) -> PrMaterial:
    """LLM or second agent call for gh-style PR title/body; falls back to template on failure."""
    if sink is not None:
        sink.set_step("PR description (LLM/agent)")
        sink.log("Drafting PR title and body from the code change …")
    _emit(
        repo_root,
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
                repo_root=repo_root,
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
            repo_root,
            sink,
            {
                "kind": "note",
                "message": f"PR description used fallback template: {exc}",
                "path": rel,
            },
        )
        material = fallback_pr_material(rel)
    _emit(
        repo_root,
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
        sync_main_from_origin(repo_root, main_branch, sink=sink)
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
                f"On {main_branch} (fast-forwarded from origin); "
                f"previous branch was {start_branch}."
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

    paths = list_gracenotes_swift_files(repo_root)
    rel = _pick_random(paths)
    if not rel:
        if sink is not None:
            sink.set_step("pick file")
        _emit(repo_root, sink, {"kind": "skip", "message": "No GraceNotes Swift files found."})
        restore_branch(repo_root, start_branch, main_branch)
        return 1

    if sink is not None:
        sink.set_step("pick file")
        sink.set_target_file(rel)
        sink.set_branch(None)
        sink.set_pr(None)

    file_path = repo_root / rel
    content = file_path.read_text(encoding="utf-8")

    if dry_run:
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
        restore_branch(repo_root, start_branch, main_branch)
        return 0

    _emit(
        repo_root,
        sink,
        {
            "kind": "fix_invoke",
            "path": rel,
            "provider": settings.fix_provider,
            "message": (
                "Invoking fix provider (cursor agent or HTTP LLM) with the Swift file from "
                f"{main_branch}."
            ),
        },
    )
    if settings.fix_provider == "cursor_agent":
        if sink is not None:
            sink.set_step("fix (cursor agent)")
            sink.log("Invoking local `agent` CLI for Swift fix (see events.jsonl: fix_invoke).")
        try:
            new_src = propose_swift_fix_via_agent(
                repo_root=repo_root,
                agent_bin=settings.agent_bin,
                prefix_args=settings.agent_prefix_args,
                extra_args=settings.agent_extra_args,
                relative_path=rel,
                file_content=content,
                timeout_sec=settings.agent_timeout_sec,
            )
        except (FileNotFoundError, OSError, RuntimeError) as exc:
            _emit(repo_root, sink, {"kind": "error", "message": str(exc), "path": rel})
            restore_branch(repo_root, start_branch, main_branch)
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
                        f"Set {settings.llm_api_key_env} (SENTRY_LLM_API_KEY_ENV) for LLM access, "
                        "or SENTRY_FIX_PROVIDER=cursor_agent for local `agent`."
                    ),
                },
            )
            restore_branch(repo_root, start_branch, main_branch)
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
            restore_branch(repo_root, start_branch, main_branch)
            return 1

    if not new_src.strip():
        _emit(
            repo_root,
            sink,
            {"kind": "skip", "message": "Fix step returned NO_CHANGE", "path": rel},
        )
        restore_branch(repo_root, start_branch, main_branch)
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

    material = _draft_pr_material(repo_root, settings, rel, content, new_src, sink)

    touch = classify_paths([rel])
    high_touch = is_high_touch(touch)
    needs_human = high_touch

    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    branch = f"sentry/auto-{ts}"
    title = material.title
    body = build_pr_body_from_material(
        material,
        risk=risk_label_for_touch(touch),
        touch=touch,
        needs_human_line=needs_human,
        approval_phrase=settings.approval_phrase,
    )

    if sink is not None:
        sink.set_step("commit & branch")
        sink.set_branch(branch)

    try:
        _git_output(repo_root, "checkout", "-b", branch)
        file_path.write_text(new_src, encoding="utf-8")
        _git_output(repo_root, "add", rel)
        _git_output(repo_root, "commit", "-m", f"sentry: refine {rel}")
    except subprocess.CalledProcessError as exc:
        _emit(repo_root, sink, {"kind": "error", "message": f"git commit failed: {exc}"})
        _cleanup_failed_branch(repo_root, branch, main_branch)
        restore_branch(repo_root, start_branch, main_branch)
        return 1

    if sink is not None:
        sink.set_step("grace ci")
        sink.log("Running `grace ci` (this may take several minutes)…")

    if not run_grace_ci(repo_root, settings):
        _emit(
            repo_root,
            sink,
            {"kind": "error", "message": "grace ci failed; dropping branch", "branch": branch},
        )
        try:
            _git_output(repo_root, "checkout", "--", rel)
        except subprocess.CalledProcessError:
            pass
        _cleanup_failed_branch(repo_root, branch, main_branch)
        restore_branch(repo_root, start_branch, main_branch)
        return 1

    if sink is not None:
        sink.set_step("git push")

    try:
        _git_output(repo_root, "push", "-u", "origin", branch)
    except subprocess.CalledProcessError as exc:
        _emit(repo_root, sink, {"kind": "error", "message": f"git push failed: {exc}"})
        _cleanup_failed_branch(repo_root, branch, main_branch)
        restore_branch(repo_root, start_branch, main_branch)
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
        ],
        cwd=repo_root,
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
        try:
            _git_output(repo_root, "checkout", "--", rel)
        except subprocess.CalledProcessError:
            pass
        _cleanup_failed_branch(repo_root, branch, main_branch)
        restore_branch(repo_root, start_branch, main_branch)
        return 1

    # `gh pr create` does not support `--json` on many CLI versions; read metadata separately.
    view = subprocess.run(
        ["gh", "pr", "view", "--json", "number,url"],
        cwd=repo_root,
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
        try:
            _git_output(repo_root, "checkout", "--", rel)
        except subprocess.CalledProcessError:
            pass
        _cleanup_failed_branch(repo_root, branch, main_branch)
        restore_branch(repo_root, start_branch, main_branch)
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

    if not merge:
        _emit(repo_root, sink, {"kind": "note", "message": "Skipping merge (--no-merge)."})
        restore_branch(repo_root, start_branch, main_branch)
        return 0

    remote = git_remote_owner_repo(repo_root)
    if not remote:
        _emit(
            repo_root,
            sink,
            {"kind": "error", "message": "Could not parse origin remote (GitHub)."},
        )
        restore_branch(repo_root, start_branch, main_branch)
        return 1

    owner, repo = remote
    allow = set(settings.approval_users)
    merge_ok = _poll_until_merge(
        repo_root,
        settings,
        owner,
        repo,
        pr_number,
        high_touch,
        allow,
        main_branch,
        sink=sink,
    )
    if merge_ok:
        _emit(repo_root, sink, {"kind": "merged", "message": f"PR #{pr_number} squash-merged"})
    else:
        _emit(repo_root, sink, {"kind": "note", "message": f"Stopped waiting on PR #{pr_number}"})

    try:
        _git_output(repo_root, "checkout", main_branch)
        _git_output(repo_root, "pull", "--ff-only", "origin", main_branch)
    except subprocess.CalledProcessError:
        pass

    restore_branch(repo_root, start_branch, main_branch)
    return 0


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
    for pr_number in pr_numbers:
        paths = gh_api.pr_changed_file_paths(repo_root, pr_number)
        touch = classify_paths(paths)
        high_touch = is_high_touch(touch)
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
                high_touch,
                allow,
                main_branch,
                sink=sink,
                poll_yield_for_approval=False,
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
                break
            if outcome == MergePollOutcome.CONTINUE_LOOP:
                continue
            break

        try:
            _git_output(repo_root, "checkout", main_branch)
            _git_output(repo_root, "pull", "--ff-only", "origin", main_branch)
        except subprocess.CalledProcessError:
            pass


def _poll_until_merge(
    repo_root: Path,
    settings: SentrySettings,
    owner: str,
    repo: str,
    pr_number: int,
    high_touch: bool,
    allow: set[str],
    main_branch: str,
    *,
    sink: SentryLogSink | None = None,
) -> bool:
    """Return True if merged."""
    deadline = time.monotonic() + float(settings.arbitration_stuck_seconds)
    poll = 30.0

    while time.monotonic() < deadline:
        outcome = merge_poll_once(
            repo_root,
            settings,
            owner,
            repo,
            pr_number,
            high_touch,
            allow,
            main_branch,
            sink=sink,
            poll_yield_for_approval=True,
        )
        if outcome == MergePollOutcome.MERGED:
            return True
        if outcome == MergePollOutcome.YIELD_APPROVAL:
            return False
        if outcome == MergePollOutcome.TERMINAL_FAIL:
            return False
        if outcome == MergePollOutcome.CONTINUE_LOOP:
            continue
        time.sleep(poll)

    gh_api.pr_comment(
        repo_root,
        pr_number,
        "Sentry: timed out waiting for merge gates. "
        f"Resolve Copilot threads or post `{settings.approval_phrase}` (allowlisted user).",
    )
    return False
