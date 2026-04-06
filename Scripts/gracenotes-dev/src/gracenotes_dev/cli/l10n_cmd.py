"""String-catalog (l10n) commands for ``grace``."""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from io import TextIOBase
from pathlib import Path
from typing import Annotated

import typer
from rich.console import Console, Group
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

from gracenotes_dev import xcode as xcode_helpers
from gracenotes_dev.cli import core as cli_core
from gracenotes_dev.cli.apps import l10n_app

PAT_STRING = re.compile(r'String\(localized:\s*"((?:[^"\\]|\\.)*)"')
PAT_LOCALIZED = re.compile(r'(?<![\w])localized:\s*\"((?:[^\"\\]|\\.)*)"')
# Keys resolved at runtime (see WeeklyInsightCandidateBuilder+Candidates.renderLocalizedTemplate).
DYNAMIC_TEMPLATE_KEYS = frozenset(
    {
        "review.insights.recurringPeople.observation",
        "review.insights.recurringPeople.action",
        "review.insights.recurringTheme.need.observation",
        "review.insights.recurringTheme.need.action",
        "review.insights.recurringTheme.gratitude.observation",
        "review.insights.recurringTheme.gratitude.action",
        "review.insights.needsGratitudeGap.observation",
        "review.insights.needsGratitudeGap.action",
        "review.insights.continuityShift.observation",
        "review.insights.continuityShift.action",
        "review.insights.reflectionDays.observation",
    }
)

_DUP_GROUPS_SHOWN = 40
_MULTI_FILE_SHOWN = 25
_UNUSED_KEYS_SHOWN = 80

_FOCUSED_MISSING_SHOWN = 20
_FOCUSED_UNUSED_SHOWN = 15
_FOCUSED_DUP_PREVIEW = 3


def _catalog_path(repo_root: Path) -> Path:
    return repo_root / "GraceNotes/GraceNotes/Localizable.xcstrings"


def _swift_roots(repo_root: Path) -> list[Path]:
    return [repo_root / "GraceNotes", repo_root / "GraceNotesTests"]


def _unescape_swift_string(inner: str) -> str:
    if "\\" in inner:
        return bytes(inner, "utf-8").decode("unicode_escape")
    return inner


def _keys_in_swift(repo_root: Path) -> tuple[set[str], dict[str, list[str]]]:
    found: set[str] = set()
    locations: dict[str, list[str]] = defaultdict(list)
    for base in _swift_roots(repo_root):
        if not base.is_dir():
            continue
        for path in base.rglob("*.swift"):
            text = path.read_text(encoding="utf-8")
            rel = str(path.relative_to(repo_root))
            for pattern in (PAT_STRING, PAT_LOCALIZED):
                for m in pattern.finditer(text):
                    k = _unescape_swift_string(m.group(1))
                    found.add(k)
                    locations[k].append(rel)
    return found, dict(locations)


@dataclass(frozen=True)
class StringsCatalogAuditReport:
    """Result of comparing Localizable.xcstrings to Swift literal references."""

    catalog_key_count: int
    code_key_count: int
    unused_keys: tuple[str, ...]
    missing_keys: tuple[str, ...]
    duplicate_english_groups: tuple[tuple[str, tuple[str, ...]], ...]
    multi_file_keys: tuple[tuple[str, tuple[str, ...]], ...]


def build_strings_catalog_audit(repo_root: Path) -> StringsCatalogAuditReport:
    """Load the catalog and Swift sources; return structured audit data (no printing)."""
    catalog_file = _catalog_path(repo_root)
    data = json.loads(catalog_file.read_text(encoding="utf-8"))
    catalog_keys = set(data.get("strings", {}).keys())

    code_keys, locs = _keys_in_swift(repo_root)
    effective_code = code_keys | DYNAMIC_TEMPLATE_KEYS
    unused = tuple(sorted(catalog_keys - effective_code))
    missing = tuple(sorted(code_keys - catalog_keys))

    by_en: dict[str, list[str]] = defaultdict(list)
    for key in catalog_keys:
        entry = data["strings"].get(key, {})
        try:
            en = entry["localizations"]["en"]["stringUnit"]["value"]
        except (KeyError, TypeError):
            continue
        by_en[en].append(key)

    dup_raw = [(en, ks) for en, ks in by_en.items() if len(ks) > 1 and en.strip()]
    dup_raw.sort(key=lambda x: -len(x[1]))
    duplicate_english_groups = tuple(
        (en, tuple(sorted(ks))) for en, ks in dup_raw
    )

    multi_raw = [(k, locs[k]) for k in code_keys if len(set(locs[k])) > 1]
    multi_raw.sort(key=lambda x: -len(x[1]))
    multi_file_keys = tuple(
        (k, tuple(sorted(set(paths)))) for k, paths in multi_raw
    )

    return StringsCatalogAuditReport(
        catalog_key_count=len(catalog_keys),
        code_key_count=len(code_keys),
        unused_keys=unused,
        missing_keys=missing,
        duplicate_english_groups=duplicate_english_groups,
        multi_file_keys=multi_file_keys,
    )


