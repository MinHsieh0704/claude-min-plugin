#!/usr/bin/env bash
# test-session-start.sh
#
# SessionStart handler 的自動化測試套件。守住三件事：
#
#   1. hooks-handlers/session-start.sh 裡那段摘要，必須就是拿
#      skills/coding-guidelines/SKILL.md 重跑一次 generate-session-start.py 會產生的東西
#      —— 重新產生一份，再逐 byte 比對。編號、標題與標語三者一起被蓋住。
#   2. handler 印出來的東西仍然是 SessionStart hook 被允許送出的形狀。
#   3. generator 自己收到的東西：來源不完整、或位置參數只給一半時，它要大聲擋下來，
#      而不是安靜地產生半套條目，或改到不是它該改的那份 handler。
#
# 為什麼是「重新產生再比對」而不是逐項比字串：標語現在只有一份（住在 SKILL.md 標題
# 正下一行的 HTML 註解裡），handler 那一行是產出物。唯一要問的問題因此變成「產出物
# 跟來源同步了嗎」，而那個問題只有 generator 自己答得準。
#
# 唯一還是蓋不到的：標語本身是否還講得出它那一節在講什麼。那是編輯性的判斷，
# 沒有東西可以拿來機械比對。
#
# 全部突變都作用在暫存目錄裡的複本上，repo 的 working tree 不會被動到 ——
# generator 會就地改寫，所以每次都改在複本上。
# 突變本身刻意不綁死任何一段現有文字（都對「第一個編號標題／標語」下手），
# 這樣 SKILL.md 日後正常改寫時，這些負向案例不會誤報。
#
# 用法：
#   bash hooks-handlers/tests/test-session-start.sh [handler] [skill-md]
#
# 執行環境是明確的前提，不是還沒補的缺口。這三項不成立時的行為刻意不處理：
#   - Windows + Git Bash。cmd.exe／PowerShell 不支援。
#   - GNU sed。unfold() 靠它在置換端把 \n 展開成換行；BSD／macOS sed 會當成字面的 n。
#     偵測本身用 cmp 逐 byte 比，不受影響，受影響的是失敗訊息的可讀性。
#   - Python 3。python 指到 Python 2 的主機不支援 —— 底下的探針只驗「跑得動」，
#     驗不出版本，而 generator 與內嵌驗證器都需要 3。
#
# 結束碼：每個案例都符合預期則為 0，只要有任一案例不符則為 1 — 可安心接進 CI。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

HANDLER="${1:-$REPO_ROOT/hooks-handlers/session-start.sh}"
SKILL="${2:-$REPO_ROOT/skills/coding-guidelines/SKILL.md}"
GENERATOR="$REPO_ROOT/hooks-handlers/generate-session-start.py"

for required in "$HANDLER" "$SKILL" "$GENERATOR"; do
  if [ ! -f "$required" ]; then
    echo "Source file not found at: $required"
    echo "Usage: $0 [path-to-session-start-handler] [path-to-coding-guidelines-SKILL.md]"
    exit 1
  fi
done

# JSON 必須用真的 parser 驗，不能拿 grep 湊：少一個右大括號、多一個沒跳脫的引號，
# 純文字比對都看不出來。挑第一個「真的跑得動」的直譯器 — Windows 上的 python3
# 常常是 Microsoft Store 的空殼，會什麼都不印就結束，所以這裡看輸出而不是看存在。
# generator 也是同一支直譯器跑的。
# print("ok") 在 Python 2 也會印 ok，所以這裡驗不出版本；Python 2 的主機不處理（見表頭）。
PY=""
for candidate in python python3; do
  if [ "$("$candidate" -c 'print("ok")' 2>/dev/null)" = "ok" ]; then
    PY="$candidate"
    break
  fi
done
if [ -z "$PY" ]; then
  echo "No working Python interpreter found (tried: python, python3)."
  echo "One is required to run the generator and to parse the handler's JSON output."
  exit 1
fi

# 不沿用 TMPDIR 這個名字：底下會把 handler 當子行程跑，測試不該改到受測對象的環境。
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

PASS=0
FAIL=0

# --- 輔助 ---

# 拿 skill 重新產生一份 handler 到 dest。generator 是就地改寫，所以先複製再交給它。
regenerate() {
  local skill="$1" handler="$2" dest="$3"
  cp "$handler" "$dest"
  "$PY" "$GENERATOR" "$skill" "$dest"
}

# 把摘要那一行裡「字面上的」\n 換成真換行。整段摘要在檔案裡是兩千多字的一整行，
# 不攤開的話 diff 只會說「這一行不一樣」，看不出差在哪一條。
# 置換端的 \n 要 GNU sed 才會變成換行；BSD／macOS sed 不處理（見表頭）。
unfold() {
  sed 's/\\n/\n/g' "$1"
}

# --- 受測的檢查 ---

