#!/usr/bin/env bash
# test-session-start.sh
#
# SessionStart handler 的自動化測試：檢查它注入的十行摘要，與
# skills/coding-guidelines/SKILL.md 之間有沒有漂移。
#
# 這兩者的對應是本 repo 最高風險的不變量，先前只靠 CLAUDE.md 與 handler 註解裡的
# 散文宣告「沒有任何機制會自動偵測落差」。這支測試就是那個機制。
#
# 分兩層，缺一不可：
#
#   層一（結構）— 摘要每一行都以 SKILL.md 對應那條的「編號 + 標題」開頭，且兩邊
#   都剛好十條。抓得到標題改名、增刪、重排。
#
#   層二（絆線）— 每一條「正文」的雜湊值記在下方 EXPECTED 表裡。正文一改，雜湊就
#   對不上，測試轉紅。
#
# 為什麼層二不能省：摘要是十條的「改寫」而不是複製 — 有幾條跟自己的標語幾乎沒有
# 共同字詞，整句取自正文條列。所以層一完全抓不到「正文改了、摘要沒跟著改」，而那
# 正是這條規則要防的那一半。少了層二，這支測試自己就是一個不會失敗的測試。
#
# 刻意「沒有」自動更新雜湊的旗標。測試轉紅時它會把新的雜湊印出來，但要不要採用，
# 必須由人先讀過那一條的新正文、判斷摘要該不該跟著改之後，手動貼上去。一個 --update
# 旗標會讓人略過那個判斷，絆線也就失去意義。
#
# 用法（從 repo 任一位置皆可）：
#   bash hooks-handlers/tests/test-session-start.sh
#
# 在 Windows 上：請從 Git Bash 執行（不是 cmd.exe／PowerShell）。
#
# 結束碼：全數通過為 0，任一項失敗為 1。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
HANDLER="$ROOT/hooks-handlers/session-start.sh"
SKILL="$ROOT/skills/coding-guidelines/SKILL.md"

# 每一條正文的 sha256 前 16 碼。改了 SKILL.md 某一條的正文之後，先重讀 handler 裡
# 對應的那一行摘要、確認它是否仍然成立，再把新雜湊貼進來。
EXPECTED="\
1|30c17fdefc93629b
2|cc6d1116f34c6af9
3|c3aafd3759a563d1
4|7931fe27b37c5d65
5|3facdfeb488f7e34
6|dae958c865c1181a
7|1ebaabe3b92436f8
8|6bb8e2fd5cddd59c
9|c167c3eab04037bc
10|b84434ab82061439"

for required in "$HANDLER" "$SKILL"; do
  if [ ! -f "$required" ]; then
    echo "Required file not found: $required"
    exit 1
  fi
done

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

pass() { echo "PASS  [$1]"; PASS=$((PASS + 1)); }
fail() { echo "FAIL  [$1]  $2"; FAIL=$((FAIL + 1)); }

echo "Handler:    $HANDLER"
echo "Guidelines: $SKILL"
echo "========================================"

# --- 先讓 handler 跑起來，拿到它實際注入的字串 ---

bash "$HANDLER" > "$TMPDIR/payload.json" 2>"$TMPDIR/handler.err"
handler_exit=$?

if [ "$handler_exit" -eq 0 ]; then
  pass "handler exits 0"
else
  fail "handler exits 0" "(exit $handler_exit)"
  sed 's/^/  /' "$TMPDIR/handler.err"
fi

python - "$TMPDIR/payload.json" "$TMPDIR/summary.txt" > "$TMPDIR/payload.status" 2>&1 <<'PY'
import json, re, sys
try:
    with open(sys.argv[1], encoding='utf-8') as handle:
        context = json.load(handle)['hookSpecificOutput']['additionalContext']
except Exception as exc:
    print('BAD 0 0 %s' % exc)
    sys.exit(0)
numbered = [line for line in context.split('\n') if re.match(r'^\d+\. ', line)]
with open(sys.argv[2], 'w', encoding='utf-8', newline='\n') as out:
    out.write('\n'.join(numbered) + '\n')
print('OK %d %d' % (sum(1 for ch in context if ord(ch) > 127), len(numbered)))
PY

read -r status non_ascii summary_count _rest < "$TMPDIR/payload.status"

if [ "$status" = "OK" ]; then
  pass "handler emits parseable JSON carrying additionalContext"
else
  fail "handler emits parseable JSON carrying additionalContext" "$(cat "$TMPDIR/payload.status")"
  echo "========================================"
  echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)) total)"
  exit 1
fi

if [ "$non_ascii" -eq 0 ]; then
  pass "injected context is pure ASCII"
else
  fail "injected context is pure ASCII" "($non_ascii non-ASCII characters; a console that cannot encode them corrupts or kills the run)"
fi

# --- 層一：結構 ---

python - "$SKILL" "$TMPDIR/headings.txt" "$TMPDIR/hashes.txt" <<'PY'
import hashlib, re, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    lines = handle.read().split('\n')
starts = [i for i, line in enumerate(lines) if re.match(r'^## \d+\. ', line)]
heads, hashes = [], []
for position, start in enumerate(starts):
    end = starts[position + 1] if position + 1 < len(starts) else len(lines)
    heading = re.match(r'^## (\d+)\. (.+)$', lines[start])
    body = lines[start + 1:end]
    while body and not body[0].strip():
        body.pop(0)
    while body and (not body[-1].strip() or body[-1].strip() == '---'):
        body.pop()
    heads.append('%s|%s' % (heading.group(1), heading.group(2)))
    digest = hashlib.sha256('\n'.join(body).encode('utf-8')).hexdigest()[:16]
    hashes.append('%s|%s' % (heading.group(1), digest))
for path, rows in ((sys.argv[2], heads), (sys.argv[3], hashes)):
    with open(path, 'w', encoding='utf-8', newline='\n') as out:
        out.write('\n'.join(rows) + '\n')
PY

heading_count="$(grep -c '|' "$TMPDIR/headings.txt")"

if [ "$heading_count" -eq 10 ]; then
  pass "SKILL.md holds exactly 10 numbered guidelines"
else
  fail "SKILL.md holds exactly 10 numbered guidelines" "(found $heading_count)"
fi

if [ "$summary_count" -eq 10 ]; then
  pass "injected summary holds exactly 10 numbered lines"
else
  fail "injected summary holds exactly 10 numbered lines" "(found $summary_count)"
fi

while IFS='|' read -r number title; do
  [ -n "$number" ] || continue
  expected_prefix="$number. $title"
  actual="$(grep -m1 "^$number\. " "$TMPDIR/summary.txt")"
  case "$actual" in
    "$expected_prefix"*)
      pass "summary line $number opens with its guideline title"
      ;;
    *)
      fail "summary line $number opens with its guideline title" \
"(expected it to start with \"$expected_prefix\", got \"$actual\")"
      ;;
  esac
done < "$TMPDIR/headings.txt"

# --- 層二：絆線 ---

printf '%s\n' "$EXPECTED" > "$TMPDIR/expected.txt"

while IFS='|' read -r number digest; do
  [ -n "$number" ] || continue
  want="$(grep -m1 "^$number|" "$TMPDIR/expected.txt" | cut -d'|' -f2)"
  if [ "$digest" = "$want" ]; then
    pass "guideline $number body unchanged since its summary line was last checked"
  else
    fail "guideline $number body unchanged since its summary line was last checked" \
"(body changed; re-read summary line $number, decide whether it still holds, then replace $want with $digest in EXPECTED)"
  fi
done < "$TMPDIR/hashes.txt"

echo "========================================"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)) total)"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