def _render_focused_plain(report: StringsCatalogAuditReport, stream: TextIOBase) -> None:
    print("=== grace l10n audit ===\n", file=stream)
    n_miss = len(report.missing_keys)
    n_unused = len(report.unused_keys)
    n_dup = len(report.duplicate_english_groups)
    n_multi = len(report.multi_file_keys)

    if n_miss:
        print(
            f"Status: Action required — {n_miss} key(s) in Swift are missing from "
            "Localizable.xcstrings (translations will not apply; build may fall back to keys).\n",
            file=stream,
        )
    elif n_unused or n_dup or n_multi:
        print(
            "Status: OK — no missing keys. Optional cleanup and review items below.\n",
            file=stream,
        )
    else:
        print(
            "Status: OK — catalog matches scanned Swift (GraceNotes, GraceNotesTests).\n",
            file=stream,
        )

    print(
        f"Catalog: {report.catalog_key_count} keys | Swift literals: {report.code_key_count} "
        f"(+ {len(DYNAMIC_TEMPLATE_KEYS)} dynamic allowlist)\n",
        file=stream,
    )

    if report.missing_keys:
        print("## Action required — missing from catalog", file=stream)
        print(
            "Swift references these keys but they are not in the string catalog. "
            "Add them in Xcode (String Catalog) or edit Localizable.xcstrings.",
            file=stream,
        )
        for k in report.missing_keys[:_FOCUSED_MISSING_SHOWN]:
            print(f"  - {k}", file=stream)
        rest = n_miss - _FOCUSED_MISSING_SHOWN
        if rest > 0:
            print(f"  … {rest} more (run with --full)", file=stream)
        print(
            "\nNext: Add the keys with English (and zh-Hans if needed), then run "
            "`grace l10n audit` again.\n",
            file=stream,
        )

    if report.unused_keys:
        print("## Cleanup — unused catalog keys", file=stream)
        print(
            f"{n_unused} key(s) in the catalog have no matching "
            "String(localized:) / localized: literal in scanned Swift.",
            file=stream,
        )
        for k in report.unused_keys[:_FOCUSED_UNUSED_SHOWN]:
            print(f"  - {k}", file=stream)
        rest = n_unused - _FOCUSED_UNUSED_SHOWN
        if rest > 0:
            print(f"  … {rest} more (run with --full)", file=stream)
        print(
            "\nNext: Remove stale keys after confirming they are not loaded via "
            "String(localized: String.LocalizationValue(...)) or outside GraceNotes/*.swift "
            "scans. If runtime-built, add the key to DYNAMIC_TEMPLATE_KEYS in l10n_cmd.py "
            "(see LOCALIZATION.md).\n",
            file=stream,
        )

    if report.duplicate_english_groups:
        print("## Review — duplicate English under different keys", file=stream)
        print(
            f"{n_dup} group(s) share the same English text. Often intentional (different UI "
            "context); unify only when product agrees.",
            file=stream,
        )
        for en, ks in report.duplicate_english_groups[:_FOCUSED_DUP_PREVIEW]:
            print(f"  {en!r} -> {', '.join(ks)}", file=stream)
        rest = n_dup - _FOCUSED_DUP_PREVIEW
        if rest > 0:
            print(f"  … {rest} more groups (run with --full)", file=stream)
        print(
            "\nNext: Skim in Xcode or `grace l10n audit --full`; keep separate keys when "
            "VoiceOver or layout context differs.\n",
            file=stream,
        )

    if report.multi_file_keys:
        print("## FYI — keys referenced from multiple files", file=stream)
        top = report.multi_file_keys[0]
        print(
            f"{n_multi} key(s) appear in more than one file (highest fan-out: {top[0]}, "
            f"{len(top[1])} files).",
            file=stream,
        )
        print(
            "\nNext: Optional refactor if a single string is central; not a defect by itself.\n",
            file=stream,
        )

    if not n_miss and not n_unused and not n_dup and not n_multi:
        print(
            "Keys loaded only at runtime are not visible to this scan; if you add new template "
            "keys, update DYNAMIC_TEMPLATE_KEYS in cli/l10n_cmd.py.\n",
            file=stream,
        )
    else:
        print("---", file=stream)
        print("Full tables: `grace l10n audit --full`", file=stream)


