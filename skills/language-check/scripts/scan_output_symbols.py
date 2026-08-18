#!/usr/bin/env python3
r"""
scan_output_symbols.py — 找出所有會進入 console 輸出的非 ASCII 字元。

用法：
    python3 scan_output_symbols.py <file.py> [<file.py> ...]
    git ls-files '*.py' | xargs python3 scan_output_symbols.py

有命中就以 exit code 1 結束，沒有則 0，方便直接掛進檢查流程。

為什麼走語法樹而不是 grep：
    逐行比對要求「輸出動詞」與「違規字元」落在同一行，但 Python 的隱式字串串接
    會讓一個 print() 橫跨數行、訊息主體落在第二行 —— 那一行看起來只是個孤立的字串
    常數，附近沒有任何動詞，任何逐行比對式都不可能接住。走 AST 就自動涵蓋。
    實測（本 repo 的 skills/commit/scripts/ai_attribution_stats.py）：逐行 grep 看到
    4 個，AST 看到 6 個 —— 差的兩個都是跨行串接。

已知限制，是設計而非待辦：
    **只看字面常數。** 非 ASCII 也可以「透過插值」進入輸出 ——
    print(f'the "{label}" column is empty') 這一行本身一個非 ASCII 字元都沒有，
    卻會在 label 綁到中文顯示名時印出中文。那一類文字掃描完全看不到，只能人工回溯
    插值來源；SKILL.md 因此把它寫成規則，而不是交給這支腳本。

輸出刻意維持純 ASCII（字元經 ascii() 逃逸成 '\uXXXX'），這樣它自己就服從它正在
檢查的那條規則：在任何 code page 的 console 上都不會拋 UnicodeEncodeError。
"""

import ast
import sys


def literals(node):
    """這個節點底下的每個字串常數，包含 f-string 的片段與隱式串接的每一段。"""
    for sub in ast.walk(node):
        if isinstance(sub, ast.Constant) and isinstance(sub.value, str):
            yield sub


def output_kind(node):
    """若這個節點會產生 console 輸出，回傳它的種類，否則回傳 None。"""
    if isinstance(node, ast.Raise):
        return "raise"
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "print":
        # file= 關鍵字引數是唯一能分辨 stdout 與 stderr 的地方，而兩者的失敗模式
        # 不同（surrogateescape 會炸、backslashreplace 會靜靜降級），值得分開標示。
        for kw in node.keywords:
            if kw.arg == "file":
                return "print(stderr)"
        return "print(stdout)"
    return None


def scan(path):
    """回傳 path 內所有進入輸出的非 ASCII 字元，格式為 (行號, 種類, 字元, 前後文)。"""
    with open(path, encoding="utf-8") as fh:
        tree = ast.parse(fh.read(), filename=path)

    hits = []
    seen = set()
    for node in ast.walk(tree):
        kind = output_kind(node)
        if not kind:
            continue
        for const in literals(node):
            for ch in const.value:
                # 同一行的同一個字元只報一次；f-string 會讓同一段文字被走訪兩遍。
                if ord(ch) > 127 and (const.lineno, ch) not in seen:
                    seen.add((const.lineno, ch))
                    hits.append((const.lineno, kind, ch, const.value.strip()[:70]))
    return sorted(hits)


def main(argv):
    if not argv:
        print("usage: scan_output_symbols.py <file.py> [<file.py> ...]", file=sys.stderr)
        return 2

    total = 0
    for path in argv:
        try:
            hits = scan(path)
        except (OSError, SyntaxError, UnicodeDecodeError) as exc:
            # 安靜跳過讀不了或剖析不了的檔案，等於給出一個假的綠燈 —— 寧可吵。
            print(f"{path}: cannot scan: {exc}", file=sys.stderr)
            return 2
        for lineno, kind, ch, context in hits:
            print(f"{path}:{lineno} {kind:<14} U+{ord(ch):04X} {ascii(ch):<10} {ascii(context)}")
        total += len(hits)

    print(f"\ntotal non-ASCII characters in console output: {total}")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
