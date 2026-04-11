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
from gracenotes_dev.sentry.llm_client import (
    parse_fix_response,
    parse_merge_conflict_response,
    parse_pr_material_json,
)
from gracenotes_dev.sentry.merge_logic import can_merge
from gracenotes_dev.sentry.pr_template import build_pr_body_from_material, fallback_pr_material
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import format_report, read_recent_events


class SentryMergeLogicTest(unittest.TestCase):
    def test_merge_requires_ci_and_copilot_or_approve(self) -> None:
        self.assertTrue(
            can_merge(
                ci_ok=True,
                copilot_ok=True,
                approve_phrase_present=False,
            )
        )
        self.assertFalse(
            can_merge(ci_ok=True, copilot_ok=False, approve_phrase_present=False)
        )

    def test_approve_overrides_copilot_stuck(self) -> None:
        self.assertTrue(
            can_merge(ci_ok=True, copilot_ok=False, approve_phrase_present=True)
        )

    def test_ci_red_blocks(self) -> None:
        self.assertFalse(
            can_merge(ci_ok=False, copilot_ok=True, approve_phrase_present=False)
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
        self.assertEqual(s.main_branch, "main")
        self.assertTrue(s.yield_on_approval_pending)
        self.assertEqual(s.sentry_branch_prefix, "sentry/auto-")


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


class SentryPrMaterialParseTest(unittest.TestCase):
    def test_parse_pr_material_json_from_fence(self) -> None:
        inner = (
            '{"title": "Fix empty state", "headline": "H", "user_impact": "U", '
            '"what_changed": "W", "verification": "V"}'
        )
        raw = f"```json\n{inner}\n```\n"
        m = parse_pr_material_json(raw)
        self.assertEqual(m.title, "Fix empty state")
        self.assertEqual(m.headline, "H")
        self.assertEqual(m.verification, "V")

    def test_build_pr_body_from_material_contains_sections(self) -> None:
        m = fallback_pr_material("GraceNotes/Foo.swift")
        body = build_pr_body_from_material(
            m,
            risk="Low",
            touch=TouchClass.LOW_TOUCH,
            needs_human_line=False,
            approval_phrase="/x",
        )
        self.assertIn("## Headline", body)
        self.assertIn("## User impact", body)
        self.assertIn("## What changed", body)
        self.assertIn("## Verification", body)
        self.assertIn("Copilot review threads", body)


class SentryParseFixTest(unittest.TestCase):
    def test_no_change(self) -> None:
        self.assertEqual(parse_fix_response("NO_CHANGE"), "")

    def test_swift_block(self) -> None:
        out = parse_fix_response("Here:\n```swift\nlet x = 1\n```\n")
        self.assertIn("let x = 1", out)


class SentryParseMergeConflictTest(unittest.TestCase):
    def test_no_change(self) -> None:
        self.assertEqual(parse_merge_conflict_response("NO_CHANGE\n"), "")

    def test_any_fence_block(self) -> None:
        out = parse_merge_conflict_response("Ok:\n```\nline a\nline b\n```\n")
        self.assertIn("line a", out)
        self.assertIn("line b", out)

    def test_swift_fence(self) -> None:
        out = parse_merge_conflict_response("```swift\nfinal class X {}\n```")
        self.assertIn("final class X", out)


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

    def test_review_thread_author_logins_unique_sorted(self) -> None:
        from gracenotes_dev.sentry import github as gh

        nodes = [
            {
                "comments": {
                    "nodes": [
                        {"author": {"login": "copilot"}},
                        {"author": {"login": "alice"}},
                    ]
                }
            },
            {"comments": {"nodes": [{"author": {"login": "copilot"}}]}},
        ]
        self.assertEqual(gh.review_thread_author_logins(nodes), ["alice", "copilot"])

    def test_unresolved_copilot_threads_counts_matching_login(self) -> None:
        from gracenotes_dev.sentry import github as gh

        nodes = [
            {
                "isResolved": False,
                "comments": {"nodes": [{"author": {"login": "copilot"}}]},
            },
            {
                "isResolved": True,
                "comments": {"nodes": [{"author": {"login": "copilot"}}]},
            },
        ]
        self.assertEqual(gh.unresolved_copilot_threads(nodes, "copilot"), 1)
        self.assertEqual(gh.unresolved_copilot_threads(nodes, "Copilot"), 1)
        self.assertEqual(gh.unresolved_copilot_threads(nodes, None), 0)


class SentryGithubListPrsTest(unittest.TestCase):
    def test_list_open_sentry_pr_numbers_filters_and_sorts(self) -> None:
        from unittest import mock

        from gracenotes_dev.sentry import github as gh

        fake = mock.Mock(
            returncode=0,
            stdout=(
                '[{"number":12,"headRefName":"sentry/auto-1"},'
                '{"number":3,"headRefName":"sentry/auto-2"},'
                '{"number":99,"headRefName":"feature/foo"}]'
            ),
        )
        with mock.patch("subprocess.run", return_value=fake):
            nums = gh.list_open_sentry_pr_numbers(Path("/tmp"), "main", "sentry/auto-")
        self.assertEqual(nums, [3, 12])


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
        for token in ["start", "stop", "status", "report", "review-thread-authors"]:
            self.assertIn(token, result.output)
        start_help = runner.invoke(app, ["sentry", "start", "--help"])
        self.assertEqual(start_help.exit_code, 0)
        for token in ["--once", "--dry-run", "--no-merge", "--tui", "--no-tui"]:
            self.assertIn(token, start_help.output)
