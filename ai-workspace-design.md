# ai-workspace 架構設計文件

> 前身為 `ai_refrence`，已確定改名為 `ai-workspace`。
> 本文件記錄多平台共用 AI 設定（mem / skill / rules / mcp / agent / project context）重構討論的結論，逐點增補，不會推翻已確認章節。

---

## 專案命名

- **新名稱：`ai-workspace`**
- 捨棄 `ai_refrence`（拼字易誤打，且語意侷限於「參考資料」，範圍不足以涵蓋 rules/skills/mcp/agent）
- 也捨棄過渡方案 `ai-context`（同樣範圍過窄，暗示只裝知識文件）

### 改名 Checklist（動工時執行）

- [ ] GitHub repo rename：`ai_refrence` → `ai-workspace`
- [ ] 各主機本地 clone 資料夾名稱同步改名：`~/ai-refrence` → `~/ai-workspace`
- [ ] 各主機確認 `git remote -v` 指向新 URL（不依賴 GitHub 自動轉址）
- [ ] 重建所有 symlink（改名後舊 symlink 全部斷鍊）
- [ ] Search & replace 所有腳本/文件內硬編的舊路徑字串（setup script、`CLAUDE.local.md` import 路徑、README 等）
- [ ] 檢查 Codex CLI（`AGENTS.md`）等工具設定內是否有引用到舊路徑

---

## 第一點：多主機同步機制

### 環境範圍

- 筆電（出差用）：Windows + WSL2
- SSH 遠端 Linux 主機
- 桌機（日常工作用）
- 全部都是**同一人（自己）的 user**，不涉及與他人共用同一組帳號/環境

### 核心設計：Git repo 當唯一事實來源 + Symlink

- `ai-workspace` 為唯一事實來源（single source of truth），只維護這一份
- 各主機 `git clone` 一份實體到固定路徑（如 `~/ai-workspace`）
- 各工具實際讀取路徑（`~/.claude/`、`~/.codex/`、`~/.gemini/` 等）以 **symlink** 指向 clone 內對應檔案
- **捨棄**方案：sync script 複製一份（雖較安全但需手動跑、且已改回 symlink，只維護 git 上一份）

### 新主機 Bootstrap 流程（一次性）

1. `git clone` `ai-workspace` 到固定路徑
2. 呼叫 `sync.sh`（見下）建立本機所有 symlink

> Bootstrap 與日常維護分成兩支邏輯：bootstrap 前提是「本機還沒有 clone」，`sync.sh` 前提是「已有 clone」，兩者職責不互相牽扯。

### 日常更新流程：單一腳本 `sync.sh`

一支腳本整合以下功能，**手動觸發**（不做自動 pull，避免久了忘記維護反而增加複雜度）：

1. `git pull` 拉取最新內容
2. 掃描 symlink 校驗：
   - 斷鍊（target 已被刪除/搬移）→ 提示
   - repo 有新檔案但本機未建 symlink → 提示或自動補建
   - 本機有孤兒 symlink（來源已從 repo 刪除）→ 提示清除
3. 印出本次同步結果 / 對應 commit hash，方便確認各主機版本一致

> 使用模式：不追求一次設計到位，用一陣子發現缺什麼、想到什麼，隨時手動調整 repo 結構 + 補腳本邏輯即可。

---

## 第一點延伸：專案層級 `CLAUDE.md` 的處理

### 問題背景

- `CLAUDE.md` 由 Claude Code `/init` 掃描專案程式碼產生，內容天生因專案而異
- 但同一個專案（如 SYM6-TNTSAT）會存在於多台自己的主機上，希望這份 `CLAUDE.md` **保持一致、只維護一份**

### 確認方案：`ai-workspace` 存實體，反向 symlink 回專案目錄

```
ai-workspace/projects/sym6-tntsat.md     ← 實體，進 ai-workspace git 版控
~/projects/sym6-tntsat/CLAUDE.md         ← 各主機 symlink 指向上面那份
```

- 因所有主機皆為自己專屬環境（含 SSH 遠端，受 user 權限隔離），不涉及與同事共用 repo 的 symlink 斷鍊風險，此方案可直接採用
- 新專案要納入此機制時：`ai-workspace/projects/` 建立實體檔 → 各主機專案目錄下建立對應 symlink（規劃為 `sync.sh` 子指令，如 `sync.sh link-project <專案路徑> <repo內md檔名>`）

