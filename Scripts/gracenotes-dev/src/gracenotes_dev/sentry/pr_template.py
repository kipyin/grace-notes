"""Scannable PR title/body for automated sentry PRs."""

from __future__ import annotations

from gracenotes_dev.sentry.classify import TouchClass


def build_pr_body(
    *,
    summary_bullets: list[str],
    risk: str,
    touch: TouchClass,
    needs_human_line: bool,
    approval_phrase: str,
) -> str:
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
        "---\n*Automated by `grace sentry`.*\n"
    )


def risk_label_for_touch(touch: TouchClass) -> str:
    if touch == TouchClass.LOW_TOUCH:
        return "Low"
    if touch == TouchClass.UI_UX:
        return "Medium"
    return "Medium"
