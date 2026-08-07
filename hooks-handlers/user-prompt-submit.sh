#!/usr/bin/env bash
#
# UserPromptSubmit handler — ask Claude to reply in Traditional Chinese.
#
# Gated on the plugin's `reply_zh_hant` userConfig option, which defaults to
# true. Claude Code exports every userConfig value to hook processes as
# CLAUDE_PLUGIN_OPTION_<KEY> with the key uppercased.
#
# The value cannot be interpolated into the hook command itself: shell-form
# hook commands reject ${user_config.*} substitution, because the configured
# value would then be handed to the shell to execute. Reading the environment
# variable here is the supported path.
#
# The second sentence of additionalContext separates two things Claude
# otherwise conflates: the language it replies in, and the language a file is
# written in. This hook only fires on prompt submission — an AskUserQuestion
# answer arrives as a tool result, so choosing "English" for a document's
# language lands in context with no zh-Hant instruction alongside it, and the
# newer, more specific signal wins. Naming the distinction in the injected
# text is what keeps that choice from being read as "reply in English".

if [ "${CLAUDE_PLUGIN_OPTION_REPLY_ZH_HANT:-true}" != "true" ]; then
  exit 0
fi

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Reply to the user in Traditional Chinese (zh-Hant) whenever possible; keep code, commands, identifiers, file paths, and commit messages in their original language. This governs your conversational replies only: a choice about what language to write a file, document, or commit message in never changes the language you reply in."
  }
}
EOF

exit 0
