"""OpenAI-compatible chat completions (stdlib HTTP)."""

from __future__ import annotations

import difflib
import json
import os
import re
import urllib.error
import urllib.request
from dataclasses import dataclass

from gracenotes_dev.sentry.pr_template import PrMaterial

_SWIFT_BLOCK = re.compile(r"```(?:swift)?\s*([\s\S]*?)```", re.MULTILINE)
_JSON_FENCE = re.compile(r"```(?:json)?\s*([\s\S]*?)```", re.MULTILINE)
_ANY_FENCE_BLOCK = re.compile(r"```(?:[a-zA-Z0-9]+)?\s*([\s\S]*?)```", re.MULTILINE)


@dataclass(frozen=True)
class LLMResult:
    content: str


def _chat_completion(
    *,
    base_url: str,
    api_key: str,
    model: str,
    messages: list[dict[str, str]],
    timeout_sec: int = 120,
) -> LLMResult:
    url = base_url.rstrip("/") + "/chat/completions"
    payload = json.dumps({"model": model, "messages": messages, "temperature": 0.2}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout_sec) as resp:
            raw = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"LLM HTTP {exc.code}: {body}") from exc
    except OSError as exc:
        raise RuntimeError(f"LLM request failed: {exc}") from exc

    try:
        text = raw["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError(f"Unexpected LLM response shape: {raw!r}") from exc
    return LLMResult(content=text.strip())


MACOS_XCODE_PREAMBLE = (
    "You are helping improve Grace Notes, a native iOS journaling app. "
    "The repository builds ONLY on macOS with Xcode and the iOS Simulator. "
    "Do not assume Linux, Docker-only workflows, or SwiftPM-on-Linux. "
    "Validation runs via the project's `grace` CLI (`grace test` / `grace ci`) "
    "on the Mac."
)


def propose_swift_fix(
    *,
    base_url: str,
    api_key: str,
    model: str,
    relative_path: str,
    file_content: str,
) -> str:
    """Return full replacement Swift source from the model (extracted from a ```swift``` block)."""
    messages = [
        {"role": "system", "content": MACOS_XCODE_PREAMBLE},
        {"role": "user", "content": build_fix_user_prompt(relative_path, file_content)},
    ]
    result = _chat_completion(base_url=base_url, api_key=api_key, model=model, messages=messages)
    return parse_fix_response(result.content)


def parse_fix_response(content: str) -> str:
    """Extract full Swift file from model output, or empty string if NO_CHANGE."""
    if content.strip().upper().startswith("NO_CHANGE"):
        return ""
    m = _SWIFT_BLOCK.search(content)
    if not m:
        raise RuntimeError("Model did not return a ```swift``` block and did not say NO_CHANGE.")
    return m.group(1).strip() + "\n"


def parse_merge_conflict_response(content: str) -> str:
    """Extract resolved file from agent output (any fenced block), or empty if NO_CHANGE."""
    if content.strip().upper().startswith("NO_CHANGE"):
        return ""
    m = _ANY_FENCE_BLOCK.search(content)
    if not m:
        raise RuntimeError("Model did not return a fenced code block and did not say NO_CHANGE.")
    return m.group(1).strip() + "\n"


def build_merge_conflict_prompt(relative_path: str, file_content: str) -> str:
    """Instruction block for resolving git conflict markers in a single file."""
    return (
        f"File: `{relative_path}`\n\n"
        "This file contains git merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`). "
        "Resolve the conflict by combining or choosing the correct changes from both sides. "
        "Remove ALL conflict markers and produce a complete, valid file.\n\n"
        "Reply with ONLY a markdown fenced code block with the full new file contents "
        "(use ```swift for Swift files; otherwise a plain ``` block). "
        "If you cannot safely resolve, reply exactly: NO_CHANGE\n\n"
        f"---BEGIN FILE---\n{file_content}\n---END FILE---"
    )


def build_fix_user_prompt(relative_path: str, file_content: str) -> str:
    """Shared instruction block for HTTP and local ``agent`` providers."""
    return (
        f"File: `{relative_path}`\n\n"
        "Find a real bug, unsafe edge case, or clear improvement. "
        "If nothing is worth changing, reply exactly: NO_CHANGE\n\n"
        "Otherwise reply with ONLY a single markdown fenced code block ```swift ... ``` "
        "containing the complete new file contents (entire file, not a diff).\n\n"
        f"---BEGIN FILE---\n{file_content}\n---END FILE---"
    )


def _clip_text(s: str, max_chars: int) -> str:
    if len(s) <= max_chars:
        return s
    return s[:max_chars] + "\n… [truncated]"


def build_cursor_review_fix_prompt(
    relative_path: str,
    file_content: str,
    feedback_text: str,
) -> str:
    """Instruction block for applying a reviewer's feedback to a single file."""
    fb = _clip_text(feedback_text.strip(), 24_000)
    return (
        f"File: `{relative_path}`\n\n"
        "A reviewer left feedback on this pull request. Apply the requested changes to the "
        "Swift file below. Preserve existing behavior except where the feedback requires a "
        "change. If the feedback does not apply to this file, reply exactly: NO_CHANGE\n\n"
        "## Reviewer feedback\n\n"
        f"{fb}\n\n"
        "Reply with ONLY a single markdown fenced code block ```swift ... ``` containing the "
        "complete new file contents (entire file, not a diff).\n\n"
        f"---BEGIN FILE---\n{file_content}\n---END FILE---"
    )


def build_ci_failure_prompt(
    relative_path: str,
    file_content: str,
    ci_log_excerpt: str,
) -> str:
    """Instruction block for fixing a file so ``grace ci`` passes (local Mac run)."""
    log = _clip_text(ci_log_excerpt.strip(), 24_000)
    return (
        f"File: `{relative_path}`\n\n"
        "The project's `grace ci` command failed on macOS. Use the CI output below to fix "
        "this file so the project passes CI. Preserve unrelated behavior.\n\n"
        "## CI output\n\n"
        f"```text\n{log}\n```\n\n"
        "Reply with ONLY a markdown fenced code block with the full new file contents "
        "(use ```swift for Swift; ```python for Python). "
        "If this file does not need changes or the failure is elsewhere, reply exactly: NO_CHANGE\n\n"
        f"---BEGIN FILE---\n{file_content}\n---END FILE---"
    )


def parse_ci_fix_response(content: str, relative_path: str) -> str:
    """Parse agent output for CI recovery: Swift uses a swift fenced block; else any fence."""
    if relative_path.endswith(".swift"):
        return parse_fix_response(content)
    return parse_merge_conflict_response(content)


def _unified_diff_excerpt(old: str, new: str, path: str, *, max_lines: int = 120) -> str:
    lines = list(
        difflib.unified_diff(
            old.splitlines(True),
            new.splitlines(True),
            fromfile=f"a/{path}",
            tofile=f"b/{path}",
        )
    )
    if len(lines) > max_lines:
        return "".join(lines[:max_lines]) + "… [diff truncated]\n"
    return "".join(lines)


PR_MATERIAL_SYSTEM = (
    MACOS_XCODE_PREAMBLE + " "
    "You write GitHub pull request descriptions for Grace Notes. "
    "Be concrete: what was wrong or weak, why it matters to users or reliability, "
    "and what the change does in plain language. "
    "Reply with ONLY a single JSON object (no markdown outside JSON). "
    "Use American English. Keys: "
    '"title" (short PR title, imperative, ≤72 chars), '
    '"headline" (one line, product-focused), '
    '"user_impact" (1–3 sentences), '
    '"what_changed" (short paragraphs; no raw code), '
    '"verification" (how a reviewer can validate, e.g. grace ci).'
)


def build_pr_material_user_prompt(relative_path: str, old_content: str, new_content: str) -> str:
    old_c = _clip_text(old_content, 14_000)
    new_c = _clip_text(new_content, 14_000)
    diff_excerpt = _unified_diff_excerpt(old_content, new_content, relative_path)
    return (
        f"File: `{relative_path}`\n\n"
        "The sentry automation already applied a full-file Swift replacement. "
        "Using the diff and file excerpts below, write the JSON object described "
        "in your instructions.\n\n"
        "## Unified diff (excerpt)\n\n"
        f"```diff\n{diff_excerpt}\n```\n\n"
        "## Previous file (excerpt)\n\n"
        f"```swift\n{old_c}\n```\n\n"
        "## New file (excerpt)\n\n"
        f"```swift\n{new_c}\n```\n"
    )


def parse_pr_material_json(text: str) -> PrMaterial:
    t = text.strip()
    m = _JSON_FENCE.search(t)
    blob = m.group(1).strip() if m else t
    if not blob.lstrip().startswith("{"):
        raise ValueError("PR material response did not contain JSON")
    data = json.loads(blob)
    title = str(data.get("title", "")).strip()
    headline = str(data.get("headline", "")).strip()
    user_impact = str(data.get("user_impact", "")).strip()
    what_changed = str(data.get("what_changed", "")).strip()
    verification = str(data.get("verification", "")).strip()
    if not title or not headline:
        raise ValueError("PR material JSON missing title or headline")
    return PrMaterial(
        title=title,
        headline=headline,
        user_impact=user_impact or "See diff on this PR.",
        what_changed=what_changed or "Swift file updated in one automated pass.",
        verification=verification or "Run `grace ci` on macOS.",
    )


def propose_pr_material_http(
    *,
    base_url: str,
    api_key: str,
    model: str,
    relative_path: str,
    old_content: str,
    new_content: str,
    timeout_sec: int = 120,
) -> PrMaterial:
    """Ask the chat model for PR title + narrative JSON."""
    user = build_pr_material_user_prompt(relative_path, old_content, new_content)
    messages = [
        {"role": "system", "content": PR_MATERIAL_SYSTEM},
        {"role": "user", "content": user},
    ]
    result = _chat_completion(
        base_url=base_url,
        api_key=api_key,
        model=model,
        messages=messages,
        timeout_sec=timeout_sec,
    )
    try:
        return parse_pr_material_json(result.content)
    except (json.JSONDecodeError, ValueError, KeyError, TypeError) as exc:
        raise RuntimeError(f"Invalid PR material JSON: {exc}") from exc


def classify_touch_llm(
    *,
    base_url: str,
    api_key: str,
    model: str,
    paths: list[str],
    diff_stat: str,
) -> str | None:
    """Return one of low-touch, business-logic, ui-ux; or None on failure."""
    messages = [
        {"role": "system", "content": MACOS_XCODE_PREAMBLE},
        {
            "role": "user",
            "content": (
                "Classify the change scope for this automated PR.\n"
                "Reply with exactly one token: low-touch | business-logic | ui-ux\n\n"
                f"Paths: {paths}\n\nDiff summary:\n{diff_stat[:8000]}"
            ),
        },
    ]
    result = _chat_completion(base_url=base_url, api_key=api_key, model=model, messages=messages)
    token = result.content.strip().split()[0].lower() if result.content else ""
    if token in ("low-touch", "business-logic", "ui-ux"):
        return token
    return None


def api_key_from_env(env_var_name: str) -> str | None:
    key = os.environ.get(env_var_name, "").strip()
    return key or None
