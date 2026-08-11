# AI / 人類程式碼歸屬方案

適用範圍：所有導入此 commit skill 的 repo（Node.js/MongoDB/Express、Python/FastAPI 兩個 stack 通用）。

---

## 1. 規範

### 1.1 Commit trailer 格式

每個 commit message 在 subject 之後、空一行，依情況附加以下 trailer：

```
<subject>

Co-Authored-By: Claude <model> <noreply@anthropic.com>
AI-Contribution: assisted | generated
Fixes: <short-sha>            (可重複出現，見 1.1.1)
Fixes: unknown
Fixes-Candidates: <sha1>,<sha2>,...   (只能伴隨 Fixes: unknown 出現)
Refs: <內部單號>              (可重複出現，固定放在最後，見 1.1.3)
```

| Trailer | 何時必填 | 說明 |
|---|---|---|
| `Co-Authored-By: Claude ...` | 這次 commit 內容有 Claude 產出 | 沿用既有慣例，GitHub/GitLab UI 原生支援顯示 |
| `AI-Contribution` | 只要有 `Co-Authored-By: Claude` 就必填 | `assisted`＝AI 給建議、人類主導寫法或改動很小；`generated`＝AI 端到端寫出這次 diff 的主要邏輯，人類審查後才 commit |
| `Fixes: <sha>` | subject type 為 `fix` 時（skill 只用這個字，見 1.1.2），且能唯一確認起源 commit | 標明這次修復對應到哪個 commit 引入的問題；同一個 commit 若真的同時修復多個不同起源的問題，可重複這行（見 1.1.1） |
| `Fixes: unknown` | 同上，但無法唯一確認起源 commit | 誠實標記「不確定」，不准省略、不准瞎猜 |
| `Fixes-Candidates: <sha1>,<sha2>` | 只能伴隨 `Fixes: unknown` 一起出現 | 把 `git blame` 找到的多個候選都列出來，供人工事後判斷，見 1.1.1 |
| `Refs: <內部單號>` | 呼叫 commit skill 時有明講內部單號 | 對應公司內部 bug/suggestion 追蹤單號；可重複多行，一行一個，原樣照抄。**只吃呼叫時給的參數**——不從分支名或 diff 推斷、也不反問，沒給就不寫這行，見 1.1.3 |

### 1.1.1 為何用「多個候選都列出來」而非強迫立即指定

這是實作中修正過的一版設計，原因說明如下：

- **不做成單一 `Fixes:` 塞多個 sha**：`git blame` 給出多個候選時，通常代表兩種截然不同的情況——(a) 這次 fix 其實同時修了兩個各自獨立、各自可確認的起源（真的是多因），或 (b) 同一段程式碼有好幾個候選、但無法判斷哪一個才是真正起因（單一起因、但不確定是哪個）。這兩種情況語意不同，混在一起會讓統計腳本無法正確判讀，因此：
  - 情況 (a)：`Fixes:` 這個 key **重複出現**，每一行都是一個獨立確認的因果關係（跟 `Co-authored-by` 可以多行出現是同樣的 git trailer 慣例）。
  - 情況 (b)：主線寫 `Fixes: unknown`（維持「無法確認」的誠實聲明），額外用 `Fixes-Candidates:` 把候選列出來，當作**人工事後排查用的提示**，不進入自動化統計的「已確認」欄位。
- **為何不在 commit 當下要求人員立即指定**：commit skill 的既有原則是不中斷、不詢問確認即可執行；若每次候選不唯一就跳出來要人選一個，一來打斷自動化流程，二來**commit 當下的人（可能正忙著修一個緊急 bug）不見得比事後做 code review 或定期回溯分析的人更清楚正確答案**——被追著在時間壓力下隨手選一個，做出來的是「看起來確定、其實是用猜的」的錯誤資料，比誠實寫 `unknown` 更危險。把候選留著讓後續有更多上下文的人來判斷，是更穩妥的做法。
- **已知簡化**：目前判斷粒度停在「整個 commit」層級，不做到每個 hunk 各自判斷。也就是說，只要這次 commit 裡有任何一個 hunk 是模糊的，整個 commit 就落入 `Fixes: unknown` + `Fixes-Candidates`，即使其他 hunk 各自有明確候選。這是刻意的簡化，避免過度複雜的逐 hunk 資料結構；如果之後發現這個粒度不夠用，可以再細化。

### 1.1.2 動詞/類型清單：skill 用單一標準詞，hook 用較寬的偵測清單

