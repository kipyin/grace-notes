"""Tests for simulator runtime argv builders and parsers."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from gracenotes_dev import simulator_runtime


class SimulatorRuntimeHelpersTest(unittest.TestCase):
    def test_xcode_download_platform_argv_uses_build_version_flag(self) -> None:
        argv = simulator_runtime.xcode_download_platform_argv(
            export_path=Path("/tmp/runtimes"),
            build_version="18.5",
        )
        self.assertEqual(
            argv,
            [
                "xcodebuild",
                "-downloadPlatform",
                "iOS",
                "-exportPath",
                "/tmp/runtimes",
                "-buildVersion",
                "18.5",
            ],
        )

    def test_simctl_runtime_list_argv_supports_json(self) -> None:
        self.assertEqual(
            simulator_runtime.simctl_runtime_list_argv(json_out=True),
            ["xcrun", "simctl", "runtime", "list", "-j"],
        )
        self.assertEqual(
            simulator_runtime.simctl_runtime_list_argv(json_out=False),
            ["xcrun", "simctl", "runtime", "list"],
        )

    def test_parse_runtime_list_json_parses_xcode26_shape(self) -> None:
        raw = """
{
  "abc": {
    "identifier": "abc",
    "runtimeIdentifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-4",
    "platformIdentifier": "com.apple.platform.iphonesimulator",
    "version": "26.4",
    "build": "23E244",
    "state": "Ready",
    "deletable": true
  }
}
""".strip()
        rows = simulator_runtime.parse_runtime_list_json(raw)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].identifier, "abc")
        self.assertEqual(rows[0].platform, "iOS")
        self.assertEqual(rows[0].version, "26.4")
        self.assertEqual(rows[0].build, "23E244")
        self.assertTrue(rows[0].deletable)

    def test_parse_runtime_list_text_parses_lines(self) -> None:
        raw = """
== Disk Images ==
-- iOS --
iOS 26.4 (23E244) - 4D16FE4F-730D-4CB3-956D-30C4ABAF416E (Ready)
""".strip()
        rows = simulator_runtime.parse_runtime_list_text(raw)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].platform, "iOS")
        self.assertEqual(rows[0].version, "26.4")
        self.assertEqual(rows[0].build, "23E244")
        self.assertEqual(rows[0].state, "Ready")
        self.assertEqual(rows[0].identifier, "4D16FE4F-730D-4CB3-956D-30C4ABAF416E")

    def test_discover_downloaded_dmg_prefers_latest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            older = root / "iOS Simulator Runtime 1.dmg"
            newer = root / "iOS Simulator Runtime 2.dmg"
            older.write_text("old", encoding="utf-8")
            newer.write_text("new", encoding="utf-8")
            os.utime(older, (1000, 1000))
            os.utime(newer, (2000, 2000))
            discovered = simulator_runtime.discover_downloaded_dmg(export_path=root)
            self.assertEqual(discovered, newer)
