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
from gracenotes_dev.sentry import github as gh_sentry
from gracenotes_dev.sentry import runner as sentry_runner
from gracenotes_dev.sentry.classify import TouchClass, classify_paths
from gracenotes_dev.sentry.llm_client import (
    parse_ci_fix_response,
    parse_fix_response,
    parse_merge_conflict_response,
    parse_pr_material_json,
)
from gracenotes_dev.sentry.merge_logic import can_merge
from gracenotes_dev.sentry.pr_template import build_pr_body_from_material, fallback_pr_material
from gracenotes_dev.sentry.review_gates import review_wait_satisfied
from gracenotes_dev.sentry.settings import SentrySettings
from gracenotes_dev.sentry.state import format_report, read_recent_events


class SentryMergeLogicTest(unittest.TestCase):
    def test_merge_requires_ci_and_reviewers_or_approve(self) -> None:
        self.assertTrue(
            can_merge(
                ci_ok=True,
                reviewers_ok=True,
                approve_phrase_present=False,
            )
        )
        self.assertFalse(
            can_merge(
                ci_ok=True,
                reviewers_ok=False,
                approve_phrase_present=False,
            )
        )

    def test_approve_overrides_reviewers_stuck(self) -> None:
        self.assertTrue(
            can_merge(
                ci_ok=True,
                reviewers_ok=False,
                approve_phrase_present=True,
            )
        )

    def test_reviewers_not_clear_blocks_without_approve(self) -> None:
        self.assertFalse(
            can_merge(
                ci_ok=True,
                reviewers_ok=False,
                approve_phrase_present=False,
            )
        )

    def test_ci_red_blocks(self) -> None:
        self.assertFalse(
            can_merge(
                ci_ok=False,
                reviewers_ok=True,
                approve_phrase_present=False,
            )
        )


class SentryListAtRefTest(unittest.TestCase):
    def test_ls_tree_failure_raises_runtime_error(self) -> None:
        fake = mock.Mock(returncode=128, stdout="", stderr="fatal: Not a valid object name")
        with mock.patch("subprocess.run", return_value=fake):
            with self.assertRaises(RuntimeError) as ctx:
                sentry_runner.list_gracenotes_swift_files_at_ref(Path("/repo"), "origin/nope")
        self.assertIn("git ls-tree failed", str(ctx.exception))
        self.assertIn("origin/nope", str(ctx.exception))


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


