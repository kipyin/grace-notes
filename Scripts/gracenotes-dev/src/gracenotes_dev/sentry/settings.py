"""Sentry settings: ``gracenotes-dev.toml`` ``[sentry]`` + environment (env wins)."""

from __future__ import annotations

import os
import shlex
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from gracenotes_dev.config import discover_repo_root, load_sentry_table


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


def _merge_approval_users(tom: dict[str, Any]) -> tuple[str, ...]:
    if os.environ.get("SENTRY_APPROVAL_USERS", "").strip():
        return _comma_list("SENTRY_APPROVAL_USERS")
    t = _approval_from_tom(tom)
    return t if t is not None else ()


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

    copilot_login: str | None
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

    @classmethod
    def from_repo(cls, repo_root: Path) -> SentrySettings:
        tom = load_sentry_table(repo_root=repo_root)
        return cls(
            copilot_login=_merge_opt_str("SENTRY_COPILOT_LOGIN", tom, "copilot_login"),
            approval_phrase=_merge_str(
                "SENTRY_APPROVAL_PHRASE",
                tom,
                "approval_phrase",
                "/sentry-approve",
            ),
            approval_users=_merge_approval_users(tom),
            copilot_wait_seconds=_merge_int(
                "SENTRY_COPILOT_WAIT_SEC",
                tom,
                "copilot_wait_seconds",
                15 * 60,
            ),
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
            interval_seconds=_merge_int("SENTRY_INTERVAL_SEC", tom, "interval_seconds", 300),
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
        )

    @classmethod
    def from_environ(cls) -> SentrySettings:
        """Load using repo discovery from the current working directory."""
        return cls.from_repo(discover_repo_root())
