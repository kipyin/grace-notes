"""Scannable PR title/body for automated sentry PRs."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from gracenotes_dev.sentry.classify import TouchClass


@dataclass(frozen=True)
class PrMaterial:
    """LLM/agent-produced PR title and narrative (gh-style: headline, impact, change, verify)."""

    title: str
    headline: str
    user_impact: str
    what_changed: str
    verification: str


def fallback_pr_material(relative_path: str) -> PrMaterial:
    """When the PR-description model step fails, still open a readable PR."""
    name = Path(relative_path).name
    return PrMaterial(
        title=f"Sentry: refine {name}",
        headline="Automated refinement from `grace sentry`.",
        user_impact="Maintainers get a small scoped change with CI preflight before review.",
        what_changed=f"Updates `{relative_path}` in a single automated pass (see diff on the PR).",
        verification="`grace ci` on macOS using the configured sentry CI profile.",
    )


def build_pr_body(
    *,
    summary_bullets: list[str],
    risk: str,
    touch: TouchClass,
    needs_human_line: bool,
    approval_phrase: str,
) -> str:
    """Legacy bullet-only body; prefer :func:`build_pr_body_from_material`."""
    bullets = "\n".join(f"- {b}" for b in summary_bullets[:5])
    human_section = ""
    if needs_human_line:
        human_section = (
            f"\n## Human\n\nPost `{approval_phrase}` from an allowlisted account to merge "
            "when review is satisfied.\n"
        )
    return (
        f"## Summary\n\n{bullets}\n\n"
        f"## Risk\n\n{risk}\n\n"
        f"## Touch class\n\n`{touch.value}`\n"
        f"{human_section}"
        "---\n"
        "*Automated by `grace sentry`.* "
        f"If Copilot review threads block merge, post `{approval_phrase}` "
        "from an allowlisted account.\n"
    )


def build_pr_body_from_material(
    material: PrMaterial,
    *,
    risk: str,
    touch: TouchClass,
    needs_human_line: bool,
    approval_phrase: str,
) -> str:
    """Full PR body: product narrative first, then risk/touch/human (per gh/explain style)."""
    human_section = ""
    if needs_human_line:
        human_section = (
            f"\n## Human\n\nPost `{approval_phrase}` from an allowlisted account to merge "
            "when review is satisfied.\n"
        )
    return (
        f"## Headline\n\n{material.headline}\n\n"
        f"## User impact\n\n{material.user_impact}\n\n"
        f"## What changed\n\n{material.what_changed}\n\n"
        f"## Verification\n\n{material.verification}\n\n"
        f"## Risk\n\n{risk}\n\n"
        f"## Touch class\n\n`{touch.value}`\n"
        f"{human_section}"
        "---\n"
        "*Automated by `grace sentry`.* "
        f"If Copilot review threads block merge, post `{approval_phrase}` "
        "from an allowlisted account.\n"
    )


def risk_label_for_touch(touch: TouchClass) -> str:
    if touch == TouchClass.LOW_TOUCH:
        return "Low"
    if touch == TouchClass.UI_UX:
        return "Medium"
    return "Medium"
