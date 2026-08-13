#!/usr/bin/env bash
# test-commit-msg-hook.sh
#
# commit-msg 歸屬 hook 的自動化測試套件。「不」需要真實的 git repo — 該 hook
# 只會讀取以 $1 傳入的訊息檔，所以這裡單純製造各種訊息檔，再檢查 hook 的結束碼
# （其中少數案例還會檢查「觸發的是對的那個錯誤」，而不只是隨便哪個錯誤）。
#
# 用法：
#   chmod +x test-commit-msg-hook.sh commit-msg
#   ./test-commit-msg-hook.sh ./commit-msg
#
# 在 Windows 上：請從 Git Bash 執行（不是 cmd.exe／PowerShell）。
#
# 結束碼：每個案例都符合預期則為 0，只要有任一案例不符則為 1 — 可安心接進 CI。

set -uo pipefail

HOOK="${1:-./commit-msg}"
if [ ! -f "$HOOK" ]; then
  echo "Hook script not found at: $HOOK"
  echo "Usage: $0 [path-to-commit-msg-hook]"
  exit 1
fi
chmod +x "$HOOK" 2>/dev/null || true

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

# run_case 案例名稱 預期結束碼 訊息內容 [stderr 必須包含的字串]
run_case() {
  local name="$1" expected_exit="$2" content="$3" stderr_pattern="${4:-}"
  local msgfile="$TMPDIR/msg.txt" errfile="$TMPDIR/stderr.txt"
  printf '%s' "$content" > "$msgfile"
  "$HOOK" "$msgfile" >/dev/null 2>"$errfile"
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

echo "Testing hook: $HOOK"
echo "========================================"

# --- Conventional Commits（有冒號）格式 ---

run_case "fix: no Fixes: trailer -> reject" 1 \
"fix: correct off-by-one
"

run_case "fix: with Fixes: unknown -> pass" 0 \
"fix: correct off-by-one

Fixes: unknown
"

run_case "fix: with confirmed Fixes: <sha> -> pass" 0 \
"fix: correct off-by-one

Fixes: a1b2c3d
"

run_case "fix(scope): with no Fixes: -> reject (scope still detected as fix)" 1 \
"fix(auth): correct off-by-one
"

run_case "feat: (non-fix type) -> pass without Fixes:" 0 \
"feat: add new endpoint
"

run_case "hotfix: no Fixes: -> reject" 1 \
"hotfix: null pointer crash
"

run_case "fixed: (past tense) no Fixes: -> reject" 1 \
"fixed: race condition
"

# --- 舊式純字詞格式（早於 Conventional Commits 的歷史紀錄）---

run_case "legacy 'fix ...' (no colon) no Fixes: -> reject" 1 \
"fix off-by-one bug
"

run_case "legacy 'update ...' (no colon, non-fix) -> pass" 0 \
"update logging verbosity
"

# --- 多個源頭 / 候選清單 ---

run_case "multiple Fixes: lines (tangled commit) -> pass" 0 \
"fix: two unrelated regressions

Fixes: 1111111
Fixes: 2222222
"

run_case "Fixes-Candidates alone, no Fixes: at all -> reject" 1 \
"fix: ambiguous regression

Fixes-Candidates: aaa1111,bbb2222
"

run_case "Fixes: unknown + Fixes-Candidates together -> pass" 0 \
"fix: ambiguous regression

Fixes: unknown
Fixes-Candidates: aaa1111,bbb2222
"

run_case "Fixes: <sha> + Fixes-Candidates (contradiction) -> reject with the right error" 1 \
"fix: something

Fixes: a1b2c3d
Fixes-Candidates: aaa1111,bbb2222
" "Fixes-Candidates"

run_case "Fixes: unknown + confirmed Fixes: <sha> together (contradiction) -> reject" 1 \
"fix: something

Fixes: unknown
Fixes: a1b2c3d
" "both present"

# --- AI-Contribution 警告（不阻擋）---

run_case "Co-Authored-By without AI-Contribution -> pass, but warns" 0 \
"feat: add helper

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
" "AI-Contribution"

run_case "Co-Authored-By with AI-Contribution -> clean pass" 0 \
"feat: add helper

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
AI-Contribution: assisted
"

# --- 基準案例 ---

run_case "plain non-fix commit, no AI involvement -> pass" 0 \
"chore: bump dependency version
"

echo "========================================"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)) total)"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
