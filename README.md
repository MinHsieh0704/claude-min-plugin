# claude-min-plugin

一個包含四個 skill、兩個 agent 與三個 hook 的 Claude Code 外掛：一套用來減少 LLM 常見
錯誤的 coding guidelines、一套會記錄 AI 貢獻歸屬的 commit 流程、一個 worktree 合併
輔助工具、一個中英文語言分界的稽核工具，以及兩個照著那套準則實作與審查的 agent。

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
| `/claude-min-plugin:commit` | 不再逐次徵詢同意即完成 stage 與 commit，產生符合 Conventional Commits 的標題，加上 `Co-Authored-By` / `AI-Contribution` / `Fixes:` trailer，以及由你傳入的追蹤編號所組成的 `Refs:` trailer — 沒傳的話，每個 commit 會問你一次。那次提問同時是你喊停的地方：選第三個選項就會把 `git diff --staged` 與擬好的訊息攤開給你看，並且不建立那一個 commit — 同批的其他 commit 照常建立。當單一組 trailer 無法誠實描述整份 diff 時，會拆成多個 commit。 |
| `/claude-min-plugin:merge-worktree` | 將目前 worktree 的分支 fast-forward 進主 checkout，接著移除該 worktree 與其分支。 |
| `/claude-min-plugin:language-check` | 稽核 repo 內繁體中文與英文的分界：註解與人讀文件用繁中，所有 runtime 輸出、`SKILL.md`、`agents/<name>.md` 與 manifest 用英文，且輸出必須是純 ASCII。回報逐檔比例，抓出混進 `echo` / `print` / `throw` 的中文字元與非 ASCII 符號，並以 AST 掃描逐行 grep 看不到的跨行輸出敘述，以及完全不經輸出動詞的輸出（例如 heredoc 吐出的 JSON）。只分析與回報，不會自行改寫。 |

## Agents

安裝後以命名空間出現在 `@` 選單：`@claude-min-plugin:developer`、`@claude-min-plugin:reviewer`。
兩者都在 frontmatter 以 `skills: coding-guidelines` 於啟動時把**完整**準則載入自己的
context，所以它們是真的照那十條做事，而不是只拿到 session 注入的那份摘要。

| Agent | 定位 |
|---|---|
| `claude-min-plugin:developer` | 實作端。動手前先把任務翻成可驗證的成功條件，讀過周邊程式碼再依既有風格改，只寫滿足條件的最小改動，最後真的把測試／建置跑過才算完成 — 沒跑過就明講沒跑過。回報一定列出動過的每個檔案，你才找得到那份 diff。歧義、更簡單的替代做法、碰到 auth／授權／持久化／機密的改動、新增的相依、被改掉的契約與其下游呼叫者，都會主動攤開而不是默默吞掉。範圍外順手看到的問題只回報、不順手修。 |
| `claude-min-plugin:reviewer` | 審查端，**唯讀**。預設審未提交的改動，也接受指定分支、commit 範圍或路徑；沒指定而工作區是乾淨的，就退回去審 `HEAD` 並明講自己退回了，不會把剛提交的 commit 混充成進行中的工作。依序看四件事：**有沒有做到它該做的事**（一個完美實作了錯需求的改動是代價最高的問題，所以排第一；沒拿到需求時會明講，不會從 diff 反推一個需求再拿它評 diff）、**正確性**（null 與邊界、被吞掉的錯誤路徑、off-by-one、race、未驗證就進到查詢或 shell 的輸入、誤入版控的機密）、**測試擋不擋得住**（測試存在不等於有效 — 判準是實作壞掉時它會不會真的失敗）、**紀律**（對照那十條準則，找的是 diff 上的痕跡：即使是「開工前」的規則，被跳過時往往仍留下痕跡，例如改了行為卻沒帶任何驗證）。它不採信自己沒查過的說法，也不會停下來問你 — 答不了的問題會當成一條 finding 寫進報告，不中斷審查。 |

### 幾個刻意的取捨

**developer 不會自己 commit，也不會動你的 index。** 做完就停，改動原封不動留在工作目錄
給你看 — 不 stage、不 stash、不 checkout/reset，因為那些會移走或藏起你還沒看過的東西，
而樹裡的改動未必全是它剛做的。由你決定要不要用 `/claude-min-plugin:commit` 記錄下來。
這跟外掛預設開啟的 **Confirm before git commit** 是同一個立場：commit 是你的決定，
不是收尾動作。

**reviewer 的唯讀有兩層，強度不一樣。** `tools: Read, Grep, Glob, Bash` 這個 allowlist
拿掉了 Edit 與 Write — 這層是工具層的保證。但 Bash 本身有寫入能力（重導向、`sed -i`、
`git checkout`），擋住它的只有 agent 內文的明文禁止，那是約束不是保證。實務上這樣夠用，
但別把它當沙箱。它會描述該怎麼修，不替你修 — 審查結論與修改分開，你才有否決的機會。

**findings 要先確認過才寫出來。** 每一條都要求先開檔案、追呼叫端、讀過被指控的函式定義；
確認不了的就丟掉或標成未確認，不會當成事實陳述。分級只有三層 — Blocking（照這樣不能出：
做錯了事、弄壞行為、掉資料或開了資安缺口）、Should fix（現在能動，但以後有人要付代價：
冷路徑上的真缺陷、改了行為卻沒有東西擋得住它的回歸、會累積的準則違反）、Consider（見仁
見智，提一次就好），每條都標到 `file:line`，並且要給出觸發它的具體輸入或狀態，而不是
「這裡可能會是 null」。沒發現就直說沒發現。

