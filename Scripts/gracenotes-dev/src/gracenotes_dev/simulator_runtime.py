"""Helpers for simulator runtime install/list/delete command argv and parsing."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

_RUNTIME_LINE_RE = re.compile(
    r"^(?P<platform>[A-Za-z0-9]+)\s+"
    r"(?P<version>[0-9][0-9A-Za-z.\-]*)\s+"
    r"\((?P<build>[^)]+)\)\s+-\s+"
    r"(?P<identifier>[A-F0-9\-]+)"
    r"(?:\s+\((?P<state>[^)]+)\))?$",
)


@dataclass(frozen=True)
class RuntimeRecord:
    identifier: str
    platform: str
    version: str
    build: str
    state: str
    runtime_identifier: str | None = None
    deletable: bool | None = None


def xcode_download_platform_argv(*, export_path: Path, build_version: str | None = None) -> list[str]:
    argv = [
        "xcodebuild",
        "-downloadPlatform",
        "iOS",
        "-exportPath",
        str(export_path),
    ]
    if build_version:
        argv.extend(["-buildVersion", build_version])
    return argv


def xcode_import_platform_argv(*, dmg_path: Path) -> list[str]:
    return ["xcodebuild", "-importPlatform", str(dmg_path)]


def simctl_runtime_add_argv(*, dmg_path: Path, move: bool = False, async_mode: bool = False) -> list[str]:
    argv = ["xcrun", "simctl", "runtime", "add", str(dmg_path)]
    if move:
        argv.append("--move")
    if async_mode:
        argv.append("--async")
    return argv


def simctl_runtime_list_argv(*, json_out: bool, verbose: bool = False) -> list[str]:
    argv = ["xcrun", "simctl", "runtime", "list"]
    if verbose:
        argv.append("-v")
    if json_out:
        argv.append("-j")
    return argv


def simctl_runtime_delete_argv(
    *,
    identifier: str,
    dry_run: bool = False,
    keep_asset: bool = False,
) -> list[str]:
    argv = ["xcrun", "simctl", "runtime", "delete", identifier]
    if dry_run:
        argv.append("--dry-run")
    if keep_asset:
        argv.append("--keep-asset")
    return argv


def discover_downloaded_dmg(*, export_path: Path, platform_name: str = "iOS") -> Path:
    if not export_path.exists():
        raise FileNotFoundError(f"Export path does not exist: {export_path}")

    dmgs = [path for path in export_path.rglob("*.dmg") if path.is_file()]
    if not dmgs:
        raise FileNotFoundError(f"No simulator runtime DMG found under {export_path}")

    token = platform_name.lower()
    preferred = [path for path in dmgs if token in path.name.lower()]
    candidates = preferred or dmgs
    candidates.sort(key=lambda item: item.stat().st_mtime, reverse=True)
    return candidates[0]


def parse_runtime_list_json(raw: str) -> list[RuntimeRecord]:
    payload: Any = json.loads(raw or "{}")
    rows: list[RuntimeRecord] = []

    if isinstance(payload, dict) and isinstance(payload.get("runtimes"), list):
        entries: list[dict[str, Any]] = [entry for entry in payload["runtimes"] if isinstance(entry, dict)]
    elif isinstance(payload, dict):
        entries = [entry for entry in payload.values() if isinstance(entry, dict)]
    else:
        entries = []

    for entry in entries:
        identifier = str(entry.get("identifier", "")).strip()
        runtime_identifier = str(entry.get("runtimeIdentifier", "")).strip() or None
        platform = _platform_from_runtime_identifier(runtime_identifier)
        if not platform:
            platform = _platform_from_identifier(str(entry.get("platformIdentifier", "")).strip()) or "unknown"
        state = str(entry.get("state", "")).strip() or "unknown"
        version = str(entry.get("version", "")).strip() or "unknown"
        build = str(entry.get("build", "")).strip() or "unknown"
        deletable_raw = entry.get("deletable")
        deletable = bool(deletable_raw) if isinstance(deletable_raw, bool) else None
        rows.append(
            RuntimeRecord(
                identifier=identifier,
                platform=platform,
                version=version,
                build=build,
                state=state,
                runtime_identifier=runtime_identifier,
                deletable=deletable,
            ),
        )
    return sorted(rows, key=_runtime_sort_key)


def parse_runtime_list_text(raw: str) -> list[RuntimeRecord]:
    rows: list[RuntimeRecord] = []
    for line in raw.splitlines():
        match = _RUNTIME_LINE_RE.match(line.strip())
        if not match:
            continue
        rows.append(
            RuntimeRecord(
                identifier=match.group("identifier"),
                platform=match.group("platform"),
                version=match.group("version"),
                build=match.group("build"),
                state=(match.group("state") or "unknown"),
            ),
        )
    return sorted(rows, key=_runtime_sort_key)


def runtime_record_to_dict(row: RuntimeRecord) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "identifier": row.identifier,
        "platform": row.platform,
        "version": row.version,
        "build": row.build,
        "state": row.state,
    }
    if row.runtime_identifier:
        payload["runtime_identifier"] = row.runtime_identifier
    if row.deletable is not None:
        payload["deletable"] = row.deletable
    return payload


def _platform_from_identifier(platform_identifier: str) -> str | None:
    lowered = platform_identifier.lower()
    if "iphonesimulator" in lowered:
        return "iOS"
    if "appletvsimulator" in lowered:
        return "tvOS"
    if "watchsimulator" in lowered:
        return "watchOS"
    if "xrsimulator" in lowered:
        return "visionOS"
    return None


def _platform_from_runtime_identifier(runtime_identifier: str | None) -> str | None:
    if not runtime_identifier:
        return None
    if ".iOS-" in runtime_identifier:
        return "iOS"
    if ".tvOS-" in runtime_identifier:
        return "tvOS"
    if ".watchOS-" in runtime_identifier:
        return "watchOS"
    if ".xrOS-" in runtime_identifier:
        return "visionOS"
    return None


def _runtime_sort_key(row: RuntimeRecord) -> tuple[str, tuple[int, ...], str, str]:
    return (row.platform, _version_key(row.version), row.build, row.identifier)


def _version_key(version: str) -> tuple[int, ...]:
    values: list[int] = []
    for piece in version.split("."):
        if piece.isdigit():
            values.append(int(piece))
            continue
        numeric = "".join(ch for ch in piece if ch.isdigit())
        values.append(int(numeric) if numeric else 0)
    return tuple(values)
