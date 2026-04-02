"""Unit tests for simulator destination parsing (no simctl)."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from gracenotes_dev import simulator

_FIXTURES = Path(__file__).resolve().parent / "fixtures"


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

    def test_user_destination_requests_physical_ios(self) -> None:
        self.assertTrue(
            simulator.user_destination_requests_physical_ios("platform=iOS,id=00008140-001"),
        )
        self.assertFalse(
            simulator.user_destination_requests_physical_ios("platform=iOS Simulator,name=X,OS=1"),
        )
        self.assertFalse(simulator.user_destination_requests_physical_ios("iPhone 17 Pro@latest"))

    def test_physical_udid_from_resolved_destination(self) -> None:
        self.assertEqual(
            simulator.physical_udid_from_resolved_destination("platform=iOS,id=abc"),
            "abc",
        )
        self.assertIsNone(
            simulator.physical_udid_from_resolved_destination(
                "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0",
            ),
        )

    def test_resolve_physical_destination_by_udid(self) -> None:
        devices = [
            {"name": "P", "udid": "00008140-111", "identifier": "core", "os_version": "18.0"},
        ]
        out = simulator.resolve_physical_destination("platform=iOS,id=00008140-111", devices)
        self.assertEqual(out, "platform=iOS,id=00008140-111")

    def test_resolve_physical_destination_by_name(self) -> None:
        devices = [
            {"name": "P", "udid": "u1", "identifier": "core", "os_version": "18.0"},
        ]
        out = simulator.resolve_physical_destination("platform=iOS,name=P", devices)
        self.assertEqual(out, "platform=iOS,id=u1")

    def test_parse_devicetypes_json_filters_ios_handsets(self) -> None:
        raw = json.loads((_FIXTURES / "simctl_devicetypes.json").read_text(encoding="utf-8"))
        rows = simulator.parse_simctl_devicetypes_json_payload(raw)
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0].name, "iPad Pro 11-inch (M4)")
        self.assertEqual(rows[1].name, "iPhone 17 Pro")

    def test_parse_runtimes_json_orders_available_before_version(self) -> None:
        raw = json.loads((_FIXTURES / "simctl_runtimes.json").read_text(encoding="utf-8"))
        rows = simulator.parse_simctl_runtimes_json_payload(raw)
        self.assertEqual(len(rows), 3)
        self.assertEqual(rows[0].version, "18.5")
        self.assertEqual(rows[1].version, "26.0")
        self.assertFalse(rows[2].is_available)

    def test_resolve_ios_runtime_latest_prefers_available(self) -> None:
        raw = json.loads((_FIXTURES / "simctl_runtimes.json").read_text(encoding="utf-8"))
        rows = simulator.parse_simctl_runtimes_json_payload(raw)
        pick = simulator.resolve_ios_runtime_for_os_spec(rows, "latest")
        self.assertIsNotNone(pick)
        assert pick is not None
        self.assertEqual(pick.version, "26.0")

    def test_devicetype_for_name_case_insensitive(self) -> None:
        dts = [
            simulator.DeviceTypeRecord(
                name="iPhone 17 Pro",
                identifier="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
            )
        ]
        found = simulator.devicetype_for_name(dts, "iphone 17 pro")
        self.assertIsNotNone(found)
        assert found is not None
        self.assertEqual(found.identifier, dts[0].identifier)
