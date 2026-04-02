"""Repo-scoped defaults and TOML-backed configuration for ``grace``."""

from __future__ import annotations

from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python < 3.11
    import tomli as tomllib  # type: ignore[import-not-found]

# Xcode project and scheme
DEFAULT_PROJECT_RELATIVE = "GraceNotes/GraceNotes.xcodeproj"
DEFAULT_SCHEME = "GraceNotes"

# Default simulator destination (human / xcodebuild string)
DEFAULT_DESTINATION = "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest"

# Default ``grace ci`` profile when ``--profile`` is omitted (lint + simulator build).
DEFAULT_CI_PROFILE = "lint-build"

# CI pins (override if runtimes differ)
CI_SIMULATOR_PRO = "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest"
CI_SIMULATOR_XR = "platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.5"

TEST_DESTINATION_MATRIX = "iPhone SE (3rd generation)@18.5;iPhone 17 Pro@latest"

ISOLATED_DERIVED_DATA = "/tmp/GraceNotes-TestDerivedData"

UNIT_TEST_BUNDLE = "GraceNotesTests"
UI_TEST_BUNDLE = "GraceNotesUITests"
SMOKE_UI_TEST = "GraceNotesUITests/GraceNotesSmokeUITests/testSmokeLaunch"

XCODE_TEST_FLAGS: tuple[str, ...] = ()

# XCTest parallel execution (separate toggles; smoke/UI use the UI toggle).
DEFAULT_PARALLEL_TESTING_UNIT = True
DEFAULT_PARALLEL_TESTING_UI = False

# iOS 17 hosted runtime can crash in these suites before assertions run.
LEGACY_RUNTIME_SKIP_FLAGS: tuple[str, ...] = (
    "-skip-testing:GraceNotesTests/DeterministicReviewInsightsTests",
    "-skip-testing:GraceNotesTests/HistoryEntryGroupingTests",
)

DEFAULT_BUNDLE_ID = "com.gracenotes.GraceNotes"
DEFAULT_CONFIG_FILENAME = "gracenotes-dev.toml"


@dataclass(frozen=True)
class CIProfile:
    name: str
    lint: bool = True
    build: bool = False
    build_destination: str | None = None
    test: bool = False
    test_kind: str = "all"
    test_destination: str | None = None
    matrix: bool = False
    isolated_dd: bool = False
    reset_simulators_before_test: bool = False
    smoke: bool = False
    smoke_destination: str | None = None


@dataclass(frozen=True)
class DevConfig:
    project: str
    scheme: str
    bundle_id: str
    default_ci_profile: str
    destination: str
    ci_simulator_pro: str
    ci_simulator_xr: str
    test_destination_matrix: tuple[str, ...]
    isolated_derived_data: str
    unit_test_bundle: str
    ui_test_bundle: str
    smoke_ui_test: str
    xcode_test_flags: tuple[str, ...]
    parallel_testing_unit: bool
    parallel_testing_ui: bool
    legacy_runtime_skip_flags: tuple[str, ...]
    ci_profiles: dict[str, CIProfile]
    run_presets: dict[str, tuple[str, ...]]


def _default_ci_profiles() -> dict[str, CIProfile]:
    return {
        "lint-build": CIProfile(
            name="lint-build",
            lint=True,
            build=True,
            build_destination=CI_SIMULATOR_PRO,
        ),
        "test-all": CIProfile(
            name="test-all",
            lint=True,
            test=True,
            test_kind="all",
            reset_simulators_before_test=True,
        ),
        "lint-build-test": CIProfile(
            name="lint-build-test",
            lint=True,
            build=True,
            build_destination=CI_SIMULATOR_PRO,
            test=True,
            test_kind="all",
            reset_simulators_before_test=True,
        ),
        "full": CIProfile(
            name="full",
            lint=True,
            test=True,
            test_kind="all",
            test_destination=CI_SIMULATOR_PRO,
            smoke=True,
            smoke_destination=CI_SIMULATOR_XR,
            reset_simulators_before_test=False,
        ),
    }


def default_config() -> DevConfig:
    return DevConfig(
        project=DEFAULT_PROJECT_RELATIVE,
        scheme=DEFAULT_SCHEME,
        bundle_id=DEFAULT_BUNDLE_ID,
        default_ci_profile=DEFAULT_CI_PROFILE,
        destination=DEFAULT_DESTINATION,
        ci_simulator_pro=CI_SIMULATOR_PRO,
        ci_simulator_xr=CI_SIMULATOR_XR,
        test_destination_matrix=tuple(
            item.strip() for item in TEST_DESTINATION_MATRIX.split(";") if item.strip()
        ),
        isolated_derived_data=ISOLATED_DERIVED_DATA,
        unit_test_bundle=UNIT_TEST_BUNDLE,
        ui_test_bundle=UI_TEST_BUNDLE,
        smoke_ui_test=SMOKE_UI_TEST,
        xcode_test_flags=tuple(XCODE_TEST_FLAGS),
        parallel_testing_unit=DEFAULT_PARALLEL_TESTING_UNIT,
        parallel_testing_ui=DEFAULT_PARALLEL_TESTING_UI,
        legacy_runtime_skip_flags=tuple(LEGACY_RUNTIME_SKIP_FLAGS),
        ci_profiles=_default_ci_profiles(),
        run_presets={},
    )


