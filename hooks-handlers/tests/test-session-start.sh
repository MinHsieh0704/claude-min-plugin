#!/usr/bin/env bash
# test-session-start.sh
#
# SessionStart handler 的自動化測試套件。守住兩件事：
#
#   1. hooks-handlers/session-start.sh 裡那份「衍生」摘要，其編號標題必須與
#      skills/coding-guidelines/SKILL.md 的編號標題完全一致 — 數量、編號、標題文字。
#   2. handler 印出來的東西仍然是 SessionStart hook 被允許送出的形狀。
#
# 標題後面那段標語（" - ..." 之後的文字）刻意不比對：它是整節內容的編輯性濃縮，
# 不是任何一行的複製，要機械比對就得再維護第二份手工副本 —
# 而「手工副本會偷偷走鐘」正是這支測試要減少的問題本身。
#
# 七個突變全部作用在暫存目錄裡的複本上，repo 的 working tree 不會被動到。
# 突變本身刻意不綁死任何一段現有文字（都對「第一個編號標題」下手），
# 這樣 SKILL.md 日後正常改寫時，這些負向案例不會誤報。
#
# 用法：
#   bash hooks-handlers/tests/test-session-start.sh [handler] [skill-md]
#
# 在 Windows 上：請從 Git Bash 執行（不是 cmd.exe／PowerShell）。
#
# 結束碼：每個案例都符合預期則為 0，只要有任一案例不符則為 1 — 可安心接進 CI。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

HANDLER="${1:-$REPO_ROOT/hooks-handlers/session-start.sh}"
SKILL="${2:-$REPO_ROOT/skills/coding-guidelines/SKILL.md}"

for required in "$HANDLER" "$SKILL"; do
  if [ ! -f "$required" ]; then
    echo "Source file not found at: $required"
    echo "Usage: $0 [path-to-session-start-handler] [path-to-coding-guidelines-SKILL.md]"
    exit 1
  fi
done

# JSON 必須用真的 parser 驗，不能拿 grep 湊：少一個右大括號、多一個沒跳脫的引號，
# 純文字比對都看不出來。挑第一個「真的跑得動」的直譯器 — Windows 上的 python3
# 常常是 Microsoft Store 的空殼，會什麼都不印就結束，所以這裡看輸出而不是看存在。
PY=""
for candidate in python python3; do
  if [ "$("$candidate" -c 'print("ok")' 2>/dev/null)" = "ok" ]; then
    PY="$candidate"
    break
  fi
done
if [ -z "$PY" ]; then
  echo "No working Python interpreter found (tried: python, python3)."
  echo "One is required to parse the handler's JSON output."
  exit 1
fi

# 不沿用 TMPDIR 這個名字：底下會把 handler 當子行程跑，測試不該改到受測對象的環境。
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

PASS=0
FAIL=0

# --- 抽取 ---

# SKILL.md 的編號標題，輸出成 "<n>. <title>"。
skill_headings() {
  tr -d '\r' < "$1" | sed -n 's/^## \([0-9][0-9]*\)\. \(.*\)$/\1. \2/p'
}

# handler 摘要裡的編號條目，輸出成同樣的 "<n>. <title>"。
# 那串摘要是 JSON 字串裡的一整行，條目之間以「字面上的」\n 分隔，所以先換成真換行。
# ${line%% - *} 砍掉的是最長的後綴，也就是切在「第一個」" - " — 標題本身可以含連字號
# （Goal-Driven、Non-Obvious），但不會含 " - "。
summary_headings() {
  tr -d '\r' < "$1" | sed 's/\\n/\n/g' | grep -E '^[0-9]+\. ' | while IFS= read -r line; do
    printf '%s\n' "${line%% - *}"
  done
}

# --- 受測的兩個檢查 ---

# 摘要與來源是否一致。訊息要指出「差在哪」，所以列出只出現在單邊的條目。
check_drift() {
  local skill="$1" handler="$2"
  local skill_list="$WORKDIR/skill.list" summary_list="$WORKDIR/summary.list"
  skill_headings "$skill" > "$skill_list"
  summary_headings "$handler" > "$summary_list"

  local skill_count summary_count only_skill only_summary
  skill_count="$(wc -l < "$skill_list")"
  summary_count="$(wc -l < "$summary_list")"
  only_skill="$(grep -Fxv -f "$summary_list" "$skill_list")"
  only_summary="$(grep -Fxv -f "$skill_list" "$summary_list")"

  # 兩邊都空會「數量相符、差集為空」地默默通過，那是這支測試最該擋下的沉默失敗。
  if [ "$skill_count" -eq 0 ]; then
    echo "no numbered headings found in $skill" >&2
    return 1
  fi

  if [ "$skill_count" -eq "$summary_count" ] && [ -z "$only_skill" ] && [ -z "$only_summary" ]; then
    return 0
  fi

  echo "the guideline summary has drifted from its source" >&2
  echo "  numbered headings in SKILL.md: $skill_count" >&2
  echo "  numbered entries in the summary: $summary_count" >&2
  if [ -n "$only_skill" ]; then
    printf '%s\n' "$only_skill" | sed 's/^/  only in SKILL.md: /' >&2
  fi
  if [ -n "$only_summary" ]; then
    printf '%s\n' "$only_summary" | sed 's/^/  only in the summary: /' >&2
  fi
  return 1
}

