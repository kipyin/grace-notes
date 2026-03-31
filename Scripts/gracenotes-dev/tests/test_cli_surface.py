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
        for token in ["doctor", "lint", "sim", "config", "build", "clean", "test", "ci", "interactive", "run", "xcode"]:
            self.assertIn(token, result.output)
        self.assertIn("Examples:", result.output)
        self.assertIn("grace doctor", result.output)
        self.assertIn("grace build --clean", result.output)

    def test_build_help_includes_clean_option(self) -> None:
        runner = CliRunner()
        result = runner.invoke(app, ["build", "--help"])

        self.assertEqual(result.exit_code, 0)
        self.assertIn("--clean", result.output)

    def test_sim_help_includes_required_subcommands(self) -> None:
        runner = CliRunner()
        result = runner.invoke(app, ["sim", "--help"])

        self.assertEqual(result.exit_code, 0)
        for token in ["list", "resolve", "reset"]:
            self.assertIn(token, result.output)

    def test_config_help_includes_required_subcommands(self) -> None:
        runner = CliRunner()
        result = runner.invoke(app, ["config", "--help"])

        self.assertEqual(result.exit_code, 0)
        for token in ["list", "edit", "open", "set", "interactive"]:
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
        combined = f"{result.stdout}\n{result.stderr}"
        self.assertIn("grace ci --profile lint-build-test", combined)

    def test_ci_without_profile_uses_default_ci_profile(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        cfg = replace(config.default_config(), default_ci_profile="test-all")
        with mock.patch.object(cli, "_repo_root", return_value=repo_root):
            with mock.patch.object(cli, "_load_config", return_value=cfg):
                with mock.patch.object(cli, "_execute_ci_profile") as run_ci:
                    runner = CliRunner()
                    result = runner.invoke(app, ["ci"])

        self.assertEqual(result.exit_code, 0, msg=result.output)
        run_ci.assert_called_once_with(cfg, "test-all", verbose=False)

    def test_ci_with_explicit_profile_passes_through(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        cfg = config.default_config()
        with mock.patch.object(cli, "_repo_root", return_value=repo_root):
            with mock.patch.object(cli, "_load_config", return_value=cfg):
                with mock.patch.object(cli, "_execute_ci_profile") as run_ci:
                    runner = CliRunner()
                    result = runner.invoke(app, ["ci", "--profile", "full"])

        self.assertEqual(result.exit_code, 0, msg=result.output)
        run_ci.assert_called_once_with(cfg, "full", verbose=False)

    def test_interactive_refused_when_stdin_not_tty(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        cfg = config.default_config()
        with mock.patch.object(cli, "_repo_root", return_value=repo_root):
            with mock.patch.object(cli, "_load_config", return_value=cfg):
                runner = CliRunner()
                result = runner.invoke(app, ["interactive"])

        self.assertEqual(result.exit_code, 2)
        combined = f"{result.stdout}\n{result.stderr}"
        self.assertIn("Interactive mode unavailable", combined)

    def test_interactive_refused_when_ci_env_set(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        cfg = config.default_config()
        with mock.patch.dict(os.environ, {"CI": "true"}, clear=False):
            stdin_mock = mock.Mock()
            stdin_mock.isatty.return_value = True
            with mock.patch.object(cli, "_repo_root", return_value=repo_root):
                with mock.patch.object(cli, "_load_config", return_value=cfg):
                    runner = CliRunner()
                    with mock.patch.object(sys, "stdin", stdin_mock):
                        result = runner.invoke(app, ["interactive"])

        self.assertEqual(result.exit_code, 2)

    def test_interactive_refused_when_grace_noninteractive_set(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        cfg = config.default_config()
        with mock.patch.dict(os.environ, {"GRACE_NONINTERACTIVE": "1"}, clear=False):
            stdin_mock = mock.Mock()
            stdin_mock.isatty.return_value = True
            with mock.patch.object(cli, "_repo_root", return_value=repo_root):
                with mock.patch.object(cli, "_load_config", return_value=cfg):
                    runner = CliRunner()
                    with mock.patch.object(sys, "stdin", stdin_mock):
                        result = runner.invoke(app, ["interactive"])

        self.assertEqual(result.exit_code, 2)

    def test_interactive_runs_selected_profile(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        cfg = config.default_config()
        menu_prompt = mock.Mock()
        menu_prompt.ask.return_value = "CI"
        profile_prompt = mock.Mock()
        profile_prompt.ask.return_value = "lint-build"
        verbose_prompt = mock.Mock()
        verbose_prompt.ask.return_value = True

        with mock.patch.object(cli, "_repo_root", return_value=repo_root):
            with mock.patch.object(cli, "_load_config", return_value=cfg):
                with mock.patch.object(cli, "_interactive_cli_allowed", return_value=True):
                    with mock.patch.object(cli.questionary, "select", side_effect=[menu_prompt, profile_prompt]):
                        with mock.patch.object(cli.questionary, "confirm", return_value=verbose_prompt):
                            with mock.patch.object(cli, "_execute_ci_profile") as run_ci:
                                runner = CliRunner()
                                result = runner.invoke(app, ["interactive"])

        self.assertEqual(result.exit_code, 0, msg=f"{result.stdout}\n{result.stderr}")
        run_ci.assert_called_once_with(cfg, "lint-build", verbose=True)

    def test_interactive_cancel_exits_with_code_one(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        cfg = config.default_config()
        prompt = mock.Mock()
        prompt.ask.return_value = None

        with mock.patch.object(cli, "_repo_root", return_value=repo_root):
            with mock.patch.object(cli, "_load_config", return_value=cfg):
                with mock.patch.object(cli, "_interactive_cli_allowed", return_value=True):
                    with mock.patch.object(cli.questionary, "select", return_value=prompt):
                        runner = CliRunner()
                        result = runner.invoke(app, ["interactive"])

        self.assertEqual(result.exit_code, 1)

    def test_interactive_dispatches_to_config_interactive(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        cfg = config.default_config()
        menu_prompt = mock.Mock()
        menu_prompt.ask.return_value = "Config (interactive)"

        with mock.patch.object(cli, "_repo_root", return_value=repo_root):
            with mock.patch.object(cli, "_load_config", return_value=cfg):
                with mock.patch.object(cli, "_interactive_cli_allowed", return_value=True):
                    with mock.patch.object(cli.questionary, "select", return_value=menu_prompt):
                        with mock.patch.object(cli, "config_interactive") as run_config:
                            runner = CliRunner()
                            result = runner.invoke(app, ["interactive"])

        self.assertEqual(result.exit_code, 0, msg=f"{result.stdout}\n{result.stderr}")
        run_config.assert_called_once_with()

    def test_run_preset_and_passthrough_merge_for_simctl_launch(self) -> None:
        """``--preset`` argv plus ``--`` app args reach ``simctl launch`` (no real Xcode)."""
        repo_root = Path(__file__).resolve().parents[3]
        rows = [
            {"name": "iPhone 17 Pro", "runtime_version": "26.0", "runtime_key": "k1", "udid": "u1"},
        ]
        capture_run: list[list[str]] = []
        capture_capture: list[list[str]] = []

        def fake_run(
            argv: list[str],
            *,
            cwd: Path,
            check: bool = True,
            verbose: bool = False,
        ) -> subprocess.CompletedProcess[str]:
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

    def test_prepare_xcodebuild_argv_adds_quiet_for_interactive_tty(self) -> None:
        stdout_mock = mock.Mock()
        stdout_mock.isatty.return_value = True
        with mock.patch.dict(os.environ, {"CI": ""}, clear=False):
            with mock.patch.object(sys, "stdout", stdout_mock):
                argv = cli._prepare_xcodebuild_argv(["xcodebuild", "build"], verbose=False)
        self.assertEqual(argv, ["xcodebuild", "-quiet", "build"])

    def test_prepare_xcodebuild_argv_keeps_full_logs_for_verbose_ci_or_non_tty(self) -> None:
        stdout_mock = mock.Mock()
        stdout_mock.isatty.return_value = True
        with mock.patch.dict(os.environ, {"CI": ""}, clear=False):
            with mock.patch.object(sys, "stdout", stdout_mock):
                verbose_argv = cli._prepare_xcodebuild_argv(["xcodebuild", "test"], verbose=True)
        self.assertEqual(verbose_argv, ["xcodebuild", "test"])

        with mock.patch.dict(os.environ, {"CI": "true"}, clear=False):
            with mock.patch.object(sys, "stdout", stdout_mock):
                ci_argv = cli._prepare_xcodebuild_argv(["xcodebuild", "test"], verbose=False)
        self.assertEqual(ci_argv, ["xcodebuild", "test"])

        non_tty_stdout = mock.Mock()
        non_tty_stdout.isatty.return_value = False
        with mock.patch.dict(os.environ, {"CI": ""}, clear=False):
            with mock.patch.object(sys, "stdout", non_tty_stdout):
                non_tty_argv = cli._prepare_xcodebuild_argv(["xcodebuild", "test"], verbose=False)
        self.assertEqual(non_tty_argv, ["xcodebuild", "test"])

    def test_config_set_updates_value_in_toml(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            config_file = root / "gracenotes-dev.toml"
            config_file.write_text(
                "# keep comment\n[defaults]\nscheme = \"GraceNotes\"\n",
                encoding="utf-8",
            )
            with mock.patch.object(cli, "_repo_root", return_value=root):
                runner = CliRunner()
                result = runner.invoke(app, ["config", "set", "defaults.scheme", "GraceNotes (Demo)"])

            self.assertEqual(result.exit_code, 0, msg=f"{result.stdout}\n{result.stderr}")
            loaded = config.load_config(repo_root=root)
            self.assertEqual(loaded.scheme, "GraceNotes (Demo)")
            rendered = config_file.read_text(encoding="utf-8")
            self.assertIn("# keep comment", rendered)

    def test_config_set_unknown_key_exits_non_zero(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            with mock.patch.object(cli, "_repo_root", return_value=root):
                runner = CliRunner()
                result = runner.invoke(app, ["config", "set", "defaults.unknown_key", "value"])
        self.assertEqual(result.exit_code, 2)

    def test_config_interactive_updates_selected_key(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "gracenotes-dev.toml").write_text(
                "[defaults]\nbundle_id = \"com.gracenotes.GraceNotes\"\n",
                encoding="utf-8",
            )
            call_count = {"count": 0}

            def fake_select(*_: object, **kwargs: object) -> mock.Mock:
                prompt = mock.Mock()
                choices = kwargs["choices"]
                if call_count["count"] == 0:
                    prompt.ask.return_value = choices[0]
                else:
                    prompt.ask.return_value = "Done"
                call_count["count"] += 1
                return prompt

            text_prompt = mock.Mock()
            text_prompt.ask.return_value = "com.example.test"
            with mock.patch.object(cli, "_repo_root", return_value=root):
                with mock.patch.object(cli, "_interactive_cli_allowed", return_value=True):
                    with mock.patch.object(cli.questionary, "select", side_effect=fake_select):
                        with mock.patch.object(cli.questionary, "text", return_value=text_prompt):
                            runner = CliRunner()
                            result = runner.invoke(app, ["config", "interactive"])

            self.assertEqual(result.exit_code, 0, msg=f"{result.stdout}\n{result.stderr}")
            loaded = config.load_config(repo_root=root)
            self.assertEqual(loaded.bundle_id, "com.example.test")

    def test_xcode_command_opens_configured_project(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            project = root / "GraceNotes" / "GraceNotes.xcodeproj"
            project.mkdir(parents=True)
            cfg = config.default_config()
            with mock.patch.object(sys, "platform", "darwin"):
                with mock.patch.object(cli, "_repo_root", return_value=root):
                    with mock.patch.object(cli, "_load_config", return_value=cfg):
                        with mock.patch.object(cli, "_run") as run_cmd:
                            runner = CliRunner()
                            result = runner.invoke(app, ["xcode"])

            self.assertEqual(result.exit_code, 0, msg=f"{result.stdout}\n{result.stderr}")
            run_cmd.assert_called_once_with(["open", str(project.resolve())], cwd=root, check=True)

    def test_no_color_disables_rich_output(self) -> None:
        stream = io.StringIO()
        stream.isatty = lambda: True  # type: ignore[method-assign]
        with mock.patch.dict(os.environ, {"NO_COLOR": "1"}, clear=False):
            self.assertFalse(cli._supports_rich_output(stream))

    def test_print_error_block_plain_mode(self) -> None:
        buffer = io.StringIO()
        fake_console = Console(file=buffer, force_terminal=False, no_color=True)
        with mock.patch.object(cli, "_stderr_console", return_value=fake_console):
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