### 操作紀律（重要，需牢記）

- **只在一台「主編輯機」上執行 `/init`**（建議固定用桌機）
  - 原因：`/init` 是整份重新掃描覆寫，非增量合併；若在多台主機分別重跑，會互相覆蓋、蓋掉先前累積的內容
- 其他主機純粹讀取；若要手動小改，改完需 `git push`

### 與 `CLAUDE.local.md` 的分工（共用規則掛載機制）

- `CLAUDE.md`：專案獨有內容（架構、指令、慣例），依上述方案由 `ai-workspace` 管理
- `CLAUDE.local.md`：僅一行 `@import`，指向 `ai-workspace` 內的共用 rules（如 `@~/ai-workspace/rules/claude-global.md`）
  - 不受 `/init` 影響（`/init` 只改寫 `CLAUDE.md`），寫一次永久有效
  - 同樣以 `ai-workspace` 存實體、symlink 進各專案根目錄的機制處理，與 rules/skills 同一套邏輯，不需另立心法

---

## 第二點：Rules 的分工與存放方式

### 規則分層架構（含 path-scoped 第三層）

| 層級 | 內容性質 | 存放位置 |
|---|---:|---|
| Global rule | 所有專案都適用的行為準則（如 commit message 語言、註解語言） | `ai-workspace/rules/global.md` |
| Project rule（全域） | 特定專案全域適用的行為準則 | `ai-workspace/rules/projects/<專案名>/general.md` |
| **Project rule（path-scoped）** | 特定專案內，只在特定檔案類型/路徑生效的規則 | `ai-workspace/rules/projects/<專案名>/<主題名>.md`，含 `paths:` frontmatter |
| CLAUDE.md（已於第一點確認） | 專案的事實/架構，`/init` 產生 | `ai-workspace/projects/<專案名>.md` |

### Path-scoped rule 機制（Claude Code 原生功能）

- `.claude/rules/` 資料夾下的 md 檔，用 YAML frontmatter 的 `paths:` 欄位限定觸發範圍：**只有當 Claude 實際讀/改符合 glob pattern 的檔案時，這份規則才載入進 context**，平常不佔 token
- 與 skill 的 project-scoped 限定維度不同：skill 是按「專案目錄」限定，rule 的 `paths:` 是按「檔案類型/子路徑」限定，兩者可並存

```markdown
---
paths:
  - "drivers/**/*.c"
  - "drivers/**/*.h"
---
# SYM6 Driver 層規範
- 所有 GPIO 操作需搭配 interrupt unmask 檢查
```

- Symlink 方式與 `CLAUDE.local.md` 的 `@import` 模式不同：`paths:` 機制是 Claude Code 原生掃描 `.claude/rules/` 目錄運作，需將 `ai-workspace` 內對應規則檔（或整個資料夾）symlink 進該專案的 `.claude/rules/`，而非用 import 語法引入

### 檔案切分原則：依「規則主題」分檔，不是依「路徑」分檔

- 每個規則檔案對應**一個主題**，各自獨立的 `paths:`，不要把不相關主題的規則塞進同一檔案（即使路徑有重疊）：

```
ai-workspace/rules/projects/sym6-tntsat/
├── general.md          ← project 全域規則
├── driver-layer.md      ← 只管 drivers/**/*.c
├── test-convention.md   ← 只管 tests/**/*
```

### AI 代建 Rule 時的判斷規則（併入 `rules/global.md`）

```markdown
## Rule 建立規則
當使用者要求新增規則時：
- 判斷層級（依序判斷）：
  1. 跨所有專案都適用 → Global rule（ai-workspace/rules/global.md）
  2. 特定專案全域適用 → Project rule（ai-workspace/rules/projects/<專案>/general.md）
  3. 特定專案內，只在特定檔案類型/路徑生效 → Project + Path-scoped rule，依規則主題命名檔案；若已有相近主題檔案則追加，否則新建
- 建立完成後，告知使用者實際寫入的檔案路徑與層級判斷結果，方便使用者確認分類是否正確
```

### 內容只寫一份，各工具入口檔只放 import

