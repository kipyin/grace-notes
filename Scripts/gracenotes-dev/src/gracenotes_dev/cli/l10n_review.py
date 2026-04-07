"""Surface-based localization review data and interactive flow (issue #224)."""

from __future__ import annotations

import json
from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

import questionary
import typer
from rich.console import Group
from rich.panel import Panel
from rich.text import Text

from gracenotes_dev import config
from gracenotes_dev.cli import core as cli_core
from gracenotes_dev.cli import l10n_cmd, l10n_surfaces
from gracenotes_dev.cli_rich import QUESTIONARY_STYLE


@dataclass(frozen=True)
class LocalizedPair:
    """One catalog key prepared for review (English + zh-Hans + audit hints)."""

    key: str
    en: str | None
    zh_hans: str | None
    catalog_comment: str | None
    example_paths: tuple[str, ...]
    primary_surface: str
    also_surfaces: frozenset[str]
    audit: frozenset[str]


def _catalog_file(repo_root: Path) -> Path:
    return repo_root / "GraceNotes/GraceNotes/Localizable.xcstrings"


def _localization_unit(entry: dict[str, object], locale: str) -> str | None:
    try:
        locs = entry["localizations"]  # type: ignore[index]
        if not isinstance(locs, dict):
            return None
        lu = locs[locale]  # type: ignore[index]
        if not isinstance(lu, dict):
            return None
        su = lu["stringUnit"]  # type: ignore[index]
        if not isinstance(su, dict):
            return None
        val = su["value"]
        return str(val) if val is not None else None
    except (KeyError, TypeError):
        return None


def _catalog_comment(entry: dict[str, object]) -> str | None:
    raw = entry.get("comment")
    return str(raw) if isinstance(raw, str) and raw.strip() else None


def _review_audit_sets(
    code_keys: set[str],
    locs: dict[str, list[str]],
    catalog_strings: dict[str, object],
) -> tuple[set[str], set[str], set[str]]:
    """Derive duplicate-English, multi-file, and missing-catalog flags from one Swift scan."""
    english_to_keys: dict[str, list[str]] = defaultdict(list)
    for key, entry in catalog_strings.items():
        if not isinstance(entry, dict):
            continue
        en = _localization_unit(entry, "en")
        if en is None or not en.strip():
            continue
        english_to_keys[en].append(key)
    dup_keys: set[str] = set()
    for keys in english_to_keys.values():
        if len(keys) > 1:
            dup_keys.update(keys)
    multi_keys = {k for k in code_keys if len(set(locs.get(k, []))) > 1}
    catalog_key_set = set(catalog_strings.keys())
    missing_set = {k for k in code_keys if k not in catalog_key_set}
    return dup_keys, multi_keys, missing_set


def build_review_index(repo_root: Path) -> dict[str, tuple[LocalizedPair, ...]]:
    """Group Swift-used keys (plus dynamic template allowlist) by primary product surface."""
    overrides = l10n_surfaces.load_surface_overrides(repo_root)
    code_keys, locs = l10n_cmd.swift_localization_key_locations(repo_root)
    catalog_path = _catalog_file(repo_root)
    data = json.loads(catalog_path.read_text(encoding="utf-8"))
    catalog_strings = data.get("strings", {})
    if not isinstance(catalog_strings, dict):
        catalog_strings = {}

    dup_keys, multi_keys, missing_set = _review_audit_sets(code_keys, locs, catalog_strings)

    keys_to_review = set(code_keys) | l10n_cmd.DYNAMIC_TEMPLATE_KEYS

    by_surface: dict[str, list[LocalizedPair]] = defaultdict(list)

    for key in sorted(keys_to_review):
        paths_list = locs.get(key, [])
        primary, also = l10n_surfaces.primary_surface_for_key(
            key,
            paths_list,
            overrides=overrides,
        )
        entry = catalog_strings.get(key, {})
        if not isinstance(entry, dict):
            entry = {}

        en = _localization_unit(entry, "en") if entry else None
        zh = _localization_unit(entry, "zh-Hans") if entry else None
        comment = _catalog_comment(entry) if entry else None
        unique_paths = tuple(sorted(set(paths_list)))
        if not unique_paths and key in l10n_cmd.DYNAMIC_TEMPLATE_KEYS:
            unique_paths = ("(runtime / dynamic template)",)

        audit: set[str] = set()
        if key in missing_set:
            audit.add("missing")
        if key in multi_keys:
            audit.add("multi_file")
        if key in dup_keys:
            audit.add("duplicate_en")

        by_surface[primary].append(
            LocalizedPair(
                key=key,
                en=en,
                zh_hans=zh,
                catalog_comment=comment,
                example_paths=unique_paths,
                primary_surface=primary,
                also_surfaces=also,
                audit=frozenset(audit),
            ),
        )

    return {surf: tuple(sorted(rows, key=lambda r: r.key)) for surf, rows in by_surface.items()}


def _zh_placeholder() -> str:
    return "(no zh-Hans in catalog)"


