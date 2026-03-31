"""Unit tests for simulator destination parsing (no simctl)."""

from __future__ import annotations

import unittest

from gracenotes_dev import simulator


class SimulatorParsingTest(unittest.TestCase):
    def test_version_tuple(self) -> None:
        self.assertEqual(simulator.version_tuple("18.5"), (18, 5))
        self.assertEqual(simulator.version_tuple("26"), (26,))

    def test_parse_destination(self) -> None:
        d = simulator.parse_destination(
            "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest",
        )
        self.assertEqual(d.get("platform"), "iOS Simulator")
        self.assertEqual(d.get("name"), "iPhone 17 Pro")
        self.assertEqual(d.get("OS"), "latest")

    def test_resolve_latest_picks_newest_runtime(self) -> None:
        rows = [
            {"name": "iPhone 17 Pro", "runtime_version": "26.0", "runtime_key": "k", "udid": "a"},
            {"name": "iPhone 17 Pro", "runtime_version": "26.2", "runtime_key": "k", "udid": "b"},
        ]
        out = simulator.resolve_destination(
            "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest",
            rows,
        )
        self.assertEqual(out, "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2")

    def test_row_for_resolved_destination_returns_udid(self) -> None:
        rows = [
            {
                "name": "iPhone 17 Pro",
                "runtime_version": "26.0",
                "runtime_key": "k",
                "udid": "u-old",
            },
            {
                "name": "iPhone 17 Pro",
                "runtime_version": "26.2",
                "runtime_key": "k",
                "udid": "u-new",
            },
        ]
        resolved = "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2"
        row = simulator.row_for_resolved_destination(resolved, rows)
        self.assertIsNotNone(row)
        assert row is not None
        self.assertEqual(row["udid"], "u-new")

    def test_row_for_resolved_destination_none_when_no_match(self) -> None:
        rows = [
            {"name": "iPhone 17 Pro", "runtime_version": "26.0", "runtime_key": "k", "udid": "u1"}
        ]
        self.assertIsNone(
            simulator.row_for_resolved_destination(
                "platform=iOS Simulator,name=iPhone 17 Pro,OS=99.0",
                rows,
            ),
        )
