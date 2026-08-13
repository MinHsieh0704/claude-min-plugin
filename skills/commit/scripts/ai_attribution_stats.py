#!/usr/bin/env python3
"""
ai_attribution_stats.py — 依據 Co-Authored-By / AI-Contribution / Fixes:
trailer 慣例，統整「AI 對比人工」的 commit 歸屬。

用法：
    python3 ai_attribution_stats.py [git-log-range] [--path <file-or-dir>]

範例：
    python3 ai_attribution_stats.py                     # 目前分支的完整歷史
    python3 ai_attribution_stats.py main..dev            # 指定範圍
    python3 ai_attribution_stats.py --path src/auth/     # 某路徑的功能演進時間軸

它會回報什麼：
  1. 整體 AI 與人工的 commit 數量，並依 AI-Contribution 程度細分。
  2. fix 連結對照表：對每個帶有 Fixes: trailer 的 commit，判斷「原始 commit」
     （Fixes: 所指向的那個）與「修正 commit」本身各自是 AI 還是人工撰寫。這回答了
     「AI 主導的程式碼事後被人類修掉的頻率有多高」，而且不必倚賴自動化的 git
     blame / SZZ 推論（團隊已決定不依賴那套 — 理由見
     ../references/ai-attribution-proposal.md）。
  3. 加上 --path 時：針對單一檔案或目錄，列出依時間排序的 AI-Contribution 時間軸
     （透過 `git log --follow`），用來追蹤某個功能在非修正類更新中的演進 — 這是
     刻意「不」引入新 trailer 的做法。為何更新類 commit 不另設專屬的連結 trailer，
     見 ../references/ai-attribution-proposal.md 的相關章節。

會印在輸出中、不掃到地毯下的但書：
  - 完全倚賴 trailer 確實存在。採用本慣例之前所做的 commit 會被歸為 "untagged"。
  - "Fixes: unknown" 代表作者在 commit 當下自行執行 git blame 的結果並不明確 —
    這類 commit 會另外計數，不會被默默丟棄，也不會事後臆測補上。
"""

import re
import subprocess
import sys
from collections import defaultdict

RECORD_SEP = "\x1e"
FIELD_SEP = "\x1f"

AI_TRAILER_RE = re.compile(r"^Co-Authored-By: Claude ", re.MULTILINE)
LEVEL_RE = re.compile(r"^AI-Contribution: (assisted|generated)$", re.MULTILINE)
# Fixes: 在單一 commit 中可能出現不只一次（一個 commit 確實可能修正多個先前的
# 源頭，而且每個都各自有把握）— 所以用 findall 而非 search。"unknown" 與真實
# sha 並存是自相矛盾的，往後 hook 會擋下這種寫法，但這支腳本仍要防禦較舊的歷史
# 紀錄，或是早於／繞過該檢查的手動 commit — 見 main() 中的 "contradictory" 處理。
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
        # git 本身已經指名它無法解析的東西（錯誤的 rev range、repo 外的路徑）。
        # 直接把那段訊息透傳出去：resolve_short_sha() 依賴 run_git 會拋出例外，
        # 所以這個 catch 該放在這裡，而不是放在那邊。
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
        fixes_list = FIXES_RE.findall(body)  # 例如 ["a1b2c3d", "unknown"] — 可能有多筆
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
    # order[] 從 git log 回來時是最新在前；這裡改以最舊在前印出，讀起來才像該功能
    # 實際的演進歷程。
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
    # 不在已載入的範圍內（例如落在 rev_range 之外的較舊歷史）— 直接問 git。
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
            # 空的時間軸再加上底下那段註記，讀起來像是「查過了，沒什麼特別的」；
            # 但「這個路徑根本沒有任何歷史」是完全不同的答案。要講清楚是哪一種，
            # 跟空範圍的處理方式一致。
            print(f"No commits touch {path} — nothing to report.")
            return
        print_timeline(path, commits, order)
        return

    total = len(commits)
    if not total:
        # 範圍為空時，底下每張表都會退化成一整排 0，那看起來像是一個真實結果而不是
        # 空結果。所以直接講明並停止。
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
            # 自相矛盾的資料（unknown 與已確認的 sha 同時出現）照理說不可能發生
            # — 往後 hook 會擋下 — 但修正前的歷史紀錄，或是繞過 hook 的手動
            # commit 仍可能有。不要像「一律當成 unknown」那樣默默丟掉已確認的
            # sha；照常處理它們，並把這個矛盾另外標記出來，讓它被看見，而不是往
            # 任何一邊掃掉。
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