- **skill 產生 commit message 時，type 是封閉清單**（見 1.3 的完整列表：`feat`/`fix`/`refactor`/`perf`/`chore`/`docs`/`style`/`test`/`build`/`ci`），不可用同義詞替代。修復類一律只用 `fix` 這一個詞——單一標準詞才能讓 `git log --grep`／統計腳本／commitlint 這類工具查詢穩定，不需要在多個同義詞之間做對應。
- **hook 的「這是不是 fix commit」偵測邏輯刻意比 skill 的詞彙更寬，且同時支援新舊兩種格式**：
  - 先嘗試解析 Conventional Commits 的 `type:`／`type(scope):`／`type!:` 前綴；
  - 解析不到冒號格式（例如轉換前的舊 commit）就退回舊版「取第一個字」的判斷方式；
  - 不論哪種格式取到的詞，只要屬於 `fix`/`fixes`/`fixed`/`correct`/`corrects`/`corrected`/`resolve`/`resolves`/`resolved`/`patch`/`patches`/`patched`/`hotfix`/`bugfix` 就視為 fix commit。
  - 原因是 hook 管的是**所有**進到 repo 的 commit，不只是 skill 產生的——人工手動打的 commit 不受 skill 詞彙限制，可能用任何同義詞或舊格式，hook 必須盡量涵蓋兩者。
- **仍是已知限制**：這仍然是一份封閉詞表，人工手打 commit 若用清單外的字（例如 `repair`、`address`、`workaround`），`Fixes:` 要求就會被跳過，不會被 hook 攔到。這是關鍵字比對法本質上的侷限，不是遺漏——目前選擇接受這個殘餘風險，而非做語意分析。

`AI-Contribution` 的判斷基準是**當下實際發生的協作過程**，不是單純看 diff 行數多寡——一個 3 行的關鍵演算法修正若是 AI 端到端寫的，仍算 `generated`；一個 50 行的樣板程式碼若是人類抄範本、AI 只是順手排版，仍算 `assisted`。

### 1.1.3 內部單號為何用獨立的 `Refs:`，且不納入 hook 強制

- **不沿用 `Fixes:`**：`Fixes:` 的語意是「引入這個 bug 的那個 commit 的 sha」，hook 與統計腳本都以 `^Fixes: (unknown|[0-9a-f]{7,40})$` 解析它。把追蹤單號塞進去會同時破壞 hook 驗證與 2.2 的修復鏈路交叉表。這兩者本來就是不同軸線——「哪個 commit 弄壞的」與「這次工作對應哪張單」——所以並存於同一個 commit 是正常狀態，不是重複。
- **不用 `Closes:` / `Resolves:`**：GitHub、GitLab 都把這幾個字當作 issue 關閉關鍵字處理，用它們會產生非預期的自動關單。`Refs:` 沒有這層平台語意，純粹是引用。
- **放 trailer 而非塞進 subject**：1.3 的「subject 永遠單行」是硬規則，hook 的 type 抽取與統計腳本的正則全都建立在這個前提上。單號改放 subject 會連帶要改 hook 正則與整套測試；放 trailer 則兩者都不必動。
- **強制力刻意停在 skill 層**：`commit-msg` hook 會隨這個 plugin 裝進**每一個**採用它的 repo，而單號格式是單一公司的內部慣例。把它寫進共用 hook 等於把公司規則強加給所有使用者，因此 hook 完全不檢查這個 trailer。代價要說清楚：**單號打錯不會有任何東西擋下來**，所以規範是照抄、不要憑印象重打。
- **不由 skill 推斷、也不反問**：分支名或 diff 內容看起來像單號並不代表就是這次要記的單號，猜錯等於在歷史裡寫下一筆錯誤且無人查核的關聯——比沒有這行更糟。而反問又會打破 commit skill 不中斷的既有原則（同 1.1.1 的理由）。因此只有呼叫當下明講的單號才會被寫入。

### 1.2 同一功能後續更新時，如何判定

這點沒有新增 trailer，而是延伸既有規則，原因說明如下：

