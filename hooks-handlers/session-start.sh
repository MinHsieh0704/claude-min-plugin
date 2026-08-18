#!/usr/bin/env bash
#
# SessionStart handler — 注入精簡版的 coding guidelines。
#
# 這份摘要是從 skills/coding-guidelines/SKILL.md「衍生」而來：十個編號標題與其
# 單行標語都是從那裡抄過來的。那些標題一有變動，就必須重新產生這段字串 — 沒有任何
# 機制會自動偵測兩者之間的落差。
#
# 176 行的完整全文刻意不進入每個 session 的 context（約 1.5k token）；Claude 會在
# 需要時透過 /claude-min-plugin:coding-guidelines 自行讀取。
#
# 一律啟用：這支 handler 沒有 userConfig 開關。不想要這套準則的使用者請停用整個外掛。

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "claude-min-plugin coding guidelines are active. Follow these while writing or modifying code:\n\n1. Think Before Coding - don't assume, don't hide confusion, surface tradeoffs; if something is unclear, stop and ask.\n2. Simplicity First - the minimum code that solves the problem; nothing speculative, no abstractions for single-use code.\n3. Surgical Changes - touch only what you must, match existing style, and clean up only the orphans your own change created.\n4. Goal-Driven Execution - turn the task into verifiable success criteria and loop until they pass.\n5. Security Is Non-Negotiable - never hardcode secrets, treat all external input as untrusted, never hand-roll crypto; flag any change touching auth, authorization, or persistence.\n6. Dependency Awareness - a new dependency is a decision, not a default; state the reason, version, and license.\n7. Regression Awareness - name the downstream callers and changed contracts your edit affects before submitting.\n8. Explain Non-Obvious Decisions - say why A over B, and why code that looks shortenable intentionally is not.\n9. Fail Loudly, Not Silently - no empty catch blocks, no silent defaults on anomalous data, no type assertions masking real errors.\n10. Context Sync Before Long Tasks - more than 3 steps or more than 3 files: state the plan and get confirmation before starting.\n\nThese bias toward caution over speed; use judgment on trivial tasks such as typo fixes and one-line changes.\n\nFull text with rationale, examples, and the inline-note formats: run /claude-min-plugin:coding-guidelines."
  }
}
EOF

exit 0
