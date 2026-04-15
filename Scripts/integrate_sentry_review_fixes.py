#!/usr/bin/env python3
"""
Integrate origin/sentry-review-fix-<PR> branches onto the current branch.

Assumes you are on an integration branch based on origin/main. For each remote
branch (ascending PR #), tries to cherry-pick the "address PR review" commit;
on failure, attempts a merge. Logs actions to stdout.

Usage (from repo root):
  git checkout -b integrate/sentry-review-fixes origin/main
  python3 Scripts/integrate_sentry_review_fixes.py
  python3 Scripts/integrate_sentry_review_fixes.py --min-pr 290   # resume after a conflict stop
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys

REMOTE = "origin"
OWNER_REPO = "grace-notes"  # unused; kept for clarity


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, check=check)


def sh_out(cmd: list[str]) -> str:
    p = run(cmd, check=False)
    if p.returncode != 0:
        return ""
    return (p.stdout or "").strip()


def list_fix_branches() -> list[tuple[int, str]]:
    p = run(
        ["git", "ls-remote", REMOTE, "refs/heads/sentry-review-fix-*"],
        check=False,
    )
    if p.returncode != 0:
        print(p.stderr, file=sys.stderr)
        sys.exit(1)
    out: list[tuple[int, str]] = []
    for line in p.stdout.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        ref = parts[1]
        m = re.search(r"sentry-review-fix-(\d+)$", ref)
        if m:
            out.append((int(m.group(1)), ref.split("/")[-1]))
    out.sort(key=lambda x: x[0])
    return out


def commits_ahead(main_ref: str, branch_name: str) -> list[tuple[str, str]]:
    """Commits reachable from branch tip but not main, oldest first."""
    p = run(
        [
            "git",
            "log",
            "--reverse",
            "--format=%H %s",
            f"{main_ref}..{branch_name}",
        ],
        check=False,
    )
    if p.returncode != 0:
        return []
    rows: list[tuple[str, str]] = []
    for line in (p.stdout or "").strip().splitlines():
        if not line:
            continue
        sha, _, subj = line.partition(" ")
        rows.append((sha, subj))
    return rows


def pick_address_commit_sha(rows: list[tuple[str, str]]) -> str | None:
    for sha, subj in rows:
        s = subj.lower()
        if "address" in s and "review" in s:
            return sha
    if not rows:
        return None
    # Newest commit (last in --reverse list)
    return rows[-1][0]


def fetch_branch(branch_name: str) -> bool:
    p = run(
        ["git", "fetch", REMOTE, f"{branch_name}:refs/heads/{branch_name}"],
        check=False,
    )
    return p.returncode == 0


def cherry_pick(sha: str) -> int:
    p = run(["git", "cherry-pick", sha], check=False)
    if p.returncode == 0:
        return 0
    err = (p.stderr or "") + (p.stdout or "")
    if "nothing to commit" in err or "empty" in err.lower():
        run(["git", "cherry-pick", "--abort"], check=False)
        return 2
    return 1


def merge_branch(branch_name: str) -> bool:
    # Prefer the fix branch for overlapping hunks (main already has the Sentry refine; we want the review patch).
    p = run(
        [
            "git",
            "merge",
            "--no-ff",
            "-X",
            "theirs",
            "-m",
            f"Merge {branch_name}",
            branch_name,
        ],
        check=False,
    )
    return p.returncode == 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Integrate sentry-review-fix-* branches.")
    parser.add_argument(
        "--min-pr",
        type=int,
        default=0,
        metavar="N",
        help="Only process branches sentry-review-fix-M where M >= N (for resume).",
    )
    args = parser.parse_args()
    min_pr = args.min_pr

    main_ref = f"{REMOTE}/main"
    branches = [(n, b) for n, b in list_fix_branches() if n >= min_pr]
    stats = {
        "total_remote": len(branches),
        "skipped_no_ahead": 0,
        "cherry_pick_ok": 0,
        "cherry_pick_empty": 0,
        "cherry_pick_conflict": 0,
        "merge_ok": 0,
        "merge_fail": 0,
        "fetch_fail": 0,
    }

    print(f"Found {len(branches)} remote sentry-review-fix-* branches.", flush=True)
    print(f"Base: {main_ref} (current HEAD should be based on this)\n", flush=True)

    for pr, branch_name in branches:
        if not fetch_branch(branch_name):
            print(f"PR {pr}: FETCH failed for {branch_name}", flush=True)
            stats["fetch_fail"] += 1
            continue

        ahead = commits_ahead(main_ref, branch_name)
        if not ahead:
            print(f"PR {pr}: skip (0 commits ahead of {main_ref})", flush=True)
            stats["skipped_no_ahead"] += 1
            continue

        pick_sha = pick_address_commit_sha(ahead)
        if not pick_sha:
            print(f"PR {pr}: skip (could not resolve commit)", flush=True)
            stats["skipped_no_ahead"] += 1
            continue

        subj = next((s for h, s in ahead if h == pick_sha), "")
        print(
            f"PR {pr}: cherry-pick {pick_sha[:7]} {subj!r} ({len(ahead)} ahead)",
            flush=True,
        )
        rc = cherry_pick(pick_sha)
        if rc == 0:
            stats["cherry_pick_ok"] += 1
            continue
        if rc == 2:
            print(f"PR {pr}: cherry-pick empty (already applied?), skip", flush=True)
            stats["cherry_pick_empty"] += 1
            continue

        run(["git", "cherry-pick", "--abort"], check=False)
        stats["cherry_pick_conflict"] += 1
        print(f"PR {pr}: cherry-pick conflict; trying merge {branch_name}...", flush=True)
        if merge_branch(branch_name):
            stats["merge_ok"] += 1
        else:
            print(
                f"PR {pr}: MERGE FAILED — resolve manually with "
                f"git merge {branch_name} or inspect and continue script after fix.",
                flush=True,
            )
            stats["merge_fail"] += 1
            sys.exit(1)

    print("\nDone.\n" + "\n".join(f"{k}: {v}" for k, v in sorted(stats.items())))


if __name__ == "__main__":
    main()
