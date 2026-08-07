#!/usr/bin/env bash
#
# UserPromptSubmit handler — ask Claude to reply in Traditional Chinese.
#
# Gated on the plugin's `reply_zh_hant` userConfig option, which defaults to
# false. Claude Code exports every userConfig value to hook processes as
# CLAUDE_PLUGIN_OPTION_<KEY> with the key uppercased.
#
# The value cannot be interpolated into the hook command itself: shell-form
# hook commands reject ${user_config.*} substitution, because the configured
# value would then be handed to the shell to execute. Reading the environment
# variable here is the supported path.

if [ "${CLAUDE_PLUGIN_OPTION_REPLY_ZH_HANT:-false}" != "true" ]; then
  exit 0
fi

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Reply to the user in Traditional Chinese (zh-Hant) whenever possible; keep code, commands, identifiers, file paths, and commit messages in their original language."
  }
}
EOF

exit 0