- **`AI-Contribution` 永遠只看「這次 commit 自己的 diff」，不繼承、不累加**。功能原本是 AI `generated`，後續某次更新是人類自己寫的，這次更新就標 `----`（無 AI trailer）；下次又是 AI 協助，就標 `assisted` 或 `generated`。不去計算「這個功能整體有幾成是 AI 寫的」這種累積分數——那需要逐行追蹤程式碼存活狀況（哪些行還留著、哪些行被誰的哪次改動取代），本質上就是先前已經排除的行級別歸屬問題，複雜度與失準率都不划算。
- **「更新／擴充功能」不等於「修復」，不需要 `Fixes:`**。`Fixes:` 語意上專指「這裡曾經是壞的，這次修好了」；單純加新能力、擴充邏輯，即使改到的是 AI 寫的程式碼，也不是修復，維持現有 hook 以 type 判斷（見 1.1.2 的偵測清單）即可，不需要額外規則。
- **灰色地帶：掛著「feat」外皮的修復**。如果一次「feat」其實是在修正先前（可能是 AI 寫的）設計缺陷，而不是單純擴充，應該讓 subject type 誠實反映（改用 `fix`），或至少手動加上 `Fixes:`。Hook 的 type 偵測是**最低要求**，不是上限——鼓勵在這類灰色地帶主動補標，而不是靠選字來規避 `Fixes:` 的要求。
- **想看功能隨時間的完整演進，不需要新 trailer**：`ai_attribution_stats.py --path <file-or-dir>` 直接用 `git log --follow` 把某個檔案/模組的所有 commit 按時間排出來，附上各自的 `AI-Contribution` 與 `Fixes` 標記，就能看到一個功能從 AI 主導、到人類更新、到後續修復的完整時間軸，不需要為此另外設計 lineage trailer。

### 1.3 Subject 格式細節

這節的決定原本是「動詞開頭、不加冒號」，後來重新以「業界慣例＋統計/工具需求」為準則檢討過，改為採用 **Conventional Commits 的 `type: description` 格式**：

- **格式**：`<type>: <description>`，小寫、單行，例如 `fix: correct server version comparison`、`feat: add product status report script`。暫不使用 scope（`feat(auth): ...`）——分組用 `Fixes:` 鏈路解決（見 1.1），scope 之後如果需要仍可相容加上。
- **為何改用 colon 格式**：
  - Conventional Commits 規範定義 commit message 應結構化為 `<type>[optional scope]: <description>`，footer 遵循類似 git trailer 的 `token:` 格式——commitlint、semantic-release、conventional-changelog 這套生態系都建立在這個格式上。
  - 這個 repo 既有的 `Co-Authored-By:`、`AI-Contribution:`、`Fixes:` trailer 本來就是 `token:` 語法，subject 若不用冒號，等於同一則訊息內兩套語法混用；改成 colon 格式後整條訊息語法一致。
  - Colon 是明確、無歧義的類型邊界，比純空白分詞更穩健——不需要為了防同義詞跟時態變化而維護一長串偵測清單。
- **類型詞彙也一併改成標準 Conventional Commits 類型**，不再用自訂的 `add`/`update`/`remove`：
  - `feat` — 新功能，或對既有行為的有意義強化（規範正式定義是「引入新功能」，但沒有獨立的 MINOR 級「強化」類型，實務上兩者都歸這裡）
  - `fix` — 修復（永遠只用這個字，理由同 1.1.2）
  - `refactor` — 不影響行為的內部重構
  - `perf` — 效能改善、無功能變化
  - `chore` — 其餘維護性變更（含大部分死碼刪除）
  - `docs` / `style` / `test` / `build` / `ci` — 依規範定義
- **`Fixes:` 觸發條件同步改為「type 是 `fix`」**（原本是「動詞是 fix」，語意相同，只是判斷位置從第一個字改成冒號前的類型）。
- **Subject 強制單行，不因內容複雜而改變**：這不只是風格偏好——hook 的類型解析、統計腳本的 trailer regex 都假設第一行是 subject、trailer 各自獨立成行。若一次改動複雜到一行寫不完，這是該拆成多個 commit 的訊號（見 1.4），不是把 subject 寫長或寫成多行的理由。維持不寫 prose body、不寫條列。

### 1.3.1 各類型定義、情境與範例

以下以 Node.js/Express/MongoDB、Python/FastAPI 這兩個 stack 為例，說明每個類型的定義、使用情境，以及跟相近類型的界線：

