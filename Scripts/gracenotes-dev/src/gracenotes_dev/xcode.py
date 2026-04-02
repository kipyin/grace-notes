"""xcodebuild-related helpers (logic migrated from the root Makefile)."""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from collections.abc import Sequence
from pathlib import Path

from gracenotes_dev import config
from gracenotes_dev.simulator import destination_display_name


def with_quiet_flag(argv: Sequence[str], *, quiet: bool) -> list[str]:
    """Insert ``-quiet`` for xcodebuild argv when requested and absent."""
    args = list(argv)
    if not quiet:
        return args
    if not args or args[0] != "xcodebuild":
        return args
    if "-quiet" in args:
        return args
    return [args[0], "-quiet", *args[1:]]


def repo_root_from(start: Path | None = None) -> Path:
    """Walk up from ``start`` to find the repo root (directory containing GraceNotes/)."""
    here = (start or Path.cwd()).resolve()
    for candidate in [here, *here.parents]:
        project = candidate / config.DEFAULT_PROJECT_RELATIVE
        if (candidate / "GraceNotes").is_dir() and project.exists():
            return candidate
    # Fall back to cwd for relative paths (callers may set cwd explicitly).
    return here


def ios_major_from_resolved_destination(resolved_destination: str) -> int | None:
    """Parse major iOS version from ``OS=`` in an xcodebuild destination string."""
    match = re.search(r"(?:^|,)OS=([^,]+)", resolved_destination)
    if not match:
        return None
    value = match.group(1).strip()
    if value == "latest":
        return None
    major_str = value.split(".", 1)[0]
    if not major_str.isdigit():
        return None
    return int(major_str)


def legacy_skip_flags_if_needed(resolved_destination: str) -> list[str]:
    """Return Makefile-equivalent skip flags when the runtime major version is under 18."""
    major = ios_major_from_resolved_destination(resolved_destination)
    if major is None:
        return []
    if major < 18:
        return list(config.LEGACY_RUNTIME_SKIP_FLAGS)
    return []


def xcodebuild_test_flag_list() -> list[str]:
    """Legacy extra xcodebuild test flags as a list (often empty)."""
    return list(config.XCODE_TEST_FLAGS)


def merge_parallel_testing_flags(
    base: Sequence[str] | None,
    *,
    parallel_enabled: bool,
) -> list[str]:
    """Remove any ``-parallel-testing-enabled`` pair from ``base``, then set it from the bool."""
    raw = list(base) if base is not None else []
    out: list[str] = []
    index = 0
    while index < len(raw):
        if raw[index] == "-parallel-testing-enabled" and index + 1 < len(raw):
            index += 2
            continue
        out.append(raw[index])
        index += 1
    out.extend(["-parallel-testing-enabled", "YES" if parallel_enabled else "NO"])
    return out


def xcodebuild_base_args(
    *,
    project: str | Path,
    scheme: str,
    resolved_destination: str,
) -> list[str]:
    """Shared argv prefix: ``xcodebuild -project … -scheme … -destination …``."""
    return [
        "xcodebuild",
        "-project",
        str(project),
        "-scheme",
        scheme,
        "-destination",
        resolved_destination,
    ]


def build_argv(
    *,
    project: Path,
    scheme: str,
    resolved_destination: str,
    configuration: str | None = None,
    derived_data_path: Path | str | None = None,
) -> list[str]:
    """``xcodebuild build`` argument list."""
    args = xcodebuild_base_args(
        project=project, scheme=scheme, resolved_destination=resolved_destination
    )
    if configuration:
        args.extend(["-configuration", configuration])
    if derived_data_path is not None:
        args.extend(["-derivedDataPath", str(derived_data_path)])
    args.append("build")
    return args


def clean_argv(
    *,
    project: Path,
    scheme: str,
    resolved_destination: str,
    configuration: str | None = None,
    derived_data_path: Path | str | None = None,
) -> list[str]:
    """``xcodebuild clean`` argument list (same flags as ``build``)."""
    args = xcodebuild_base_args(
        project=project, scheme=scheme, resolved_destination=resolved_destination
    )
    if configuration:
        args.extend(["-configuration", configuration])
    if derived_data_path is not None:
        args.extend(["-derivedDataPath", str(derived_data_path)])
    args.append("clean")
    return args


def test_argv(
    *,
    project: Path,
    scheme: str,
    resolved_destination: str,
    only_testing: Sequence[str] | None = None,
    extra_xcodebuild_args: Sequence[str] | None = None,
    isolated_derived_data: Path | str | None = None,
    apply_legacy_skips: bool = True,
    xcode_test_flags: Sequence[str] | None = None,
    parallel_testing: bool | None = None,
    legacy_skip_flags: Sequence[str] | None = None,
) -> list[str]:
    """``xcodebuild test`` argv list matching Makefile test patterns.

    Covers ``test``, ``test-unit``, and ``test-ui`` Makefile targets.

    When ``parallel_testing`` is set, ``-parallel-testing-enabled`` is applied for that run
    (after stripping any parallel pair from ``xcode_test_flags``). When ``None``, extra flags
    are passed through unchanged.
    """
    args = xcodebuild_base_args(
        project=project, scheme=scheme, resolved_destination=resolved_destination
    )
    base_flags = xcode_test_flags if xcode_test_flags is not None else xcodebuild_test_flag_list()
    if parallel_testing is not None:
        args.extend(merge_parallel_testing_flags(base_flags, parallel_enabled=parallel_testing))
    else:
        args.extend(list(base_flags))
    if apply_legacy_skips:
        if legacy_skip_flags is None:
            args.extend(legacy_skip_flags_if_needed(resolved_destination))
        else:
            major = ios_major_from_resolved_destination(resolved_destination)
            if major is not None and major < 18:
                args.extend(list(legacy_skip_flags))
    if isolated_derived_data is not None:
        args.extend(["-derivedDataPath", str(isolated_derived_data)])
    if only_testing:
        for item in only_testing:
            args.extend(["-only-testing", item])
    if extra_xcodebuild_args:
        args.extend(extra_xcodebuild_args)
    args.append("test")
    return args