- 規則內容**不依工具分開維護**（捨棄舊架構的 `claude-global.md` / `gemini-global.md` / `codex-global.md` 各自一份的做法），避免同樣規則要改多次
- 各工具入口檔（`CLAUDE.local.md`、`AGENTS.md` 等，皆為 symlink）只放 import 這份共用內容：

```markdown
@~/ai-workspace/rules/global.md
@~/ai-workspace/rules/projects/sym6-tntsat.md   ← 若該專案有 project rule
```

### 現階段先用單一檔案，不預先拆分主題

- `rules/global.md` 先不拆成 `coding-style.md`、`commit-message.md` 等多檔，內容量大到難維護時再拆（漸進式擴充原則）

### Project rule 的新增／修改／刪除操作

- **修改**：直接編輯 `ai-workspace/rules/projects/<專案名>.md`，`git pull` 後各主機同步生效
- **新增**：
  1. `ai-workspace/rules/projects/` 新建該專案 md
  2. 該專案 `CLAUDE.local.md` 補上對應 import 行（規劃併入 `sync.sh link-project` 子指令，跟建立 `CLAUDE.md` symlink 一併處理）
- **刪除**：
  1. 刪除 `ai-workspace/rules/projects/<專案名>.md`
  2. **需手動**同步移除對應 `CLAUDE.local.md` 裡的那行 import（否則 import 不存在的檔案會報錯）；`sync.sh` 的斷鍊校驗功能應能偵測並提示此情況

### `/init` 觸發主機不固定 → `sync.sh` 需具備 push 能力

- 原假設「固定一台主編輯機跑 `/init`」不切實際，`/init` 實際觸發主機不固定
- `sync.sh` 需新增 `push` 子指令：

```
sync.sh          # pull + symlink 校驗（原有功能）
sync.sh push     # git add + commit + push，且內建「push 前先 pull」保護
```

- **`sync.sh push` 執行順序**：
  1. `cd ai-workspace`
  2. 先 `git pull`（避免多主機互相覆蓋，若遠端有其他主機已推送的新內容，先同步）
  3. 若 pull 出現衝突 → 停下提示手動處理，不自動合併
  4. 無衝突 → `git add -A && git commit && git push`
- 此設計取代原本「session 結束自動 push 的 hook」構想：問題本質是「push 前未確認遠端最新狀態」，而非「忘記 push」，`push` 內建 `pull` 已直接堵住風險來源（避免靜默覆蓋），不需額外做 hook 自動化機制

### ⚠️ 需要手工維護的部分（提醒）

- **跑完 `/init` 之後，要記得手動執行 `sync.sh push`**——目前不做自動化（不做 session-end hook、不做自動 push），純靠人工判斷：
  - 平時：定期手動跑一次 `sync.sh push` 做例行同步即可
  - 若自認這次改動重要：**在 A、B 兩台主機都立即各自手動跑一次 `sync.sh push`**，確保盡快同步
- **新增/刪除 project rule 時，`CLAUDE.local.md` 裡的 import 行需手動同步增減**（新增可望併入 `sync.sh link-project` 半自動化，刪除目前仍全靠手動移除，`sync.sh` 只能事後校驗提示斷鍊，無法自動修正）
- 忘記跑 `sync.sh push` 的風險已由「push 內建 pull」機制降低為「內容晚一點同步」，非「內容遺失」，可接受，但仍需你自行留意執行時機

---

## 第三點：Mem（累積筆記）

### 定位

- 特指「手動維護的累積筆記」（非 Claude.ai 內建 memory 功能，那是平台自動處理、與本文件的同步機制無關）
- 性質介於 rules 與 CLAUDE.md 之間：
  - 與 rules 不同：更新頻率高、內容是「發生過什麼／學到什麼」而非「該怎麼做」
  - 與 CLAUDE.md 不同：CLAUDE.md 是 `/init` 掃描出的專案事實，mem 是持續累積的經驗/進度記錄

### 存放方式：比照 rules 機制（單一檔案 + symlink + `sync.sh` 同步）

```
ai-workspace/mem/global.md              ← 跨專案通用的累積筆記（工具心得、環境踩雷）
ai-workspace/mem/projects/<專案名>.md   ← 特定專案的累積筆記（除錯進度、專案特有踩雷）
```

