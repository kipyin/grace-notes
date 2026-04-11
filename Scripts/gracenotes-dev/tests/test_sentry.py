"""Unit tests for ``grace sentry`` helpers (no iOS build)."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from typer.testing import CliRunner

from gracenotes_dev.cli import app
from gracenotes_dev.config import load_sentry_table
from gracenotes_dev.sentry.classify import TouchClass, classify_paths
from gracenotes_dev.sentry.llm_client import parse_fix_response
from gracenotes_dev.sentry.merge_logic import can_merge
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import format_report, read_recent_events


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
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "GraceNotes").mkdir()
            (root / "gracenotes-dev.toml").write_text("", encoding="utf-8")
            s = SentrySettings.from_repo(root)
        self.assertEqual(s.approval_phrase, "/sentry-approve")
        self.assertEqual(s.fix_provider, "http")
        self.assertEqual(s.agent_bin, "agent")


class SentryTomlTest(unittest.TestCase):
    def test_from_repo_reads_toml(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "GraceNotes").mkdir()
            (root / "gracenotes-dev.toml").write_text(
                '[sentry]\nfix_provider = "cursor_agent"\nagent_bin = "my-agent"\n',
                encoding="utf-8",
            )
            s = SentrySettings.from_repo(root)
            self.assertEqual(s.fix_provider, "cursor_agent")
            self.assertEqual(s.agent_bin, "my-agent")

    def test_load_sentry_table_strips_secret_keys(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "GraceNotes").mkdir()
            (root / "gracenotes-dev.toml").write_text(
                '[sentry]\napi_key = "nope"\nfix_provider = "http"\n',
                encoding="utf-8",
            )
            t = load_sentry_table(root)
            self.assertNotIn("api_key", t)
            self.assertEqual(t.get("fix_provider"), "http")


class SentryParseFixTest(unittest.TestCase):
    def test_no_change(self) -> None:
        self.assertEqual(parse_fix_response("NO_CHANGE"), "")

    def test_swift_block(self) -> None:
        out = parse_fix_response("Here:\n```swift\nlet x = 1\n```\n")
        self.assertIn("let x = 1", out)


class SentryFixProviderEnvTest(unittest.TestCase):
    def test_cursor_agent_provider(self) -> None:
        with mock.patch.dict("os.environ", {"SENTRY_FIX_PROVIDER": "cursor-agent"}):
            s = SentrySettings.from_environ()
            self.assertEqual(s.fix_provider, "cursor_agent")


class SentryGithubGraphQLTest(unittest.TestCase):
    def test_review_threads_query_variable_declarations(self) -> None:
        from gracenotes_dev.sentry import github as gh

        # GraphQL requires commas between operation variables.
        self.assertIn("$owner:String!,$name:String!,$number:Int!", gh._REVIEW_THREADS_QUERY)


class SentryStateTailTest(unittest.TestCase):
    def test_read_recent_events_returns_last_lines(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            p = root / ".grace" / "sentry" / "events.jsonl"
            p.parent.mkdir(parents=True)
            with p.open("w", encoding="utf-8") as f:
                for i in range(120):
                    f.write(json.dumps({"i": i}) + "\n")
            events = read_recent_events(root, limit=5)
            self.assertEqual([e.get("i") for e in events], [115, 116, 117, 118, 119])

    def test_read_recent_events_small_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            p = root / ".grace" / "sentry" / "events.jsonl"
            p.parent.mkdir(parents=True)
            p.write_text('{"a":1}\n{"a":2}\n', encoding="utf-8")
            events = read_recent_events(root, limit=50)
            self.assertEqual(len(events), 2)
            self.assertEqual(events[0].get("a"), 1)


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
        for token in ["--once", "--dry-run", "--no-merge", "--tui", "--no-tui"]:
            self.assertIn(token, start_help.output)
