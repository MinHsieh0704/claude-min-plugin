#!/usr/bin/env python3
"""
ai_attribution_stats.py — summarize AI-vs-human commit attribution using
the Co-Authored-By / AI-Contribution / Fixes: trailer convention.

Usage:
    python3 ai_attribution_stats.py [git-log-range] [--path <file-or-dir>]

Example:
    python3 ai_attribution_stats.py                     # whole history on current branch
    python3 ai_attribution_stats.py main..dev            # a specific range
    python3 ai_attribution_stats.py --path src/auth/     # feature-evolution timeline for a path

What it reports:
  1. Overall AI vs human commit counts, split by AI-Contribution level.
  2. Fix-linkage table: for every commit carrying a Fixes: trailer, whether
     the ORIGIN commit (what Fixes: points to) and the FIX commit itself
     were AI- or human-authored. This answers "was AI-led code fixed by a
     human afterwards, and how often" without relying on automated git
     blame / SZZ inference (which the team has decided not to depend on —
     see ../references/ai-attribution-proposal.md for why).
  3. With --path: a chronological AI-Contribution timeline for one file or
     directory (via `git log --follow`), for tracking how a feature has
     evolved across non-fix updates too — deliberately NOT a new trailer.
     See ../references/ai-attribution-proposal.md section on why updates
     don't get their own linkage trailer.

Caveats printed in the output, not swept under the rug:
  - Relies entirely on trailers actually being present. Commits made
    before this convention was adopted will show up as "untagged".
  - "Fixes: unknown" means the author's own git-blame check was
    inconclusive at commit time — these are counted separately, not
    silently dropped and not guessed at after the fact.
"""

import re
import subprocess
import sys
from collections import defaultdict

RECORD_SEP = "\x1e"
FIELD_SEP = "\x1f"

AI_TRAILER_RE = re.compile(r"^Co-Authored-By: Claude ", re.MULTILINE)
LEVEL_RE = re.compile(r"^AI-Contribution: (assisted|generated)$", re.MULTILINE)
# Fixes: can appear more than once per commit (a commit may genuinely fix
# more than one prior origin, each individually confident) — findall, not
# search. "unknown" and a real sha coexisting is contradictory and the
# hook rejects it going forward, but this script still defends against
# older history or hand-typed commits that predate/bypass that check —
# see the "contradictory" handling in main().
FIXES_RE = re.compile(r"^Fixes: (unknown|[0-9a-f]{7,40})$", re.MULTILINE)
CANDIDATES_RE = re.compile(r"^Fixes-Candidates: (.+)$", re.MULTILINE)


def run_git(args):
    return subprocess.run(
        ["git"] + args, capture_output=True, text=True, check=True
    ).stdout


def load_commits(rev_range, path=None):
    fmt = f"{RECORD_SEP}%H{FIELD_SEP}%s{FIELD_SEP}%B"
    args = ["log", f"--format={fmt}"]
    if path:
        args.append("--follow")
    if rev_range:
        args.append(rev_range)
    if path:
        args.extend(["--", path])
    try:
        raw = run_git(args)
    except subprocess.CalledProcessError as exc:
        # git already names what it could not resolve (a bad rev range, a
        # path outside the repo). Pass that through: resolve_short_sha()
        # relies on run_git raising, so the catch belongs here, not there.
        sys.exit(f"error: git log failed: {exc.stderr.strip() or exc}")
    commits = {}
    order = []
    for record in raw.split(RECORD_SEP):
        record = record.strip("\n")
        if not record:
            continue
        parts = record.split(FIELD_SEP, 2)
        if len(parts) != 3:
            continue
        full_hash, subject, body = parts
        is_ai = bool(AI_TRAILER_RE.search(body))
        level_m = LEVEL_RE.search(body)
        fixes_list = FIXES_RE.findall(body)  # e.g. ["a1b2c3d", "unknown"] — may be several
        candidates_m = CANDIDATES_RE.search(body)
        commits[full_hash] = {
            "subject": subject,
            "is_ai": is_ai,
            "level": level_m.group(1) if level_m else None,
            "fixes": fixes_list,
            "candidates": candidates_m.group(1) if candidates_m else None,
        }
        order.append(full_hash)
    return commits, order


def print_timeline(path, commits, order):
    # order[] comes back newest-first from git log; print oldest-first so
    # it reads as the feature's actual evolution.
    print(f"=== Feature timeline: {path} ===")
    print("(chronological; --follow tracks the path across renames)")
    for full_hash in reversed(order):
        c = commits[full_hash]
        tag = "----"
        if c["is_ai"]:
            tag = c["level"] or "ai?"
        fixes_note = ""
        if c["fixes"]:
            fixes_note = " [" + ", ".join(f"fixes {s[:7]}" for s in c["fixes"]) + "]"
        print(f"  {full_hash[:7]}  {tag:10s}  {c['subject']}{fixes_note}")
    print()
    print("Note: this is a per-commit trace, not a cumulative AI-percentage for the")
    print("file. Each commit's AI-Contribution reflects only that commit's own diff —")
    print("it is judged fresh every time, never inherited from an earlier commit that")
    print("touched the same feature. See the commit skill's own")
    print("references/ai-attribution-proposal.md for why a cumulative")
    print("feature-level score is intentionally not computed.")


