"""Sentry settings: ``gracenotes-dev.toml`` ``[sentry]`` + environment (env wins)."""

from __future__ import annotations

import os
import shlex
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from gracenotes_dev.config import discover_repo_root, load_sentry_table
from gracenotes_dev.sentry.review_comment import (
    DEFAULT_REVIEW_OUTCOME_TEMPLATES,
    merge_outcome_templates,
)


def _env_int(key: str, default: int) -> int:
    raw = os.environ.get(key)
    if raw is None or raw.strip() == "":
        return default
    try:
        return int(raw.strip(), 10)
    except ValueError:
        return default


def _env_float(key: str, default: float) -> float:
    raw = os.environ.get(key)
    if raw is None or raw.strip() == "":
        return default
    try:
        return float(raw.strip())
    except ValueError:
        return default


def _comma_list(key: str) -> tuple[str, ...]:
    raw = os.environ.get(key, "")
    return tuple(s.strip() for s in raw.split(",") if s.strip())


def _split_shell(env_key: str, default: str) -> tuple[str, ...]:
    raw = os.environ.get(env_key)
    if raw is None:
        raw = default
    s = raw.strip()
    if not s:
        return ()
    return tuple(shlex.split(s))


def _normalize_fix_provider(raw: str) -> str:
    n = raw.strip().lower().replace("-", "_")
    if n in ("cursor_agent", "agent"):
        return "cursor_agent"
    return "http"


def _str_from_toml(tom: dict[str, Any], key: str) -> str | None:
    raw = tom.get(key)
    if raw is None:
        return None
    s = str(raw).strip()
    return s or None


def _opt_int(tom: dict[str, Any], key: str) -> int | None:
    raw = tom.get(key)
    if raw is None:
        return None
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def _opt_float(tom: dict[str, Any], key: str) -> float | None:
    raw = tom.get(key)
    if raw is None:
        return None
    try:
        return float(raw)
    except (TypeError, ValueError):
        return None


def _approval_from_tom(tom: dict[str, Any]) -> tuple[str, ...] | None:
    raw = tom.get("approval_users")
    if raw is None:
        return None
    if isinstance(raw, list):
        return tuple(str(x).strip() for x in raw if str(x).strip())
    if isinstance(raw, str):
        return tuple(s.strip() for s in raw.split(",") if s.strip())
    return None


def _split_args_from_toml(raw: Any) -> tuple[str, ...] | None:
    if raw is None:
        return None
    if isinstance(raw, list):
        return tuple(str(x) for x in raw)
    if isinstance(raw, str):
        s = raw.strip()
        if not s:
            return ()
        return tuple(shlex.split(s))
    return None


def _merge_str(env_key: str, tom: dict[str, Any], toml_key: str, default: str) -> str:
    if os.environ.get(env_key, "").strip():
        return os.environ[env_key].strip()
    v = _str_from_toml(tom, toml_key)
    return v if v is not None else default


def _merge_opt_str(env_key: str, tom: dict[str, Any], toml_key: str) -> str | None:
    if os.environ.get(env_key, "").strip():
        return os.environ[env_key].strip()
    return _str_from_toml(tom, toml_key)


def _merge_int(
    env_key: str,
    tom: dict[str, Any],
    toml_key: str,
    default: int,
) -> int:
    if os.environ.get(env_key, "").strip():
        return _env_int(env_key, default)
    v = _opt_int(tom, toml_key)
    return default if v is None else v


def _merge_float(
    env_key: str,
    tom: dict[str, Any],
    toml_key: str,
    default: float,
) -> float:
    if os.environ.get(env_key, "").strip():
        return _env_float(env_key, default)
    v = _opt_float(tom, toml_key)
    return default if v is None else v