| Type | 定義 | 使用情境 | 範例 subject |
|---|---|---|---|
| `feat` | 新功能，或對既有行為有意義的強化（使用者/API 可見的行為變化） | 新增 API endpoint、新增一項可設定的行為、擴充既有功能的能力 | `feat: add FastAPI endpoint for report export`／`feat: support retry backoff in report-tracking worker` |
| `fix` | 修復缺陷（曾經是壞的，這次修好了） | 修正錯誤邏輯、修正例外處理、修正資安漏洞 | `fix: correct MongoDB connection pool retry logic`／`fix: patch path traversal in file upload handler` |
| `refactor` | 內部重構，行為完全不變 | 抽出共用函式、調整模組結構、改寫演算法但輸出相同 | `refactor: extract mongo retry logic into helper` |
| `perf` | 效能改善，功能不變 | 優化查詢、減少不必要的 I/O、改善記憶體用量 | `perf: reduce query latency in report aggregation pipeline` |
| `chore` | 不屬於以上的維護性變更，含大部分死碼刪除 | 升版相依套件、調整設定檔、清理不再使用的程式碼 | `chore: bump express to 4.19`／`chore: remove deprecated snapshot endpoint` |
| `docs` | 只改文件 | 更新 README、更新 CLAUDE.md、補 API 文件 | `docs: update CLAUDE.md with new trailer convention` |
| `style` | 純格式調整，無邏輯變化 | 跑 formatter（black、prettier）、修 linter 警告、調整縮排 | `style: apply black formatting to report_service.py` |
| `test` | 只改測試 | 新增單元測試、補邊界案例、修測試本身的 bug | `test: add unit tests for token expiry logic` |
| `build` | 建置系統或相依性清單本身的變更 | 改 `package.json`／`requirements.txt`、調整 Dockerfile、改打包設定 | `build: update requirements.txt for numpy 2.0` |
| `ci` | CI/CD pipeline 設定 | 改 GitHub Actions workflow、調整測試/部署流程 | `ci: add pytest step to GitHub Actions workflow` |

### 1.3.2 容易混淆的界線

- **`feat` vs `chore`**：是否有使用者／呼叫端可見的行為變化。有變化算 `feat`，純內部維護（升版、清理、調整設定）算 `chore`。
- **`refactor` vs `perf`**：兩者都可能改寫程式碼結構，差別在**意圖與可驗證的結果**——`refactor` 目的是結構更好、行為不變；`perf` 目的是變快／變省資源，即使程式碼看起來也像重構，只要主要動機與可衡量結果是效能，就算 `perf`。
- **`style` vs `refactor`**：`style` 必須是零邏輯變化（純格式、跑 formatter）；只要動到程式邏輯或結構，即使很小，就該算 `refactor` 而不是 `style`。
- **`chore` vs `build` vs `ci`**：`build` 限定在「建置/打包/相依性清單」本身（`package.json`、`requirements.txt`、Dockerfile）；`ci` 限定在 CI/CD pipeline 設定檔；其餘維護性變更才落到 `chore`，不要把三者混用。
- **刪除（原本的 `remove`）沒有獨立類型**：內部死碼刪除算 `chore`；若刪除的是使用者可見的功能本身（產品層級的移除），算 `feat`，且應在 body／footer 用 `BREAKING CHANGE:` 標明——但目前 skill 規則裡沒有body，若真的遇到這種情況需要額外討論是否要破例加 body，這點方案文件尚未涵蓋，留待實際遇到時再決定。

### 1.4 何時拆成多個 commit

- **判斷基準是 trailer 準不準，不是整潔度**。一個 commit 只能有一個 `AI-Contribution` 值、一組 `Fixes:` 連結；如果 diff 裡混了語意不同的變更（例如一部分是 `fix` 有自己的起源，另一部分是不相關的 `feat`/`chore`；或兩部分的 AI 參與程度明顯不同），硬塞成一個 commit 會讓其中至少一部分的 trailer 失真——這時要拆。
- **不問確認，直接拆**，拆完在 commit 輸出（見下一點）裡講清楚拆了幾個、為什麼拆——延續整套 skill「不中斷流程」的原則。
- **拆不乾淨就不硬拆**：如果同一段程式碼裡功能擴充跟 bug 修復根本纏在一起、無法用檔案或 hunk 切開，就退回單一 commit，挑主要性質下 subject 跟 trailer，不要硬拆出兩個各自都講不通的 commit。
- **不是所有不相關的變更都要拆**：如果兩個不相關的小改動誠實算下來 trailer 完全一樣（例如都是純人類、都不是 fix），拆不拆只是風格問題，不強制。

### 1.5 commit 完成後的輸出

用 `git log -1`（完整格式，不用 `--oneline`）顯示結果——`--oneline` 會把 `AI-Contribution`／`Fixes` 全部藏起來，等於讓整套 trailer 慣例白做。若這次觸發了 1.4 的拆分，逐一顯示每個 commit 的完整 `git log -1`。

### 1.6 強制機制