def _render_focused_rich(report: StringsCatalogAuditReport, console: Console) -> None:
    n_miss = len(report.missing_keys)
    n_unused = len(report.unused_keys)
    n_dup = len(report.duplicate_english_groups)
    n_multi = len(report.multi_file_keys)

    if n_miss:
        status = Text(
            f"Action required — {n_miss} key(s) missing from Localizable.xcstrings",
            style="status.error",
        )
    elif n_unused or n_dup or n_multi:
        status = Text(
            "OK — no missing keys; optional cleanup/review below",
            style="status.ok",
        )
    else:
        status = Text(
            "OK — catalog matches scanned Swift",
            style="status.ok",
        )

    meta = Text.assemble(
        Text("Catalog: ", style="muted"),
        str(report.catalog_key_count),
        Text(" keys | Swift: ", style="muted"),
        str(report.code_key_count),
        Text(" (+ ", style="muted"),
        str(len(DYNAMIC_TEMPLATE_KEYS)),
        Text(" dynamic)", style="muted"),
    )
    status_panel = Panel(
        Group(status, Text(""), meta),
        title="Status",
        border_style="red" if n_miss else "green",
    )

    sections: list[Panel | Table] = [status_panel]

    if report.missing_keys:
        t = Table(title="Action required", show_header=False, border_style="red")
        t.add_column("Key", style="status.error", overflow="fold")
        for k in report.missing_keys[:_FOCUSED_MISSING_SHOWN]:
            t.add_row(k)
        rest = n_miss - _FOCUSED_MISSING_SHOWN
        if rest > 0:
            t.add_row(Text(f"… {rest} more — use --full", style="muted"))
        next_txt = Text(
            "Add keys in Xcode String Catalog or Localizable.xcstrings, then re-run this command.",
            style="dim",
        )
        sections.append(Panel(Group(t, Text(""), Text("Next:", style="accent"), next_txt)))

    if report.unused_keys:
        t = Table(title="Cleanup — unused in catalog", show_header=False, border_style="yellow")
        t.add_column("Key", overflow="fold")
        for k in report.unused_keys[:_FOCUSED_UNUSED_SHOWN]:
            t.add_row(k)
        rest = n_unused - _FOCUSED_UNUSED_SHOWN
        if rest > 0:
            t.add_row(Text(f"… {rest} more — use --full", style="muted"))
        next_txt = Text(
            "Remove stale keys after review, or add runtime keys to DYNAMIC_TEMPLATE_KEYS "
            "(see LOCALIZATION.md).",
            style="dim",
        )
        sections.append(Panel(Group(t, Text(""), Text("Next:", style="accent"), next_txt)))

    if report.duplicate_english_groups:
        t = Table(title="Review — duplicate English", show_header=True, border_style="yellow")
        t.add_column("English", overflow="fold")
        t.add_column("Keys", style="muted", overflow="fold")
        for en, ks in report.duplicate_english_groups[:_FOCUSED_DUP_PREVIEW]:
            t.add_row(en, ", ".join(ks))
        rest = n_dup - _FOCUSED_DUP_PREVIEW
        if rest > 0:
            t.add_row(Text(f"… {rest} groups — use --full", style="muted"), "")
        next_txt = Text(
            "Decide per group whether split keys are intentional; use --full for the full list.",
            style="dim",
        )
        sections.append(Panel(Group(t, Text(""), Text("Next:", style="accent"), next_txt)))

    if report.multi_file_keys:
        top = report.multi_file_keys[0]
        body = Text.assemble(
            f"{n_multi} shared key(s). Highest fan-out: ",
            (top[0], "cyan"),
            f" ({len(top[1])} files).",
        )
        next_txt = Text(
            "Optional refactor if one key spans many features; not an error.",
            style="dim",
        )
        sections.append(
            Panel(Group(body, Text(""), Text("Next:", style="accent"), next_txt), title="FYI"),
        )

    if not (n_miss or n_unused or n_dup or n_multi):
        reminder = Text(
            "Runtime-only keys need an entry in DYNAMIC_TEMPLATE_KEYS in l10n_cmd.py.",
            style="dim",
        )
        sections.append(Panel(reminder, title="Reminder", border_style="dim"))
    else:
        sections.append(
            Panel(
                Text("Run `grace l10n audit --full` for exhaustive tables.", style="muted"),
                border_style="dim",
            ),
        )

    console.print(
        Panel.fit(
            Group(*sections),
            title="grace l10n audit",
            border_style="accent",
        ),
    )