def _merge_bool(env_key: str, tom: dict[str, Any], toml_key: str, default: bool) -> bool:
    if os.environ.get(env_key, "").strip():
        raw = os.environ[env_key].strip().lower()
        return raw in ("1", "true", "yes", "on")
    raw = tom.get(toml_key)
    if raw is None:
        return default
    if isinstance(raw, bool):
        return raw
    if isinstance(raw, (int, float)):
        return bool(raw)
    if isinstance(raw, str):
        return raw.strip().lower() in ("1", "true", "yes", "on")
    return default


def _merge_approval_users(tom: dict[str, Any]) -> tuple[str, ...]:
    if os.environ.get("SENTRY_APPROVAL_USERS", "").strip():
        return _comma_list("SENTRY_APPROVAL_USERS")
    t = _approval_from_tom(tom)
    return t if t is not None else ()


# PR comments use ``cursor[bot]`` (Bugbot). ``cursor`` / ``cursoragent`` are fallbacks.
_DEFAULT_CURSOR_REVIEWER_LOGINS = ("cursor[bot]", "cursor", "cursoragent")

# GitHub Copilot PR reviewer app (``author.login`` on review threads).
_DEFAULT_COPILOT_REVIEWER_LOGIN = "copilot-pull-request-reviewer"

_DEFAULT_CURSOR_START_PHRASES = ("Taking a look", "taking a look")


def _cursor_list_from_tom(tom: dict[str, Any], key: str) -> tuple[str, ...] | None:
    raw = tom.get(key)
    if raw is None:
        return None
    if isinstance(raw, list):
        return tuple(str(x).strip() for x in raw if str(x).strip())
    if isinstance(raw, str):
        return tuple(s.strip() for s in raw.split(",") if s.strip())
    return None


def _merge_cursor_reviewer_logins(tom: dict[str, Any]) -> tuple[str, ...]:
    if os.environ.get("SENTRY_CURSOR_REVIEWER_LOGINS", "").strip():
        return _comma_list("SENTRY_CURSOR_REVIEWER_LOGINS")
    t = _cursor_list_from_tom(tom, "cursor_reviewer_logins")
    if t is not None:
        return t
    return _DEFAULT_CURSOR_REVIEWER_LOGINS


def _merge_reviewer_logins(tom: dict[str, Any]) -> tuple[str, ...]:
    """Default: Copilot reviewer bot + Cursor logins when ``reviewer_logins`` is unset."""
    if os.environ.get("SENTRY_REVIEWER_LOGINS", "").strip():
        return _comma_list("SENTRY_REVIEWER_LOGINS")
    t = _cursor_list_from_tom(tom, "reviewer_logins")
    if t is not None:
        return t
    cursor_list = _merge_cursor_reviewer_logins(tom)
    out: list[str] = []
    seen: set[str] = set()
    copilot = _DEFAULT_COPILOT_REVIEWER_LOGIN.strip()
    if copilot:
        out.append(copilot)
        seen.add(copilot.lower())
    for x in cursor_list:
        if not x.strip():
            continue
        k = x.strip().lower()
        if k not in seen:
            seen.add(k)
            out.append(x.strip())
    return tuple(out)


def _merge_review_fix_cooldown_base(tom: dict[str, Any]) -> int:
    """Canonical cooldown for review-fix automation (TOML ``review_fix_cooldown_seconds``)."""
    if os.environ.get("SENTRY_REVIEW_FIX_COOLDOWN_SEC", "").strip():
        return _env_int("SENTRY_REVIEW_FIX_COOLDOWN_SEC", 180)
    v = _opt_int(tom, "review_fix_cooldown_seconds")
    if v is not None:
        return v
    v = _opt_int(tom, "cursor_review_fix_cooldown_seconds")
    return v if v is not None else 180


def _merge_cursor_review_fix_cooldown_seconds(tom: dict[str, Any], base: int) -> int:
    """
    Cursor-agent path may override with ``cursor_review_fix_cooldown_seconds`` / env.

    When unset, matches ``base`` (from :func:`_merge_review_fix_cooldown_base`).
    """
    if os.environ.get("SENTRY_CURSOR_FIX_COOLDOWN_SEC", "").strip():
        return _env_int("SENTRY_CURSOR_FIX_COOLDOWN_SEC", base)
    v = _opt_int(tom, "cursor_review_fix_cooldown_seconds")
    return v if v is not None else base


