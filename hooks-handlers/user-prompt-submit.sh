#!/usr/bin/env bash
#
# UserPromptSubmit handler — 要求 Claude 以繁體中文回覆。
#
# 受外掛的 `reply_zh_hant` userConfig 選項控制，預設為 true。Claude Code 會把每個
# userConfig 值以 CLAUDE_PLUGIN_OPTION_<KEY>（key 轉大寫）的形式匯出給 hook 行程。
#
# 這個值無法直接內插進 hook 指令本身：shell 形式的 hook 指令會「拒絕」
# ${user_config.*} 替換，因為那等於把設定值交給 shell 去執行。在這裡讀取環境變數
# 才是官方支援的做法。
#
# 這支 hook 只管回覆語言；檔案內容要用哪種語言撰寫，不在它的管轄範圍內。
#
# 因此第一句的豁免清單講的是「出現在 zh-Hant 回覆行文中的 token」— 它避免
# `git commit` 變成「git 提交」、路徑變成一句翻譯過的詞。commit message 刻意不列入
# 其中：commit message 是產出的成品，而不是回覆中的一個 token，其語言已由
# skills/commit/SKILL.md 固定為英文。
#
# additionalContext 的第二句用來分開 Claude 否則會混為一談的兩件事：它「回覆」所用的
# 語言，以及檔案「撰寫」所用的語言。這支 hook 只在送出 prompt 時觸發 — 而
# AskUserQuestion 的答案是以工具結果的形式抵達，所以當使用者為某份文件的語言選了
# 「English」，那個訊息會在沒有 zh-Hant 指示相伴的情況下進入 context，於是這個更新、
# 更具體的訊號就勝出。把這層區別明講在注入的文字裡，正是避免那個選擇被讀成
# 「用英文回覆」的關鍵。

if [ "${CLAUDE_PLUGIN_OPTION_REPLY_ZH_HANT:-true}" != "true" ]; then
  exit 0
fi

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Reply to the user in Traditional Chinese (zh-Hant); keep code, commands, identifiers, and file paths in their original language. This governs your conversational replies only: a choice about what language to write a file, document, or commit message in never changes the language you reply in."
  }
}
EOF

exit 0