**兩者不互相串接。** developer 做完不會自動送審，什麼時候叫哪一個由你決定 — 一個小改動
不必付一次完整審查的成本。代價是需求不會自己傳過去：叫 reviewer 的時候把「這個改動本來
要做到什麼」一併給它，那是它的第一順位檢查，沒拿到就只能空著那一項。

**`model` 兩者都是 `inherit`**，跟隨你主對話的模型，換模型時不必改檔。

> 注意：`claude plugin validate` 完全不檢查 `agents/` — 連缺 `name`、`description` 的
> agent 檔案都會回報 *Validation passed*。要確認 agent 真的載入得了，只能實際載入：
> `claude --plugin-dir . -p "List the exact agent_type names available to your Agent tool, one per line, nothing else. Do not call any tools."`

## 語言分界

判斷一段文字用什麼語言，只看**誰讀它**，不看檔案類型：

| 語言 | 適用範圍 |
|---|---|
| 繁體中文 | 程式碼註解與 docstring、`README.md`、`references/` 下的理由文件 — 只有本 repo 維護者會讀到的文字。 |
| 英文（且純 ASCII） | 所有 runtime 輸出（stdout、stderr、丟出的例外）、`SKILL.md`、`agents/<name>.md`、`CLAUDE.md`、各種 manifest、hook 注入模型的字串、commit message — 會離開 repo 或被機器讀取的文字。 |

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
這一行。

那次提問也是整個流程唯一會停下來的地方，所以它一併充當煞車：第三個選項「先看 diff」
不回答 trailer，而是印出 `git diff --staged` 與原本要用的完整訊息，然後不建立那個 commit。

煞車只擋一個 commit，不是整次呼叫。拆分的前提本來就是各組獨立到足以各自帶自己的
trailer，所以擋掉其中一個，對其他組沒有影響。被擋下的那組會從 index 取消 stage，一方面
免得被下一個 commit 一起吃進去，另一方面讓收尾時的 `git status` 剛好只列出你還沒看過的
東西：

| 情況 | 結果 |
|---|---|
| 沒有拆分，選「先看 diff」 | 不建立 commit。index 維持不動 — 這種情況是用 `git add -A` stage 的，可能掃進了你自己先 stage 好的東西，不該替你取消。 |
| 拆成三個，在第 2 個喊停 | 第 1 個維持已建立，第 3 個依它自己的答案照常建立。第 2 組取消 stage，留在工作目錄。 |
| 拆成三個，在第 2 個喊停，而第 3 組用到第 2 組新加的東西 | 第 1 個維持已建立；第 2、3 組一起擋下，都留在工作目錄，並明講是哪幾組、為什麼連帶擋。 |
| 拆成三個，在最後一個喊停 | 前兩個維持已建立，第 3 組取消 stage 留在工作目錄。 |
| 拆成三個，三個都喊停 | 一個 commit 都沒有，三組全部取消 stage 留在工作目錄。 |
| 呼叫時就帶了編號（`/claude-min-plugin:commit BUG-1234`） | 不會有這道提問，也就沒有這個煞車。煞車要解決的是「skill 自己發動、你還沒看過 diff」；帶編號代表這次是你主動發起的，不需要再攔一次。 |
| headless／自動化，問不了 | 同樣沒有煞車。直接 commit、不帶 `Refs:`，並說明沒有記錄編號。 |

第三列那個例外關乎正確性而非整潔：若後面某組用到了被擋下那組新加的東西，單獨 commit 它
會留下建不起來的樹。已經建立的 commit 絕不會被 amend 或 reset。看完想繼續，再叫一次這個
skill 就好 — 它會從工作目錄剩下的改動重新開始，重新產生訊息、也重新問一次編號。

`commit-msg` hook 同樣不檢查它：那支 hook 會進到每一個安裝此外掛的 repo，而
issue 編號規則是各團隊自家的慣例，不該強加於所有人。編號打錯了，沒有任何東西會攔下來。

這個 skill 會直接把 `skills/commit/hooks/commit-msg` 以 git `commit-msg` hook 的形式
（透過 `core.hooksPath`）裝進你的 repo，不另行詢問。該 hook 會擋下沒有 `Fixes:`
trailer 的 `fix` commit，並在出現 `Co-Authored-By: Claude` 卻缺少 `AI-Contribution`
時發出警告。它絕不動不屬於本慣例的 `commit-msg` hook；屬於自己的那份則會持續維持最新，
透過檔案標頭中的 `hook-version` 標記就地升級過舊的安裝。

`.githooks/` 刻意不納入版控（進了版控的第二份副本會自由地跟正本漂移），代價是此後
`git status` 會永遠多一行 `?? .githooks/`。所以**第一次安裝時**會問你要不要順手把它寫進
`.gitignore`，三個選項，建議第一個：

| 選項 | 說明 |
|---|---|
| `.githooks/commit-msg`（建議） | 只忽略這個外掛建立的那一個檔案。 |
| `.githooks/` | 忽略整個目錄。但 `core.hooksPath` 已經把整個 repo 指向那裡，之後團隊若在其中加一支共用 hook，會被無聲吞掉。 |
| 不動 `.gitignore` | 保留那行 untracked 訊息。 |

只在第一次安裝時問，重新啟用、版本升級與健康的 repo 都不會問；已經被忽略的話也不會問。
寫進去的那一行**不會**被帶進這次的 commit —— 它屬於 repo 管線而非你要記錄的改動，會留在
未 stage 的狀態讓你另外處理。

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
