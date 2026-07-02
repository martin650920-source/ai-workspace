# ai-workspace

個人 AI 作業系統 — 讓 Claude Code、Gemini CLI、Codex 共用同一份規則、記憶與知識。

> 前身為 `second-brain`（再更早是 `ai_refrence`）。詳細重構決策紀錄見 [`ai-workspace-design.md`](./ai-workspace-design.md)。

## 架構

```
ai-workspace/
├── rules/                   # 規則層（該怎麼做）
│   ├── global.md            # 全域規則（永遠載入）
│   └── projects/            # 專案規則
│       └── <name>/
│           ├── general.md   # 專案全域規則
│           └── <topic>.md   # path-scoped 規則（frontmatter paths:）
├── mem/                      # 累積筆記層（發生過什麼/學到什麼）
│   ├── global.md
│   └── projects/<name>.md
├── projects/                 # 專案事實層（CLAUDE.md 本體，/init 產生，自動偵測）
│   └── _template.md
├── mcp/
│   ├── settings.json         # MCP 架構設定（引用環境變數，不含真實憑證）
│   ├── .env.example          # 憑證欄位範本
│   └── manifest.md           # 各主機 MCP 安裝狀態清單
├── adapters/                 # AI 工具轉換層（盡量薄，只放 bootstrap 指令）
│   ├── claude/CLAUDE.md
│   ├── gemini/GEMINI.md
│   └── codex/AGENTS.md
├── skills/
│   └── global/
│       ├── context-loader/   # 兩層載入邏輯（含 skill drift 偵測）
│       ├── init-project-md/  # 為任意專案目錄建立 CLAUDE.md + symlink
│       └── wiki-synthesize/  # 週報/wiki 合成
├── config/
└── setup/
    ├── sync.sh                # 日常同步：pull / push / link-project / link-skill
    ├── setup-windows.ps1      # 首次 bootstrap（Windows）
    ├── setup-wsl.sh           # 首次 bootstrap（WSL）
    └── setup-ssh.sh           # 首次 bootstrap（SSH 遠端）
```

**載入優先序：** 專案層 > 全域層

## 安裝（首次 bootstrap，只做一次）

### WSL
```bash
bash setup/setup-wsl.sh
```

### SSH Remote
```bash
bash setup/setup-ssh.sh git@github.com:yourname/ai-workspace.git
```

### Windows
```powershell
.\setup\setup-windows.ps1
```

## 日常同步

已完成 bootstrap 後，日常更新一律用 `sync.sh`（WSL / SSH）：

```bash
bash setup/sync.sh          # git pull + symlink 校驗（斷鍊/新增未連結/孤兒 symlink）
bash setup/sync.sh push     # 先 pull 防覆蓋，再 commit + push
```

新增專案或 skill 的連結：

```bash
bash setup/sync.sh link-project <專案路徑> <專案名>
bash setup/sync.sh link-skill <專案名> <skill名>
```

## 日常使用

```
開啟 Claude Code
    ↓
context-loader 自動執行
    ├─ Skill Drift 偵測：有新 skill 未連結？→ 提示建立 symlink
    ├─ 自動偵測專案（或手動選擇）
    └─ cwd CLAUDE.md 偵測：尚未建立？→ 提示執行 /init-project-md
    ↓
Ready
```

**第一次進入新專案目錄時：**
context-loader 會偵測到 `CLAUDE.md` 不存在，提示執行 `/init-project-md`。
該 skill 會分析 codebase、將本體存入 `projects/<name>.md`，並在專案目錄建立 symlink。

## 新增工作專案

1. 複製 `projects/_template.md` → `projects/<專案名>.md`
2. 填入專案架構、指令、術語
3. 在 `skills/global/context-loader/SKILL.md` 的偵測表加入 Marker Files
4. **在 `.gitignore` 加入 `/projects/<專案名>.md`**（避免公司 IP 外流）

## 公私分離

| 進 Git（公開骨架） | 不進 Git（本機 + Drive 同步 / 家目錄） |
|---|---|
| `adapters/`, `skills/`, `setup/` | `rules/global.local.md`（若日後拆分真實個人值） |
| `rules/global.md`, `rules/projects/` | `projects/<工作專案>.md` |
| `mcp/settings.json`, `mcp/.env.example` | `~/.mcp.env`（真實憑證，放使用者家目錄，不在此 repo 內） |
| `projects/_template.md` | |

## TODO（已知未解決、留給未來的自己）

- `rules/global.md` 的真實個人值（姓名、公司環境細節等）要怎麼跟公開骨架分層，目前尚未設計（可能是 `rules/global.local.md` + gitignore，仿照這裡沒有的舊 `core/profile.md` 模式）
- `mem/` 底下的檔案是否要進 git 版控，還是要比照工作專案排除，待累積內容後再決定
- `sync.sh` 目前只有 bash 版本（WSL/SSH），Windows 尚無對應的 `sync.ps1`
- 情境層（work/life + Secure Mode MCP 白名單）已在這次重構整套移除，日後有需要再重新設計

## 從舊版 `second-brain` 遷移

若要把正式在用的 `second-brain` clone 換成這份新架構，需要：
1. GitHub repo 改名 `second-brain` → `ai-workspace`
2. 各主機（含這台機器正式在用的 `~/.second-brain` 指向的 clone）重新 clone 或重新命名資料夾
3. 各主機重新執行對應的 `setup-*` 腳本重建 symlink
4. 確認 `git remote -v` 指向新 URL

這些步驟牽涉共用/遠端狀態與多台主機，不由這份 sandbox 重構自動完成，需自行安排時間執行。詳見 [`ai-workspace-design.md`](./ai-workspace-design.md) 開頭的改名 Checklist。
