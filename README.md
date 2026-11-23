# min-toolkit

一個包含四個 skill 與三個 hook 的 Claude Code 外掛：一套用來減少 LLM 常見錯誤的
coding guidelines、一套會記錄 AI 貢獻歸屬的 commit 流程、一個 worktree 合併輔助
工具，以及一個中英文語言分界的稽核工具。

## 安裝

```
/plugin marketplace add MinHsieh0704/claude-min-plugin
/plugin install min-toolkit@min-plugins
```

這個外掛原名 `claude-min-plugin`。已經裝過舊名稱的話，marketplace 不會再提供它的更新，請先移除
`claude-min-plugin@min-plugins`，再安裝上面的 `min-toolkit@min-plugins`，並重新設定兩個選項。
指令也從 `/claude-min-plugin:*` 改成 `/min-toolkit:*`。

啟用外掛時會詢問兩個選項（下文皆有說明）。若不想安裝、只想在本機載入：

```bash
claude --plugin-dir /path/to/this/repo
```

## Skills

| Skill | 功能 |
|---|---|
| `/min-toolkit:coding-guidelines` | 一整套準則，涵蓋臆測、範圍蔓延、API 查證、未執行的驗證不得宣稱通過、資安、相依套件、回歸風險、根因與錯誤處理，以及無人值守時該如何處理「先問再做」。每個 session 都會注入一份精簡版；這個 skill 提供的是含理由與範例的完整全文。 |
| `/min-toolkit:commit` | 不再逐次徵詢同意即完成 stage 與 commit，產生符合 Conventional Commits 的標題，加上 `Co-Authored-By` / `AI-Contribution` / `Fixes:` trailer，以及由你傳入的追蹤編號所組成的 `Refs:` trailer — 沒傳的話，每個 commit 會問你一次。那次提問也提供煞車，見下方「Commit 慣例」。當單一組 trailer 無法誠實描述整份 diff 時，會拆成多個 commit。 |
| `/min-toolkit:merge-worktree` | 將目前 worktree 的分支 fast-forward 進主 checkout，接著移除該 worktree 與其分支。worktree 落後主分支時會說明情況，問你要不要先 rebase。只能在 Claude 以 EnterWorktree 建立的 worktree session 內使用。 |
| `/min-toolkit:language-check` | 稽核 repo 內繁體中文與英文的分界：註解與人讀文件用繁中，所有 runtime 輸出、`SKILL.md`、`agents/<name>.md` 與 manifest 用英文，且輸出必須是純 ASCII。回報逐檔比例，把程式碼中每一行含非 ASCII 字元的行逐一分類，找出進入輸出的中文與符號（包含跨行敘述與 heredoc 吐出的 JSON）。只分析與回報，不會自行改寫。 |

## 語言分界

判斷一段文字用什麼語言，只看**誰讀它**，不看檔案類型：

| 語言 | 適用範圍 |
|---|---|
| 繁體中文 | 程式碼註解與 docstring、`README.md`、`references/` 下的理由文件 — 只有本 repo 維護者會讀到的文字。 |
| 英文（且純 ASCII） | 所有 runtime 輸出（stdout、stderr、丟出的例外）、`SKILL.md`、`agents/<name>.md`（其正文是 system prompt，只有模型讀）、`CLAUDE.md`、各種 manifest、hook 注入模型的字串、commit message — 會離開 repo 或被機器讀取的文字。 |

因此有一條可以直接 grep 的硬規則：**`.sh` / `.py` 的字串字面值內不得出現任何非 ASCII 字元**。
註解裡多少中文都可以，字串裡一個都不行 —— 而且不限中文：符號、em dash、全形標點同樣不行，
因為收不下它們的 console 不是當場中止（stdout）就是把訊息靜靜弄壞（stderr）。這條規則是
必要條件而非充分條件：中文還能經由插值進入輸出，那種情況下原始碼那一行是完全乾淨的。
理由、邊界案例與偵測方法的極限見
`skills/language-check/references/language-convention.md`（以繁體中文撰寫）。

這條規則與下方的 **Reply in Traditional Chinese** 選項無關：那個選項管 Claude 的「回覆」
語言，這條規則管檔案內容的「撰寫」語言，兩者互不影響。

## 選項

兩個選項都在啟用時詢問，之後可於 `/plugin` 內變更。

| 選項 | 預設 | 效果 |
|---|---|---|
| **Confirm before git commit**（commit 前先確認） | 開啟 | 任何執行 `git commit` 的 Bash 或 PowerShell 呼叫都必須先取得明確確認 — 包含中間夾帶全域選項的形式，例如 `git -C <path> commit`。 |
| **Reply in Traditional Chinese**（以繁體中文回覆） | 開啟 | Claude 以 zh-Hant 回覆。程式碼、指令、識別字與檔案路徑維持原本語言。此選項只管「回覆」— 它不決定檔案內容要用哪種語言撰寫。 |

coding-guidelines 摘要是無條件注入的，沒有對應選項 — 不想要就停用整個外掛。
它每個 session 花掉將近一千個 token；完整全文只有在呼叫該 skill 時才會載入。

## Commit 慣例

`/min-toolkit:commit` 只會寫入一組固定的 trailer，不會有別的 —— 完整清單在
`skills/commit/SKILL.md`，這裡只舉例：

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

`Refs:` 記錄你們團隊追蹤系統的編號，只寫你明講的內容，不會從分支名稱或 diff 推測。
呼叫時直接傳入（`/min-toolkit:commit BUG-1234`，多個編號用空白隔開），這次產生的
每個 commit 都會帶上；沒傳的話，每個 commit 建立前各問一次，預設是不加。`commit-msg`
hook 不檢查這個編號，打錯了不會被攔下。

那次提問的第三個選項「先看 diff」是煞車：印出 `git diff --staged` 與擬好的訊息，**這個
commit 與這次後面的 commit 都不建立**，留在工作目錄；已建立的 commit 不受影響。看完再叫
一次 skill 就會從剩下的改動繼續。呼叫時已帶編號或在 headless 執行時不會提問，也就沒有煞車。

第一次 commit 時，skill 會把 `commit-msg` hook 裝進 repo 的 `.githooks/`（透過
`core.hooksPath`），之後自動維持最新版本；repo 已有別人的 `commit-msg` hook 時不會動它。
這支 hook 會擋下沒有 `Fixes:` 的 `fix` commit，並在有 `Co-Authored-By: Claude` 卻缺少
`AI-Contribution` 時發出警告。`.githooks/` 不進版控，所以第一次安裝時會問要不要把
`.githooks/commit-msg` 加進 `.gitignore`（建議只加這個檔案，不加整個目錄）；那一行會留在
未 stage 的狀態讓你另外 commit，`.gitignore` 當下已有未 commit 的改動時則只提示、不代寫。

`skills/commit/scripts/ai_attribution_stats.py` 會從這些 trailer 產出整體歸屬統計與
一份 fix 連結對照表。設計理由與已知限制見
`skills/commit/references/ai-attribution-proposal.md`（以繁體中文撰寫）。

## 授權

MIT — 見 [LICENSE](LICENSE)。
