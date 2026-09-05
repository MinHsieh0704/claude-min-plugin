# workflow 設計註記

這份文件只放「為什麼」。規則本身在 `../SKILL.md`，這裡不重述規則，也不被任何 agent 預載 ——
要改規則的人才讀它。

---

## pass 編號為什麼要同時看 pass log 與 `Raised:`

兩個來源單獨用都會錯，而且錯的方向相反：

- **到最後才決定**：會把自己剛 append 的 findings 也算進去，每一趟都多一號。
- **只讀 pass log**：被中斷的審查依規定留下 findings 但不寫 pass entry。那些 findings 寫著
  `pass 3`，log 卻停在 `Pass 2`，下一位審查者也會拿 `3` —— 兩趟審查共用一個號碼，一條 finding
  會被歸給它從未參與的那一趟。

---

## review budget 為什麼不看 severity，以及 `FAIL` 為什麼不豁免

**不看 severity**：一條「讀某趟審查剛好提出什麼 severity」的規則，會讓 `high` 任務在第一趟就
結束、跟 `low` 一樣快；也會在一個需求根本沒達成的 `FAIL` 上結束任務。

**`FAIL` 不豁免**：0.9.0-rc.1 曾經寫成「FAIL 不消耗預算」，目的是讓 `low` 在失敗一次後還能有人
確認修復。那個豁免同時碰壞三件事 —— 預算與 pass 編號脫鉤成為兩個計數器、「最後一趟」在 verdict
出來前無法判定、以及 `low` 之下持續 FAIL 的迴圈沒有上界。現在改成每趟都消耗一趟，而每一級的
預算都比它想要的新鮮審查數多一趟；多出來的那一趟就是付確認用的。

---

## test apparatus 的 severity 為什麼要設上限

「這個測試會不會在程式壞掉時仍然通過？」對任何有限的測試套件，答案都是 yes。所以它不能拿來決定
審查何時結束 —— 否則永遠有下一條可提。

但一個完全不執行斷言的套件不是這個問題，那是一個不存在的檢查。上限不是放行它的許可。

---

## `trim` 為什麼不刪除條目

刪除是最直覺的設計，而它同時錯三次，三種都是靜默失敗：

- `review` 必須能用原本的 id 重開一條 `FIXED` 的 finding。
- pass log 是唯一記錄「某個任務曾經通過」的地方（`TASKS.md` 刻意沒有 status 欄位）。
- id 由現存最大值分配，刪掉最大的幾筆會讓下一筆拿到一個已經有意義的號碼。

長度是可讀性問題，條目是記錄本身。

---

## REVIEW.md 的 provenance 為什麼是欄位而不是章節

0.9.0-rc.1 曾用三個 `## Findings - <來源>` 章節來編碼「誰發現的」。那個結構逼出四條衍生規則：
`Found:` 與 `Raised:` 兩個欄位名、章節之間不可依 id 排序的例外、建檔時要寫齊所有空章節、以及
id 跨章節唯一的聲明。

更關鍵的是它與同一批加入的中斷韌性規則相衝突：reviewer 被要求「確認一條就 append 一條」，但
`## Findings - manual review` 上方還有兩個章節與 pass log，所以第二趟之後的「append」在結構上
其實是 mid-file insert —— 正好是最容易寫到一半被切斷的操作，也正好是同一份檔案禁止的改寫。

改成 `Source:` 欄位後，四條衍生規則一起消失，每個角色的寫入都回到真正的檔尾 append。這不是新
發明的形狀 —— 姊妹 ledger `TASK-CHANGES.md` 一直就是用 `Source:` 欄位。

---

## `TASK_UPDATE_REQUIRED` 為什麼也涵蓋「規格說了、而且說錯」

原本三個 verdict 之間有一格沒有出口：

- `FAIL` —— 規格對、程式錯。
- `TASK_UPDATE_REQUIRED` —— 規格**沒說**，所以判不了。
- 沒有人管的那一格 —— 規格**說了**，程式忠實達成了它，而它瞄的不是 `Goal` 說的那個東西。

2026-09-05 一次實跑撞上第三格：審查端診斷出某條 Requirement 把比對範圍指向了錯的對象，實測出
因此漏掉的靜默失效，然後回了 `PASS` 與 `TASKS.md update needed: no` —— 因為當時唯一能把工作
送回協調者的 verdict 要求規格是「沉默」的。訊號被壓成一條 `Consider`，掛在一個讀起來就是
「這件事做完了」的 pass entry 底下。

`Consider` 接不住它，是因為收件人不同：finding 交給下一個實作者，而只有規格的擁有者能動規格。
降級成 finding 等於把它寄給一個無權處理的人。

**判準為什麼是「指名 `Goal` 或 `Constraints` 的某一行」**：這一格通往協調者，而協調者是唯一
不能再往下委派的人。沒有判準的話，任何「我會用別的做法」都能停下所有人的工作。要求指名一行
同時做到兩件事 —— 它可查證，而且它把「規格達不到自己宣告的結果」跟「審查端有別的偏好」分開；
後者本來就是 finding 的用途。

順帶記一件事實：`agents/reviewer.md` 一直寫的是 "When the spec is what is wrong"，也就是較寬的
讀法，但它同時要求審查端以 `workflow` skill 的定義為準。兩份檔案不一致時，被指定為權威的那一
份贏了，而它當時是窄的。

**為什麼光改定義沒有用。** 這一節的第一版只動了 `TASK_UPDATE_REQUIRED` 的定義，隨即被一次
`/code-review` 打回，兩個理由都成立：

- `PASS` 的定義原封不動，而它同樣涵蓋這個情況 —— 「requirement is met and nothing blocking was
  found」在這裡字面上就是真的，而且它排在前面先被讀到。**開了第二道門卻沒關掉第一道，等於
  沒開。**
- `agents/reviewer.md` 全篇沒有出現 `Goal`（實測 grep 為 0）。它 step 3 的判準只來自 `T<n>` 的
  Requirement，所以一個永遠不載入 `Goal` 的流程，不可能觀察到「達成了 Requirement 卻達不到
  `Goal`」。定義改了、會觸發它的那一步沒有加，規則就到不了任何人手上。

第二點還有一層諷刺：那個 bullet 自己就寫著「A flawless change that answers the wrong question is
the most expensive finding there is」—— 它描述的正是這個失效，但它的做法只拿 Requirement 比對，
所以看不到自己那句話。

**因此這一格要成立需要三樣東西同時在場**：`PASS` 的排除子句、`TASK_UPDATE_REQUIRED` 的第二個
分支、以及 reviewer 流程裡真的去讀 `Goal` 的那一步。少任何一樣，剩下兩樣都是裝飾 —— 而裝飾比
沒改更糟，因為它看起來已經修好了。
