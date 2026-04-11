"""Parse ``owner/repo`` from ``git remote``."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

_GH_SSH = re.compile(r"git@github\.com:([^/]+)/([^/.]+)(?:\.git)?$")
_GH_HTTPS = re.compile(r"https://github\.com/([^/]+)/([^/.]+)(?:\.git)?/?$")


def git_remote_owner_repo(repo_root: Path) -> tuple[str, str] | None:
    """Return (owner, repo) from origin, or None if unavailable."""
    try:
        out = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            cwd=repo_root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    m = _GH_SSH.match(out) or _GH_HTTPS.match(out)
    if not m:
        return None
    return m.group(1), m.group(2)