def _as_string_tuple(value: Any) -> tuple[str, ...]:
    if isinstance(value, str):
        return tuple(item.strip() for item in value.split(";") if item.strip())
    if isinstance(value, list):
        return tuple(str(item).strip() for item in value if str(item).strip())
    return ()


def _parse_optional_bool(raw: Any, default: bool) -> bool:
    if raw is None:
        return default
    if isinstance(raw, bool):
        return raw
    if isinstance(raw, (int, float)):
        return bool(raw)
    if isinstance(raw, str):
        normalized = raw.strip().lower()
        if normalized in {"1", "true", "yes", "on"}:
            return True
        if normalized in {"0", "false", "no", "off"}:
            return False
    return default


def _as_profile(name: str, raw: Any, base: CIProfile | None = None) -> CIProfile:
    profile = base or CIProfile(name=name)
    if not isinstance(raw, dict):
        return profile
    return replace(
        profile,
        lint=bool(raw.get("lint", profile.lint)),
        build=bool(raw.get("build", profile.build)),
        build_destination=raw.get("build_destination", profile.build_destination),
        test=bool(raw.get("test", profile.test)),
        test_kind=str(raw.get("test_kind", profile.test_kind)),
        test_destination=raw.get("test_destination", profile.test_destination),
        matrix=bool(raw.get("matrix", profile.matrix)),
        isolated_dd=bool(raw.get("isolated_dd", profile.isolated_dd)),
        reset_simulators_before_test=bool(
            raw.get("reset_simulators_before_test", profile.reset_simulators_before_test),
        ),
        smoke=bool(raw.get("smoke", profile.smoke)),
        smoke_destination=raw.get("smoke_destination", profile.smoke_destination),
    )


def _resolve_repo_root(start: Path) -> Path:
    here = start.resolve()
    for candidate in [here, *here.parents]:
        if (candidate / "GraceNotes").is_dir():
            return candidate
    return here


def config_path(repo_root: Path | None = None) -> Path:
    root = _resolve_repo_root(repo_root or Path.cwd())
    return root / DEFAULT_CONFIG_FILENAME


def load_config(repo_root: Path | None = None) -> DevConfig:
    loaded = default_config()
    cfg_path = config_path(repo_root=repo_root)
    if not cfg_path.is_file():
        return loaded

    data = tomllib.loads(cfg_path.read_text(encoding="utf-8"))
    defaults = data.get("defaults", {})
    tests = data.get("tests", {})
    ci_profiles_raw = data.get("ci", {}).get("profiles", {})
    run_presets_raw = data.get("run", {}).get("presets", {})

    matrix = _as_string_tuple(defaults.get("test_destination_matrix"))
    if not matrix:
        matrix = loaded.test_destination_matrix

    run_presets: dict[str, tuple[str, ...]] = {}
    if isinstance(run_presets_raw, dict):
        for name, raw_value in run_presets_raw.items():
            values = _as_string_tuple(raw_value)
            if values:
                run_presets[name] = values

    profiles = dict(loaded.ci_profiles)
    if isinstance(ci_profiles_raw, dict):
        for profile_name, raw_profile in ci_profiles_raw.items():
            profiles[profile_name] = _as_profile(
                profile_name,
                raw_profile,
                base=profiles.get(profile_name),
            )

    default_ci_profile = str(
        defaults.get("default_ci_profile", loaded.default_ci_profile),
    ).strip()
    if not default_ci_profile:
        default_ci_profile = loaded.default_ci_profile

    return DevConfig(
        project=str(defaults.get("project", loaded.project)),
        scheme=str(defaults.get("scheme", loaded.scheme)),
        bundle_id=str(defaults.get("bundle_id", loaded.bundle_id)),
        default_ci_profile=default_ci_profile,
        destination=str(defaults.get("destination", loaded.destination)),
        ci_simulator_pro=str(defaults.get("ci_simulator_pro", loaded.ci_simulator_pro)),
        ci_simulator_xr=str(defaults.get("ci_simulator_xr", loaded.ci_simulator_xr)),
        test_destination_matrix=matrix,
        isolated_derived_data=str(
            defaults.get("isolated_derived_data", loaded.isolated_derived_data),
        ),
        unit_test_bundle=str(tests.get("unit_test_bundle", loaded.unit_test_bundle)),
        ui_test_bundle=str(tests.get("ui_test_bundle", loaded.ui_test_bundle)),
        smoke_ui_test=str(tests.get("smoke_ui_test", loaded.smoke_ui_test)),
        xcode_test_flags=tuple(_as_string_tuple(tests.get("xcode_test_flags")))
        if "xcode_test_flags" in tests
        else loaded.xcode_test_flags,
        parallel_testing_unit=_parse_optional_bool(
            tests.get("parallel_testing_unit"),
            loaded.parallel_testing_unit,
        ),
        parallel_testing_ui=_parse_optional_bool(
            tests.get("parallel_testing_ui"),
            loaded.parallel_testing_ui,
        ),
        legacy_runtime_skip_flags=tuple(
            _as_string_tuple(tests.get("legacy_runtime_skip_flags")),
        )
        or loaded.legacy_runtime_skip_flags,
        ci_profiles=profiles,
        run_presets=run_presets,
    )
