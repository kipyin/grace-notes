#!/usr/bin/env python3
"""Resolve and validate iOS simulator destinations for make targets."""

import json
import re
import subprocess
import sys
from typing import Dict, List, Optional, Set, Tuple


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


def load_runtime_versions() -> Dict[str, str]:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "runtimes", "--json"],
        text=True,
    )
    data = json.loads(raw)
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
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        text=True,
    )
    data = json.loads(raw)
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
    print("  3) Re-run: make list-simulator-destinations", file=sys.stderr)
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


def list_destinations(rows: List[Dict[str, str]]) -> None:
    seen: Set[Tuple[str, str]] = set()
    for row in sorted(rows, key=lambda item: (item["name"], version_tuple(item["runtime_version"]))):
        key = (row["name"], row["runtime_version"])
        if key in seen:
            continue
        seen.add(key)
        print(f"platform=iOS Simulator,name={row['name']},OS={row['runtime_version']}")


def print_destination_name(destination: str) -> None:
    fields = parse_destination(destination)
    name = fields.get("name")
    if not name:
        print("ERROR: destination does not contain name=", file=sys.stderr)
        sys.exit(2)
    print(name)


def matrix_destinations(spec: str, rows: List[Dict[str, str]]) -> None:
    entries = [entry.strip() for entry in spec.split(";") if entry.strip()]
    if not entries:
        print("ERROR: matrix specification is empty.", file=sys.stderr)
        sys.exit(2)

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
        print(resolve_destination(destination, rows))


def main() -> int:
    if len(sys.argv) < 2:
        usage()
        return 2

    command_name = sys.argv[1]
    command_args = sys.argv[2:]

    if command_name == "name":
        if len(command_args) != 1:
            print("ERROR: name command expects exactly one destination argument.", file=sys.stderr)
            return 2
        print_destination_name(command_args[0])
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
        matrix_destinations(command_args[0], rows)
        return 0

    print(f"ERROR: unknown command '{command_name}'.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
