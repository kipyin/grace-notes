"""Tests for gracenotes-dev config loading."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from gracenotes_dev import config


class ConfigLoadingTest(unittest.TestCase):
    def test_load_config_uses_default_profiles(self) -> None:
        loaded = config.load_config(repo_root=Path("/tmp/does-not-exist"))
        self.assertIn("lint-build", loaded.ci_profiles)
        self.assertIn("test-all", loaded.ci_profiles)
        self.assertIn("full", loaded.ci_profiles)

    def test_load_config_merges_toml_overrides(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "gracenotes-dev.toml").write_text(
                """
[defaults]
scheme = "GraceNotes (Demo)"
destination = "platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.5"
test_destination_matrix = ["iPhone SE (3rd generation)@18.5"]

[ci.profiles.test-all]
lint = false
test_kind = "unit"
""".strip(),
                encoding="utf-8",
            )

            loaded = config.load_config(repo_root=root)
            self.assertEqual(loaded.scheme, "GraceNotes (Demo)")
            self.assertEqual(len(loaded.test_destination_matrix), 1)
            self.assertEqual(loaded.ci_profiles["test-all"].test_kind, "unit")
            self.assertFalse(loaded.ci_profiles["test-all"].lint)