def _merge_ci_fix_cooldown_seconds(tom: dict[str, Any], default_from_cursor: int) -> int:
    """Cooldown between local ``grace ci`` + agent fix attempts for red PR checks."""
    if os.environ.get("SENTRY_CI_FIX_COOLDOWN_SEC", "").strip():
        return _env_int("SENTRY_CI_FIX_COOLDOWN_SEC", default_from_cursor)
    v = _opt_int(tom, "ci_fix_cooldown_seconds")
    return v if v is not None else default_from_cursor


def _merge_ci_fix_max_rounds_per_poll(tom: dict[str, Any]) -> int:
    """Max inner rounds (grace ci → agent passes) per merge poll for CI recovery."""
    if os.environ.get("SENTRY_CI_FIX_MAX_ROUNDS", "").strip():
        return max(1, _env_int("SENTRY_CI_FIX_MAX_ROUNDS", 5))
    v = _opt_int(tom, "ci_fix_max_rounds_per_poll")
    return max(1, v if v is not None else 5)


def _merge_cursor_start_phrases(tom: dict[str, Any]) -> tuple[str, ...]:
    if os.environ.get("SENTRY_CURSOR_START_PHRASES", "").strip():
        return _comma_list("SENTRY_CURSOR_START_PHRASES")
    t = _cursor_list_from_tom(tom, "cursor_start_phrases")
    if t is not None:
        return t
    return _DEFAULT_CURSOR_START_PHRASES


def _normalize_review_clear_mode(raw: str | None) -> str:
    if not raw:
        return "comment"
    n = str(raw).strip().lower()
    if n == "github":
        return "github"
    return "comment"


def _merge_review_clear_mode(tom: dict[str, Any]) -> str:
    if os.environ.get("SENTRY_REVIEW_CLEAR_MODE", "").strip():
        return _normalize_review_clear_mode(os.environ["SENTRY_REVIEW_CLEAR_MODE"].strip())
    return _normalize_review_clear_mode(_str_from_toml(tom, "review_clear_mode"))


def _merge_review_clear_block_outcomes(tom: dict[str, Any]) -> frozenset[str]:
    """Outcomes that do *not* clear the reviewer gate in ``comment`` mode (allowlist complement)."""
    if os.environ.get("SENTRY_REVIEW_CLEAR_BLOCK_OUTCOMES", "").strip():
        raw = os.environ["SENTRY_REVIEW_CLEAR_BLOCK_OUTCOMES"].strip()
        parts = [x.strip().lower() for x in raw.split(",") if x.strip()]
        return frozenset(parts)
    raw = tom.get("review_clear_block_outcomes")
    if isinstance(raw, list):
        return frozenset(str(x).strip().lower() for x in raw if str(x).strip())
    if isinstance(raw, str) and raw.strip():
        return frozenset(s.strip().lower() for s in raw.split(",") if s.strip())
    return frozenset(
        {
            "product_decision",
            "ci_failed",
            "error",
        }
    )


def _merge_review_outcome_templates(tom: dict[str, Any]) -> dict[str, str]:
    raw = tom.get("review_outcome_templates")
    overrides: dict[str, str] | None = None
    if isinstance(raw, dict):
        overrides = {str(k): str(v) for k, v in raw.items() if str(v).strip()}
    return merge_outcome_templates(DEFAULT_REVIEW_OUTCOME_TEMPLATES, overrides)


def _merge_review_clear_max_age_seconds(tom: dict[str, Any]) -> int:
    if os.environ.get("SENTRY_REVIEW_CLEAR_MAX_AGE_SEC", "").strip():
        return max(0, _env_int("SENTRY_REVIEW_CLEAR_MAX_AGE_SEC", 0))
    v = _opt_int(tom, "review_clear_comment_max_age_seconds")
    return max(0, v if v is not None else 0)


