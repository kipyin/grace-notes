"""Local Cursor ``agent`` CLI integration (no HTTP API)."""

from __future__ import annotations

import json
import shlex
import shutil
import subprocess
from pathlib import Path

from gracenotes_dev.sentry.llm_client import (
    MACOS_XCODE_PREAMBLE,
    PR_MATERIAL_SYSTEM,
    build_ci_failure_prompt,
    build_cursor_review_fix_prompt,
    build_fix_user_prompt,
    build_merge_conflict_prompt,
    build_pr_material_user_prompt,
    parse_ci_fix_response,
    parse_fix_response,
    parse_merge_conflict_response,
    parse_pr_material_json,
)
from gracenotes_dev.sentry.pr_template import PrMaterial


def _split_args(raw: str) -> tuple[str, ...]:
    s = raw.strip()
    if not s:
        return ()
    return tuple(shlex.split(s))


def resolve_agent_path(agent_bin: str) -> str:
    """Return path to agent executable, or raise FileNotFoundError."""
    p = Path(agent_bin).expanduser()
    if p.is_file():
        return str(p.resolve())
    found = shutil.which(agent_bin)
    if not found:
        raise FileNotFoundError(
            f"Executable not found on PATH: {agent_bin!r}. "
            "Install Cursor CLI or set SENTRY_AGENT_BIN."
        )
    return found


def propose_swift_fix_via_agent(
    *,
    repo_root: Path,
    agent_bin: str,
    prefix_args: tuple[str, ...],
    extra_args: tuple[str, ...],
    relative_path: str,
    file_content: str,
    timeout_sec: int,
) -> str:
    """
    Run ``agent`` (or ``cursor agent``, etc.) with a single prompt; parse Swift block or NO_CHANGE.

    Default argv shape: ``agent <prefix...> <extra...> "<prompt>"`` (prompt is last).
    """
    resolved = resolve_agent_path(agent_bin)
    body = build_fix_user_prompt(relative_path, file_content)
    prompt = f"{MACOS_XCODE_PREAMBLE}\n\n{body}"
    argv = [resolved, *prefix_args, *extra_args, prompt]
    try:
        proc = subprocess.run(
            argv,
            cwd=repo_root,
            capture_output=True,
            text=True,
            timeout=timeout_sec,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"agent command timed out after {timeout_sec}s") from exc

    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    try:
        return parse_fix_response(combined)
    except RuntimeError as exc:
        raise RuntimeError(
            f"{exc} Exit {proc.returncode}. Output (truncated): {combined[:2000]!r}"
        ) from exc


def address_cursor_feedback_file_via_agent(
    *,
    repo_root: Path,
    agent_bin: str,
    prefix_args: tuple[str, ...],
    extra_args: tuple[str, ...],
    relative_path: str,
    file_content: str,
    feedback_text: str,
    timeout_sec: int,
) -> str:
    """Run ``agent`` to apply PR review feedback to one file; parse Swift block or NO_CHANGE."""
    resolved = resolve_agent_path(agent_bin)
    body = build_cursor_review_fix_prompt(relative_path, file_content, feedback_text)
    prompt = f"{MACOS_XCODE_PREAMBLE}\n\n{body}"
    argv = [resolved, *prefix_args, *extra_args, prompt]
    try:
        proc = subprocess.run(
            argv,
            cwd=repo_root,
            capture_output=True,
            text=True,
            timeout=timeout_sec,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"agent command timed out after {timeout_sec}s") from exc

    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    try:
        return parse_fix_response(combined)
    except RuntimeError as exc:
        raise RuntimeError(
            f"{exc} Exit {proc.returncode}. Output (truncated): {combined[:2000]!r}"
        ) from exc


def address_ci_failure_file_via_agent(
    *,
    repo_root: Path,
    agent_bin: str,
    prefix_args: tuple[str, ...],
    extra_args: tuple[str, ...],
    relative_path: str,
    file_content: str,
    ci_log_text: str,
    timeout_sec: int,
) -> str:
    """Run ``agent`` to fix one file from captured ``grace ci`` output; Swift or Python fences."""
    resolved = resolve_agent_path(agent_bin)
    body = build_ci_failure_prompt(relative_path, file_content, ci_log_text)
    prompt = f"{MACOS_XCODE_PREAMBLE}\n\n{body}"
    argv = [resolved, *prefix_args, *extra_args, prompt]
    try:
        proc = subprocess.run(
            argv,
            cwd=repo_root,
            capture_output=True,
            text=True,
            timeout=timeout_sec,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"agent command timed out after {timeout_sec}s") from exc

    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    try:
        return parse_ci_fix_response(combined, relative_path)
    except RuntimeError as exc:
        raise RuntimeError(
            f"{exc} Exit {proc.returncode}. Output (truncated): {combined[:2000]!r}"
        ) from exc


def propose_pr_material_via_agent(
    *,
    repo_root: Path,
    agent_bin: str,
    prefix_args: tuple[str, ...],
    extra_args: tuple[str, ...],
    relative_path: str,
    old_content: str,
    new_content: str,
    timeout_sec: int,
) -> PrMaterial:
    """Second ``agent`` invocation: PR title + JSON narrative for gh-style body."""
    resolved = resolve_agent_path(agent_bin)
    body = build_pr_material_user_prompt(relative_path, old_content, new_content)
    prompt = f"{PR_MATERIAL_SYSTEM}\n\n{body}"
    argv = [resolved, *prefix_args, *extra_args, prompt]
    try:
        proc = subprocess.run(
            argv,
            cwd=repo_root,
            capture_output=True,
            text=True,
            timeout=timeout_sec,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"agent PR-draft command timed out after {timeout_sec}s") from exc

    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    try:
        return parse_pr_material_json(combined)
    except (ValueError, json.JSONDecodeError) as exc:
        raise RuntimeError(
            f"{exc} Exit {proc.returncode}. Output (truncated): {combined[:2000]!r}"
        ) from exc


def resolve_merge_conflict_file_via_agent(
    *,
    repo_root: Path,
    agent_bin: str,
    prefix_args: tuple[str, ...],
    extra_args: tuple[str, ...],
    relative_path: str,
    file_content: str,
    timeout_sec: int,
) -> str:
    """Run ``agent`` once per conflicted file; parse fenced resolved contents."""
    resolved = resolve_agent_path(agent_bin)
    body = build_merge_conflict_prompt(relative_path, file_content)
    prompt = f"{MACOS_XCODE_PREAMBLE}\n\n{body}"
    argv = [resolved, *prefix_args, *extra_args, prompt]
    try:
        proc = subprocess.run(
            argv,
            cwd=repo_root,
            capture_output=True,
            text=True,
            timeout=timeout_sec,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"agent merge-conflict command timed out after {timeout_sec}s") from exc

    combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
    try:
        return parse_merge_conflict_response(combined)
    except RuntimeError as exc:
        raise RuntimeError(
            f"{exc} Exit {proc.returncode}. Output (truncated): {combined[:2000]!r}"
        ) from exc
