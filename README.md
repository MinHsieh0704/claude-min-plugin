# claude-min-plugin

一個包含三個 skill 與三個 hook 的 Claude Code 外掛：一套用來減少 LLM 常見錯誤的
coding guidelines、一套會記錄 AI 貢獻歸屬的 commit 流程，以及一個 worktree 合併
輔助工具。

## 安裝

```
/plugin marketplace add MinHsieh0704/claude-min-plugin
/plugin install claude-min-plugin@min-plugins
```

啟用外掛時會詢問兩個選項（下文皆有說明）。若不想安裝、只想在本機載入：

```bash
claude --plugin-dir /path/to/this/repo
```

## Skills

| Skill | 功能 |
|---|---|
| `/claude-min-plugin:coding-guidelines` | 十條準則，涵蓋臆測、範圍蔓延、資安、相依套件、回歸風險與錯誤處理。每個 session 都會注入一份精簡版；這個 skill 提供的是含理由與範例的完整全文。 |
| `/claude-min-plugin:commit` | 不再逐次徵詢同意即完成 stage 與 commit，產生符合 Conventional Commits 的標題，加上 `Co-Authored-By` / `AI-Contribution` / `Fixes:` trailer，以及由你傳入的追蹤編號所組成的 `Refs:` trailer — 沒傳的話，每個 commit 會問你一次。當單一組 trailer 無法誠實描述整份 diff 時，會拆成多個 commit。 |
| `/claude-min-plugin:merge-worktree` | 將目前 worktree 的分支 fast-forward 進主 checkout，接著移除該 worktree 與其分支。 |

## 選項

兩個選項都在啟用時詢問，之後可於 `/plugin` 內變更。

| 選項 | 預設 | 效果 |
|---|---|---|
| **Confirm before git commit**（commit 前先確認） | 開啟 | 任何執行 `git commit` 的 Bash 或 PowerShell 呼叫都必須先取得明確確認 — 包含中間夾帶全域選項的形式，例如 `git -C <path> commit`。 |
| **Reply in Traditional Chinese**（以繁體中文回覆） | 開啟 | Claude 以 zh-Hant 回覆。程式碼、指令、識別字與檔案路徑維持原本語言。此選項只管「回覆」— 它不決定檔案內容要用哪種語言撰寫。 |

coding-guidelines 摘要是無條件注入的，沒有對應選項 — 不想要就停用整個外掛。
它每個 session 大約花費 400 個 token；176 行的完整全文只有在呼叫該 skill 時才會載入。

## Commit 慣例

`/claude-min-plugin:commit` 最多會寫入四個 trailer：

```
fix: correct server version comparison

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
AI-Contribution: generated
Fixes: a1b2c3d
Refs: BUG-1234
```

`AI-Contribution` 的值是 `assisted` 或 `generated`，依這次 session 中實際發生的事
判定，而非依 diff 大小。`Fixes:` 出現在 `fix` 類型的 commit 上，指向引入該問題的
commit；當 git blame 結論不明時則寫 `Fixes: unknown`，並可搭配一份選用的
`Fixes-Candidates:` 清單。

`Refs:` 記錄你們團隊所用追蹤系統的 issue 編號。你可以直接傳入 —
`/claude-min-plugin:commit BUG-1234`，多個編號就重複這個 trailer — 那次呼叫產生的
每個 commit 都會帶上它。什麼都不傳的話，會在每個 commit 建立前的那一刻問你一次，
預設值是「沒有追蹤編號」；每個 commit 各自保留自己的答案，所以要讓兩個 commit 帶
同一個編號，就得輸入兩次。這個編號永遠不會從分支名稱或 diff 推測出來，也不會以猜測
選項的形式讓你點選 — 只有你明講的內容會被寫入，沒帶編號的 commit 就單純沒有 `Refs:`
這一行。`commit-msg` hook 同樣不檢查它：那支 hook 會進到每一個安裝此外掛的 repo，而
issue 編號規則是各團隊自家的慣例，不該強加於所有人。編號打錯了，沒有任何東西會攔下來。

這個 skill 會直接把 `skills/commit/hooks/commit-msg` 以 git `commit-msg` hook 的形式
（透過 `core.hooksPath`）裝進你的 repo，不另行詢問。該 hook 會擋下沒有 `Fixes:`
trailer 的 `fix` commit，並在出現 `Co-Authored-By: Claude` 卻缺少 `AI-Contribution`
時發出警告。它絕不動不屬於本慣例的 `commit-msg` hook；屬於自己的那份則會持續維持最新，
透過檔案標頭中的 `hook-version` 標記就地升級過舊的安裝。

`skills/commit/scripts/ai_attribution_stats.py` 會從這些 trailer 產出整體歸屬統計與
一份 fix 連結對照表。設計理由與已知限制見
`skills/commit/references/ai-attribution-proposal.md`（以繁體中文撰寫）。

## 開發

本 repo 遵循的外掛開發規則見 [CLAUDE.md](CLAUDE.md)。

```bash
claude plugin validate . --strict
bash skills/commit/tests/test-commit-msg-hook.sh skills/commit/hooks/commit-msg
```

## 授權

MIT — 見 [LICENSE](LICENSE)。