def append_review_note(path: Path, key: str, note: str) -> None:
    """Append one markdown bullet; create file with UTC header when new or empty."""
    line = f"- **{key}** — {note}\n"
    new_file = not path.exists() or path.stat().st_size == 0
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        cli_core._fail(
            code=1,
            title="Could not create notes directory",
            problem=f"Could not create notes directory '{path.parent}': {exc}",
            likely_cause="Check permissions or choose a different --notes path.",
        )
    try:
        with path.open("a", encoding="utf-8") as fh:
            if new_file:
                ts = datetime.now(tz=UTC).strftime("%Y-%m-%d %H:%M:%S UTC")
                fh.write(f"# grace l10n review notes ({ts})\n\n")
            fh.write(line)
    except OSError as exc:
        cli_core._fail(
            code=1,
            title="Could not write review notes",
            problem=f"Could not write review notes to '{path}': {exc}",
            likely_cause="Check disk space and permissions.",
        )


def run_l10n_review_interactive(
    repo_root: Path,
    *,
    notes_path: Path | None,
    walk_all: bool,
) -> None:
    """TTY-only interactive walkthrough; append optional Markdown notes."""
    cfg = config.load_config(repo_root=repo_root)
    cli_core._require_interactive_cli(cfg=cfg, command_name="grace l10n review")

    index = build_review_index(repo_root)
    surface_order = (
        l10n_surfaces.SURFACE_FIRST_RUN,
        l10n_surfaces.SURFACE_TODAY,
        l10n_surfaces.SURFACE_PAST,
        l10n_surfaces.SURFACE_SETTINGS,
        l10n_surfaces.SURFACE_SHARED,
    )
    labels = {
        l10n_surfaces.SURFACE_FIRST_RUN: "First run (onboarding / tutorial)",
        l10n_surfaces.SURFACE_TODAY: "Today (journal)",
        l10n_surfaces.SURFACE_PAST: "Past (review / history / search)",
        l10n_surfaces.SURFACE_SETTINGS: "Settings",
        l10n_surfaces.SURFACE_SHARED: "Shared (common / shell / app chrome)",
    }

    available = [s for s in surface_order if index.get(s)]
    if not available:
        cli_core._fail(
            code=1,
            title="Nothing to review",
            problem="No Swift localization keys found for this repo root.",
            likely_cause="Run from the Grace Notes repository root.",
        )

    out_notes = notes_path
    if out_notes is None:
        stamp = datetime.now(tz=UTC).strftime("%Y%m%d-%H%M%S")
        out_notes = repo_root / f"l10n-review-notes-{stamp}.md"

    console = cli_core._stdout_console()

    console.print(
        Panel.fit(
            Text(f"Notes file: {out_notes}", style="muted"),
            title="grace l10n review",
            border_style="accent",
        ),
    )

    surfaces_to_walk: list[str]
    if walk_all:
        surfaces_to_walk = available
    else:
        choices = [(labels[s], s) for s in available]
        choices.append(("All surfaces (sequential)", "___ALL___"))
        picked = questionary.select(
            "Which surface do you want to review?",
            choices=[questionary.Choice(title, value=val) for title, val in choices],
            style=QUESTIONARY_STYLE,
        ).ask()
        if picked is None:
            raise typer.Exit(code=1)
        if picked == "___ALL___":
            surfaces_to_walk = available
        else:
            surfaces_to_walk = [picked]

    for surface in surfaces_to_walk:
        rows = index.get(surface, ())
        if not rows:
            continue
        console.print(
            Panel.fit(
                Text(f"{labels.get(surface, surface)} ({len(rows)} keys)", style="accent"),
                title="Surface",
                border_style="accent",
            ),
        )
        for row in rows:
            en_display = row.en if row.en is not None else "(missing from catalog)"
            zh_display = row.zh_hans if row.zh_hans is not None else _zh_placeholder()
            paths_preview = "\n".join(row.example_paths[:6])
            if len(row.example_paths) > 6:
                paths_preview += f"\n… +{len(row.example_paths) - 6} more"
            also_line = ""
            if row.also_surfaces:
                also_line = "\nAlso referenced from: " + ", ".join(sorted(row.also_surfaces))
            audit_line = ""
            if row.audit:
                audit_line = "\nAudit: " + ", ".join(sorted(row.audit))
            comment_line = ""
            if row.catalog_comment:
                comment_line = "\nComment: " + row.catalog_comment
            body = Group(
                Text.assemble(Text("Key: ", style="muted"), (row.key, "bold")),
                Text.assemble(Text("en: ", style="muted"), en_display),
                Text.assemble(Text("zh-Hans: ", style="muted"), zh_display),
                Text.assemble(Text("Paths:\n", style="muted"), paths_preview),
                Text(comment_line) if comment_line else Text(""),
                Text(audit_line) if audit_line else Text(""),
                Text(also_line) if also_line else Text(""),
            )
            console.print(Panel.fit(body, title=row.key, border_style="dim"))

            action = questionary.select(
                "Continue?",
                choices=[
                    questionary.Choice("Next", value="next"),
                    questionary.Choice("Skip remainder of this surface", value="skip"),
                    questionary.Choice("Quit", value="quit"),
                ],
                style=QUESTIONARY_STYLE,
            ).ask()
            if action is None or action == "quit":
                raise typer.Exit(code=0)
            if action == "skip":
                break

            note_raw = questionary.text(
                "Note (optional, Enter to skip)",
                style=QUESTIONARY_STYLE,
            ).ask()
            if note_raw and str(note_raw).strip():
                append_review_note(out_notes, row.key, str(note_raw).strip())

        console.print(Text("— End of surface —\n", style="muted"))
