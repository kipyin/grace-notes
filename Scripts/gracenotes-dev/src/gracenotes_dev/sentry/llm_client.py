"""OpenAI-compatible chat completions (stdlib HTTP)."""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.request
from dataclasses import dataclass

_SWIFT_BLOCK = re.compile(r"```(?:swift)?\s*([\s\S]*?)```", re.MULTILINE)


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
