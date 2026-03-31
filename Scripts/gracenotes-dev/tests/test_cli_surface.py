"""Greenfield command surface tests for the grace CLI."""

from __future__ import annotations

import io
import json
import os
import shutil
import sys
import subprocess
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path
from unittest import mock

from rich.console import Console
from typer.testing import CliRunner

from gracenotes_dev import cli
from gracenotes_dev import config
from gracenotes_dev import simulator
from gracenotes_dev.cli import app


class CLISurfaceTest(unittest.TestCase):
    def test_root_help_includes_greenfield_commands(self) -> None:
        runner = CliRunner()
        result = runner.invoke(app, ["--help"])

        self.assertEqual(result.exit_code, 0)
        for token in ["doctor", "lint", "sim", "build", "test", "ci", "run"]:
            self.assertIn(token, result.output)
        self.assertIn("Examples:", result.output)
        self.assertIn("grace doctor", result.output)

    def test_sim_help_includes_required_subcommands(self) -> None:
        runner = CliRunner()
        result = runner.invoke(app, ["sim", "--help"])

        self.assertEqual(result.exit_code, 0)
        for token in ["list", "resolve", "reset"]:
            self.assertIn(token, result.output)

    def test_sim_list_plain_outputs_columns_and_default_star(self) -> None:
        """Human list uses stable sort, table headers, and marks config default with *."""
        repo_root = Path(__file__).resolve().parents[3]
        rows = [
            {"name": "iPhone 17 Pro", "runtime_version": "26.0", "runtime_key": "k1", "udid": "u1"},
            {"name": "iPhone SE (3rd generation)", "runtime_version": "18.5", "runtime_key": "k2", "udid": "u2"},
            {"name": "iPhone 13", "runtime_version": "17.0", "runtime_key": "k3", "udid": "u3"},
        ]
        cfg = replace(
            config.default_config(),
            destination="platform=iOS Simulator,name=iPhone 17 Pro,OS=latest",
        )
        with mock.patch.object(cli, "_repo_root", return_value=repo_root):
            with mock.patch.object(cli, "_require_macos_xcode"):
                with mock.patch.object(cli, "_load_config", return_value=cfg):
                    with mock.patch.object(simulator, "load_available_ios_devices", return_value=rows):
                        runner = CliRunner()
                        result = runner.invoke(app, ["sim", "list"])

        self.assertEqual(result.exit_code, 0, msg=result.output)
        self.assertIn("Default", result.output)
        self.assertIn("Device", result.output)
        self.assertIn("Availability", result.output)
        idx_13 = result.output.index("iPhone 13")
        idx_17 = result.output.index("iPhone 17 Pro")
        idx_se = result.output.index("iPhone SE (3rd generation)")
        self.assertLess(idx_13, idx_17)
        self.assertLess(idx_17, idx_se)
        star_line = [ln for ln in result.output.splitlines() if "*" in ln and "iPhone 17 Pro" in ln]
        self.assertEqual(len(star_line), 1, msg=result.output)

    def test_sim_list_json_is_array_of_destination_strings(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        rows = [
            {"name": "iPhone 13", "runtime_version": "17.0", "runtime_key": "k3", "udid": "u3"},
            {"name": "iPhone 17 Pro", "runtime_version": "26.0", "runtime_key": "k1", "udid": "u1"},
        ]
        expected = [
            "platform=iOS Simulator,name=iPhone 13,OS=17.0",
            "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0",
        ]
        with mock.patch.object(cli, "_repo_root", return_value=repo_root):
            with mock.patch.object(cli, "_require_macos_xcode"):
                with mock.patch.object(simulator, "load_available_ios_devices", return_value=rows):
                    runner = CliRunner()
                    result = runner.invoke(app, ["sim", "list", "--json"])

        self.assertEqual(result.exit_code, 0, msg=result.output)
        parsed = json.loads(result.output)
        self.assertIsInstance(parsed, list)
        self.assertEqual(parsed, expected)
        self.assertTrue(all(isinstance(item, str) for item in parsed))

    def test_sim_list_rich_table_when_tty(self) -> None:
        """With rich output enabled, list renders as a Rich table (box lines)."""
        repo_root = Path(__file__).resolve().parents[3]
        rows = [
            {"name": "iPhone 17 Pro", "runtime_version": "26.0", "runtime_key": "k1", "udid": "u1"},
        ]
        cfg = replace(
            config.default_config(),
            destination="platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0",
        )
        with mock.patch.object(cli, "_repo_root", return_value=repo_root):
            with mock.patch.object(cli, "_require_macos_xcode"):
                with mock.patch.object(cli, "_load_config", return_value=cfg):
                    with mock.patch.object(simulator, "load_available_ios_devices", return_value=rows):
                        with mock.patch.object(cli, "_supports_rich_output", return_value=True):
                            runner = CliRunner()
                            result = runner.invoke(app, ["sim", "list"])

        self.assertEqual(result.exit_code, 0, msg=result.output)
        self.assertIn("iPhone 17 Pro", result.output)
        self.assertIn("26.0", result.output)
        self.assertIn("┏", result.output)
        self.assertIn("Default", result.output)

    def test_run_help_includes_examples(self) -> None:
        runner = CliRunner()
        result = runner.invoke(app, ["run", "--help"])

        self.assertEqual(result.exit_code, 0)
        self.assertIn("Examples:", result.output)
        self.assertIn("grace run --destination", result.output)

    def test_invalid_kind_uses_designed_error_shape(self) -> None:
        runner = CliRunner()
        result = runner.invoke(app, ["test", "--kind", "invalid"])

        self.assertEqual(result.exit_code, 2)

    def test_unknown_ci_profile_uses_designed_error_shape(self) -> None:
        runner = CliRunner()
        result = runner.invoke(app, ["ci", "--profile", "missing-profile"])

        self.assertEqual(result.exit_code, 2)

    def test_run_preset_and_passthrough_merge_for_simctl_launch(self) -> None:
        """``--preset`` argv plus ``--`` app args reach ``simctl launch`` (no real Xcode)."""
        repo_root = Path(__file__).resolve().parents[3]
        rows = [
            {"name": "iPhone 17 Pro", "runtime_version": "26.0", "runtime_key": "k1", "udid": "u1"},
        ]
        capture_run: list[list[str]] = []
        capture_capture: list[list[str]] = []

        def fake_run(argv: list[str], *, cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
            capture_run.append(list(argv))
            return subprocess.CompletedProcess(argv, 0, "", "")

        def fake_capture(
            argv: list[str],
            *,
            cwd: Path,
            check: bool = True,
        ) -> subprocess.CompletedProcess[str]:
            capture_capture.append(list(argv))
            return subprocess.CompletedProcess(argv, 0, "com.gracenotes.GraceNotes: 12345", "")

        with tempfile.TemporaryDirectory() as tmp:
            fake_app = Path(tmp) / "GraceNotes.app"
            fake_app.mkdir()
            with mock.patch.object(cli, "_repo_root", return_value=repo_root):
                with mock.patch.object(cli, "_require_macos_xcode"):
                    with mock.patch.object(simulator, "load_available_ios_devices", return_value=rows):
                        with mock.patch.object(
                            cli.xcode_helpers,
                            "built_app_path",
                            return_value=fake_app,
                        ):
                            with mock.patch.object(cli, "_run", side_effect=fake_run):
                                with mock.patch.object(cli, "_run_capture", side_effect=fake_capture):
                                    runner = CliRunner()
                                    result = runner.invoke(
                                        app,
                                        [
                                            "run",
                                            "--preset",
                                            "tutorial-reset",
                                            "--",
                                            "-extra-flag",
                                        ],
                                    )

        self.assertEqual(result.exit_code, 0, msg=result.output)
        launch_lines = [a for a in capture_capture if a[:4] == ["xcrun", "simctl", "launch", "u1"]]
        self.assertEqual(len(launch_lines), 1)
        self.assertEqual(
            launch_lines[0][4:],
            ["com.gracenotes.GraceNotes", "-reset-journal-tutorial", "-extra-flag"],
        )
        install_lines = [a for a in capture_run if a[:4] == ["xcrun", "simctl", "install", "u1"]]
        self.assertEqual(len(install_lines), 1)

    def test_matrix_test_resets_simulators_before_each_destination(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        cfg = replace(config.default_config(), test_destination_matrix=("a", "b"))
        resets: list[str] = []

        def count_reset(_: Path) -> None:
            resets.append("reset")

        def noop_test_once(**_: object) -> None:
            return None

        with mock.patch.object(cli, "_require_macos_xcode"):
            with mock.patch.object(cli, "_repo_root", return_value=repo_root):
                with mock.patch.object(cli, "_load_config", return_value=cfg):
                    with mock.patch.object(simulator, "load_available_ios_devices", return_value=[]):
                        with mock.patch.object(
                            cli,
                            "_resolved_destinations_for_matrix",
                            return_value=["d1", "d2"],
                        ):
                            with mock.patch.object(cli, "_reset_sims", side_effect=count_reset):
                                with mock.patch.object(cli, "_run_test_once", side_effect=noop_test_once):
                                    runner = CliRunner()
                                    result = runner.invoke(app, ["test", "--kind", "all", "--matrix"])

        self.assertEqual(result.exit_code, 0, msg=result.output)
        self.assertEqual(resets, ["reset", "reset"])

    def test_matrix_test_skips_reset_with_no_reset_sims_flag(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        cfg = replace(config.default_config(), test_destination_matrix=("a", "b"))
        resets: list[str] = []

        def count_reset(_: Path) -> None:
            resets.append("reset")

        with mock.patch.object(cli, "_require_macos_xcode"):
            with mock.patch.object(cli, "_repo_root", return_value=repo_root):
                with mock.patch.object(cli, "_load_config", return_value=cfg):
                    with mock.patch.object(simulator, "load_available_ios_devices", return_value=[]):
                        with mock.patch.object(
                            cli,
                            "_resolved_destinations_for_matrix",
                            return_value=["d1", "d2"],
                        ):
                            with mock.patch.object(cli, "_reset_sims", side_effect=count_reset):
                                with mock.patch.object(cli, "_run_test_once"):
                                    runner = CliRunner()
                                    result = runner.invoke(
                                        app,
                                        ["test", "--kind", "all", "--matrix", "--no-reset-sims"],
                                    )

        self.assertEqual(result.exit_code, 0, msg=result.output)
        self.assertEqual(resets, [])

    def test_doctor_json_independent_default_and_matrix_status(self) -> None:
        """Default destination can be ok while matrix reports error (not both overwritten)."""
        repo_root = Path(__file__).resolve().parents[3]
        rows = [
            {"name": "iPhone 17 Pro", "runtime_version": "26.0", "runtime_key": "k1", "udid": "u1"},
        ]
        cfg = replace(
            config.default_config(),
            destination="platform=iOS Simulator,name=iPhone 17 Pro,OS=latest",
            test_destination_matrix=("iPhone 17 Pro@latest", "Nonexistent Device@latest"),
        )

        def fake_which(name: str) -> str | None:
            if name in ("swiftlint", "xcodebuild", "xcrun"):
                return f"/usr/bin/{name}"
            return None

        with mock.patch.object(cli, "_repo_root", return_value=repo_root):
            with mock.patch.object(cli, "_load_config", return_value=cfg):
                with mock.patch.object(simulator, "load_available_ios_devices", return_value=rows):
                    with mock.patch.object(sys, "platform", "darwin"):
                        with mock.patch.object(shutil, "which", side_effect=fake_which):
                            runner = CliRunner()
                            result = runner.invoke(app, ["doctor", "--json"])

        self.assertEqual(result.exit_code, 0, msg=result.output)
        payload = json.loads(result.output)
        by_name = {c["name"]: c for c in payload["checks"]}
        self.assertEqual(by_name["default destination"]["status"], "ok")
        self.assertIn("iPhone 17 Pro", by_name["default destination"]["detail"])
        self.assertEqual(by_name["matrix destinations"]["status"], "error")

    def test_no_color_disables_rich_output(self) -> None:
        stream = io.StringIO()
        stream.isatty = lambda: True  # type: ignore[method-assign]
        with mock.patch.dict(os.environ, {"NO_COLOR": "1"}, clear=False):
            self.assertFalse(cli._supports_rich_output(stream))

    def test_print_error_block_plain_mode(self) -> None:
        buffer = io.StringIO()
        fake_console = Console(file=buffer, force_terminal=False, no_color=True)
        with mock.patch.object(cli, "_stderr_console", fake_console):
            with mock.patch.object(cli, "_supports_rich_output", return_value=False):
                cli._print_error_block(
                    title="Sample Error",
                    problem="Something failed.",
                    likely_cause="Reason here.",
                    try_commands=("grace doctor",),
                    retry_command="grace test --kind all",
                )

        output = buffer.getvalue()
        self.assertIn("Sample Error", output)
        self.assertIn("Problem: Something failed.", output)
        self.assertIn("Likely cause: Reason here.", output)
        self.assertIn("Copy this retry: grace test --kind all", output)