- **本地 `commit-msg` hook**：fix 類 commit 缺少 `Fixes:` 直接擋下（exit 1）；缺少 `AI-Contribution` 只警告不擋（判斷程度屬主觀認定，hook 無法驗證真偽，強制擋反而製造摩擦）。
- **安裝方式**（每個 repo 各自設定一次）：
  ```bash
  mkdir -p .githooks
  cp commit-msg .githooks/commit-msg
  chmod +x .githooks/commit-msg
  git config core.hooksPath \
    "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.githooks"
  ```
  **`core.hooksPath` 必須是絕對路徑，而且要錨定在 main checkout。** `.githooks/` 刻意不進版控（repo 裡多一份 hook 副本就會跟正本各自漂移），所以相對路徑會以「git 當下所在的工作樹」為基準解析——在 linked worktree 裡就是那個 worktree 自己的根目錄，那裡沒有這個目錄，git 於是**不執行任何 hook 也不報錯**。用 `--git-common-dir` 而非 `--show-toplevel` 是因為 `core.hooksPath` 存在共用的 config 裡：從 worktree 內用 `--show-toplevel` 算出的路徑，會把所有 worktree 連同 main checkout 一起釘死在「該 worktree 被刪除後就消失」的目錄上。剩下的暴露面是搬移或改名 repo，同樣會靜默失效——但那是罕見的一次性事件，不像相對路徑形式從 worktree 建立的第一刻就是壞的。
- **版本標記與自動升級**：hook 檔頭有 `# hook-version: <n>`，只在**強制行為**變動時才遞增（純註解修改不遞增）。commit skill 每次 commit 都會比對已安裝副本的版本，較舊就用套件內的正本覆寫；版本相同即使檔案有差異也不動它——那代表是本地有意的修改，不是過期。skill 也只用檔頭那句 `AI-attribution / fix-linkage conventions` 來認定「這是不是我們的 hook」，所以早於版本標記存在的舊副本仍會被認出來（視為 version 0），不會被誤判成別人的 hook 而不敢動。
- **既有規則維持不變**：不 `--no-verify`、不 amend 既有 commit、commit 後不自動 push——這些原則同時也讓 hook 的強制力不會被繞過或事後竄改。

### 1.7 skill 端配合

`commit` skill（本目錄上一層的 `../SKILL.md`）已更新，會在產生 commit message 時自動判斷並附上以上四種 trailer（`Refs:` 除外——那一種不判斷，只照抄呼叫時給的單號，見 1.1.3），並在遇到 hook 擋下時照規則重試而非繞過。

---

## 2. 統計方式

統計腳本 `ai_attribution_stats.py`（打包位置：本目錄上一層的 `../scripts/ai_attribution_stats.py`）提供兩層數據，**刻意不做行級別或百分比精確量化**（原因見第 3 節）：

### 2.1 整體歸屬統計

```bash
python3 ai_attribution_stats.py            # 整個分支
python3 ai_attribution_stats.py main..dev  # 指定範圍
```
輸出：總 commit 數、AI 參與（`Co-Authored-By`）佔比、`assisted` / `generated` 各自次數。

### 2.2 修復鏈路交叉表（回答「AI 主導的功能被誰修復幾次」）

以 `Fixes:` trailer 串連「這次修復」與「原始引入問題的 commit」，交叉比對兩者的 AI/人類歸屬，產出 2×2 表：

```
AI-led    -> AI-fixed
AI-led    -> human-fixed     ← 這一格直接回答你原本的問題
human-led -> AI-fixed
human-led -> human-fixed
Fixes: unknown（blame 判斷不出來的次數，單獨列出，不併入以上任何一格）
```

若一個 commit 真的同時修復多個不同起源（重複的 `Fixes:` 行），每個起源各自貢獻一筆計數，不算重複計算——因為那是真的修了 N 個不同問題。`Fixes: unknown` 的次數裡，額外統計「其中有幾筆有 `Fixes-Candidates` 記錄」，方便知道有多少筆是可以事後人工排查、多少筆是連候選都沒有。

### 2.3 為何用 `Fixes:` 鏈路而非用「功能 scope」分組

原本考慮過用 conventional-commit 的 `(scope)` 當分組鍵，但會強迫改變現有 subject 風格，且無法處理「一個 commit 對應多個 scope」的邊界情況。改用 `Fixes: <sha>` 直接指向具體 commit，天然形成一個可追溯的因果鏈，不需要額外定義「什麼算同一個功能」。

### 2.4 功能演進時間軸（非 fix 的更新也涵蓋在內）

