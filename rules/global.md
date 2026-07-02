# Global Rule — [Your Name] 的全域規則

所有專案都適用的行為準則。載入優先序：**專案層 > 全域層**（見「衝突解決原則」）。

## 工作環境

- OS: [e.g. Windows 10 + WSL2 / macOS / Linux]
- Shell: [bash / zsh]
- 版本控制: [Git + GitHub / GitLab，commit message 語言]
- 編輯器: [VSCode / Neovim / ...]
- Build: [Make / CMake / ...]
- 測試: [pytest / Ceedling / Jest / ...]

## 偏好與慣例

- 命名: [snake_case / camelCase / ...]
- [其他習慣]

## AI 回答偏好

- 回答語言: [繁體中文 / English / ...]
- 回答風格: [條列式 / 詳細說明 / ...]
- 其他: [先給推薦方案 / 省略客套語 / ...]

## 衝突解決原則

當不同層級的設定衝突時，遵循此優先序：

**專案層 > 全域層**

| 層級 | 來源 | 說明 |
|---|---|---|
| 全域層 | `rules/global.md` | 所有 session 都套用的基底偏好 |
| 專案層（全域） | `rules/projects/<專案名>/general.md` | 特定專案全域適用的行為準則 |
| 專案層（path-scoped） | `rules/projects/<專案名>/<主題名>.md` | 特定專案內，只在特定檔案類型/路徑生效 |
| Project Context（CLAUDE.md） | `projects/<專案名>.md` | 專案事實，`/init` 產生 |

### 範例

- global 說「繁體中文」，project 沒有特別指定 → 套用「繁體中文」
- global 說「條列式回答」，project 說「commit message 用英文」→ commit message 用英文，其他回答仍條列式繁體中文

## 每日筆記操作慣例

當 user 說「加到我每日筆記」：
- 找到 `D:\GOOGLE_DRIVE_SYNC\daily_note\<今日日期>.md`，直接寫入
- 待辦/TODO → 加到 `# Day planner` 區塊末尾，格式：`- [ ] <內容>`
- 若 `# Day planner` 不存在，先在檔案末尾建立該區塊再加入
- 若今日檔案不存在，建立新檔並加入 `# Day planner` 區塊

## Rule 建立規則

當使用者要求新增規則時：
- 判斷層級（依序判斷）：
  1. 跨所有專案都適用 → Global rule（`rules/global.md`）
  2. 特定專案全域適用 → Project rule（`rules/projects/<專案>/general.md`）
  3. 特定專案內，只在特定檔案類型/路徑生效 → Project + Path-scoped rule，依規則主題命名檔案；若已有相近主題檔案則追加，否則新建
- 建立完成後，告知使用者實際寫入的檔案路徑與層級判斷結果，方便使用者確認分類是否正確

## 記憶寫入規則

當使用者要求「記下來」「幫我記住」時：
- 判斷內容類別：
  - 規範類（以後都要這樣做）→ 提示寫入 rules，不寫進 mem
  - 專案架構/事實類（該由 `/init` 掃描的東西）→ 提示改跑 `/init`，不手動寫
  - 經驗/進度/踩雷紀錄類 → 寫入 mem
- 判斷範圍：
  - 明確指名專案或含專案特有細節 → `mem/projects/<專案>.md`
  - 泛用、跨專案都適用 → `mem/global.md`
  - 無法判斷 → 預設先寫入對應專案的 mem（較保守，不污染其他專案），並告知使用者存放位置
- 寫入格式：`## YYYY-MM-DD` 標題 + 條列，追加在檔案最後，不覆寫舊內容

## Skill 建立規則

當使用者要求建立新 skill 時：
- 判斷範圍：
  - 觸發語意獨特、不會跟其他專案情境混淆 → 建在 `skills/global/<skill名>/`
  - 觸發語意容易與其他專案混淆、且各專案做法不同 → 建在 `skills/projects/<專案名>/<skill名>/`
  - 不確定 → 詢問使用者是否為此專案專屬
- 一律先在 ai-workspace 建立本體（`SKILL.md` + 相關檔案），再於當前專案的 `.claude/skills/` 下建立 symlink 指向本體，不可直接把內容寫進專案目錄變成孤立實體檔
- 若使用者描述該任務「各專案/情境做法不同」（即使當下只提到一個專案）→ 直接判斷為 project-scoped，不建 global 版本，並提醒使用者：其他專案若需要類似能力，需另外分別建立各自版本
- 建立完成後提醒使用者：內容已建立在 ai-workspace，需執行 `sync.sh push` 才會同步到其他主機