def _merge_fix_provider(tom: dict[str, Any]) -> str:
    if os.environ.get("SENTRY_FIX_PROVIDER", "").strip():
        return _normalize_fix_provider(os.environ["SENTRY_FIX_PROVIDER"])
    raw = _str_from_toml(tom, "fix_provider")
    return _normalize_fix_provider(raw) if raw else "http"


def _merge_split_args(
    env_key: str,
    tom: dict[str, Any],
    toml_key: str,
    default: str,
) -> tuple[str, ...]:
    if os.environ.get(env_key, "").strip():
        return tuple(shlex.split(os.environ[env_key].strip()))
    raw = _split_args_from_toml(tom.get(toml_key))
    if raw is not None:
        return raw
    return _split_shell(env_key, default)


@dataclass(frozen=True)
class SentrySettings:
    """Resolved configuration: TOML ``[sentry]`` then environment (env overrides)."""

    approval_phrase: str
    approval_users: tuple[str, ...]
    copilot_wait_seconds: int
    arbitration_stuck_seconds: int
    llm_base_url: str | None
    llm_model: str
    llm_api_key_env: str
    interval_seconds: int
    max_retries: int
    retry_base_seconds: float
    ci_profile: str | None
    fix_provider: str
    agent_bin: str
    agent_prefix_args: tuple[str, ...]
    agent_extra_args: tuple[str, ...]
    agent_timeout_sec: int
    main_branch: str
    yield_on_approval_pending: bool
    sentry_branch_prefix: str
    cursor_reviewer_logins: tuple[str, ...]
    reviewer_logins: tuple[str, ...]
    cursor_start_phrases: tuple[str, ...]
    cursor_post_review_trigger: bool
    merge_sweep_budget_seconds: int
    merge_sweep_total_budget_seconds: int
    review_silence_timeout_seconds: int
    review_fix_cooldown_seconds: int
    cursor_review_fix_cooldown_seconds: int
    ci_fix_cooldown_seconds: int
    ci_fix_max_rounds_per_poll: int
    review_clear_mode: str
    review_outcome_templates: dict[str, str]
    review_clear_block_outcomes: frozenset[str]
    review_clear_comment_max_age_seconds: int

    @classmethod
    def from_repo(cls, repo_root: Path) -> SentrySettings:
        tom = load_sentry_table(repo_root=repo_root)
        cursor_reviewer_logins = _merge_cursor_reviewer_logins(tom)
        reviewer_logins = _merge_reviewer_logins(tom)
        interval_sec = _merge_int("SENTRY_INTERVAL_SEC", tom, "interval_seconds", 30)
        copilot_wait = _merge_int(
            "SENTRY_COPILOT_WAIT_SEC",
            tom,
            "copilot_wait_seconds",
            15 * 60,
        )
        review_silence = _merge_int(
            "SENTRY_REVIEW_SILENCE_TIMEOUT_SEC",
            tom,
            "review_silence_timeout_seconds",
            copilot_wait,
        )
        fix_cooldown_base = _merge_review_fix_cooldown_base(tom)
        fix_cooldown_cursor = _merge_cursor_review_fix_cooldown_seconds(tom, fix_cooldown_base)
        ci_fix_cooldown = _merge_ci_fix_cooldown_seconds(tom, fix_cooldown_cursor)
        ci_fix_max_rounds = _merge_ci_fix_max_rounds_per_poll(tom)
        review_clear_mode = _merge_review_clear_mode(tom)
        review_templates = _merge_review_outcome_templates(tom)
        review_block = _merge_review_clear_block_outcomes(tom)
        review_max_age = _merge_review_clear_max_age_seconds(tom)
        merge_sweep_per = _merge_int(
            "SENTRY_MERGE_SWEEP_BUDGET_SEC",
            tom,
            "merge_sweep_budget_seconds",
            max(120, interval_sec * 2),
        )
        merge_sweep_total = _merge_int(
            "SENTRY_MERGE_SWEEP_TOTAL_BUDGET_SEC",
            tom,
            "merge_sweep_total_budget_seconds",
            0,
        )
        return cls(
            approval_phrase=_merge_str(
                "SENTRY_APPROVAL_PHRASE",
                tom,
                "approval_phrase",
                "/sentry-approve",
            ),
            approval_users=_merge_approval_users(tom),
            copilot_wait_seconds=copilot_wait,
            arbitration_stuck_seconds=_merge_int(
                "SENTRY_ARBITRATION_STUCK_SEC",
                tom,
                "arbitration_stuck_seconds",
                48 * 3600,
            ),
            llm_base_url=_merge_opt_str("SENTRY_LLM_BASE_URL", tom, "llm_base_url"),
            llm_model=_merge_str("SENTRY_LLM_MODEL", tom, "llm_model", "gpt-4o-mini"),
            llm_api_key_env=_merge_str(
                "SENTRY_LLM_API_KEY_ENV",
                tom,
                "llm_api_key_env",
                "OPENAI_API_KEY",
            ),
            interval_seconds=interval_sec,
            max_retries=_merge_int("SENTRY_MAX_RETRIES", tom, "max_retries", 8),
            retry_base_seconds=_merge_float(
                "SENTRY_RETRY_BASE_SEC",
                tom,
                "retry_base_seconds",
                1.5,
            ),
            ci_profile=_merge_opt_str("SENTRY_CI_PROFILE", tom, "ci_profile"),
            fix_provider=_merge_fix_provider(tom),
            agent_bin=_merge_str("SENTRY_AGENT_BIN", tom, "agent_bin", "agent"),
            agent_prefix_args=_merge_split_args(
                "SENTRY_AGENT_PREFIX_ARGS",
                tom,
                "agent_prefix_args",
                "chat",
            ),
            agent_extra_args=_merge_split_args(
                "SENTRY_AGENT_EXTRA_ARGS",
                tom,
                "agent_extra_args",
                "",
            ),
            agent_timeout_sec=_merge_int(
                "SENTRY_AGENT_TIMEOUT_SEC",
                tom,
                "agent_timeout_sec",
                900,
            ),
            main_branch=_merge_str("SENTRY_MAIN_BRANCH", tom, "main_branch", "main"),
            yield_on_approval_pending=_merge_bool(
                "SENTRY_YIELD_ON_APPROVAL_PENDING",
                tom,
                "yield_on_approval_pending",
                True,
            ),
            sentry_branch_prefix=_merge_str(
                "SENTRY_BRANCH_PREFIX",
                tom,
                "sentry_branch_prefix",
                "sentry/auto-",
            ),
            cursor_reviewer_logins=cursor_reviewer_logins,
            reviewer_logins=reviewer_logins,
            cursor_start_phrases=_merge_cursor_start_phrases(tom),
            cursor_post_review_trigger=_merge_bool(
                "SENTRY_CURSOR_POST_REVIEW",
                tom,
                "cursor_post_review_trigger",
                bool(cursor_reviewer_logins),
            ),
            merge_sweep_budget_seconds=merge_sweep_per,
            merge_sweep_total_budget_seconds=merge_sweep_total,
            review_silence_timeout_seconds=review_silence,
            review_fix_cooldown_seconds=fix_cooldown_base,
            cursor_review_fix_cooldown_seconds=fix_cooldown_cursor,
            ci_fix_cooldown_seconds=ci_fix_cooldown,
            ci_fix_max_rounds_per_poll=ci_fix_max_rounds,
            review_clear_mode=review_clear_mode,
            review_outcome_templates=review_templates,
            review_clear_block_outcomes=review_block,
            review_clear_comment_max_age_seconds=review_max_age,
        )

    @classmethod
    def from_environ(cls) -> SentrySettings:
        """Load using repo discovery from the current working directory."""
        return cls.from_repo(discover_repo_root())
