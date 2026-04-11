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
from gracenotes_dev.sentry.agent_client import propose_swift_fix_via_agent
from gracenotes_dev.sentry.classify import classify_paths, is_high_touch
from gracenotes_dev.sentry.git_remote import git_remote_owner_repo
from gracenotes_dev.sentry.llm_client import api_key_from_env, propose_swift_fix
from gracenotes_dev.sentry.log_sink import SentryLogSink
from gracenotes_dev.sentry.merge_logic import can_merge
from gracenotes_dev.sentry.pr_template import build_pr_body, risk_label_for_touch
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

    paths = list_gracenotes_swift_files(repo_root)
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

    file_path = repo_root / rel
    content = file_path.read_text(encoding="utf-8")

    if dry_run:
        mode = settings.fix_provider
        _emit(
            repo_root,
            sink,
            {
                "kind": "dry_run",
                "message": f"Would propose fix for {rel} (provider={mode})",
                "path": rel,
            },
        )
        return 0

    if settings.fix_provider == "cursor_agent":
        if sink is not None:
            sink.set_step("fix (cursor agent)")
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
            return 1
    else:
        if sink is not None:
            sink.set_step("fix (LLM)")
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

    touch = classify_paths([rel])
    high_touch = is_high_touch(touch)
    needs_human = high_touch

    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    branch = f"sentry/auto-{ts}"
    title = f"Sentry: update {Path(rel).name}"

    body = build_pr_body(
        summary_bullets=[
            f"Adjust `{rel}` from automated sentry pass.",
            "Validation: `grace ci` on macOS.",
        ],
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
        _cleanup_failed_branch(repo_root, branch)
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
        _cleanup_failed_branch(repo_root, branch)
        return 1

    if sink is not None:
        sink.set_step("git push")

    try:
        _git_output(repo_root, "push", "-u", "origin", branch)
    except subprocess.CalledProcessError as exc:
        _emit(repo_root, sink, {"kind": "error", "message": f"git push failed: {exc}"})
        _cleanup_failed_branch(repo_root, branch)
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
        _cleanup_failed_branch(repo_root, branch)
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
        _cleanup_failed_branch(repo_root, branch)
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
        },
    )

    if not merge:
        _emit(repo_root, sink, {"kind": "note", "message": "Skipping merge (--no-merge)."})
        _git_output(repo_root, "checkout", "main")
        return 0

    remote = git_remote_owner_repo(repo_root)
    if not remote:
        _emit(
            repo_root,
            sink,
            {"kind": "error", "message": "Could not parse origin remote (GitHub)."},
        )
        _git_output(repo_root, "checkout", "main")
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
        sink=sink,
    )
    if merge_ok:
        _emit(repo_root, sink, {"kind": "merged", "message": f"PR #{pr_number} squash-merged"})
    else:
        _emit(repo_root, sink, {"kind": "note", "message": f"Stopped waiting on PR #{pr_number}"})

    try:
        _git_output(repo_root, "checkout", "main")
        _git_output(repo_root, "pull", "--ff-only")
    except subprocess.CalledProcessError:
        pass

    return 0


def _poll_until_merge(
    repo_root: Path,
    settings: SentrySettings,
    owner: str,
    repo: str,
    pr_number: int,
    high_touch: bool,
    allow: set[str],
    *,
    sink: SentryLogSink | None = None,
) -> bool:
    """Return True if merged."""
    deadline = time.monotonic() + float(settings.arbitration_stuck_seconds)
    poll = 30.0

    while time.monotonic() < deadline:
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
                f"merge poll: ci_ok={ci_ok} high_touch={high_touch} "
                f"copilot_unresolved={unresolved} approve={approve}"
            )

        if can_merge(
            ci_ok=ci_ok,
            high_touch=high_touch,
            copilot_ok=copilot_ok,
            approve_phrase_present=approve,
        ):
            if sink is not None:
                sink.set_step("squash merge")
            return gh_api.pr_merge_squash(repo_root, pr_number)

        time.sleep(poll)

    gh_api.pr_comment(
        repo_root,
        pr_number,
        "Sentry: timed out waiting for merge gates. "
        f"Resolve Copilot threads or post `{settings.approval_phrase}` (allowlisted user).",
    )
    return False
