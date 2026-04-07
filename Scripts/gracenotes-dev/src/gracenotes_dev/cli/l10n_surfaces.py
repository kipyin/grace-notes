"""Product-surface taxonomy for ``grace l10n review`` (issue #224)."""

from __future__ import annotations

from pathlib import Path

import tomlkit

SURFACE_FIRST_RUN = "first_run"
SURFACE_TODAY = "today"
SURFACE_PAST = "past"
SURFACE_SETTINGS = "settings"
SURFACE_SHARED = "shared"

_ALL_SURFACES = frozenset(
    {
        SURFACE_FIRST_RUN,
        SURFACE_TODAY,
        SURFACE_PAST,
        SURFACE_SETTINGS,
        SURFACE_SHARED,
    },
)

# Lower sorts first: primary picks min by this key.
_SURFACE_PRIORITY: dict[str, int] = {
    SURFACE_FIRST_RUN: 0,
    SURFACE_TODAY: 1,
    SURFACE_PAST: 2,
    SURFACE_SETTINGS: 3,
    SURFACE_SHARED: 4,
}

_PAST_PATH_MARKERS: tuple[str, ...] = (
    "PastJournal",
    "PastSearch",
    "ReviewScreen",
    "ReviewHistory",
    "ReviewSummary",
    "ReviewTrending",
    "ReviewMostRecurring",
    "ReviewInsight",
    "PastStatistics",
    "PastTappable",
)

_OVERRIDES_FILENAME = "l10n-review-overrides.toml"


def _norm_rel(p: str) -> str:
    return p.replace("\\", "/")


def surface_for_path(rel_path: str) -> str:
    """Classify a Swift source path using path-shaped rules only (for tests / path hints)."""
    return surface_for_key_and_path("", rel_path)


def _surface_from_prefix(key: str) -> str | None:
    if key.startswith(("onboarding.", "tutorial.", "startup.")):
        return SURFACE_FIRST_RUN
    if key.startswith(("settings.", "data.")):
        return SURFACE_SETTINGS
    if key.startswith(("past.", "review.")):
        return SURFACE_PAST
    if key.startswith(("journal.", "calendar.", "sharing.")):
        return SURFACE_TODAY
    if key.startswith(("common.", "shell.", "app.", "accessibility.")):
        return SURFACE_SHARED
    return None


def surface_for_key_and_path(key: str, rel_path: str) -> str:
    """First path rules (2–6), then key-prefix rules (7–12), else shared."""
    norm = _norm_rel(rel_path)
    if "Features/Onboarding/" in norm:
        return SURFACE_FIRST_RUN
    if "/Tutorial/" in norm or "AppTourView" in norm:
        return SURFACE_FIRST_RUN
    if "Features/Settings/" in norm:
        return SURFACE_SETTINGS
    if any(m in norm for m in _PAST_PATH_MARKERS):
        return SURFACE_PAST
    if "Features/Journal/" in norm:
        return SURFACE_TODAY
    pref = _surface_from_prefix(key)
    if pref is not None:
        return pref
    return SURFACE_SHARED


def load_surface_overrides(repo_root: Path) -> dict[str, str]:
    """Load optional ``[keys]`` table from ``l10n-review-overrides.toml`` under repo root."""
    path = repo_root / _OVERRIDES_FILENAME
    if not path.is_file():
        return {}
    data = tomlkit.parse(path.read_text(encoding="utf-8"))
    table = data.get("keys")
    if table is None:
        return {}
    out: dict[str, str] = {}
    for k, v in table.items():
        if not isinstance(k, str) or not isinstance(v, str):
            continue
        if v not in _ALL_SURFACES:
            continue
        out[k] = v
    return out


def primary_surface_for_key(
    key: str,
    paths: list[str],
    *,
    overrides: dict[str, str],
) -> tuple[str, frozenset[str]]:
    """Return primary surface and other surfaces seen in code paths (excluding primary)."""
    natural: set[str] = set()
    if paths:
        for rel in paths:
            natural.add(surface_for_key_and_path(key, rel))
    else:
        natural.add(surface_for_key_and_path(key, ""))

    primary: str
    if key in overrides:
        primary = overrides[key]
    else:
        primary = min(natural, key=lambda s: _SURFACE_PRIORITY[s])

    also = frozenset(s for s in natural if s != primary)
    return primary, also
