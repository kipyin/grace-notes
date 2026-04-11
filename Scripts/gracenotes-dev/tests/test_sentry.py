"""Unit tests for ``grace sentry`` helpers (no iOS build)."""

from __future__ import annotations

import unittest

from typer.testing import CliRunner

from gracenotes_dev.cli import app
from gracenotes_dev.sentry.classify import TouchClass, classify_paths
from gracenotes_dev.sentry.merge_logic import can_merge
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import format_report


class SentryMergeLogicTest(unittest.TestCase):
    def test_low_touch_merge_requires_ci_and_copilot(self) -> None:
        self.assertTrue(
            can_merge(
                ci_ok=True,
                high_touch=False,
                copilot_ok=True,
                approve_phrase_present=False,
            )
        )
        self.assertFalse(
            can_merge(ci_ok=True, high_touch=False, copilot_ok=False, approve_phrase_present=False)
        )

    def test_high_touch_requires_approve_even_if_copilot_ok(self) -> None:
        self.assertFalse(
            can_merge(ci_ok=True, high_touch=True, copilot_ok=True, approve_phrase_present=False)
        )
        self.assertTrue(
            can_merge(ci_ok=True, high_touch=True, copilot_ok=True, approve_phrase_present=True)
        )

    def test_approve_overrides_copilot_stuck(self) -> None:
        self.assertTrue(
            can_merge(ci_ok=True, high_touch=False, copilot_ok=False, approve_phrase_present=True)
        )


class SentryClassifyTest(unittest.TestCase):
    def test_views_path_ui(self) -> None:
        self.assertEqual(
            classify_paths(["GraceNotes/Features/Foo/EntryListView.swift"]),
            TouchClass.UI_UX,
        )

    def test_tests_low_touch(self) -> None:
        self.assertEqual(
            classify_paths(["GraceNotesTests/SomeTests.swift"]),
            TouchClass.LOW_TOUCH,
        )


class SentrySettingsTest(unittest.TestCase):
    def test_defaults(self) -> None:
        s = SentrySettings.from_environ()
        self.assertEqual(s.approval_phrase, "/sentry-approve")


class SentryApprovalParseTest(unittest.TestCase):
    def test_phrase(self) -> None:
        from gracenotes_dev.sentry import github as gh

        comments = [
            {"user": {"login": "alice"}, "body": "lgtm /sentry-approve thanks"},
        ]
        self.assertTrue(gh.has_approval_phrase(comments, "/sentry-approve", {"alice"}))
        self.assertFalse(gh.has_approval_phrase(comments, "/sentry-approve", {"bob"}))


class SentryReportTest(unittest.TestCase):
    def test_format_empty(self) -> None:
        self.assertIn("No sentry", format_report([]))


class SentryCLISurfaceTest(unittest.TestCase):
    def test_sentry_help_lists_commands(self) -> None:
        runner = CliRunner()
        result = runner.invoke(app, ["sentry", "--help"])
        self.assertEqual(result.exit_code, 0)
        for token in ["start", "stop", "status", "report"]:
            self.assertIn(token, result.output)
        start_help = runner.invoke(app, ["sentry", "start", "--help"])
        self.assertEqual(start_help.exit_code, 0)
        for token in ["--once", "--dry-run", "--no-merge"]:
            self.assertIn(token, start_help.output)
