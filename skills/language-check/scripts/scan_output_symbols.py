#!/usr/bin/env python3
r"""
scan_output_symbols.py — 找出所有會進入 console 輸出的非 ASCII 字元。

用法：
    python scan_output_symbols.py <file.py> [<file.py> ...]
    git ls-files '*.py' | xargs python scan_output_symbols.py

收集 print()、raise 與 sys.exit() 底下的字串常數逐字元檢查；有命中以 1 結束，乾淨為 0，
無法剖析為 2。它是 SKILL.md 步驟 4 那張網的 Python 交叉檢查：走 AST 不必判讀，跨行串接也
照樣收得到。只看字面常數，插值帶進來的文字看不到，那一類由 SKILL.md 步驟 6 人工回溯。

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
    # sys.exit("訊息") 會把訊息印到 stderr。
    if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "exit"
            and isinstance(node.func.value, ast.Name) and node.func.value.id == "sys"):
        return "sys.exit"
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