def simctl_boot_sequence_argv(simulator_name: str) -> tuple[list[str], list[str]]:
    """Return ``simctl boot`` and ``simctl bootstatus -b`` argv lists (smoke / Makefile parity)."""
    boot = ["xcrun", "simctl", "boot", simulator_name]
    bootstatus = ["xcrun", "simctl", "bootstatus", simulator_name, "-b"]
    return boot, bootstatus


def simctl_boot_sequence_argv_udid(udid: str) -> tuple[list[str], list[str]]:
    """Return ``simctl boot`` and ``simctl bootstatus -b`` argv lists for a device UDID."""
    boot = ["xcrun", "simctl", "boot", udid]
    bootstatus = ["xcrun", "simctl", "bootstatus", udid, "-b"]
    return boot, bootstatus


def simctl_reset_all_argv() -> tuple[list[str], list[str]]:
    """Return ``simctl shutdown all`` and ``simctl erase all`` argv lists."""
    shutdown = ["xcrun", "simctl", "shutdown", "all"]
    erase = ["xcrun", "simctl", "erase", "all"]
    return shutdown, erase


def resolved_name_for_smoke(resolved_destination: str) -> str:
    """Device name for simctl commands (Makefile ``test-ui-smoke``)."""
    return destination_display_name(resolved_destination)


def shared_scheme_path(xcodeproj: Path, scheme: str) -> Path:
    """Path to ``xcshareddata/xcschemes/<scheme>.xcscheme`` inside a ``.xcodeproj`` bundle."""
    return xcodeproj / "xcshareddata" / "xcschemes" / f"{scheme}.xcscheme"


def _elem_local_name(tag: str) -> str:
    if tag.startswith("{"):
        return tag.rsplit("}", 1)[-1]
    return tag


def run_launch_metadata_from_scheme(*, xcodeproj: Path, scheme: str) -> tuple[str, str]:
    """Return ``(launch_build_configuration, product_stem)`` from the scheme's LaunchAction.

    ``product_stem`` is the Built app name without ``.app`` (for example ``GraceNotes`` for
    ``GraceNotes.app``).
    """
    path = shared_scheme_path(xcodeproj, scheme)
    if not path.is_file():
        msg = f"Scheme file not found for {scheme!r}: {path}"
        raise ValueError(msg)

    try:
        tree = ET.parse(path)
    except ET.ParseError as exc:  # pragma: no cover - defensive
        msg = f"Could not parse scheme XML {path}: {exc}"
        raise ValueError(msg) from exc

    root = tree.getroot()
    launch = None
    for elem in root.iter():
        if _elem_local_name(elem.tag) == "LaunchAction":
            launch = elem
            break
    if launch is None:
        msg = f"No LaunchAction in {path}"
        raise ValueError(msg)

    attribs = {
        str(k).strip(): str(v).strip() if v is not None else "" for k, v in launch.attrib.items()
    }
    configuration = attribs.get("buildConfiguration")
    if not configuration:
        msg = f"LaunchAction missing buildConfiguration in {path}"
        raise ValueError(msg)

    product_app: str | None = None
    for child in launch.iter():
        if _elem_local_name(child.tag) != "BuildableReference":
            continue
        rattribs = {
            str(k).strip(): str(v).strip() if v is not None else "" for k, v in child.attrib.items()
        }
        buildable = rattribs.get("BuildableName", "")
        if buildable.endswith(".app") and not buildable.endswith("Tests.xctest"):
            product_app = buildable
            break

    if not product_app:
        msg = f"No runnable .app BuildableReference under LaunchAction in {path}"
        raise ValueError(msg)

    product_stem = product_app[:-4] if product_app.endswith(".app") else product_app
    return configuration, product_stem


def built_app_path(derived_data_path: Path, *, configuration: str, product_stem: str) -> Path:
    """Locate the built ``.app`` bundle under DerivedData products."""
    app_path = (
        derived_data_path
        / "Build"
        / "Products"
        / f"{configuration}-iphonesimulator"
        / f"{product_stem}.app"
    )
    if app_path.is_dir():
        return app_path

    matches = sorted(derived_data_path.glob(f"**/{product_stem}.app"))
    if matches:
        return matches[0]
    raise FileNotFoundError(f"Could not find {product_stem}.app under {derived_data_path}")


def simctl_install_argv(*, app_path: Path, device: str = "booted") -> list[str]:
    """Return ``simctl install`` argv."""
    return ["xcrun", "simctl", "install", device, str(app_path)]


def simctl_launch_argv(
    *, bundle_id: str, app_args: Sequence[str], device: str = "booted"
) -> list[str]:
    """Return ``simctl launch`` argv with optional app arguments."""
    return ["xcrun", "simctl", "launch", device, bundle_id, *app_args]
