#!/usr/bin/env bash
# test-session-start.sh — session-start.sh 必須是 generator 從 SKILL.md 產生的東西，且輸出合法。
#
# 用法：bash hooks-handlers/tests/test-session-start.sh [handler] [skill-md]
#
# 前提是 Windows + Git Bash + GNU sed + Python 3（見 CLAUDE.md 的 Verification）。
# 突變都作用在暫存目錄的複本上；標語是否還描述得了它那一節，留給人或模型判斷。
# 結束碼：全部符合預期為 0，否則為 1。

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HANDLER="${1:-$REPO_ROOT/hooks-handlers/session-start.sh}"
SKILL="${2:-$REPO_ROOT/skills/coding-guidelines/SKILL.md}"
GENERATOR="$REPO_ROOT/hooks-handlers/generate-session-start.py"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
PASS=0
FAIL=0

# generator 會就地改寫，所以先複製再交給它。
regenerate() {
  cp "$HANDLER" "$2"
  python "$GENERATOR" "$1" "$2"
}

# 比對用 cmp；失敗時把字面的 \n 攤開再 diff，才看得出差在哪一條。
# 置換端的 \n 要 GNU sed 才會變成換行；BSD sed 只影響失敗訊息的可讀性，不影響偵測。
check_drift() {
  regenerate "$1" "$WORKDIR/regenerated.sh" || return 1
  cmp -s "$HANDLER" "$WORKDIR/regenerated.sh" && return 0
  echo "the handler is not what the generator produces from SKILL.md" >&2
  echo "  run: python hooks-handlers/generate-session-start.py" >&2
  diff <(sed 's/\\n/\n/g' "$HANDLER") <(sed 's/\\n/\n/g' "$WORKDIR/regenerated.sh") >&2
  return 1
}

# 輸出要是 SessionStart 文件；給了第二個參數時，additionalContext 還要原樣含有它。
check_output() {
  bash "$1" | python -c '
import json, sys
block = json.load(sys.stdin)["hookSpecificOutput"]
assert block["hookEventName"] == "SessionStart", block["hookEventName"]
assert block["additionalContext"].strip(), "additionalContext is empty"
assert sys.argv[1] in block["additionalContext"], "additionalContext lacks %r" % sys.argv[1]
' "${2:-}"
}

# 把第一個編號標題正下一行的標語換成 $3。用 ENVIRON 傳，-v 會先解掉跳脫序列。
replace_first_tagline() {
  REPLACEMENT="$3" awk \
    'next_is { print ENVIRON["REPLACEMENT"]; next_is = 0; next }
     !hit && /^## [0-9]+\. / { hit = 1; next_is = 1 } { print }' "$1" > "$2"
}

append_section() {
  cp "$1" "$2"
  printf '%s\n' "" "${@:3}" >> "$2"
}

# run_case 名稱 預期結束碼 stderr必須包含的字串 -- 指令...
run_case() {
  local name="$1" expected="$2" pattern="$3"
  shift 3
  "$@" >/dev/null 2>"$WORKDIR/stderr.txt"
  local actual=$?
  if [ "$actual" -eq "$expected" ] && { [ -z "$pattern" ] || grep -q "$pattern" "$WORKDIR/stderr.txt"; }; then
    echo "PASS  [$name]"
    PASS=$((PASS + 1))
  else
    echo "FAIL  [$name]  (exit $actual, expected $expected${pattern:+; stderr should contain \"$pattern\"})"
    sed 's/^/  /' "$WORKDIR/stderr.txt"
    FAIL=$((FAIL + 1))
  fi
}

echo "Testing handler: $HANDLER"
echo "Against source:  $SKILL"
echo "========================================"

run_case "the handler is what the generator produces as the tree stands" 0 "" \
  check_drift "$SKILL"

replace_first_tagline "$SKILL" "$WORKDIR/retagged.md" "<!-- summary: Drift Probe Tagline -->"
run_case "a tagline changed in SKILL.md -> drift reported" 1 "Drift Probe Tagline" \
  check_drift "$WORKDIR/retagged.md"

append_section "$SKILL" "$WORKDIR/orphan.md" "## Drift Probe Orphan" "" "Body text."
run_case "a heading with no tagline -> the generator refuses" 1 "no summary comment" \
  check_drift "$WORKDIR/orphan.md"

append_section "$SKILL" "$WORKDIR/opted-out.md" "## Drift Probe Opted Out" "<!-- no-summary -->"
run_case "a heading marked no-summary -> left out, no drift" 0 "" \
  check_drift "$WORKDIR/opted-out.md"

run_case "handler emits a valid SessionStart document" 0 "" \
  check_output "$HANDLER"

ESCAPE_PROBE='a "quoted" word and a \backslash probe.'
replace_first_tagline "$SKILL" "$WORKDIR/escapes.md" "<!-- summary: $ESCAPE_PROBE -->"
regenerate "$WORKDIR/escapes.md" "$WORKDIR/escapes.sh" > /dev/null
run_case 'a tagline carrying " and \ survives into parsable stdout' 0 "" \
  check_output "$WORKDIR/escapes.sh" "$ESCAPE_PROBE"

echo "========================================"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)) total)"
[ "$FAIL" -eq 0 ]