# handler 是不是就是 generator 從這份 SKILL.md 產生出來的東西。
# 比對用 cmp（真的逐 byte），訊息才用攤開後的 diff —— 攤開只為了給人看。
check_drift() {
  local skill="$1" handler="$2"
  local regenerated="$WORKDIR/regenerated.sh"

  if ! regenerate "$skill" "$handler" "$regenerated"; then
    return 1
  fi

  if cmp -s "$handler" "$regenerated"; then
    return 0
  fi

  echo "the handler is not what the generator produces from SKILL.md" >&2
  echo "  run: python hooks-handlers/generate-session-start.py" >&2
  unfold "$handler" > "$WORKDIR/committed.txt"
  unfold "$regenerated" > "$WORKDIR/generated.txt"
  diff "$WORKDIR/committed.txt" "$WORKDIR/generated.txt" >&2
  return 1
}

# handler 的 stdout 是否仍是 SessionStart hook 允許送出的形狀。
# 第二個參數給了的話，additionalContext 還必須「原樣」含有那段字 —— 跳脫錯了的話
# JSON 可能照樣 parse 得過（\b 是合法的跳脫，只是變成退格），只有比對文字才抓得到。
check_output() {
  local handler="$1" needle="${2:-}"
  local out rc
  out="$(bash "$handler" 2>/dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "handler exited $rc, expected 0" >&2
    return 1
  fi
  printf '%s' "$out" | "$PY" -c '
import json, sys

needle = sys.argv[1] if len(sys.argv) > 1 else ""

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

if needle and needle not in context:
    sys.stderr.write("additionalContext does not carry %s verbatim\n" % ascii(needle))
    sys.exit(1)
' "$needle"
}

# 只給一個位置參數時，generator 必須擋下來，而不是把沒給的那半默默套成 repo 自己的
# handler。另外複製一份 generator 與 handler 到 WORKDIR 裡才跑：這個案例紅的時候，
# 被改寫的是那份複本，repo 的檔案動不到。
check_lone_argument_refused() {
  local skill="$1"
  local sandbox="$WORKDIR/lone-arg"
  rm -rf "$sandbox"
  mkdir -p "$sandbox"
  cp "$GENERATOR" "$sandbox/generate-session-start.py"
  cp "$HANDLER" "$sandbox/session-start.sh"

  if "$PY" "$sandbox/generate-session-start.py" "$skill"; then
    echo "the generator accepted a single positional argument" >&2
    return 1
  fi
  if ! cmp -s "$HANDLER" "$sandbox/session-start.sh"; then
    echo "a one-argument run rewrote the handler it defaulted to" >&2
    return 1
  fi
  return 0
}

# --- 突變（只寫進 WORKDIR）---

mutate_skill_rename() {
  awk '!hit && /^## [0-9]+\. / { sub(/\. .*/, ". Drift Probe Renamed"); hit = 1 } { print }' "$1" > "$2"
}

# 新增一節「連同它的標語」—— 也就是有人加了一條準則卻忘了重跑 generator。
mutate_skill_add() {
  cp "$1" "$2"
  printf '\n## 99. Drift Probe Added\n<!-- summary: a guideline the handler has not been regenerated for. -->\n' >> "$2"
}

# 新增一節但「沒寫標語」。這不是走鐘而是來源本身不完整，該由 generator 大聲擋下。
mutate_skill_add_orphan() {
  cp "$1" "$2"
  printf '\n## 98. Drift Probe Orphan\n' >> "$2"
}

# 標語註解在，但 marker 後面是空的。regex 收得下（"summary:" 之後兩個空格就會匹配到
# 空字串），而那會讓某一條準則只剩編號、標題與一個懸空的破折號進到每個 session。
# 一樣是來源本身不完整，而且是安靜的，該由 generator 大聲擋下。
# 對準「第一個編號標題」底下那一行：第一個標語可能屬於沒編號的標題（見下一個突變）。
mutate_skill_blank_tagline() {
  awk 'next_is { print "<!-- summary:  -->"; next_is = 0; next }
       !hit && /^## [0-9]+\. / { hit = 1; next_is = 1 } { print }' "$1" > "$2"
}

# 沒編號的標題：帶標語就進摘要，不帶就不進，空標語一樣要擋。
mutate_skill_add_unnumbered() {
  cp "$1" "$2"
  printf '\n## Drift Probe Unnumbered\n<!-- summary: an unnumbered section the handler has not been regenerated for. -->\n' >> "$2"
}

mutate_skill_add_unnumbered_bare() {
  cp "$1" "$2"
  printf '\n## Drift Probe Unnumbered Bare\n\nBody text with no summary comment.\n' >> "$2"
}

mutate_skill_add_unnumbered_blank() {
  cp "$1" "$2"
  printf '\n## Drift Probe Unnumbered Blank\n<!-- summary:  -->\n' >> "$2"
}

