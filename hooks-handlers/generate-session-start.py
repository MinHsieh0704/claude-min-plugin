#!/usr/bin/env python3
"""
generate-session-start.py — 從 SKILL.md 重新產生 session-start.sh 的那段摘要。

用法：
    python hooks-handlers/generate-session-start.py
    python hooks-handlers/generate-session-start.py <SKILL.md> <session-start.sh>

需要 Python 3，這是明確的前提而不是還沒補的缺口 —— Python 2 不處理（底下用了 print
的關鍵字參數，在 2 底下是語法錯誤）。Windows 上請用 python 而不是 python3：後者常常是
Microsoft Store 的空殼。

摘要裡的條目不再是手抄的：編號與標題直接取自 skills/coding-guidelines/SKILL.md
的編號標題，標語取自標題「正下一行」的 <!-- summary: ... --> 註解。改了哪一節就改那一節
的註解，然後重跑這支腳本 —— 兩份文字之間沒有東西可以走鐘，因為只剩一份。

沒編號的標題一樣收進摘要，照文件順序、不帶編號。每個 ## 標題的正下一行，要嘛是
summary 註解，要嘛是 <!-- no-summary --> 明說這一節不進摘要 —— 例外要寫在標題旁邊，
而不是「沒帶註解就當作不打算進摘要」：那樣的話，有人刪掉某一節的標語，它就會安靜地從
每個 session 消失。標記跟著標題走，所以改標題名稱不必回頭改這支腳本。

註解而不是可見文字：這樣 SKILL.md 讀起來跟以前一模一樣，代價是編輯某一節的人不會
一眼看到它。標語是「整節的濃縮」，本來就不屬於渲染出來的內容。

框架文字（開場、結語、指向完整全文那一行）只屬於這段注入字串，SKILL.md 裡沒有對應物，
所以留在這支腳本裡 —— 它們沒有第二份，也就沒有走鐘的對象。

handler 本身刻意維持靜態 heredoc。它每個 session 都會跑，在那裡做解析或跳脫，一旦失敗
就是「完全沒有 guidelines」，而且是安靜的失敗；產生的動作只在有人改 guidelines 時才跑。
"""

import json
import re
import sys
from pathlib import Path

HEADING = re.compile(r"^## (?:(\d+)\. )?(.+)$")
SUMMARY = re.compile(r"^<!-- summary: (.*) -->$")
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


def fail(message):
    print(message, file=sys.stderr)
    raise SystemExit(1)


def entries(skill_path):
    """SKILL.md 的每個 ## 標題（標了 no-summary 的除外）配上它的標語：編號標題組成
    "<n>. <title> - <tagline>"，沒編號的組成 "<title> - <tagline>"。"""
    # SKILL.md 在 working tree 上是 CRLF（.gitattributes 只釘 *.sh），所以用 splitlines。
    lines = skill_path.read_bytes().decode("utf-8").splitlines()
    found = []
    has_numbered = False
    # 刻意不辨認 code fence：fence 裡的 "## " 一樣被當成標題，沒帶標語就大聲停下。
    # 追蹤 fence 的開關曾經試過，但 fence 一旦沒關好，後面每一節都會安靜地消失 ——
    # 比「範例被誤認成標題而報錯」糟得多。真要在 SKILL.md 放這種範例，就給它標語或
    # no-summary 標記。
    for i, line in enumerate(lines):
        heading = HEADING.match(line)
        if not heading:
            continue
        next_line = lines[i + 1] if i + 1 < len(lines) else ""
        if next_line == NO_SUMMARY:
            continue
        number, title = heading.groups()
        label = "%s. %s" % (number, title) if number else title
        has_numbered = has_numbered or bool(number)
        # 只認「正下一行」：位置固定，漏寫或放錯地方都會在這裡大聲停下來，
        # 而不是安靜地少產生一個條目。
        summary = SUMMARY.match(next_line)
        if not summary:
            fail('no summary comment (or %s to leave it out) on the line after heading "%s" in %s'
                 % (NO_SUMMARY, label, skill_path))
        # marker 後面兩個空格的 "<!-- summary:  -->" 也匹配得過，group(1) 是空的。
        # 擋在這裡，否則那一條準則會變成只剩編號、標題與一個懸空的破折號進到每個
        # session，而且下游沒有任何東西看得見。
        if not summary.group(1).strip():
            fail('empty tagline in the summary comment after heading "%s" in %s' % (label, skill_path))
        found.append("%s - %s" % (label, summary.group(1)))
    # 只看編號標題：只剩沒編號標題的摘要一樣是壞掉的來源。
    if not has_numbered:
        fail("no numbered headings found in %s" % skill_path)
    return found


def rewrite(handler_path, context):
    """換掉 handler 的 additionalContext 那一行，其餘每個 byte 原封不動。"""
    # *.sh 被 .gitattributes 釘在 LF，所以直接按 "\n" 切接；CRLF 的 handler 不處理。
    original = handler_path.read_bytes()
    lines = original.decode("utf-8").split("\n")
    hits = [i for i, line in enumerate(lines) if CONTEXT.match(line)]
    if len(hits) != 1:
        fail('expected exactly one "additionalContext" line in %s, found %d'
             % (handler_path, len(hits)))
    # json.dumps 負責跳脫：引號、反斜線與換行都在這裡變成合法的 JSON 字串常數。
    lines[hits[0]] = '    "additionalContext": ' + json.dumps(context)
    updated = "\n".join(lines).encode("utf-8")
    if updated == original:
        return False
    handler_path.write_bytes(updated)
    return True


def main(argv):
    # 兩個路徑要嘛一起給，要嘛都不給：只給一個時，沒給的那半會默默套成 repo 自己的
    # handler，等於拿別處的來源改寫掉 repo 裡的那一份。
    if len(argv) not in (1, 3):
        fail("usage: generate-session-start.py [<SKILL.md> <session-start.sh>]"
             " - both paths or neither")
    here = Path(__file__).resolve().parent
    skill = Path(argv[1]) if len(argv) > 1 else here.parent / "skills" / "coding-guidelines" / "SKILL.md"
    handler = Path(argv[2]) if len(argv) > 2 else here / "session-start.sh"
    for path in (skill, handler):
        if not path.is_file():
            fail("file not found: %s" % path)

    changed = rewrite(handler, PREAMBLE + "\n".join(entries(skill)) + POSTAMBLE)
    print("%s: %s" % (handler, "regenerated" if changed else "already up to date"))


if __name__ == "__main__":
    main(sys.argv)
