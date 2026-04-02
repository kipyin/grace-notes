"""Resolve and validate iOS simulator destinations for xcodebuild and ``grace sim``."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def version_tuple(version: str) -> tuple[int, ...]:
    return tuple(int(piece) for piece in version.split("."))


def parse_destination(destination: str) -> dict[str, str]:
    parts = [part.strip() for part in destination.split(",") if part.strip()]
    fields: dict[str, str] = {}
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


def parse_runtime_version_from_key(runtime_key: str) -> str | None:
    # Common key style: com.apple.CoreSimulator.SimRuntime.iOS-18-2
    match = re.search(r"iOS-([0-9]+(?:-[0-9]+)*)", runtime_key)
    if match:
        return match.group(1).replace("-", ".")

    # Fallback style: iOS 18.2
    match = re.search(r"iOS ([0-9]+(?:\.[0-9]+)*)", runtime_key)
    if match:
        return match.group(1)
    return None


def _simctl_json(simctl_args: list[str]) -> dict:
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


def load_runtime_versions() -> dict[str, str]:
    data = _simctl_json(["list", "runtimes", "--json"])
    versions: dict[str, str] = {}
    for runtime in data.get("runtimes", []):
        identifier = runtime.get("identifier", "")
        if not identifier.startswith("com.apple.CoreSimulator.SimRuntime.iOS"):
            continue
        version = runtime.get("version")
        if version:
            versions[identifier] = version
    return versions


def destination_platform_kind(destination: str) -> str:
    """Return ``simulator``, ``physical``, or ``unknown`` for a ``platform=`` destination."""
    fields = parse_destination(destination)
    platform = fields.get("platform", "")
    if platform == "iOS Simulator":
        return "simulator"
    if platform == "iOS":
        return "physical"
    return "unknown"


def user_destination_requests_physical_ios(value: str) -> bool:
    """True when the spec is a physical ``platform=iOS`` destination (not ``device@os``)."""
    stripped = value.strip()
    if not stripped.startswith("platform="):
        return False
    return destination_platform_kind(stripped) == "physical"


def physical_udid_from_resolved_destination(resolved_destination: str) -> str | None:
    """Return the ``id=`` value from a resolved ``platform=iOS,...`` string, if any."""
    fields = parse_destination(resolved_destination)
    if fields.get("platform") != "iOS":
        return None
    device_id = fields.get("id")
    return device_id.strip() if device_id else None


def _parse_devicectl_devices_payload(data: dict) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for device in data.get("result", {}).get("devices", []):
        hw = device.get("hardwareProperties") or {}
        if hw.get("reality") != "physical" or hw.get("platform") != "iOS":
            continue
        props = device.get("deviceProperties") or {}
        udid = hw.get("udid")
        ident = device.get("identifier", "")
        rows.append(
            {
                "name": str(props.get("name", "")),
                "udid": str(udid) if udid else "",
                "identifier": str(ident),
                "os_version": str(props.get("osVersionNumber", "")),
            },
        )
    rows.sort(key=lambda r: (r["name"], r.get("udid", ""), r.get("identifier", "")))
    return rows


def try_load_connected_ios_devices() -> list[dict[str, str]]:
    """Best-effort device listing for doctor checks (returns ``[]`` on tooling failure)."""
    fd, tmp_name = tempfile.mkstemp(suffix=".json", prefix="grace-devicectl-")
    os.close(fd)
    out_path = Path(tmp_name)
    try:
        try:
            subprocess.run(
                [
                    "xcrun",
                    "devicectl",
                    "list",
                    "devices",
                    "--json-output",
                    str(out_path),
                    "-q",
                ],
                capture_output=True,
                text=True,
                check=True,
            )
        except (FileNotFoundError, subprocess.CalledProcessError, OSError):
            return []
        try:
            data = json.loads(out_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return []
        return _parse_devicectl_devices_payload(data)
    finally:
        out_path.unlink(missing_ok=True)


def load_connected_ios_devices() -> list[dict[str, str]]:
    """List connected physical iOS devices via ``devicectl`` JSON (Xcode 15+).

    Each row: ``name``, ``udid`` (when present), ``identifier`` (Core Device UUID),
    ``os_version``.
    """
    fd, tmp_name = tempfile.mkstemp(suffix=".json", prefix="grace-devicectl-")
    os.close(fd)
    out_path = Path(tmp_name)
    try:
        try:
            subprocess.run(
                [
                    "xcrun",
                    "devicectl",
                    "list",
                    "devices",
                    "--json-output",
                    str(out_path),
                    "-q",
                ],
                capture_output=True,
                text=True,
                check=True,
            )
        except FileNotFoundError:
            print(
                "ERROR: `xcrun` was not found. Install Xcode for physical device support.",
                file=sys.stderr,
            )
            sys.exit(4)
        except subprocess.CalledProcessError as exc:
            err = (exc.stderr or exc.stdout or "").strip()
            print("ERROR: devicectl list devices failed:", file=sys.stderr)
            if err:
                print(err, file=sys.stderr)
            sys.exit(4)

        try:
            data = json.loads(out_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            print(f"ERROR: could not read devicectl JSON: {exc}", file=sys.stderr)
            sys.exit(4)

        return _parse_devicectl_devices_payload(data)
    finally:
        out_path.unlink(missing_ok=True)


def resolve_physical_destination(
    destination: str,
    devices: list[dict[str, str]],
) -> str:
    """Normalize a ``platform=iOS,name=…|id=…`` spec to ``platform=iOS,id=<udid>``."""
    fields = parse_destination(destination)
    if fields.get("platform") != "iOS":
        print("ERROR: expected platform=iOS for a physical device destination.", file=sys.stderr)
        print(f"Received: {destination}", file=sys.stderr)
        sys.exit(2)

    id_value = fields.get("id")
    name_value = fields.get("name")

    def pick_udid(dev: dict[str, str]) -> str:
        udid = (dev.get("udid") or "").strip()
        if udid:
            return udid
        return (dev.get("identifier") or "").strip()

    if id_value:
        want = id_value.strip()
        for dev in devices:
            if dev.get("udid", "") == want or dev.get("identifier", "") == want:
                chosen = pick_udid(dev)
                if not chosen:
                    break
                return f"platform=iOS,id={chosen}"
        print(f"ERROR: No connected physical iOS device matches id `{want}`.", file=sys.stderr)
        _print_connected_devices_hint(devices)
        sys.exit(3)

    if name_value:
        want = name_value.strip()
        want_fold = want.casefold()
        matches = [d for d in devices if d.get("name", "").strip().casefold() == want_fold]
        if len(matches) == 1:
            chosen = pick_udid(matches[0])
            if chosen:
                return f"platform=iOS,id={chosen}"
        if not matches:
            print(f"ERROR: No connected physical iOS device named `{want}`.", file=sys.stderr)
        else:
            print(
                f"ERROR: Multiple connected devices are named `{want}`; "
                "use platform=iOS,id=<UDID> from `grace sim list --physical`.",
                file=sys.stderr,
            )
        _print_connected_devices_hint(devices)
        sys.exit(3)

    print(
        "ERROR: physical destination must include id=<UDID> or name=<device> "
        "(see `grace sim list --physical`).",
        file=sys.stderr,
    )
    print(f"Received: {destination}", file=sys.stderr)
    sys.exit(2)


def _print_connected_devices_hint(devices: list[dict[str, str]]) -> None:
    print("", file=sys.stderr)
    print("Connected physical iOS devices (CoreDevice):", file=sys.stderr)
    if not devices:
        print("  (none reported by devicectl)", file=sys.stderr)
    else:
        for dev in devices:
            label = dev.get("name") or "(unnamed)"
            udid = dev.get("udid", "")
            ident = dev.get("identifier", "")
            os_ver = dev.get("os_version", "")
            detail = f"udid={udid}" if udid else f"id={ident}"
            print(f"  - {label}  iOS {os_ver}  ({detail})", file=sys.stderr)
    print("", file=sys.stderr)
    print("Try: grace sim list --physical", file=sys.stderr)


def list_simulator_devicetypes() -> list[dict[str, str]]:
    data = _simctl_json(["list", "devicetypes", "--json"])
    rows: list[dict[str, str]] = []
    for item in data.get("devicetypes", []):
        name = item.get("name", "")
        ident = item.get("identifier", "")
        if name and ident:
            rows.append({"name": name, "identifier": ident})
    return rows


def list_ios_simulator_runtimes_detail() -> list[dict[str, object]]:
    data = _simctl_json(["list", "runtimes", "--json"])
    rows: list[dict[str, object]] = []
    for runtime in data.get("runtimes", []):
        identifier = runtime.get("identifier", "")
        if not str(identifier).startswith("com.apple.CoreSimulator.SimRuntime.iOS"):
            continue
        if not runtime.get("isAvailable", False):
            continue
        rows.append(runtime)
    return rows


def find_simulator_runtime_identifier_for_os(os_version: str) -> str | None:
    """Return a SimRuntime identifier whose version matches ``os_version`` or shares its prefix."""
    want = os_version.strip()
    runtimes = list_ios_simulator_runtimes_detail()
    if not runtimes:
        return None
    if want.lower() == "latest":

        def _runtime_sort_key(row: dict[str, object]) -> tuple[int, ...]:
            ver = str(row.get("version") or "0")
            try:
                return version_tuple(ver)
            except ValueError:
                return (0,)

        best = max(runtimes, key=_runtime_sort_key)
        return str(best.get("identifier") or "")

    matches: list[tuple[tuple[int, ...], str]] = []
    for runtime in runtimes:
        ver = str(runtime.get("version") or "")
        ident = str(runtime.get("identifier") or "")
        if not ver or not ident:
            continue
        if ver == want or ver.startswith(f"{want}."):
            try:
                matches.append((version_tuple(ver), ident))
            except ValueError:
                continue
    if not matches:
        return None
    matches.sort(key=lambda item: item[0])
    return matches[-1][1]


def pick_devicetype_identifier_for_device_name(device_name: str) -> tuple[str | None, list[str]]:
    """Pick the SimDeviceType identifier for an Apple device *name* (e.g. iPhone 17 Pro)."""
    want = device_name.strip()
    types = list_simulator_devicetypes()
    exact = [t for t in types if t["name"] == want]
    if len(exact) == 1:
        return exact[0]["identifier"], []
    if len(exact) > 1:
        return None, [t["name"] for t in exact]

    prefix_matches = [t for t in types if t["name"].startswith(want)]
    if len(prefix_matches) == 1:
        return prefix_matches[0]["identifier"], []
    if len(prefix_matches) > 1:
        return None, [t["name"] for t in prefix_matches]

    contains = [t for t in types if want.casefold() in t["name"].casefold()]
    if len(contains) == 1:
        return contains[0]["identifier"], []
    if len(contains) > 1:
        return None, [t["name"] for t in contains]

    return None, []


def create_simulator_device(name: str, device_type_id: str, runtime_id: str) -> str:
    """Run ``simctl create`` and return the new device UDID string."""
    cmd = ["xcrun", "simctl", "create", name, device_type_id, runtime_id]
    try:
        completed = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        print("ERROR: simctl create failed:", file=sys.stderr)
        print(" ", " ".join(cmd), file=sys.stderr)
        err_out = (exc.stderr or "").strip()
        if err_out:
            print(err_out, file=sys.stderr)
        sys.exit(4)
    udid = (completed.stdout or "").strip()
    if not udid:
        print("ERROR: simctl create produced no UDID.", file=sys.stderr)
        sys.exit(4)
    return udid


def load_available_ios_devices() -> list[dict[str, str]]:
    data = _simctl_json(["list", "devices", "available", "--json"])
    runtime_versions = load_runtime_versions()

    rows: list[dict[str, str]] = []
    for runtime_key, devices in data.get("devices", {}).items():
        if "iOS" not in runtime_key:
            continue

        runtime_version = runtime_versions.get(runtime_key) or parse_runtime_version_from_key(
            runtime_key
        )
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


def fail_with_guidance(message: str, rows: list[dict[str, str]]) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    print("", file=sys.stderr)
    print("Installed iOS simulator device/runtime pairs:", file=sys.stderr)

    if not rows:
        print("  (none found)", file=sys.stderr)
    else:
        seen: set[tuple[str, str]] = set()
        for row in sorted(
            rows, key=lambda item: (item["name"], version_tuple(item["runtime_version"]))
        ):
            key = (row["name"], row["runtime_version"])
            if key in seen:
                continue
            seen.add(key)
            print(f"  - {row['name']} (iOS {row['runtime_version']})", file=sys.stderr)

    print("", file=sys.stderr)
    print("To add missing simulators on macOS:", file=sys.stderr)
    print("  1) Open Xcode > Settings > Platforms and install the iOS runtime.", file=sys.stderr)
    print(
        "  2) Open Xcode > Window > Devices and Simulators and add the device type.",
        file=sys.stderr,
    )
    print("  3) Re-run: grace sim list", file=sys.stderr)
    sys.exit(3)


def resolve_destination(destination: str, rows: list[dict[str, str]]) -> str:
    fields = parse_destination(destination)
    platform = fields.get("platform")
    name = fields.get("name")
    os_value = fields.get("OS")

    if platform != "iOS Simulator" or not name or not os_value:
        print(
            "ERROR: destination must include platform=iOS Simulator,name=<device>,"
            "OS=<version|latest>",
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
            (
                f"Device '{name}' does not have iOS {os_value}. "
                f"Available versions: {', '.join(available_versions)}"
            ),
            rows,
        )

    resolved_runtime = sorted(
        {row["runtime_version"] for row in exact},
        key=version_tuple,
    )[-1]
    return f"platform=iOS Simulator,name={name},OS={resolved_runtime}"


def row_for_resolved_destination(
    resolved_destination: str,
    rows: list[dict[str, str]],
) -> dict[str, str] | None:
    """Return one device row (including ``udid``) for a resolved destination string.

    Expects the usual ``platform=iOS Simulator,name=…,OS=…`` form.
    """
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


def matrix_destinations_lines(spec: str, rows: list[dict[str, str]]) -> list[str]:
    """Return resolved destination lines for a matrix spec (semicolon-separated)."""
    entries = [entry.strip() for entry in spec.split(";") if entry.strip()]
    if not entries:
        print("ERROR: matrix specification is empty.", file=sys.stderr)
        sys.exit(2)

    lines: list[str] = []
    for entry in entries:
        if entry.startswith("platform="):
            destination = entry
        else:
            if "@" not in entry:
                print(
                    f"ERROR: invalid matrix entry '{entry}'. "
                    "Expected device@os or full destination.",
                    file=sys.stderr,
                )
                sys.exit(2)
            name, os_value = entry.rsplit("@", 1)
            destination = f"platform=iOS Simulator,name={name.strip()},OS={os_value.strip()}"
        lines.append(resolve_destination(destination, rows))
    return lines
