"""Unit tests for xcodebuild helper logic (no xcodebuild)."""

from __future__ import annotations

import tempfile
import textwrap
import unittest
from pathlib import Path

from gracenotes_dev import xcode


class XcodeHelpersTest(unittest.TestCase):
    def test_with_quiet_flag_only_applies_to_xcodebuild(self) -> None:
        self.assertEqual(
            xcode.with_quiet_flag(["xcodebuild", "build"], quiet=True),
            ["xcodebuild", "-quiet", "build"],
        )
        self.assertEqual(
            xcode.with_quiet_flag(["xcodebuild", "-quiet", "build"], quiet=True),
            ["xcodebuild", "-quiet", "build"],
        )
        self.assertEqual(
            xcode.with_quiet_flag(["xcrun", "simctl", "list"], quiet=True),
            ["xcrun", "simctl", "list"],
        )
        self.assertEqual(
            xcode.with_quiet_flag(["xcodebuild", "test"], quiet=False),
            ["xcodebuild", "test"],
        )

    def test_ios_major_from_destination(self) -> None:
        self.assertEqual(
            xcode.ios_major_from_resolved_destination(
                "platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.5",
            ),
            18,
        )
        self.assertIsNone(
            xcode.ios_major_from_resolved_destination(
                "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest",
            ),
        )

    def test_legacy_skips_under_ios_18(self) -> None:
        flags = xcode.legacy_skip_flags_if_needed(
            "platform=iOS Simulator,name=iPhone SE (3rd generation),OS=17.5",
        )
        self.assertTrue(all(f.startswith("-skip-testing:") for f in flags))
        self.assertEqual(
            xcode.legacy_skip_flags_if_needed(
                "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0",
            ),
            [],
        )

    def test_build_argv_order(self) -> None:
        argv = xcode.build_argv(
            project=Path("GraceNotes/GraceNotes.xcodeproj"),
            scheme="GraceNotes",
            resolved_destination="platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0",
            configuration="Debug",
            derived_data_path="/tmp/dd",
        )
        self.assertEqual(argv[0], "xcodebuild")
        self.assertIn("-project", argv)
        self.assertEqual(argv[-1], "build")
        self.assertIn("-configuration", argv)
        self.assertIn("Debug", argv)
        self.assertIn("-derivedDataPath", argv)
        self.assertIn("/tmp/dd", argv)

    def test_clean_argv_matches_build_except_action(self) -> None:
        project = Path("GraceNotes/GraceNotes.xcodeproj")
        dest = "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0"
        build = xcode.build_argv(
            project=project,
            scheme="GraceNotes",
            resolved_destination=dest,
            configuration="Debug",
            derived_data_path="/tmp/dd",
        )
        clean = xcode.clean_argv(
            project=project,
            scheme="GraceNotes",
            resolved_destination=dest,
            configuration="Debug",
            derived_data_path="/tmp/dd",
        )
        self.assertEqual(build[:-1], clean[:-1])
        self.assertEqual(build[-1], "build")
        self.assertEqual(clean[-1], "clean")

    def test_repo_root_from_package_dir(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        package_dir = Path(__file__).resolve().parents[1]
        self.assertTrue((repo_root / "GraceNotes").is_dir())
        self.assertEqual(xcode.repo_root_from(package_dir), repo_root)

    def test_run_launch_metadata_from_fixture_scheme(self) -> None:
        xml = textwrap.dedent(
            """\
            <?xml version="1.0" encoding="UTF-8"?>
            <Scheme version="1.7">
              <LaunchAction buildConfiguration = "Demo">
                <BuildableProductRunnable>
                  <BuildableReference BuildableName = "GraceNotes.app"/>
                </BuildableProductRunnable>
              </LaunchAction>
            </Scheme>
            """
        )
        with tempfile.TemporaryDirectory() as tmp:
            proj = Path(tmp) / "App.xcodeproj"
            scheme_dir = proj / "xcshareddata" / "xcschemes"
            scheme_dir.mkdir(parents=True)
            path = scheme_dir / "GraceNotes (Demo).xcscheme"
            path.write_text(xml, encoding="utf-8")
            self.assertEqual(
                xcode.run_launch_metadata_from_scheme(xcodeproj=proj, scheme="GraceNotes (Demo)"),
                ("Demo", "GraceNotes"),
            )

    def test_run_launch_metadata_shared_schemes_in_repo(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        proj = repo_root / "GraceNotes" / "GraceNotes.xcodeproj"
        self.assertEqual(
            xcode.run_launch_metadata_from_scheme(xcodeproj=proj, scheme="GraceNotes"),
            ("Debug", "GraceNotes"),
        )
        self.assertEqual(
            xcode.run_launch_metadata_from_scheme(xcodeproj=proj, scheme="GraceNotes (Demo)"),
            ("Demo", "GraceNotes"),
        )

    def test_built_app_path_prefers_products_configuration_dir(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            app_dir = base / "Build" / "Products" / "Debug-iphonesimulator" / "GraceNotes.app"
            app_dir.mkdir(parents=True)
            found = xcode.built_app_path(base, configuration="Debug", product_stem="GraceNotes")
            self.assertEqual(found, app_dir)

    def test_simctl_boot_udid_uses_identifier(self) -> None:
        boot, status = xcode.simctl_boot_sequence_argv_udid("ABC-UDID")
        self.assertEqual(boot, ["xcrun", "simctl", "boot", "ABC-UDID"])
        self.assertEqual(status, ["xcrun", "simctl", "bootstatus", "ABC-UDID", "-b"])