def _render_audit_plain(report: StringsCatalogAuditReport, stream: TextIOBase) -> None:
    dyn_n = len(DYNAMIC_TEMPLATE_KEYS)
    print("=== Grace Notes string catalog audit ===\n", file=stream)
    print(f"Catalog keys: {report.catalog_key_count}", file=stream)
    print(
        f"Keys referenced in Swift: {report.code_key_count} (+ {dyn_n} dynamic template keys)",
        file=stream,
    )
    print(f"Unused in catalog (not referenced): {len(report.unused_keys)}", file=stream)
    print(f"Referenced but missing from catalog: {len(report.missing_keys)}", file=stream)
    print(file=stream)

    if report.missing_keys:
        print("--- Missing from catalog (build will fall back poorly) ---", file=stream)
        for k in report.missing_keys:
            print(f"  {k!r}", file=stream)
        print(file=stream)

    print("--- Duplicate English values (review for accidental copy drift) ---", file=stream)
    if not report.duplicate_english_groups:
        print("  (none)", file=stream)
    else:
        for en, ks in report.duplicate_english_groups[:_DUP_GROUPS_SHOWN]:
            print(f"  {en!r} ({len(ks)} keys)", file=stream)
            for k in ks:
                print(f"    - {k}", file=stream)
        rest = len(report.duplicate_english_groups) - _DUP_GROUPS_SHOWN
        if rest > 0:
            print(f"  ... and {rest} more groups", file=stream)
    print(file=stream)

    print("--- Keys referenced from multiple files (highest fan-out) ---", file=stream)
    for k, paths in report.multi_file_keys[:_MULTI_FILE_SHOWN]:
        print(f"  {k}", file=stream)
        for p in paths[:8]:
            print(f"    {p}", file=stream)
        if len(paths) > 8:
            print(f"    ... +{len(paths) - 8} more", file=stream)
    print(file=stream)

    print(f"--- Unused keys (first {_UNUSED_KEYS_SHOWN}) ---", file=stream)
    for k in report.unused_keys[:_UNUSED_KEYS_SHOWN]:
        print(f"  {k}", file=stream)
    if len(report.unused_keys) > _UNUSED_KEYS_SHOWN:
        print(f"  ... {len(report.unused_keys) - _UNUSED_KEYS_SHOWN} more", file=stream)
    print(file=stream)
    print(
        "Tip: unused keys are safe to delete after manual review if they are not "
        "loaded dynamically (e.g. String(localized: String.LocalizationValue(key))) "
        "or used from tests only.",
        file=stream,
    )