# handler 的 stdout 是否仍是 SessionStart hook 允許送出的形狀。
check_output() {
  local handler="$1"
  local out rc
  out="$(bash "$handler" 2>/dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "handler exited $rc, expected 0" >&2
    return 1
  fi
  printf '%s' "$out" | "$PY" -c '
import json, sys

try:
    doc = json.loads(sys.stdin.read())
except ValueError as err:
    sys.stderr.write("stdout is not a single valid JSON document: %s\n" % err)
    sys.exit(1)

block = doc.get("hookSpecificOutput")
if not isinstance(block, dict):
    sys.stderr.write("hookSpecificOutput is missing or is not an object\n")
    sys.exit(1)

name = block.get("hookEventName")
if name != "SessionStart":
    sys.stderr.write("hookEventName is %s, expected SessionStart\n" % ascii(name))
    sys.exit(1)

context = block.get("additionalContext")
if not isinstance(context, str) or context.strip() == "":
    sys.stderr.write("additionalContext is empty or missing\n")
    sys.exit(1)
'
}

# --- 突變（只寫進 WORKDIR）---

mutate_skill_rename() {
  awk '!hit && /^## [0-9]+\. / { sub(/\. .*/, ". Drift Probe Renamed"); hit = 1 } { print }' "$1" > "$2"
}

mutate_skill_add() {
  cp "$1" "$2"
  printf '\n## 99. Drift Probe Added\n' >> "$2"
}

mutate_skill_remove() {
  awk '!hit && /^## [0-9]+\. / { hit = 1; next } { print }' "$1" > "$2"
}

mutate_skill_remove_all() {
  awk '!/^## [0-9]+\. /' "$1" > "$2"
}

# 砍掉文件最外層的右大括號 — 產生語法上真的壞掉的 JSON。
mutate_handler_broken_json() {
  awk '$0 == "}" { next } { print }' "$1" > "$2"
}

mutate_handler_wrong_event() {
  sed 's/"SessionStart"/"NotSessionStart"/' "$1" > "$2"
}

# 保持它是物件的最後一個鍵（不補逗號），否則測到的會是壞 JSON 而不是空字串。
mutate_handler_empty_context() {
  awk '/"additionalContext":/ { print "    \"additionalContext\": \"\""; next } { print }' "$1" > "$2"
}

# --- 案例執行器 ---

# run_case 案例名稱 預期結束碼 stderr必須包含的字串 -- 要跑的指令...
run_case() {
  local name="$1" expected_exit="$2" stderr_pattern="$3"
  shift 3
  local errfile="$WORKDIR/stderr.txt"
  "$@" >/dev/null 2>"$errfile"
  local actual_exit=$?

  local ok=true
  if [ "$actual_exit" -ne "$expected_exit" ]; then
    ok=false
  fi
  if [ -n "$stderr_pattern" ] && ! grep -q "$stderr_pattern" "$errfile"; then
    ok=false
  fi

  if [ "$ok" = true ]; then
    echo "PASS  [$name]"
    PASS=$((PASS + 1))
  else
    echo "FAIL  [$name]  (exit $actual_exit, expected $expected_exit${stderr_pattern:+; expected stderr to contain: \"$stderr_pattern\"})"
    echo "  --- stderr ---"
    sed 's/^/  /' "$errfile"
    FAIL=$((FAIL + 1))
  fi
}

echo "Testing handler: $HANDLER"
echo "Against source:  $SKILL"
echo "========================================"

# --- 正向：樹目前的狀態 ---

run_case "summary agrees with SKILL.md as the tree stands" 0 "" \
  check_drift "$SKILL" "$HANDLER"

# --- SKILL.md 突變：改名、新增、刪除 ---

mutate_skill_rename "$SKILL" "$WORKDIR/renamed.md"
run_case "a numbered heading renamed in SKILL.md -> drift reported" 1 "Drift Probe Renamed" \
  check_drift "$WORKDIR/renamed.md" "$HANDLER"

mutate_skill_add "$SKILL" "$WORKDIR/added.md"
run_case "a numbered heading added to SKILL.md -> drift reported" 1 "Drift Probe Added" \
  check_drift "$WORKDIR/added.md" "$HANDLER"

mutate_skill_remove "$SKILL" "$WORKDIR/removed.md"
run_case "a numbered heading removed from SKILL.md -> drift reported" 1 "only in the summary" \
  check_drift "$WORKDIR/removed.md" "$HANDLER"

mutate_skill_remove_all "$SKILL" "$WORKDIR/emptied.md"
run_case "every numbered heading gone -> reported, not a silent match" 1 "no numbered headings" \
  check_drift "$WORKDIR/emptied.md" "$HANDLER"

# --- handler 輸出 ---

run_case "handler emits a valid SessionStart document, exit 0" 0 "" \
  check_output "$HANDLER"

mutate_handler_broken_json "$HANDLER" "$WORKDIR/broken.sh"
run_case "handler emits invalid JSON -> rejected" 1 "not a single valid JSON document" \
  check_output "$WORKDIR/broken.sh"

mutate_handler_wrong_event "$HANDLER" "$WORKDIR/wrong-event.sh"
run_case "hookEventName is not SessionStart -> rejected" 1 "expected SessionStart" \
  check_output "$WORKDIR/wrong-event.sh"

mutate_handler_empty_context "$HANDLER" "$WORKDIR/empty-context.sh"
run_case "additionalContext is empty -> rejected" 1 "additionalContext is empty" \
  check_output "$WORKDIR/empty-context.sh"

echo "========================================"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)) total)"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
