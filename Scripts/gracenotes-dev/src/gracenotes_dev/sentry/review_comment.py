"""Sentry PR review outcome comments (``<!-- sentry-review: … -->`` markers)."""

from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Any

# Machine-readable marker (HTML comment so it is hidden in rendered Markdown).
SENTRY_REVIEW_MARKER_RE = re.compile(
    r"<!--\s*sentry-review:\s*([a-zA-Z0-9_]+)\s*-->",
    re.IGNORECASE,
)

DEFAULT_REVIEW_OUTCOME_TEMPLATES: dict[str, str] = {
    "addressed": (
        "**Sentry — review feedback**\n\n"
        "Outcome: **addressed** (changes pushed for PR #{pr}).\n\n"
        "Local `grace ci` passed before push."
    ),
    "pushback": (
        "**Sentry — review feedback**\n\n"
        "Outcome: **pushback** (PR #{pr}).\n\n"
        "Deliberate non-compliance with the review as written; not flagged as a product decision."
    ),
    "caveat": (
        "**Sentry — review feedback**\n\n"
        "Outcome: **caveat** (PR #{pr}).\n\n"
        "Shipped with noted limitations or follow-ups."
    ),
    "product_decision": (
        "**Sentry — review feedback**\n\n"
        "Outcome: **product_decision** (PR #{pr}).\n\n"
        "Needs human / product approval before merge."
    ),
    "no_change": (
        "**Sentry — review feedback**\n\n"
        "Outcome: **no_change** (PR #{pr}).\n\n"
        "Automated pass did not produce substantive source edits for the review feedback."
    ),
    "ci_failed": (
        "**Sentry — review feedback**\n\n"
        "Outcome: **ci_failed** (PR #{pr}).\n\n"
        "Local `grace ci` failed after edits; changes were not pushed."
    ),
    "error": (
        "**Sentry — review feedback**\n\n"
        "Outcome: **error** (PR #{pr}).\n\n"
        "Automated review-fix pass failed (see sentry logs / JSONL)."
    ),
    "no_swift_files": (
        "**Sentry — review feedback**\n\n"
        "Outcome: **no_swift_files** (PR #{pr}).\n\n"
        "No `GraceNotes/**/*.swift` paths in the PR diff to edit automatically."
    ),
}


def parse_sentry_review_outcome(body: str) -> str | None:
    """Return the first ``sentry-review`` outcome token in ``body``, or ``None``."""
    m = SENTRY_REVIEW_MARKER_RE.search(body or "")
    if not m:
        return None
    return m.group(1).strip().lower()


def merge_outcome_templates(
    defaults: dict[str, str],
    overrides: dict[str, str] | None,
) -> dict[str, str]:
    """Defaults with TOML overrides (same keys)."""
    out = dict(defaults)
    if overrides:
        for k, v in overrides.items():
            ks = str(k).strip().lower()
            if ks and isinstance(v, str) and v.strip():
                out[ks] = v.strip()
    return out


def merge_gate_marker_body(agent_comment: str, outcome: str = "addressed") -> str:
    """
    Public PR comment body: agent-written text plus ``<!-- sentry-review: … -->`` for merge mode.

    The visible comment should be **only** ``agent_comment`` (what was done and why); the marker
    is appended for ``review_clear_mode = comment`` unless already present.
    """
    text = (agent_comment or "").strip()
    if not text:
        text = "(Sentry could not generate a summary; see JSONL events under `.grace/sentry/`.)"
    key = outcome.strip().lower()
    marker = f"<!-- sentry-review: {key} -->"
    if marker.lower() in text.lower():
        return text
    return f"{text.rstrip()}\n\n{marker}"


def format_review_comment_body(
    outcome: str,
    *,
    pr_number: int,
    templates: dict[str, str],
) -> str:
    """
    Render the issue comment body: template (with ``{pr}``) plus a trailing marker line.

    Unknown ``outcome`` keys fall back to the ``error`` template when present, else a minimal body.
    """
    key = outcome.strip().lower()
    tpl = (
        templates.get(key)
        or templates.get("error")
        or ("**Sentry — review feedback**\n\nAutomated review outcome for PR #{pr}.")
    )
    try:
        text = tpl.format(pr=pr_number)
    except (KeyError, ValueError):
        text = str(tpl).replace("{pr}", str(pr_number))
    marker = f"<!-- sentry-review: {key} -->"
    if marker.lower() in text.lower():
        return text
    return f"{text.rstrip()}\n\n{marker}"


def auth_user_has_sentry_marker_comment(
    comments: list[dict[str, Any]],
    authenticated_login: str | None,
) -> bool:
    """
    True if ``authenticated_login`` has at least one issue comment containing a
    ``sentry-review`` marker.

    Used to decide whether ``review_clear_mode=comment`` applies marker semantics
    (newest outcome + block list) or treats the review gate as cleared with no marker yet.
    """
    if not authenticated_login:
        return False
    auth_l = authenticated_login.strip().lower()
    for c in comments:
        user = ((c.get("user") or {}).get("login") or "").strip().lower()
        if user != auth_l:
            continue
        if parse_sentry_review_outcome(str(c.get("body") or "")) is not None:
            return True
    return False


def reviewers_clear_from_sentry_comment(
    *,
    comments: list[dict[str, Any]],
    authenticated_login: str | None,
    block_outcomes: frozenset[str],
    max_age_seconds: int,
) -> bool:
    """
    True when the newest qualifying comment from ``authenticated_login`` has an outcome
    not in ``block_outcomes``.

    If ``authenticated_login`` is None, returns False. If ``max_age_seconds`` > 0, comments
    older than that (by ``created_at``) do not qualify, and comments without a parseable
    ``created_at`` cannot clear the gate.
    """
    if not authenticated_login:
        return False
    auth_l = authenticated_login.strip().lower()
    now = datetime.now(timezone.utc)

    scored: list[tuple[str, str, datetime | None]] = []
    for c in comments:
        user = ((c.get("user") or {}).get("login") or "").strip().lower()
        if user != auth_l:
            continue
        body = c.get("body") or ""
        outcome = parse_sentry_review_outcome(str(body))
        if outcome is None:
            continue
        raw_ts = c.get("created_at")
        dt: datetime | None = None
        if isinstance(raw_ts, str) and raw_ts.strip():
            try:
                s = raw_ts.replace("Z", "+00:00")
                dt = datetime.fromisoformat(s)
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)
            except ValueError:
                dt = None
        scored.append((str(body), outcome, dt))

    if not scored:
        return False

    if max_age_seconds > 0:
        dated = [t for t in scored if t[2] is not None]
        if not dated:
            return False
        scored = dated

    def _dt_key(t: tuple[str, str, datetime | None]) -> datetime:
        _, _, dt = t
        if dt is None:
            return datetime.min.replace(tzinfo=timezone.utc)
        return dt

    scored.sort(key=_dt_key, reverse=True)
    _, newest_outcome, newest_dt = scored[0]

    if max_age_seconds > 0 and newest_dt is not None:
        age = (now - newest_dt).total_seconds()
        if age > float(max_age_seconds):
            return False

    return newest_outcome.lower() not in block_outcomes
