#!/usr/bin/env bash
#
# SessionStart handler — 注入精簡版的 coding guidelines。
#
# 底下 additionalContext 那一行是「產生」出來的，不要手改：每個編號標題與它的單行
# 標語都住在 skills/coding-guidelines/SKILL.md（標語是標題正下一行的 HTML 註解）。
# 改完那邊，跑這個指令把這一行重新產生出來：
#
#     python hooks-handlers/generate-session-start.py
#
# 忘記重跑會被 hooks-handlers/tests/test-session-start.sh 擋下來。
#
# 完整全文刻意不進入每個 session 的 context（約 1.5k token）；Claude 會在
# 需要時透過 /claude-min-plugin:coding-guidelines 自行讀取。
#
# 一律啟用：這支 handler 沒有 userConfig 開關。不想要這套準則的使用者請停用整個外掛。

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "claude-min-plugin coding guidelines are active. Follow these while writing or modifying code:\n\n1. Think Before Coding - don't assume, don't hide confusion, surface tradeoffs; any set of options you offer must include one that does less; if something is unclear, stop and ask.\n2. Simplicity First - the minimum code that solves the problem; nothing speculative, no abstractions for single-use code, no branch for a case that cannot reasonably occur - where that collides with 9, 2 wins, and you leave one comment line saying the case is not handled.\n3. Surgical Changes - touch only what you must, match existing style, and clean up only the orphans your own change created.\n4. Goal-Driven Execution - turn the task into verifiable success criteria and loop until they pass; where the task sets a size or review budget, spending it also ends the loop - then report rather than open another round.\n5. Security Is Non-Negotiable - never hardcode secrets, treat all external input as untrusted, never hand-roll crypto; flag any change touching auth, authorization, or persistence.\n6. Dependency Awareness - a new dependency is a decision, not a default; state the reason, version, and license.\n7. Regression Awareness - name the downstream callers and changed contracts your edit affects before submitting.\n8. Explain Non-Obvious Decisions - say why A over B in one sentence, and why code that looks shortenable intentionally is not; measurements and longer arguments go to a references file.\n9. Fail Loudly, Not Silently - no empty catch blocks, no silent defaults on anomalous data, no type assertions masking real errors.\n10. Context Sync Before Long Tasks - more than 3 steps or more than 3 files: state the plan and get confirmation before starting.\n11. Fix the Cause, Not the Symptom - group a batch of review findings by root cause before fixing any, since deleting the construct they share beats guarding each one; when one thing keeps breaking or a fix costs a regression elsewhere, the spec is the suspect, not the code.\n\nThese bias toward caution over speed; use judgment on trivial tasks such as typo fixes and one-line changes.\n\nFull text with rationale, examples, and the inline-note formats: run /claude-min-plugin:coding-guidelines."
  }
}
EOF

exit 0
