# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 這個目錄是什麼

`D:\GOOGLE_DRIVE_SYNC` 是 Google Drive 同步根目錄，主要內容：

| 子目錄 | 用途 |
|---|---|
| `ai-workspace/` | AI 個人作業系統（本機透過 symlink 掛載到 `~/.ai-workspace`） |
| `knowledge/` | Obsidian 知識庫（wiki 條目、wiki-inbox） |
| `daily_note/` | 每日筆記（YYYY-MM-DD.md）與每週摘要 |
| `工作/` | 工作相關筆記 |
| `私人/` | 私人筆記 |
| `AI_參考資料/` | 舊版 AI 參考資料（已遷移至 ai-workspace，保留備查） |

## Obsidian Vault 結構

Obsidian vault 根目錄為 `D:\GOOGLE_DRIVE_SYNC\`，結構如下：

```
D:\GOOGLE_DRIVE_SYNC\
├── knowledge/
│   ├── wiki/             # wiki 條目（每週五由 routine 合成）
│   └── wiki-inbox/       # Web Clipper 匯入的 clips，依主題建子資料夾
├── daily_note/
│   ├── weekly-summary/   # 每週摘要（每週五由 routine 產生）
│   └── YYYY-MM-DD.md     # 每日筆記
├── 工作/
├── 私人/
└── ai-workspace/         # AI OS（不屬於 Obsidian 筆記內容）
```

**週五 12:00 自動 Routine（Wiki Synthesize - Friday Noon）：**
- 任務 A：掃描 `knowledge/wiki-inbox/` 近 7 天新 clips → 合成 `knowledge/wiki/` wiki 條目
- 任務 B：讀取 `daily_note/` 近 7 天日誌 → 產生 `daily_note/weekly-summary/YYYY-WNN.md`

## ai-workspace 架構

```
ai-workspace/
├── rules/          # 規則層：global.md（全域）+ projects/<name>/（專案全域/path-scoped）
├── mem/            # 累積筆記：global.md（全域）+ projects/<name>.md（專案）
├── projects/       # 專案事實層（CLAUDE.md 本體，自動偵測或手動選擇）
├── mcp/            # MCP 架構設定 / 憑證範本 / 各主機安裝清單
├── adapters/       # AI 工具轉換層（claude / gemini / codex）
│   └── claude/
│       └── CLAUDE.md          # 全域 bootstrap 指令
├── skills/
│   └── global/     # Claude Code skills（context-loader 等）
├── config/         # statusline.sh 等工具設定
└── setup/          # 安裝腳本（Windows / WSL / SSH）+ sync.sh
```

**載入優先序：** 專案層 > 全域層

## Symlink 架構

安裝腳本（`setup/setup-windows.ps1`）建立的 symlink：

| 目標（本機） | 來源（Google Drive） |
|---|---|
| `~/.ai-workspace` | `D:\GOOGLE_DRIVE_SYNC\ai-workspace` |
| `~/.claude/CLAUDE.md` | `ai-workspace/adapters/claude/CLAUDE.md` |
| `~/.claude/skills/<name>` | `ai-workspace/skills/global/<name>`（per-skill） |
| `~/.claude/statusline.sh` | `ai-workspace/config/statusline.sh` |
| `~/.gemini/GEMINI.md` | `ai-workspace/adapters/gemini/GEMINI.md` |
| `~/.codex/AGENTS.md` | `ai-workspace/adapters/codex/AGENTS.md` |

**Project-level CLAUDE.md 慣例：**
本體存放於 `projects/<project>.md`，各 project 目錄以 symlink 指向本體。

## 安裝 / 重裝

```powershell
# 需要系統管理員 或 Developer Mode 已開啟
pwsh -ExecutionPolicy Bypass -File setup\setup-windows.ps1
```

## 新增工作專案

```powershell
# 1. 複製範本
Copy-Item projects\_template.md projects\新專案名.md

# 2. 填入內容後，加入 .gitignore（避免公司 IP 外流）
Add-Content .gitignore "/projects/新專案名.md"

# 3. 在 skills/global/context-loader/SKILL.md 的 Step 3 偵測表加入 Marker Files
```

## 公私分離（Git 管理規則）

| 進 Git（公開骨架） | 不進 Git（本機 + Drive 同步） |
|---|---|
| `adapters/`, `skills/`, `setup/` | `rules/global.local.md`（若有） |
| `rules/global.md` | `projects/<工作專案>.md` |
| `projects/_template.md` | `mcp/.env`（實際憑證，放 `~/.mcp.env`） |

## Claude Code 設定（`~/.claude/settings.json`）

### SessionStart Hook

每次 session 開始時自動執行：
1. **SSH 環境**：`git pull ~/.ai-workspace`（同步最新 ai-workspace）
2. **所有環境**：注入指令讓 Claude 執行 `/context-loader`

Hook 存放於各機器的 `~/.claude/settings.json`，**不進 Git**（屬於本機設定）。

### SSH 主機初始設定

SSH 主機完成 `setup-ssh.sh` 後，貼上以下指令設定 hook：

```bash
python3 << 'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
hook_cmd = """if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then git -C "$HOME/.ai-workspace" pull --quiet 2>/dev/null || true; fi; echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"IMPORTANT: 立即執行 /context-loader skill 以載入 ai-workspace context（rules、專案層）。請在回應使用者之前先完成此步驟。"}}'"""

os.makedirs(os.path.expanduser("~/.claude"), exist_ok=True)

settings = {}
if os.path.exists(settings_path):
    with open(settings_path, encoding="utf-8") as f:
        settings = json.load(f)

settings.setdefault("hooks", {})["SessionStart"] = [
    {"hooks": [{"type": "command", "command": hook_cmd, "shell": "bash"}]}
]

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print("Done:", settings_path)
PYEOF
```

## 日常同步

```bash
bash setup/sync.sh          # git pull + symlink 校驗
bash setup/sync.sh push     # git pull（防覆蓋）→ commit → push
```
