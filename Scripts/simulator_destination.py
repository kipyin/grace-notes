#!/usr/bin/env python3
"""Resolve and validate iOS simulator destinations for make targets.

Thin delegator to ``gracenotes_dev.simulator`` so external callers can keep
invoking ``python3 Scripts/simulator_destination.py …`` without installing the package.
Prefer ``grace sim …`` after ``pip install -e Scripts/gracenotes-dev``.
"""

from __future__ import annotations

import sys
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
_SRC = _SCRIPTS_DIR / "gracenotes-dev" / "src"
if _SRC.is_dir() and str(_SRC) not in sys.path:
    sys.path.insert(0, str(_SRC))

from gracenotes_dev.simulator import run_legacy_cli

if __name__ == "__main__":
    raise SystemExit(run_legacy_cli())
