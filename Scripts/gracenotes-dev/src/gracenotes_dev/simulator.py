"""Resolve and validate iOS simulator destinations (migrated from Scripts/simulator_destination.py)."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from typing import Dict, List, Optional, Sequence, Set, Tuple


def usage() -> None:
    print(
        """Usage:
  python3 Scripts/simulator_destination.py list
  python3 Scripts/simulator_destination.py resolve "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3"
  python3 Scripts/simulator_destination.py name "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3"
  python3 Scripts/simulator_destination.py matrix-destinations "iPhone XR@17.5;iPhone 17 Pro@26.3"

Notes:
  - Each matrix entry can be either:
      1) device@os (for example: iPhone XR@17.5)
      2) full destination string (platform=iOS Simulator,name=...,OS=...)
  - OS=latest resolves to the newest installed iOS runtime for the requested device.
""".strip()
    )


def version_tuple(version: str) -> Tuple[int, ...]:
    return tuple(int(piece) for piece in version.split("."))


def parse_destination(destination: str) -> Dict[str, str]:
    parts = [part.strip() for part in destination.split(",") if part.strip()]
    fields: Dict[str, str] = {}
    for part in parts:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        fields[key.strip()] = value.strip()
    return fields


def destination_display_name(destination: str) -> str:
    """Return the Simulator device name from a full ``platform=…,name=…,OS=…`` string."""
    fields = parse_destination(destination)
    name = fields.get("name")
    if not name:
        print("ERROR: destination does not contain name=", file=sys.stderr)
        sys.exit(2)
    return name


def parse_runtime_version_from_key(runtime_key: str) -> Optional[str]:
    # Common key style: com.apple.CoreSimulator.SimRuntime.iOS-18-2
    match = re.search(r"iOS-([0-9]+(?:-[0-9]+)*)", runtime_key)
    if match:
        return match.group(1).replace("-", ".")

    # Fallback style: iOS 18.2
    match = re.search(r"iOS ([0-9]+(?:\.[0-9]+)*)", runtime_key)
    if match:
        return match.group(1)
    return None


def _simctl_json(simctl_args: List[str]) -> dict:
    """Run ``xcrun simctl … --json`` and parse JSON. Exit 4 on tooling failures."""
    cmd = ["xcrun", "simctl", *simctl_args]
    try:
        completed = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
        )
    except FileNotFoundError:
        print(
            "ERROR: `xcrun` was not found. Install Xcode and use the full Xcode app "
            "(not Command Line Tools only) for iOS Simulator support.",
            file=sys.stderr,
        )
        sys.exit(4)
    except subprocess.CalledProcessError as exc:
        print("ERROR: simctl command failed:", file=sys.stderr)
        print(" ", " ".join(cmd), file=sys.stderr)
        err_out = (exc.stderr or "").strip()
        if err_out:
            print(err_out, file=sys.stderr)
        print(
            "",
            "If Xcode is installed, select it with:",
            "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer",
            sep="\n",
            file=sys.stderr,
        )
        sys.exit(4)

    try:
        return json.loads(completed.stdout)
    except json.JSONDecodeError:
        print(
            "ERROR: simctl returned output that is not valid JSON. "
            "Try updating Xcode or re-running the command.",
            file=sys.stderr,
        )
        sys.exit(4)


def load_runtime_versions() -> Dict[str, str]:
    data = _simctl_json(["list", "runtimes", "--json"])
    versions: Dict[str, str] = {}
    for runtime in data.get("runtimes", []):
        identifier = runtime.get("identifier", "")
        if not identifier.startswith("com.apple.CoreSimulator.SimRuntime.iOS"):
            continue
        version = runtime.get("version")
        if version:
            versions[identifier] = version
    return versions


def load_available_ios_devices() -> List[Dict[str, str]]:
    data = _simctl_json(["list", "devices", "available", "--json"])
    runtime_versions = load_runtime_versions()

    rows: List[Dict[str, str]] = []
    for runtime_key, devices in data.get("devices", {}).items():
        if "iOS" not in runtime_key:
            continue

        runtime_version = runtime_versions.get(runtime_key) or parse_runtime_version_from_key(runtime_key)
        if runtime_version is None:
            continue

        for device in devices:
            if not device.get("isAvailable", False):
                continue
            rows.append(
                {
                    "name": device.get("name", ""),
                    "runtime_version": runtime_version,
                    "runtime_key": runtime_key,
                    "udid": device.get("udid", ""),
                }
            )
    return rows


def fail_with_guidance(message: str, rows: List[Dict[str, str]]) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    print("", file=sys.stderr)
    print("Installed iOS simulator device/runtime pairs:", file=sys.stderr)

    if not rows:
        print("  (none found)", file=sys.stderr)
    else:
        seen: Set[Tuple[str, str]] = set()
        for row in sorted(rows, key=lambda item: (item["name"], version_tuple(item["runtime_version"]))):
            key = (row["name"], row["runtime_version"])
            if key in seen:
                continue
            seen.add(key)
            print(f"  - {row['name']} (iOS {row['runtime_version']})", file=sys.stderr)

    print("", file=sys.stderr)
    print("To add missing simulators on macOS:", file=sys.stderr)
    print("  1) Open Xcode > Settings > Platforms and install the iOS runtime.", file=sys.stderr)
    print("  2) Open Xcode > Window > Devices and Simulators and add the device type.", file=sys.stderr)
    print("  3) Re-run: grace sim list", file=sys.stderr)
    sys.exit(3)


def resolve_destination(destination: str, rows: List[Dict[str, str]]) -> str:
    fields = parse_destination(destination)
    platform = fields.get("platform")
    name = fields.get("name")
    os_value = fields.get("OS")

    if platform != "iOS Simulator" or not name or not os_value:
        print(
            "ERROR: destination must include platform=iOS Simulator,name=<device>,OS=<version|latest>",
            file=sys.stderr,
        )
        print(f"Received: {destination}", file=sys.stderr)
        sys.exit(2)

    matching = [row for row in rows if row["name"] == name]
    if not matching:
        fail_with_guidance(f"Device '{name}' is not installed.", rows)

    if os_value == "latest":
        resolved_runtime = max(
            matching,
            key=lambda row: version_tuple(row["runtime_version"]),
        )["runtime_version"]
        return f"platform=iOS Simulator,name={name},OS={resolved_runtime}"

    exact = [
        row
        for row in matching
        if row["runtime_version"] == os_value or row["runtime_version"].startswith(f"{os_value}.")
    ]
    if not exact:
        available_versions = sorted(
            {row["runtime_version"] for row in matching},
            key=version_tuple,
        )
        fail_with_guidance(
            f"Device '{name}' does not have iOS {os_value}. Available versions: {', '.join(available_versions)}",
            rows,
        )

    resolved_runtime = sorted(
        {row["runtime_version"] for row in exact},
        key=version_tuple,
    )[-1]
    return f"platform=iOS Simulator,name={name},OS={resolved_runtime}"


def row_for_resolved_destination(
    resolved_destination: str,
    rows: List[Dict[str, str]],
) -> Optional[Dict[str, str]]:
    """Return one device row (including ``udid``) matching a resolved ``platform=…`` destination string."""
    fields = parse_destination(resolved_destination)
    name = fields.get("name")
    os_value = fields.get("OS")
    if not name or not os_value:
        return None
    matching = [row for row in rows if row["name"] == name]
    if not matching:
        return None
    if os_value == "latest":
        return max(matching, key=lambda row: version_tuple(row["runtime_version"]))
    exact = [
        row
        for row in matching
        if row["runtime_version"] == os_value or row["runtime_version"].startswith(f"{os_value}.")
    ]
    if not exact:
        return None
    resolved_runtime = sorted({row["runtime_version"] for row in exact}, key=version_tuple)[-1]
    candidates = [row for row in exact if row["runtime_version"] == resolved_runtime]
    candidates.sort(key=lambda r: r.get("udid", ""))
    return candidates[0] if candidates else None


def list_destinations(rows: List[Dict[str, str]]) -> None:
    seen: Set[Tuple[str, str]] = set()
    for row in sorted(rows, key=lambda item: (item["name"], version_tuple(item["runtime_version"]))):
        key = (row["name"], row["runtime_version"])
        if key in seen:
            continue
        seen.add(key)
        print(f"platform=iOS Simulator,name={row['name']},OS={row['runtime_version']}")


def matrix_destinations_lines(spec: str, rows: List[Dict[str, str]]) -> List[str]:
    """Return resolved destination lines for a matrix spec (semicolon-separated)."""
    entries = [entry.strip() for entry in spec.split(";") if entry.strip()]
    if not entries:
        print("ERROR: matrix specification is empty.", file=sys.stderr)
        sys.exit(2)

    lines: List[str] = []
    for entry in entries:
        if entry.startswith("platform="):
            destination = entry
        else:
            if "@" not in entry:
                print(
                    f"ERROR: invalid matrix entry '{entry}'. Expected device@os or full destination.",
                    file=sys.stderr,
                )
                sys.exit(2)
            name, os_value = entry.rsplit("@", 1)
            destination = f"platform=iOS Simulator,name={name.strip()},OS={os_value.strip()}"
        lines.append(resolve_destination(destination, rows))
    return lines


def emit_matrix_destinations(spec: str, rows: List[Dict[str, str]]) -> None:
    for line in matrix_destinations_lines(spec, rows):
        print(line)


def run_legacy_cli(argv: Optional[Sequence[str]] = None) -> int:
    """CLI parity with ``Scripts/simulator_destination.py`` (for the thin shim)."""
    args = list(sys.argv[1:] if argv is None else argv)
    if not args:
        usage()
        return 2

    command_name = args[0]
    command_args = args[1:]

    if command_name == "name":
        if len(command_args) != 1:
            print("ERROR: name command expects exactly one destination argument.", file=sys.stderr)
            return 2
        print(destination_display_name(command_args[0]))
        return 0

    rows = load_available_ios_devices()

    if command_name == "list":
        list_destinations(rows)
        return 0
    if command_name == "resolve":
        if len(command_args) != 1:
            print("ERROR: resolve command expects exactly one destination argument.", file=sys.stderr)
            return 2
        print(resolve_destination(command_args[0], rows))
        return 0
    if command_name == "matrix-destinations":
        if len(command_args) != 1:
            print("ERROR: matrix-destinations expects exactly one matrix specification argument.", file=sys.stderr)
            return 2
        emit_matrix_destinations(command_args[0], rows)
        return 0

    print(f"ERROR: unknown command '{command_name}'.", file=sys.stderr)
    return 2
