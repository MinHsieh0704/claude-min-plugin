#!/usr/bin/env bash
#
# PreToolUse handler — require explicit confirmation before a git commit runs.
#
# Gated on the plugin's `commit_gate` userConfig option, which defaults to
# true. See user-prompt-submit.sh for why the value is read from the
# environment rather than substituted into the hook command.
#
# Scope note: this matches the literal text "git commit" anywhere in the tool
# input. A Bash call that merely mentions that string — grepping the log for
# it, say — also trips the prompt. That is deliberate: the failure mode is one
# extra confirmation, whereas parsing the command precisely enough to avoid it
# would risk missing a real commit.
#
# Always exits 0. A PreToolUse hook that exits 2 blocks the call outright; the
# decision here is "ask", which is carried in the JSON payload, not the exit
# code.

if [ "${CLAUDE_PLUGIN_OPTION_COMMIT_GATE:-true}" != "true" ]; then
  exit 0
fi

input="$(cat)"

if printf '%s' "$input" | grep -Fq 'git commit'; then
  cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "claude-min-plugin: automatic commits are gated — confirm this git commit explicitly."
  }
}
EOF
fi

exit 0
