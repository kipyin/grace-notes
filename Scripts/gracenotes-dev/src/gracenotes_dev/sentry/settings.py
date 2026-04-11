"""Environment-backed settings for ``grace sentry``."""

from __future__ import annotations

import os
from dataclasses import dataclass


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


@dataclass(frozen=True)
class SentrySettings:
    """Resolved configuration (see plan: defaults overridable via env)."""

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

    @classmethod
    def from_environ(cls) -> SentrySettings:
        prof = os.environ.get("SENTRY_CI_PROFILE", "").strip()
        return cls(
            copilot_login=os.environ.get("SENTRY_COPILOT_LOGIN", "").strip() or None,
            approval_phrase=os.environ.get("SENTRY_APPROVAL_PHRASE", "/sentry-approve").strip()
            or "/sentry-approve",
            approval_users=_comma_list("SENTRY_APPROVAL_USERS"),
            copilot_wait_seconds=_env_int("SENTRY_COPILOT_WAIT_SEC", 15 * 60),
            arbitration_stuck_seconds=_env_int("SENTRY_ARBITRATION_STUCK_SEC", 48 * 3600),
            llm_base_url=os.environ.get("SENTRY_LLM_BASE_URL", "").strip() or None,
            llm_model=os.environ.get("SENTRY_LLM_MODEL", "gpt-4o-mini").strip() or "gpt-4o-mini",
            llm_api_key_env=os.environ.get("SENTRY_LLM_API_KEY_ENV", "OPENAI_API_KEY").strip()
            or "OPENAI_API_KEY",
            interval_seconds=_env_int("SENTRY_INTERVAL_SEC", 300),
            max_retries=_env_int("SENTRY_MAX_RETRIES", 8),
            retry_base_seconds=_env_float("SENTRY_RETRY_BASE_SEC", 1.5),
            ci_profile=prof or None,
        )