def resolve_short_sha(short_sha, commits):
    if short_sha == "unknown":
        return None
    matches = [h for h in commits if h.startswith(short_sha)]
    if len(matches) == 1:
        return matches[0]
    # Not in the loaded range (e.g. older history outside rev_range) — try git directly.
    try:
        full = run_git(["rev-parse", short_sha]).strip()
        return full if full in commits else None
    except subprocess.CalledProcessError:
        return None


def main():
    args = sys.argv[1:]
    path = None
    if "--path" in args:
        idx = args.index("--path")
        if idx + 1 >= len(args):
            sys.exit("error: --path needs a file or directory argument")
        path = args[idx + 1]
        del args[idx:idx + 2]
    rev_range = args[0] if args else None

    commits, order = load_commits(rev_range, path=path)

    if path:
        if not order:
            # An empty timeline plus the note below reads as "checked, nothing
            # of note"; the path having no history at all is a different
            # answer. Say which one it is, same as the empty range does.
            print(f"No commits touch {path} — nothing to report.")
            return
        print_timeline(path, commits, order)
        return

    total = len(commits)
    if not total:
        # Every table below reduces to zeros for an empty range, which reads as
        # a real result rather than an empty one. Say so and stop.
        print(f"No commits in {rev_range or 'this branch'} — nothing to report.")
        return

    ai_count = sum(1 for c in commits.values() if c["is_ai"])
    level_counts = defaultdict(int)
    for c in commits.values():
        if c["level"]:
            level_counts[c["level"]] += 1

    print("=== Overall attribution ===")
    print(f"Total commits:            {total}")
    print(f"AI-touched (Co-Authored-By): {ai_count} ({ai_count / total:.0%})")
    print(f"  AI-Contribution: assisted:  {level_counts['assisted']}")
    print(f"  AI-Contribution: generated: {level_counts['generated']}")
    untagged_ai = ai_count - level_counts["assisted"] - level_counts["generated"]
    if untagged_ai:
        print(f"  (missing AI-Contribution level: {untagged_ai} — likely pre-dates this convention)")

    print()
    print("=== Fix linkage (Fixes: trailer) ===")
    matrix = defaultdict(int)
    unknown = 0
    unknown_with_candidates = 0
    unresolved = 0
    contradictory = 0
    fix_commits = [(h, c) for h, c in commits.items() if c["fixes"]]
    for h, c in fix_commits:
        fixer_is_ai = c["is_ai"]
        confirmed_shas = [s for s in c["fixes"] if s != "unknown"]
        has_unknown = "unknown" in c["fixes"]

        if has_unknown and confirmed_shas:
            # Contradictory data (unknown + a confirmed sha together) is
            # supposed to be impossible — the hook rejects it going
            # forward — but pre-fix history or a hand-typed commit that
            # bypassed the hook could still have it. Don't silently drop
            # the confirmed sha(s) the way treating this as plain
            # "unknown" would; process them, and flag the contradiction
            # separately so it's visible rather than swept in either
            # direction.
            contradictory += 1
        elif has_unknown:
            unknown += 1
            if c["candidates"]:
                unknown_with_candidates += 1
            continue

        for sha in confirmed_shas:
            origin_hash = resolve_short_sha(sha, commits)
            if origin_hash is None:
                unresolved += 1
                continue
            origin_is_ai = commits[origin_hash]["is_ai"]
            key = (
                "AI-led" if origin_is_ai else "human-led",
                "AI-fixed" if fixer_is_ai else "human-fixed",
            )
            matrix[key] += 1

    print(f"Total fix commits with a Fixes: trailer: {len(fix_commits)}")
    print("(a commit fixing more than one prior origin contributes one count per origin below)")
    for key in [
        ("AI-led", "AI-fixed"),
        ("AI-led", "human-fixed"),
        ("human-led", "AI-fixed"),
        ("human-led", "human-fixed"),
    ]:
        origin, fixer = key
        print(f"  {origin:10s} -> {fixer:12s}: {matrix[key]}")
    print(f"  Fixes: unknown (blame inconclusive at commit time): {unknown}")
    if unknown:
        print(f"    of which {unknown_with_candidates} recorded Fixes-Candidates for manual triage")
    if unresolved:
        print(f"  Fixes: <sha> pointing outside loaded range/not found: {unresolved}")
    if contradictory:
        print(f"  WARNING: {contradictory} commit(s) had 'Fixes: unknown' AND a confirmed sha")
        print("    together — contradictory data the hook now blocks going forward, but")
        print("    these predate that check (or bypassed it). Confirmed shas were still")
        print("    counted above rather than silently dropped; worth a manual look.")

    print()
    print("Note: this table only reflects commits that carry the trailer convention.")
    print("Commits from before the convention was adopted are invisible to this report,")
    print("not counted as human-led — treat historical trend lines with that in mind.")


if __name__ == "__main__":
    main()
