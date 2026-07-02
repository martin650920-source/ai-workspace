---
name: context-loader
description: >
  兩層 context 載入器（全域 → 專案）。
  在 session 開始時自動觸發（由 adapters bootstrap），
  或 user 說「load context」、「載入 context」時觸發。
---

# Context Loader v3

## Step 1：解析 Base Path

| 環境 | Base Path |
|---|---|
| Windows (PowerShell) | `$env:USERPROFILE\.ai-workspace` |
| WSL / Linux / SSH | `~/.ai-workspace` |

若路徑不存在，停止並回報：
```
`~/.ai-workspace` not found — 請先執行 setup script。
```

## Step 2：載入全域層（必載）

讀取：
1. `<BASE>/rules/global.md` — 個人偏好、AI 行為準則、衝突優先權規則

## Step 2.5：Skill Drift 偵測

比對 `<BASE>/skills/global/` 與 `~/.claude/skills/`，找出有 skill 目錄但**缺少對應 symlink** 的項目。

**Windows（PowerShell）：**
```powershell
$base      = "$env:USERPROFILE\.ai-workspace"
$skillsDir = "$env:USERPROFILE\.claude\skills"
$missing   = Get-ChildItem "$base\skills\global" -Directory |
             Where-Object { -not (Test-Path "$skillsDir\$($_.Name)") }
$missing | ForEach-Object { $_.Name }
```

**WSL / SSH（bash）：**
```bash
base=~/.ai-workspace
for d in "$base/skills/global"/*/; do
  name=$(basename "$d")
  [ ! -e ~/.claude/skills/"$name" ] && echo "$name"
done
```

**若有缺漏 skill：**
```
發現 N 個尚未連結的 skill：<name1>, <name2>
要現在建立 symlink 嗎？[Y/n]
```

若 Y，依環境建立 symlink：

Windows：
```powershell
foreach ($s in $missing) {
    New-Item -ItemType SymbolicLink `
      -Path "$skillsDir\$($s.Name)" -Target "$base\skills\global\$($s.Name)"
}
```

WSL / SSH：
```bash
for name in $missing_names; do
    ln -sf "$base/skills/global/$name" ~/.claude/skills/"$name"
done
```

若無缺漏 → 靜默跳過，不輸出任何訊息。

## Step 3：自動偵測專案

掃描 cwd 的特徵檔案：

| 特徵                                         | 專案             |
| ------------------------------------------- | -------------- |
| `CMakeLists.txt` + `include/mt_unf_*.h`     | `nagra-tntsat` |
| `robot/` + `*.robot`                        | `nagra-tntsat` |
| `project.yml`（Ceedling）                     | `nagra-tntsat` |
| `Android.bp` 或路徑含 `aosp`/`android`/`1319D`  | `android-aosp` |
| LINUX DDK                                   | Sym6_SGT       |
|                                              |                |

若偵測到 → 確認：
```
偵測到專案：nagra-tntsat，載入？[Y/n]
```

若未偵測到 → 列出 `<BASE>/projects/` 的 `.md` 檔（排除 `_template.md`）讓 user 選，或輸入 0 跳過。

## Step 4：載入專案層

若有選定專案 `<name>`，依序讀取（存在才讀，不存在靜默跳過）：
1. `<BASE>/projects/<name>.md` — 專案事實（`/init` 產生的 CLAUDE.md 本體）
2. `<BASE>/rules/projects/<name>/general.md` — 專案全域規則
3. `<BASE>/rules/projects/<name>/<topic>.md` — path-scoped 規則（若當前操作路徑符合 frontmatter `paths:`）
4. `<BASE>/mem/projects/<name>.md` — 該專案的累積筆記

## Step 5：cwd CLAUDE.md 偵測

檢查 `<cwd>/CLAUDE.md` 是否存在：

- 若**不存在** → 提示：
  ```
  此目錄尚未建立 CLAUDE.md，要現在建立嗎？[Y/n]
  ```
  若 Y → 觸發 `/init-project-md` skill。

- 若存在但**不是 symlink**（真實檔案）→ 靜默略過（使用者自行管理）。

- 若已是 symlink → 靜默略過。

## Step 6：確認並待命

輸出摘要：
```
## Session Context Loaded
- Global : rules/global.md ✓
- Project: projects/<name>.md ✓  |  rules: [有/無]  |  mem: [有/無]
Ready. What are we working on today?
```