掛載方式（`CLAUDE.local.md` 追加 import）：
```markdown
@~/ai-workspace/rules/global.md
@~/ai-workspace/rules/projects/sym6-tntsat.md
@~/ai-workspace/mem/global.md
@~/ai-workspace/mem/projects/sym6-tntsat.md
```

### 格式建議：時間序條列，新增在檔案末尾，不刪舊內容

```markdown
## 2026-07-02
- WSL2 掛載新硬碟後 systemd 要手動 enable，不然 reboot 會跑掉
- SYM6 driver 這次卡在 GPIO interrupt 沒 unmask
```

- 檔案變長後的整理/歸檔（如搬去 `mem/archive/2026-h1.md`）不預先設規則，累積到你自己覺得不好找時再手動處理

### AI 代寫時的歸屬判斷規則

當你要求「幫我記一下」時，AI 需自行判斷寫入位置，判斷邏輯規劃寫入 **`ai-workspace/rules/global.md`**（因為這是「AI 該怎麼做」的行為準則，與其他 rules 性質一致，不另立新檔案）：

```markdown
## 記憶寫入規則
當使用者要求「記下來」「幫我記住」時：
- 判斷內容類別：
  - 規範類（以後都要這樣做）→ 提示寫入 rules，不寫進 mem
  - 專案架構/事實類（該由 /init 掃描的東西）→ 提示改跑 /init，不手動寫
  - 經驗/進度/踩雷紀錄類 → 寫入 mem
- 判斷範圍：
  - 明確指名專案或含專案特有細節 → mem/projects/<專案>.md
  - 泛用、跨專案都適用 → mem/global.md
  - 無法判斷 → 預設先寫入對應專案的 mem（較保守，不污染其他專案），並告知使用者存放位置
- 寫入格式：`## YYYY-MM-DD` 標題 + 條列，追加在檔案最後，不覆寫舊內容
```

---

## 第四點：Skill（僅考慮 Claude Code）

### 本質

- Skill 是「可執行的能力模組」，非單純知識文件——含 `SKILL.md`（description + 觸發規則 + 步驟），可能附帶輔助腳本，通常是**整個資料夾**而非單一檔案
- Lazy-load 機制：用到才佔 context，這點在 global skill 已天生滿足，「省 context」不是 project-scoped 的理由

### 存放與 Symlink：資料夾層級

```
ai-workspace/skills/global/<skill名>/                  ← 全域 skill 本體
ai-workspace/skills/projects/<專案名>/<skill名>/        ← 專案專屬 skill 本體
```

Symlink 對應：
```
~/.claude/skills/<skill名>/                             → ai-workspace/skills/global/<skill名>/
~/projects/<專案名>/.claude/skills/<skill名>/            → ai-workspace/skills/projects/<專案名>/<skill名>/
```

> 與 rules/mem 的差異：symlink 對象是**整個資料夾**，`sync.sh` 校驗邏輯需能處理資料夾層級的 symlink，不只是單一檔案。

### Global vs Project-scoped 判斷準則

| Skill 類型 | 放置位置 | 範例 |
|---|---|---|
| 觸發語意獨特，不會跟其他情境混淆 | Global | `dual-discuss`（多模型辯論流程） |
| 觸發語意容易在多專案間混淆，且**各專案做法不同** | 各專案目錄下，各自一份（可同名） | `build-bsp`（各案子建置方式完全不同） |
| 觸發語意容易混淆，但**各專案做法相同/相似** | 保持 Global，把「哪裡不同」抽成參數，由 skill 讀取當下專案的 `CLAUDE.md`/設定值決定行為 | （視實際案例再細化） |

> Project-scoped 的核心價值是**觸發準確度**（用路徑範圍физически隔離，避免跨專案誤觸發），不是效能考量。同名 skill 存在於不同專案目錄下，因 Claude Code 只在當前專案目錄載入，不會互相干擾。

### 新增用例：新專案 `new-chip-project` 建立專屬 build skill

1. 在 `ai-workspace` 建本體：
   ```bash
   mkdir -p ~/ai-workspace/skills/projects/new-chip-project/build-bsp
   # 撰寫 SKILL.md（含 description/trigger 與步驟）、放入輔助腳本
   ```
2. 在該專案目錄建 symlink 指向本體：
   ```bash
   mkdir -p ~/projects/new-chip-project/.claude/skills
   ln -s ~/ai-workspace/skills/projects/new-chip-project/build-bsp \
         ~/projects/new-chip-project/.claude/skills/build-bsp
   ```
3. `cd ~/ai-workspace && git add -A && git commit && git push`（同步給其他主機）
4. 其他主機：`sync.sh`（pull）→ 補建對應 symlink
   - 步驟 2、4 的 symlink 建立規劃併入 `sync.sh link-skill <專案名> <skill名>` 子指令，指令化後免手動輸入多行

### AI 代為建立 Skill 時的判斷規則

比照 mem 的做法，寫入 **`ai-workspace/rules/global.md`**：

```markdown
## Skill 建立規則
當使用者要求建立新 skill 時：
- 判斷範圍：
  - 觸發語意獨特、不會跟其他專案情境混淆 → 建在 ai-workspace/skills/global/<skill名>/
  - 觸發語意容易與其他專案混淆、且各專案做法不同 → 建在 ai-workspace/skills/projects/<專案名>/<skill名>/
  - 不確定 → 詢問使用者是否為此專案專屬
