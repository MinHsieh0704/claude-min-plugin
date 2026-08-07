#!/usr/bin/env bash
#
# PreToolUse handler — require explicit confirmation before a git commit runs.
#
# Gated on the plugin's `commit_gate` userConfig option, which defaults to
# true. See user-prompt-submit.sh for why the value is read from the
# environment rather than substituted into the hook command.
#
# Scope note: this matches the literal text "git commit" within the tool call's
# `command` only. A command that merely mentions that string — grepping the log
# for it, say — still trips the prompt. That is deliberate: the failure mode is
# one extra confirmation, whereas parsing the command precisely enough to avoid
# it would risk missing a real commit.
#
# The match is scoped to `command` rather than the whole payload because the
# PreToolUse input also carries `description`, `cwd`, and `transcript_path`. A
# harmless call described as "check git commit policy" tripped the old
# whole-payload match, which is noise unrelated to what the call actually runs.
#
# Always exits 0. A PreToolUse hook that exits 2 blocks the call outright; the
# decision here is "ask", which is carried in the JSON payload, not the exit
# code.

if [ "${CLAUDE_PLUGIN_OPTION_COMMIT_GATE:-true}" != "true" ]; then
  exit 0
fi

input="$(cat)"

# Take the JSON string value of "command": the alternation consumes escaped
# pairs (\" among them) before plain characters, so the match ends at the first
# *unescaped* quote and cannot run on into the next key.
command="$(printf '%s' "$input" | grep -oE '"command"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -n 1)"

# No extractable command — fall back to searching the whole payload. Asking
# once too often is the safe direction to fail; letting a real commit through
# unprompted is not.
if [ -z "$command" ]; then
  command="$input"
fi

if printf '%s' "$command" | grep -Fq 'git commit'; then
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