```bash
python3 ai_attribution_stats.py --path src/auth/token.js
```
用 `git log --follow` 把某個檔案／模組的所有 commit 按時間列出，每行標示該次 commit 的 `AI-Contribution`（或 `----` 表示無 AI 參與）與 `Fixes` 連結。這是回答「這個功能後續更新時是誰做的」的方式，不需要另外設計 lineage trailer——見 1.2 節說明。

---

## 3. 可能問題

以下是目前這套方案**已知但尚未解決**的限制，如實列出：

1. **歷史 commit 不可見**：導入此慣例之前的 commit 沒有 trailer，統計腳本會直接跳過，不會誤算成「人類主導」，但也代表舊功能完全沒有數據可看。
2. **`git blame` 判斷本身有失準率**：學術研究顯示 SZZ 演算法（bug-introducing commit 追溯的基礎方法）在不同資料集上有約 25%–40% 的案例無法單靠 blame 正確追溯（ghost commit、跨檔案變更、格式化雜訊等原因）。這也是為何規範要求判斷不出來時**明寫 `unknown`**而非省略或瞎猜——把不確定性攤在檯面上，而不是藏進「已解決」的統計裡。
3. **`AI-Contribution` 是自陳（self-reported），無法被 hook 驗證**：如果協作過程中判斷失準或有意美化，統計數字會失真。這是設計上的取捨——比起自動判定的高失準率，自陳雖然主觀但至少誠實可控。
4. **原始 commit 計數仍可能重複**：`git revert` 預設會複製原 commit 訊息（含 trailer）；cherry-pick 到多分支會產生新 hash 但相同內容；squash merge 又會反過來把多個子 commit 合併成 1 個。**這些狀況只影響「2.1 整體歸屬統計」，不影響「2.2 修復鏈路交叉表」**——因為後者是以具體 commit 對之間的因果關係為單位，不是靠計數。
5. **hook 只在本地生效**：`core.hooksPath` 是每個 clone 各自的本機設定，不隨 repo 散佈（同一個 clone 底下的所有 worktree 則共用同一份，見 1.6），新 clone 的人若沒有手動執行安裝步驟，hook 不會生效；用 `--no-verify` 也能繞過（規範上禁止，但技術上擋不住）。

---

## 4. 其他未提到但重要的事項

1. **Squash merge 會打斷整條鏈路**：如果團隊在 GitHub/GitLab 上用「Squash and merge」把一個 PR 的多個 commit 壓成一個，個別 commit 的 `Fixes:`／`AI-Contribution` trailer 可能被合併訊息覆蓋或遺失。**這是目前方案沒有涵蓋到的缺口**——建議明確決定 PR 合併策略：若採用 squash，需要額外規則要求在 squash 後的最終 commit message 手動保留關鍵 trailer；若想完全避免這個問題，改用「Rebase and merge」或一般 merge commit，保留每個原始 commit 逐一進主分支。
2. **本地 hook 沒有伺服器端對應**：目前的強制力只到「本機 commit 當下」。若要防止有人略過安裝步驟或用 `--no-verify` 繞過，需要在 CI（例如 PR 檢查的 GitHub Action）加一層伺服器端驗證，重新解析 PR 內所有 commit 訊息確認 trailer 存在。這是本地 hook 天生做不到的事，屬於下一步可以考慮補強的地方，目前方案尚未涵蓋。
3. **這份數據不該被拿來當作個人績效指標**：`human-fixed AI-led` 這一格數字高，代表的是「AI 產出需要人工把關」這個正常的審查流程，不是某個工程師的負面紀錄；使用這份統計時建議只用於流程改善（例如發現某個模組 AI 產出經常需要修正，就該檢討 prompt 或 code review 深度），不要用於個人考核，避免造成團隊對誠實標記 `AI-Contribution` 產生抵觸心理而開始隱瞞。
4. **是否回溯（backfill）舊 commit**：目前方案只對「導入後」的 commit 生效。若未來想補齊舊資料，可以額外跑一次性的 SZZ-based 回溯分析，但輸出必須明確標示「近似值、非精確」，不要跟前瞻式的 hook 強制資料混在同一張報表裡比較，避免誤導判讀。
5. **monorepo / repo 拆分風險**：若之後把某個模組拆成獨立 repo 或搬進 submodule，`Fixes: <sha>` 指向的 commit 會因為歷史被切斷而失效——這在拆分當下需要額外處理（例如在拆分 commit 上註記原始 repo 與對照表），目前方案未涵蓋此情境。
