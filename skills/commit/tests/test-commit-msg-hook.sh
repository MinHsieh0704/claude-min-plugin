#!/usr/bin/env bash
# test-commit-msg-hook.sh
#
# Automated test suite for the commit-msg attribution hook. Does NOT need
# a real git repo — the hook only reads the message file passed as $1,
# so this just crafts message files and checks the hook's exit code
# (and, for a few cases, that the RIGHT error fired, not just any error).
#
# Usage:
#   chmod +x test-commit-msg-hook.sh commit-msg
#   ./test-commit-msg-hook.sh ./commit-msg
#
# On Windows: run this from Git Bash (not cmd.exe/PowerShell).
#
# Exit code: 0 if every case behaved as expected, 1 if any case didn't —
# safe to wire into CI.

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

# run_case NAME EXPECTED_EXIT CONTENT [STDERR_MUST_CONTAIN]
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

# --- Conventional Commits (colon) format ---

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

# --- Legacy bare-word format (pre-Conventional-Commits history) ---

run_case "legacy 'fix ...' (no colon) no Fixes: -> reject" 1 \
"fix off-by-one bug
"

run_case "legacy 'update ...' (no colon, non-fix) -> pass" 0 \
"update logging verbosity
"

# --- Multiple origins / candidates ---

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

# --- AI-Contribution warning (non-blocking) ---

run_case "Co-Authored-By without AI-Contribution -> pass, but warns" 0 \
"feat: add helper

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
" "AI-Contribution"

run_case "Co-Authored-By with AI-Contribution -> clean pass" 0 \
"feat: add helper

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
AI-Contribution: assisted
"

# --- Baseline ---

run_case "plain non-fix commit, no AI involvement -> pass" 0 \
"chore: bump dependency version
"

echo "========================================"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)) total)"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