def _render_audit_rich(report: StringsCatalogAuditReport, console: Console) -> None:
    dyn_n = len(DYNAMIC_TEMPLATE_KEYS)
    summary = Table(title="Summary", show_header=True, header_style="accent")
    summary.add_column("Metric", style="muted", no_wrap=True)
    summary.add_column("Value", style="default")
    summary.add_row("Catalog keys", str(report.catalog_key_count))
    summary.add_row(
        "Keys in Swift (+ dynamic allowlist)",
        f"{report.code_key_count} (+ {dyn_n} template keys)",
    )
    unused_style = "status.other" if report.unused_keys else "status.ok"
    summary.add_row(
        "Unused in catalog",
        Text(str(len(report.unused_keys)), style=unused_style),
    )
    missing_style = "status.error" if report.missing_keys else "status.ok"
    summary.add_row(
        "Missing from catalog",
        Text(str(len(report.missing_keys)), style=missing_style),
    )

    body: list[Panel | Table] = [summary]

    if report.missing_keys:
        miss = Table(title="Missing from catalog", border_style="red", show_lines=False)
        miss.add_column("Key", style="status.error", overflow="fold")
        for k in report.missing_keys:
            miss.add_row(k)
        body.append(miss)

    dup = Table(title="Duplicate English values", border_style="yellow")
    dup.add_column("English", style="default", overflow="fold")
    dup.add_column("Keys", style="muted", overflow="fold")
    if not report.duplicate_english_groups:
        dup.add_row("(none)", "")
    else:
        shown = 0
        for en, ks in report.duplicate_english_groups:
            if shown >= _DUP_GROUPS_SHOWN:
                rest = len(report.duplicate_english_groups) - shown
                dup.add_row(f"… {rest} more groups", "")
                break
            dup.add_row(en, "\n".join(ks))
            shown += 1
    body.append(dup)

    multi = Table(title="Keys referenced from multiple files", border_style="cyan")
    multi.add_column("Key", no_wrap=True)
    multi.add_column("Files", style="muted", overflow="fold")
    if not report.multi_file_keys:
        multi.add_row("(none)", "")
    else:
        for k, paths in report.multi_file_keys[:_MULTI_FILE_SHOWN]:
            display_paths = list(paths[:8])
            if len(paths) > 8:
                display_paths.append(f"… +{len(paths) - 8} more")
            multi.add_row(k, "\n".join(display_paths))
    body.append(multi)

    unused_tbl = Table(
        title=f"Unused catalog keys (first {_UNUSED_KEYS_SHOWN})",
        border_style="dim",
    )
    unused_tbl.add_column("Key", style="muted", overflow="fold")
    if not report.unused_keys:
        unused_tbl.add_row("(none)")
    else:
        for k in report.unused_keys[:_UNUSED_KEYS_SHOWN]:
            unused_tbl.add_row(k)
        rest = len(report.unused_keys) - _UNUSED_KEYS_SHOWN
        if rest > 0:
            unused_tbl.add_row(Text(f"… {rest} more", style="muted"))

    body.append(unused_tbl)

    tip = Text(
        "Unused keys: delete only after manual review if nothing loads them dynamically "
        "(e.g. String(localized: String.LocalizationValue(key))) "
        "or uses them outside the scanned paths.",
        style="dim",
    )
    body.append(Panel(tip, title="Tip", border_style="dim"))

    console.print(
        Panel.fit(
            Group(*body),
            title="Grace Notes — string catalog audit",
            border_style="accent",
        ),
    )


def print_strings_catalog_audit(
    *,
    repo_root: Path,
    stream: TextIOBase | None = None,
    full: bool = False,
) -> None:
    """Build the audit and print to ``stream`` (default stdout), plain or Rich by TTY.

    When ``full`` is False (default), print a short status, capped samples, and next steps.
    When ``full`` is True, print the legacy exhaustive tables.
    """
    report = build_strings_catalog_audit(repo_root)
    out = stream if stream is not None else sys.stdout
    use_rich = stream is None and cli_core._supports_rich_output(sys.stdout)
    if full:
        if use_rich:
            _render_audit_rich(report, cli_core._stdout_console())
        else:
            _render_audit_plain(report, out)
    elif use_rich:
        _render_focused_rich(report, cli_core._stdout_console())
    else:
        _render_focused_plain(report, out)


@l10n_app.command("audit")
def l10n_audit(
    full: Annotated[
        bool,
        typer.Option(
            "--full",
            help="Print exhaustive tables instead of the short summary and next steps.",
        ),
    ] = False,
) -> None:
    """Compare Localizable.xcstrings keys to Swift ``String(localized:)`` / ``localized:`` usage."""
    repo_root = xcode_helpers.repo_root_from(Path.cwd())
    catalog = repo_root / "GraceNotes/GraceNotes/Localizable.xcstrings"
    if not catalog.is_file():
        cli_core._fail(
            code=2,
            title="Localization catalog not found",
            problem=f"Expected catalog at {catalog}",
            likely_cause="Run from the Grace Notes repo root (directory containing GraceNotes/).",
            try_commands=("cd …/grace-notes", "grace l10n audit"),
        )
    print_strings_catalog_audit(repo_root=repo_root, full=full)
