"""Tests for l10n surface taxonomy."""

from __future__ import annotations

import unittest
from pathlib import Path

from gracenotes_dev.cli import l10n_surfaces


class TestL10nSurfaces(unittest.TestCase):
    def test_path_onboarding_is_first_run(self) -> None:
        s = l10n_surfaces.surface_for_path(
            "GraceNotes/GraceNotes/Features/Onboarding/OnboardingScreen.swift"
        )
        self.assertEqual(s, "first_run")

    def test_review_screen_is_past(self) -> None:
        s = l10n_surfaces.surface_for_path(
            "GraceNotes/GraceNotes/Features/Journal/Views/ReviewScreen.swift"
        )
        self.assertEqual(s, "past")

    def test_journal_screen_is_today(self) -> None:
        s = l10n_surfaces.surface_for_path(
            "GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift"
        )
        self.assertEqual(s, "today")

    def test_load_repo_overrides_returns_dict(self) -> None:
        root = Path(__file__).resolve().parents[3]
        mapping = l10n_surfaces.load_surface_overrides(root)
        self.assertIsInstance(mapping, dict)
        primary, _ = l10n_surfaces.primary_surface_for_key(
            "shell.tab.today",
            ["GraceNotes/GraceNotes/Application/GraceNotesApp.swift"],
            overrides=mapping,
        )
        self.assertIsInstance(primary, str)

    def test_fixture_override_changes_shell_tab(self) -> None:
        fixture_root = Path(__file__).resolve().parent / "fixtures"
        ov = l10n_surfaces.load_surface_overrides(fixture_root)
        primary, also = l10n_surfaces.primary_surface_for_key(
            "shell.tab.today",
            ["GraceNotes/GraceNotes/Application/GraceNotesApp.swift"],
            overrides=ov,
        )
        self.assertEqual(primary, "past")
        self.assertIn("shared", also)