- 一律先在 ai-workspace 建立本體（SKILL.md + 相關檔案），再於當前專案的 .claude/skills/ 下建立 symlink 指向本體，不可直接把內容寫進專案目錄變成孤立實體檔
- 建立完成後提醒使用者：內容已建立在 ai-workspace，需執行 sync.sh push 才會同步到其他主機
```

---

## 第五點：MCP（`ai-workspace` 為 public repo，前提已確認）

### 核心原則：架構、憑證、安裝狀態三者分離管理

| 內容 | 存放位置 | 是否進 `ai-workspace` 版控 | 同步方式 |
|---|---|---|---|
| 架構設定（引用環境變數，不含實際值） | `ai-workspace/mcp/settings.json`（或 Claude Code 實際讀取的設定檔名，動工時查證確認） | 是 | 比照 rules/skill：symlink + `sync.sh` |
| 實際憑證（API key/token） | `~/.mcp.env`（使用者家目錄，**不放在 `ai-workspace` 目錄內**） | 否 | 完全不同步，各主機手動填值 |
| 憑證欄位範本（只列 key 名稱，不含值） | `ai-workspace/mcp/.env.example` | 是 | symlink 同步，作為新主機填值依據 |
| 各主機安裝狀態清單 | `ai-workspace/mcp/manifest.md` | 是 | **自動化例外**（見下） |

### 憑證處理細節

- `.env` 放在使用者家目錄（`~/.mcp.env`）而非 `ai-workspace` 目錄內，從路徑上直接排除被 git 掃描到的可能，比僅依賴 `.gitignore` 更保險（雙重防護）
- 新主機設定流程：複製 `.env.example` → `~/.mcp.env`，手動填入實際 key 值（相同帳號，沿用同一組 key）
- Shell 需 `source ~/.mcp.env` 才能讓 `${ASANA_API_KEY}` 這類引用生效；這一行本身不含敏感資料，可由 `sync.sh`/bootstrap 自動寫入 `.bashrc`/`.zshrc`，不需手動
- **唯一無法自動化、必須手動的步驟**：把實際 key 值填進 `~/.mcp.env`

### 各主機安裝狀態：`manifest.md`（自動偵測 + 自動 push 例外）

- 不強制每台主機都安裝相同的 MCP 清單（如 SSH 遠端可能不需要 Google Drive MCP），改用「清單提醒」取代「內容強制同步」

`manifest.md` 格式範例：
```markdown
# MCP Manifest
## asana
- 安裝指令：claude mcp add asana ...
- 已安裝主機：桌機, 筆電-WSL

