#!/usr/bin/env bash
#
# SessionStart handler — inject a condensed form of the coding guidelines.
#
# This summary is DERIVED from skills/coding-guidelines/SKILL.md: the ten
# numbered headings and their one-line taglines are copied from there. When
# those headings change, regenerate this string — nothing checks the two for
# drift automatically.
#
# The full 171-line text deliberately stays out of every session's context
# (~1.5k tokens); Claude reads it on demand via /claude-min-plugin:coding-guidelines.
#
# Always on: this handler takes no userConfig gate. A user who does not want
# the guidelines should disable the plugin.

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "claude-min-plugin coding guidelines are active. Follow these while writing or modifying code:\n\n1. Think Before Coding — don't assume, don't hide confusion, surface tradeoffs; if something is unclear, stop and ask.\n2. Simplicity First — the minimum code that solves the problem; nothing speculative, no abstractions for single-use code.\n3. Surgical Changes — touch only what you must, match existing style, and clean up only the orphans your own change created.\n4. Goal-Driven Execution — turn the task into verifiable success criteria and loop until they pass.\n5. Security Is Non-Negotiable — never hardcode secrets, treat all external input as untrusted, never hand-roll crypto; flag any change touching auth, authorization, or persistence.\n6. Dependency Awareness — a new dependency is a decision, not a default; state the reason, version, and license.\n7. Regression Awareness — name the downstream callers and changed contracts your edit affects before submitting.\n8. Explain Non-Obvious Decisions — say why A over B, and why code that looks shortenable intentionally is not.\n9. Fail Loudly, Not Silently — no empty catch blocks, no silent defaults on anomalous data, no type assertions masking real errors.\n10. Context Sync Before Long Tasks — more than 3 steps or more than 3 files: state the plan and get confirmation before starting.\n\nThese bias toward caution over speed; use judgment on trivial tasks such as typo fixes and one-line changes.\n\nFull text with rationale, examples, and the inline-note formats: run /claude-min-plugin:coding-guidelines."
  }
}
EOF

exit 0
