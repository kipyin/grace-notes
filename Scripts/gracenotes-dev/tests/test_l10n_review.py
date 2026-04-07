"""Tests for grace l10n review data and CLI guardrails."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import typer
from typer.testing import CliRunner

from gracenotes_dev.cli import app
from gracenotes_dev.cli import core as cli_core
from gracenotes_dev.cli import l10n_review
from gracenotes_dev.cli import l10n_surfaces


class TestL10nReview(unittest.TestCase):
    def test_build_review_index_has_core_surfaces(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        idx = l10n_review.build_review_index(repo_root)
        self.assertIn("today", idx)
        self.assertGreater(len(idx["today"]), 10)

    def test_append_review_note_creates_header(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "notes.md"
            l10n_review.append_review_note(path, "k1", "check tone")
            text = path.read_text(encoding="utf-8")
            self.assertIn("# grace l10n review notes", text)
            self.assertIn("**k1**", text)
            self.assertIn("check tone", text)

    def test_l10n_review_refuses_non_tty(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        runner = CliRunner()
        prior = os.getcwd()
        try:
            os.chdir(repo_root)
            result = runner.invoke(app, ["l10n", "review"])
        finally:
            os.chdir(prior)

        self.assertEqual(result.exit_code, 2)
        combined = f"{result.stdout}\n{result.stderr}"
        self.assertIn("Interactive mode unavailable", combined)

    def test_l10n_review_interactive_quits_early(self) -> None:
        repo_root = Path(__file__).resolve().parents[3]
        cfg_calls = {"select": 0}

        def select_side_effect(*_a: object, **_kw: object) -> mock.Mock:
            cfg_calls["select"] += 1
            m = mock.Mock()
            if cfg_calls["select"] == 1:
                m.ask.return_value = l10n_surfaces.SURFACE_SHARED
            else:
                m.ask.return_value = "quit"
            return m

        text_mock = mock.Mock()
        text_mock.ask.return_value = ""

        with tempfile.TemporaryDirectory() as td:
            notes_file = Path(td) / "session.md"
            quiet_console = mock.Mock()
            with mock.patch.object(cli_core, "_require_interactive_cli"):
                with mock.patch.object(cli_core, "_stdout_console", return_value=quiet_console):
                    with mock.patch.object(l10n_review.questionary, "select", side_effect=select_side_effect):
                        with mock.patch.object(l10n_review.questionary, "text", return_value=text_mock):
                            with self.assertRaises(typer.Exit) as ctx:
                                l10n_review.run_l10n_review_interactive(
                                    repo_root,
                                    notes_path=notes_file,
                                    walk_all=False,
                                )
        self.assertEqual(ctx.exception.exit_code, 0)
