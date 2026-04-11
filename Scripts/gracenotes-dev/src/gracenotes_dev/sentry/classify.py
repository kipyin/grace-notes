"""Touch classification: path heuristics first; optional LLM assist."""

from __future__ import annotations

import re
from enum import Enum


class TouchClass(str, Enum):
    LOW_TOUCH = "low-touch"
    BUSINESS_LOGIC = "business-logic"
    UI_UX = "ui-ux"


_VIEWISH = re.compile(
    r"(^|/)(Views?/|.*View\.swift|.*Screen\.swift|.*Sheet\.swift|.*Modifier\.swift)",
    re.IGNORECASE,
)


def classify_paths(paths: list[str]) -> TouchClass:
    """Path-first classification; ambiguous → high-touch (business-logic)."""
    if not paths:
        return TouchClass.BUSINESS_LOGIC

    scores = {TouchClass.LOW_TOUCH: 0, TouchClass.BUSINESS_LOGIC: 0, TouchClass.UI_UX: 0}

    for p in paths:
        norm = p.replace("\\", "/")
        low = norm.lower()
        if "/tests/" in low or low.endswith("tests.swift") or "/gracenotestests/" in low:
            scores[TouchClass.LOW_TOUCH] += 2
        if _VIEWISH.search(norm) or "/views/" in low:
            scores[TouchClass.UI_UX] += 2
        if any(
            x in low
            for x in (
                "/services/",
                "/repository",
                "journalrepository",
                "/data/",
                "/model",
                "persistence",
                "summariz",
            )
        ):
            scores[TouchClass.BUSINESS_LOGIC] += 2

    ui = scores[TouchClass.UI_UX]
    biz = scores[TouchClass.BUSINESS_LOGIC]
    if ui >= 2 and ui >= biz:
        return TouchClass.UI_UX
    if scores[TouchClass.LOW_TOUCH] >= 2 and scores[TouchClass.LOW_TOUCH] >= max(
        scores[TouchClass.BUSINESS_LOGIC],
        scores[TouchClass.UI_UX],
    ):
        return TouchClass.LOW_TOUCH
    if scores[TouchClass.BUSINESS_LOGIC] > 0 or scores[TouchClass.UI_UX] > 0:
        if scores[TouchClass.UI_UX] > scores[TouchClass.BUSINESS_LOGIC]:
            return TouchClass.UI_UX
        return TouchClass.BUSINESS_LOGIC
    return TouchClass.BUSINESS_LOGIC


def is_high_touch(tc: TouchClass) -> bool:
    return tc in (TouchClass.BUSINESS_LOGIC, TouchClass.UI_UX)