# 標題與它正下一行的標語一起刪掉 —— generator 要求兩者相鄰，只刪一行會變成另一種錯。
mutate_skill_remove() {
  awk '!hit && /^## [0-9]+\. / { hit = 1; skip = 1; next } skip { skip = 0; next } { print }' "$1" > "$2"
}

mutate_skill_remove_all() {
  awk '!/^## [0-9]+\. /' "$1" > "$2"
}

# 只改標語、標題原封不動 —— T1 那半邊（只比對標題）完全看不見的那個案例。
mutate_skill_tagline() {
  awk '!hit && /^<!-- summary: / { print "<!-- summary: Drift Probe Tagline -->"; hit = 1; next } { print }' "$1" > "$2"
}

# 標語裡塞進 " 與 \ 。用 ENVIRON 傳而不是 -v：-v 會先把值裡的跳脫序列解掉。
ESCAPE_PROBE='a "quoted" word and a \backslash probe.'
mutate_skill_escapes() {
  ESCAPE_PROBE="$ESCAPE_PROBE" awk \
    '!hit && /^<!-- summary: / { print "<!-- summary: " ENVIRON["ESCAPE_PROBE"] " -->"; hit = 1; next } { print }' \
    "$1" > "$2"
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

run_case "the handler is what the generator produces as the tree stands" 0 "" \
  check_drift "$SKILL" "$HANDLER"

# --- SKILL.md 突變：改名、新增、刪除、改標語 ---

mutate_skill_rename "$SKILL" "$WORKDIR/renamed.md"
run_case "a numbered heading renamed in SKILL.md -> drift reported" 1 "Drift Probe Renamed" \
  check_drift "$WORKDIR/renamed.md" "$HANDLER"

mutate_skill_add "$SKILL" "$WORKDIR/added.md"
run_case "a numbered heading added to SKILL.md -> drift reported" 1 "Drift Probe Added" \
  check_drift "$WORKDIR/added.md" "$HANDLER"

# 刪掉的是第一條，所以攤開後的 diff 必定少掉一行 "1. ..."。斷言不綁任何現有文字。
mutate_skill_remove "$SKILL" "$WORKDIR/removed.md"
run_case "a numbered heading removed from SKILL.md -> drift reported" 1 "^< 1\. " \
  check_drift "$WORKDIR/removed.md" "$HANDLER"

mutate_skill_tagline "$SKILL" "$WORKDIR/retagged.md"
run_case "a tagline changed in SKILL.md -> drift reported" 1 "Drift Probe Tagline" \
  check_drift "$WORKDIR/retagged.md" "$HANDLER"

mutate_skill_add_orphan "$SKILL" "$WORKDIR/orphan.md"
run_case "a numbered heading with no tagline -> the generator refuses" 1 "no summary comment" \
  check_drift "$WORKDIR/orphan.md" "$HANDLER"

mutate_skill_blank_tagline "$SKILL" "$WORKDIR/blank-tagline.md"
run_case "a tagline that is empty after the marker -> the generator refuses" 1 "empty tagline" \
  check_drift "$WORKDIR/blank-tagline.md" "$HANDLER"

mutate_skill_add_unnumbered "$SKILL" "$WORKDIR/unnumbered.md"
run_case "an unnumbered heading with a tagline added -> drift reported" 1 "Drift Probe Unnumbered" \
  check_drift "$WORKDIR/unnumbered.md" "$HANDLER"

mutate_skill_add_unnumbered_bare "$SKILL" "$WORKDIR/unnumbered-bare.md"
run_case "an unnumbered heading with no tagline -> left out, no drift" 0 "" \
  check_drift "$WORKDIR/unnumbered-bare.md" "$HANDLER"

mutate_skill_add_unnumbered_blank "$SKILL" "$WORKDIR/unnumbered-blank.md"
run_case "an unnumbered heading with an empty tagline -> the generator refuses" 1 "empty tagline" \
  check_drift "$WORKDIR/unnumbered-blank.md" "$HANDLER"

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

# --- 跳脫：標語裡的 " 與 \ 必須完好地抵達 handler 的 stdout ---

mutate_skill_escapes "$SKILL" "$WORKDIR/escapes.md"
regenerate "$WORKDIR/escapes.md" "$HANDLER" "$WORKDIR/escapes.sh" > /dev/null
run_case 'a tagline carrying " and \ survives into parsable stdout' 0 "" \
  check_output "$WORKDIR/escapes.sh" "$ESCAPE_PROBE"

# --- generator 的參數：兩個路徑或都不給，只給一個要被擋下 ---

# 來源用改過標語的複本：沒擋下來的話，它會真的把預設的那份 handler 改掉。
mutate_skill_tagline "$SKILL" "$WORKDIR/lone-arg-source.md"
run_case "the generator refuses a single positional argument" 0 "usage:" \
  check_lone_argument_refused "$WORKDIR/lone-arg-source.md"

echo "========================================"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)) total)"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