## google-drive
- 安裝指令：claude mcp add gdrive ...
- 已安裝主機：桌機
```

`sync.sh` 針對 manifest.md 的邏輯：
1. 執行本機 MCP 清單查詢指令（如 `claude mcp list`，實際指令名稱動工時查證）
2. 比對 `manifest.md` 內容：
   - 本機已裝、manifest 未列 → 自動補上本機名稱
   - manifest 列了本機、但本機實際未裝 → 印出提醒，**不自動刪除**（避免誤判暫時性狀態）
3. **manifest.md 若有變更 → 自動 `git add && commit && push`**（不同於 rules/mem/skill/CLAUDE.md 的手動 push 原則）

### 為何 manifest.md 允許自動 push（例外理由）

- 內容是可驗證的客觀事實（本機裝了什麼），不存在需要人工審查對錯的空間，不同於 rules/mem/CLAUDE.md 那種需要人工把關內容品質的檔案
- 此檔案存在目的就是讓其他主機**即時**看到最新安裝狀態，若還要等手動 push 才生效，會經常性失準，違背設計初衷
- 例外範圍僅限 `manifest.md`，其餘檔案（rules/mem/skill/CLAUDE.md）仍維持手動 `sync.sh push`

---

## 第六點：Agent

### 定位：Skill 的特化型態，不獨立分類

- Agent（如多模型辯論流程、code review 流程）本質是「處理範圍更全面的 skill」——可能多輪來回、呼叫其他工具/模型、含決策分支，但這是**內部複雜度**的差異，不是分類層級的差異
- 存放位置、symlink 機制、global vs project-scoped 判斷準則、AI 代建規則，**完全沿用 skill 那一套**，不另立 `ai-workspace/agents/` 目錄，避免製造「該放 skill 資料夾還是 agent 資料夾」的新困擾
- 唯一區分方式：`SKILL.md` frontmatter 加 `type: agent` 標籤，僅供瀏覽辨識，不影響 Claude Code 實際載入機制

```yaml
---
name: dual-discuss
type: agent   # 一般 skill 可省略，或標 type: simple
description: ...
---
```

### 用例：`code-review` agent——概念相同、但各專案做法不同

- 這類「同一件事、各專案實作邏輯不同」的 agent（跟 build-bsp 同類型判斷），應**規劃時就直接判斷為 project-scoped**，不建 global 版本，不用等衝突發生才回頭覆蓋

```
ai-workspace/skills/projects/sym6-tntsat/code-review/     ← SYM6 專案的 review 邏輯
ai-workspace/skills/projects/android-aosp/code-review/    ← AOSP 專案的 review 邏輯
```

- 同名 `code-review`，各自客製內容，只在對應專案目錄建 symlink，不設 global 版本

### Global skill/agent 的「不需要」情境，不用主動排除

- 若某專案單純用不到某個 global agent（但邏輯本身沒有衝突），**不需要任何排除機制**——skill 天生是「有觸發語意才載入」，不喊就不會觸發，不佔 context
- 只有當某專案需要**不同行為**（而非單純不需要）時，才需要在該專案目錄下放同名的覆蓋版本，Claude Code 載入邏輯以當前專案目錄優先

### AI 代建規則補充（併入 rules/global.md 的「Skill 建立規則」）

```markdown
- 若使用者描述該任務「各專案/情境做法不同」（即使當下只提到一個專案）→ 直接判斷為 project-scoped，不建 global 版本，並提醒使用者：其他專案若需要類似能力，需另外分別建立各自版本
```

---

## 第二點總結：mem / skill / rules / mcp / agent 分工（全部子問題已收斂）

| 類別 | 本質 | 存放核心機制 | Push 機制 |
|---|---|---|---|
| Rules | 靜態行為準則（該怎麼做） | 單一 md 檔，symlink | 手動 |
| Project Context（CLAUDE.md） | 專案事實，`/init` 產生 | 單一 md 檔，反向 symlink 回專案目錄 | 手動，只在異動所在主機執行後即時 push |
| Mem | 動態累積筆記（發生過什麼/學到什麼） | 單一 md 檔，時間序條列，symlink | 手動 |
| Skill / Agent | 可執行能力模組，global 或 project-scoped | 資料夾，symlink | 手動 |
| MCP 架構設定 | 引用環境變數，不含敏感值 | 單一設定檔，symlink | 手動 |
| MCP 憑證 | 實際 API key | `~/.mcp.env`，不進版控 | 不同步，各主機手動填值 |
| MCP 安裝清單（manifest.md） | 客觀安裝狀態記錄 | 單一 md 檔 | **自動**（例外） |

所有需要「AI 自動判斷歸屬/自動建立」的場景（mem 寫入、skill/agent 建立），統一規劃寫入 `ai-workspace/rules/global.md`，作為 AI 行為準則的一部分。

---

## 待討論（尚未開始的部分）

（目前已無，第一、二點主要子題已全數討論完畢，後續若有新主題再增補）
