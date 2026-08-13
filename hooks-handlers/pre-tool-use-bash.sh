#!/usr/bin/env bash
#
# PreToolUse handler — 在 git commit 執行前要求明確確認。
#
# 受外掛的 `commit_gate` userConfig 選項控制，預設為 true。為何是從環境變數讀取
# 而非代入 hook 指令中，見 user-prompt-submit.sh 的說明。
#
# 比對範圍說明：此處比對 `git`，接著任意數量以空白分隔的 token，再接 `commit`，
# 且只在工具呼叫的 `command` 欄位內比對。單純提到這組字的指令 — 例如拿它去 grep
# log — 一樣會觸發確認提示。這是刻意的：最壞情況只是多確認一次，而要精準到能避開
# 這種誤判的指令剖析，反而有漏掉真正 commit 的風險。
#
# 中間那些 token 正是單純比對字面 "git commit" 會漏掉的部分：git 的全域選項就落在
# 那裡，所以 `git -C <path> commit` 與 `git --no-pager commit` 會完全繞過這道關卡，
# 連中間打了兩個空白的 `git  commit` 也一樣。`-C` 並不冷僻 — 它就是從工作目錄外操作
# 一個 repo 的標準做法，任何 worktree 或 CI 形態的流程遲早都會用上。
#
# 比對範圍限縮在 `command` 而非整包 payload，是因為 PreToolUse 的輸入還帶有
# `description`、`cwd` 與 `transcript_path`。一個無害、但描述寫成 "check git commit
# policy" 的呼叫會觸發舊版的整包比對，那與該呼叫實際執行的內容無關，純屬雜訊。
#
# 一律以 0 結束。PreToolUse hook 若以 2 結束會直接封鎖該呼叫；這裡的決策是「詢問」，
# 而它是由 JSON payload 傳達，不是由結束碼傳達。

if [ "${CLAUDE_PLUGIN_OPTION_COMMIT_GATE:-true}" != "true" ]; then
  exit 0
fi

input="$(cat)"

# 取出 "command" 的 JSON 字串值：這個交替樣式會先消耗掉轉義配對（包含 \"）再處理
# 一般字元，所以比對會停在第一個「未轉義」的引號，不會一路吃到下一個 key。
command="$(printf '%s' "$input" | grep -oE '"command"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"' | head -n 1)"

# 取不出 command — 退回搜尋整包 payload。多問一次是安全的失敗方向；讓真正的 commit
# 未經詢問就過關則不是。
if [ -z "$command" ]; then
  command="$input"
fi

if printf '%s' "$command" | grep -Eq 'git[[:space:]]+([^[:space:]]+[[:space:]]+)*commit'; then
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
