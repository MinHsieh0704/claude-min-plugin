#!/usr/bin/env python3
"""
generate-session-start.py — 從 SKILL.md 重新產生 session-start.sh 的 additionalContext 那一行。

用法：
    python hooks-handlers/generate-session-start.py [<SKILL.md> <session-start.sh>]

每個 ## 標題的正下一行必須是 <!-- summary: ... --> 或 <!-- no-summary -->，缺了就大聲停下，
免得某一節安靜地從每個 session 消失。需要 Python 3；Windows 上用 python 而不是 python3。
handler 刻意維持靜態 heredoc：它每個 session 都跑，在那裡解析一旦失敗就是安靜地沒有準則。
"""

import json
import re
import sys
from pathlib import Path

HEADING = re.compile(r"^## (?:(\d+)\. )?(.+)$")
# \S 讓 marker 後面空白的標語也算「沒有標語」。
SUMMARY = re.compile(r"^<!-- summary: (\S.*) -->$")
NO_SUMMARY = "<!-- no-summary -->"
CONTEXT = re.compile(r'^    "additionalContext": ')

PREAMBLE = (
    "claude-min-plugin coding guidelines are active. "
    "Follow these while writing or modifying code:\n\n"
)
POSTAMBLE = (
    "\n\nThese bias toward caution over speed; use judgment on trivial tasks such as "
    "typo fixes and one-line changes.\n\n"
    "Full text with rationale, examples, and the inline-note formats: "
    "run /claude-min-plugin:coding-guidelines."
)


def entries(skill_path):
    # SKILL.md 在 working tree 上是 CRLF，所以用 splitlines。刻意不辨認 code fence（見 458ca2e）。
    lines = skill_path.read_text(encoding="utf-8").splitlines() + [""]
    found = []
    for heading, next_line in zip(lines, lines[1:]):
        match = HEADING.match(heading)
        if not match or next_line == NO_SUMMARY:
            continue
        number, title = match.groups()
        label = "%s. %s" % (number, title) if number else title
        summary = SUMMARY.match(next_line)
        if not summary:
            sys.exit('no summary comment (or %s to leave it out) on the line after heading "%s" in %s'
                     % (NO_SUMMARY, label, skill_path))
        found.append("%s - %s" % (label, summary.group(1)))
    return found


def main(argv):
    here = Path(__file__).resolve().parent
    # 只給一個參數時這裡的解包會丟例外：沒給的那半若默默套成 repo 的 handler，會改錯檔案。
    skill, handler = (map(Path, argv[1:]) if len(argv) > 1 else
                      (here.parent / "skills" / "coding-guidelines" / "SKILL.md", here / "session-start.sh"))
    context = PREAMBLE + "\n".join(entries(skill)) + POSTAMBLE

    # *.sh 被 .gitattributes 釘在 LF，所以直接按 "\n" 切接。
    original = handler.read_bytes()
    lines = original.decode("utf-8").split("\n")
    # 不是剛好一行時，解包會丟例外。
    [i] = [n for n, line in enumerate(lines) if CONTEXT.match(line)]
    lines[i] = '    "additionalContext": ' + json.dumps(context)
    updated = "\n".join(lines).encode("utf-8")
    if updated != original:
        handler.write_bytes(updated)
    print("%s: %s" % (handler, "regenerated" if updated != original else "already up to date"))


if __name__ == "__main__":
    main(sys.argv)