class SentryReviewGatesTest(unittest.TestCase):
    def test_review_wait_satisfied_empty_allowlist(self) -> None:
        self.assertTrue(
            review_wait_satisfied(
                pr_created_at=None,
                review_silence_timeout_seconds=0,
                comments=[],
                pr_reviews=[],
                reviewer_logins=(),
                start_phrases=(),
            )
        )

    def test_review_wait_satisfied_after_silence_when_stuck_on_start(self) -> None:
        from datetime import datetime, timedelta, timezone

        old = datetime.now(timezone.utc) - timedelta(seconds=10_000)
        self.assertTrue(
            review_wait_satisfied(
                pr_created_at=old,
                review_silence_timeout_seconds=60,
                comments=[{"user": {"login": "x"}, "body": "Taking a look"}],
                pr_reviews=[],
                reviewer_logins=("x",),
                start_phrases=("Taking a look",),
            )
        )

    def test_review_wait_blocks_before_silence_when_stuck_on_start(self) -> None:
        from datetime import datetime, timedelta, timezone

        recent = datetime.now(timezone.utc) - timedelta(seconds=5)
        self.assertFalse(
            review_wait_satisfied(
                pr_created_at=recent,
                review_silence_timeout_seconds=3600,
                comments=[{"user": {"login": "x"}, "body": "Taking a look"}],
                pr_reviews=[],
                reviewer_logins=("x",),
                start_phrases=("Taking a look",),
            )
        )

    def test_review_wait_blocks_when_created_at_unknown_and_gate_not_ok(self) -> None:
        self.assertFalse(
            review_wait_satisfied(
                pr_created_at=None,
                review_silence_timeout_seconds=3600,
                comments=[{"user": {"login": "x"}, "body": "Taking a look"}],
                pr_reviews=[],
                reviewer_logins=("x",),
                start_phrases=("Taking a look",),
            )
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
        self.assertEqual(
            s.cursor_reviewer_logins,
            ("cursor[bot]", "cursor", "cursoragent"),
        )
        self.assertEqual(
            s.reviewer_logins,
            (
                "copilot-pull-request-reviewer",
                "cursor[bot]",
                "cursor",
                "cursoragent",
            ),
        )
        self.assertTrue(s.cursor_post_review_trigger)
        self.assertEqual(s.merge_sweep_budget_seconds, 120)
        self.assertEqual(s.merge_sweep_total_budget_seconds, 0)
        self.assertEqual(s.review_silence_timeout_seconds, 15 * 60)
        self.assertEqual(s.review_fix_cooldown_seconds, 180)
        self.assertEqual(s.cursor_review_fix_cooldown_seconds, 180)
        self.assertEqual(s.ci_fix_cooldown_seconds, 180)
        self.assertEqual(s.ci_fix_max_rounds_per_poll, 5)


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

    def test_cursor_reviewer_logins_empty_disables(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "GraceNotes").mkdir()
            (root / "gracenotes-dev.toml").write_text(
                "[sentry]\ncursor_reviewer_logins = []\n",
                encoding="utf-8",
            )
            s = SentrySettings.from_repo(root)
        self.assertEqual(s.cursor_reviewer_logins, ())
        self.assertFalse(s.cursor_post_review_trigger)

    def test_reviewer_logins_explicit_overrides_default_union(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "GraceNotes").mkdir()
            (root / "gracenotes-dev.toml").write_text(
                '[sentry]\nreviewer_logins = ["only-me"]\n',
                encoding="utf-8",
            )
            s = SentrySettings.from_repo(root)
        self.assertEqual(s.reviewer_logins, ("only-me",))

    def test_cursor_review_fix_cooldown_can_override_base(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "GraceNotes").mkdir()
            (root / "gracenotes-dev.toml").write_text(
                "[sentry]\n"
                "review_fix_cooldown_seconds = 100\n"
                "cursor_review_fix_cooldown_seconds = 250\n",
                encoding="utf-8",
            )
            s = SentrySettings.from_repo(root)
        self.assertEqual(s.review_fix_cooldown_seconds, 100)
        self.assertEqual(s.cursor_review_fix_cooldown_seconds, 250)
        self.assertEqual(s.ci_fix_cooldown_seconds, 250)

    def test_ci_fix_cooldown_can_override_cursor_default(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "GraceNotes").mkdir()
            (root / "gracenotes-dev.toml").write_text(
                "[sentry]\n"
                "cursor_review_fix_cooldown_seconds = 200\n"
                "ci_fix_cooldown_seconds = 400\n",
                encoding="utf-8",
            )
            s = SentrySettings.from_repo(root)
        self.assertEqual(s.cursor_review_fix_cooldown_seconds, 200)
        self.assertEqual(s.ci_fix_cooldown_seconds, 400)

    def test_reviewer_logins_defaults_union_copilot_and_cursor_when_unset(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "GraceNotes").mkdir()
            (root / "gracenotes-dev.toml").write_text(
                '[sentry]\ncursor_reviewer_logins = ["cursor[bot]"]\n',
                encoding="utf-8",
            )
            s = SentrySettings.from_repo(root)
        self.assertEqual(
            s.reviewer_logins,
            ("copilot-pull-request-reviewer", "cursor[bot]"),
        )


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
        self.assertIn("emergency override", body)


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


class SentryParseCiFixTest(unittest.TestCase):
    def test_swift_path_uses_swift_fence(self) -> None:
        out = parse_ci_fix_response("```swift\nlet a = 1\n```\n", "GraceNotes/Foo.swift")
        self.assertIn("let a = 1", out)

    def test_python_path_uses_any_fence(self) -> None:
        out = parse_ci_fix_response("```python\nx = 2\n```\n", "Scripts/gracenotes-dev/pkg/x.py")
        self.assertIn("x = 2", out)


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

    def test_unresolved_reviewer_threads_counts_allowlisted_logins(self) -> None:
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
        self.assertEqual(gh.unresolved_reviewer_threads(nodes, ("copilot",)), 1)
        self.assertEqual(gh.unresolved_reviewer_threads(nodes, ("Copilot",)), 1)
        self.assertEqual(gh.unresolved_reviewer_threads(nodes, ()), 0)

    def test_unresolved_cursor_threads_counts_matching_login(self) -> None:
        from gracenotes_dev.sentry import github as gh

        nodes = [
            {
                "isResolved": False,
                "comments": {"nodes": [{"author": {"login": "cursor"}, "body": "a"}]},
            },
            {
                "isResolved": False,
                "comments": {"nodes": [{"author": {"login": "human"}, "body": "b"}]},
            },
        ]
        self.assertEqual(gh.unresolved_cursor_threads(nodes, ("cursor",)), 1)
        self.assertEqual(gh.unresolved_cursor_threads(nodes, ()), 0)


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


class SentryCursorIssueReviewTest(unittest.TestCase):
    def test_empty_logins_always_ok(self) -> None:
        self.assertTrue(
            gh_sentry.cursor_issue_review_ok(
                [{"user": {"login": "cursor"}, "body": "Taking a look"}],
                (),
                ("Taking a look",),
            )
        )

    def test_no_cursor_comments_ok(self) -> None:
        self.assertTrue(
            gh_sentry.cursor_issue_review_ok(
                [{"user": {"login": "human"}, "body": "hi"}],
                ("cursor",),
                ("Taking a look",),
            )
        )

    def test_no_start_phrase_skips(self) -> None:
        self.assertTrue(
            gh_sentry.cursor_issue_review_ok(
                [{"user": {"login": "cursor"}, "body": "LGTM"}],
                ("cursor",),
                ("Taking a look",),
            )
        )

    def test_start_only_blocks(self) -> None:
        self.assertFalse(
            gh_sentry.cursor_issue_review_ok(
                [{"user": {"login": "cursor"}, "body": "Taking a look"}],
                ("cursor",),
                ("Taking a look",),
            )
        )

    def test_start_then_followup_ok(self) -> None:
        self.assertTrue(
            gh_sentry.cursor_issue_review_ok(
                [
                    {
                        "user": {"login": "cursor"},
                        "body": "Taking a look",
                        "created_at": "2020-01-01T00:00:01Z",
                    },
                    {
                        "user": {"login": "cursor"},
                        "body": "Here is the review.",
                        "created_at": "2020-01-01T00:00:02Z",
                    },
                ],
                ("cursor",),
                ("Taking a look",),
            )
        )

    def test_same_comment_substantive_tail_ok(self) -> None:
        body = "Taking a look.\n\n" + ("x" * 20)
        self.assertTrue(
            gh_sentry.cursor_issue_review_ok(
                [{"user": {"login": "cursor"}, "body": body}],
                ("cursor",),
                ("Taking a look",),
            )
        )


class SentryCursorPrReviewGateTest(unittest.TestCase):
    def test_pr_review_finished_comment_state(self) -> None:
        self.assertTrue(
            gh_sentry.cursor_pr_review_finished(
                [{"user": {"login": "cursor"}, "state": "COMMENTED"}],
                ("cursor",),
            )
        )

    def test_pr_review_finished_pending_not_done(self) -> None:
        self.assertFalse(
            gh_sentry.cursor_pr_review_finished(
                [{"user": {"login": "cursor"}, "state": "PENDING"}],
                ("cursor",),
            )
        )

    def test_merge_gate_ok_when_issue_stuck_but_pr_submitted(self) -> None:
        """Starter-only issue comment + real review via PR reviews API (deleted starter case)."""
        self.assertFalse(
            gh_sentry.cursor_issue_review_ok(
                [{"user": {"login": "cursor"}, "body": "Taking a look"}],
                ("cursor",),
                ("Taking a look",),
            )
        )
        self.assertTrue(
            gh_sentry.cursor_merge_gate_ok(
                comments=[{"user": {"login": "cursor"}, "body": "Taking a look"}],
                pr_reviews=[{"user": {"login": "cursor"}, "state": "COMMENTED"}],
                cursor_logins=("cursor",),
                start_phrases=("Taking a look",),
            )
        )

    def test_merge_gate_ok_when_issue_stuck_and_only_pending_review(self) -> None:
        self.assertFalse(
            gh_sentry.cursor_merge_gate_ok(
                comments=[{"user": {"login": "cursor"}, "body": "Taking a look"}],
                pr_reviews=[{"user": {"login": "cursor"}, "state": "PENDING"}],
                cursor_logins=("cursor",),
                start_phrases=("Taking a look",),
            )
        )

    def test_merge_gate_ok_changes_requested_counts_as_review_done(self) -> None:
        """``CHANGES_REQUESTED`` still satisfies ``cursor_merge_gate_ok`` (review submitted)."""
        self.assertTrue(
            gh_sentry.cursor_merge_gate_ok(
                comments=[{"user": {"login": "cursor"}, "body": "Taking a look"}],
                pr_reviews=[{"user": {"login": "cursor"}, "state": "CHANGES_REQUESTED"}],
                cursor_logins=("cursor",),
                start_phrases=("Taking a look",),
            )
        )


class SentryCursorMergeClearTest(unittest.TestCase):
    def test_empty_logins_always_clear(self) -> None:
        self.assertTrue(
            gh_sentry.cursor_merge_clear(
                review_thread_nodes=[],
                pr_reviews=[{"user": {"login": "cursor"}, "state": "CHANGES_REQUESTED"}],
                cursor_logins=(),
            )
        )

    def test_changes_requested_blocks_merge_clear(self) -> None:
        self.assertFalse(
            gh_sentry.cursor_merge_clear(
                review_thread_nodes=[],
                pr_reviews=[
                    {
                        "user": {"login": "cursor"},
                        "state": "CHANGES_REQUESTED",
                        "submitted_at": "2020-01-02T00:00:00Z",
                    },
                ],
                cursor_logins=("cursor",),
            )
        )

    def test_approved_is_clear(self) -> None:
        self.assertTrue(
            gh_sentry.cursor_merge_clear(
                review_thread_nodes=[],
                pr_reviews=[
                    {
                        "user": {"login": "cursor"},
                        "state": "APPROVED",
                        "submitted_at": "2020-01-02T00:00:00Z",
                    },
                ],
                cursor_logins=("cursor",),
            )
        )

    def test_latest_review_wins_over_older_changes_requested(self) -> None:
        self.assertTrue(
            gh_sentry.cursor_merge_clear(
                review_thread_nodes=[],
                pr_reviews=[
                    {
                        "user": {"login": "cursor"},
                        "state": "CHANGES_REQUESTED",
                        "submitted_at": "2020-01-01T00:00:00Z",
                    },
                    {
                        "user": {"login": "cursor"},
                        "state": "APPROVED",
                        "submitted_at": "2020-01-02T00:00:00Z",
                    },
                ],
                cursor_logins=("cursor",),
            )
        )

    def test_unresolved_cursor_thread_blocks(self) -> None:
        self.assertFalse(
            gh_sentry.cursor_merge_clear(
                review_thread_nodes=[
                    {
                        "isResolved": False,
                        "comments": {
                            "nodes": [
                                {"author": {"login": "cursor"}, "body": "fix this"},
                            ],
                        },
                    },
                ],
                pr_reviews=[],
                cursor_logins=("cursor",),
            )
        )


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
        for token in [
            "start",
            "stop",
            "status",
            "report",
            "review-thread-authors",
            "issue-comment-authors",
        ]:
            self.assertIn(token, result.output)
        start_help = runner.invoke(app, ["sentry", "start", "--help"])
        self.assertEqual(start_help.exit_code, 0)
        for token in ["--once", "--dry-run", "--no-merge", "--tui", "--no-tui"]:
            self.assertIn(token, start_help.output)


class MergePollCiFixTest(unittest.TestCase):
    def test_red_ci_runs_agent_fix_and_continues_loop(self) -> None:
        from gracenotes_dev.sentry.merge_poll import MergePollOutcome, merge_poll_once

        settings = mock.Mock()
        settings.fix_provider = "cursor_agent"
        settings.reviewer_logins = ()
        settings.approval_phrase = "/sentry-approve"
        settings.cursor_start_phrases = ()
        settings.review_silence_timeout_seconds = 900
        settings.cursor_review_fix_cooldown_seconds = 180
        settings.ci_fix_cooldown_seconds = 180
        settings.ci_fix_max_rounds_per_poll = 5

        patch_checks = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.pr_checks_passed",
            return_value=False,
        )
        patch_threads = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.graphql_review_threads",
            return_value=[],
        )
        patch_comments = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.issue_comments",
            return_value=[],
        )
        patch_reviews = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.pr_reviews",
            return_value=[],
        )
        patch_created = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.pr_created_at_utc",
            return_value=None,
        )
        patch_wait = mock.patch(
            "gracenotes_dev.sentry.merge_poll.review_wait_satisfied",
            return_value=True,
        )
        patch_clear = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.reviewers_merge_clear",
            return_value=True,
        )
        patch_should = mock.patch(
            "gracenotes_dev.sentry.merge_poll.ci_fix_should_attempt",
            return_value=True,
        )
        patch_mark = mock.patch("gracenotes_dev.sentry.merge_poll.ci_fix_mark_attempt")
        patch_try = mock.patch(
            "gracenotes_dev.sentry.merge_poll.try_fix_ci_with_agent",
            return_value=True,
        )

        with (
            patch_checks,
            patch_threads,
            patch_comments,
            patch_reviews,
            patch_created,
            patch_wait,
            patch_clear,
            patch_should,
            patch_mark,
            patch_try,
        ):
            out = merge_poll_once(
                Path("/tmp"),
                settings,
                "o",
                "r",
                42,
                set(),
                "main",
                sink=None,
            )
        self.assertEqual(out, MergePollOutcome.CONTINUE_LOOP)

    def test_red_ci_wait_for_gates_when_fix_returns_false(self) -> None:
        from gracenotes_dev.sentry.merge_poll import MergePollOutcome, merge_poll_once

        settings = mock.Mock()
        settings.fix_provider = "cursor_agent"
        settings.reviewer_logins = ()
        settings.approval_phrase = "/sentry-approve"
        settings.cursor_start_phrases = ()
        settings.review_silence_timeout_seconds = 900
        settings.cursor_review_fix_cooldown_seconds = 180
        settings.ci_fix_cooldown_seconds = 180
        settings.ci_fix_max_rounds_per_poll = 5

        patch_checks = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.pr_checks_passed",
            return_value=False,
        )
        patch_threads = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.graphql_review_threads",
            return_value=[],
        )
        patch_comments = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.issue_comments",
            return_value=[],
        )
        patch_reviews = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.pr_reviews",
            return_value=[],
        )
        patch_created = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.pr_created_at_utc",
            return_value=None,
        )
        patch_wait = mock.patch(
            "gracenotes_dev.sentry.merge_poll.review_wait_satisfied",
            return_value=True,
        )
        patch_clear = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.reviewers_merge_clear",
            return_value=True,
        )
        patch_should = mock.patch(
            "gracenotes_dev.sentry.merge_poll.ci_fix_should_attempt",
            return_value=True,
        )
        patch_try = mock.patch(
            "gracenotes_dev.sentry.merge_poll.try_fix_ci_with_agent",
            return_value=False,
        )

        with (
            patch_checks,
            patch_threads,
            patch_comments,
            patch_reviews,
            patch_created,
            patch_wait,
            patch_clear,
            patch_should,
            patch_try,
        ):
            out = merge_poll_once(
                Path("/tmp"),
                settings,
                "o",
                "r",
                42,
                set(),
                "main",
                sink=None,
            )
        self.assertEqual(out, MergePollOutcome.WAIT_FOR_GATES)

    def test_red_ci_skips_ci_fix_when_http_provider(self) -> None:
        from gracenotes_dev.sentry.merge_poll import merge_poll_once

        settings = mock.Mock()
        settings.fix_provider = "http"
        settings.reviewer_logins = ()
        settings.approval_phrase = "/sentry-approve"
        settings.cursor_start_phrases = ()
        settings.review_silence_timeout_seconds = 900
        settings.cursor_review_fix_cooldown_seconds = 180
        settings.ci_fix_cooldown_seconds = 180
        settings.ci_fix_max_rounds_per_poll = 5

        patch_checks = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.pr_checks_passed",
            return_value=False,
        )
        patch_threads = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.graphql_review_threads",
            return_value=[],
        )
        patch_comments = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.issue_comments",
            return_value=[],
        )
        patch_reviews = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.pr_reviews",
            return_value=[],
        )
        patch_created = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.pr_created_at_utc",
            return_value=None,
        )
        patch_wait = mock.patch(
            "gracenotes_dev.sentry.merge_poll.review_wait_satisfied",
            return_value=True,
        )
        patch_clear = mock.patch(
            "gracenotes_dev.sentry.merge_poll.gh_api.reviewers_merge_clear",
            return_value=True,
        )
        patch_try = mock.patch(
            "gracenotes_dev.sentry.merge_poll.try_fix_ci_with_agent",
            return_value=True,
        )

        with (
            patch_checks,
            patch_threads,
            patch_comments,
            patch_reviews,
            patch_created,
            patch_wait,
            patch_clear,
        ):
            with patch_try as mock_try:
                merge_poll_once(
                    Path("/tmp"),
                    settings,
                    "o",
                    "r",
                    42,
                    set(),
                    "main",
                    sink=None,
                )
        mock_try.assert_not_called()
