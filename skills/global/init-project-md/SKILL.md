---
name: init-project-md
description: >
  為當前專案目錄建立 CLAUDE.md：本體存入
  ai-workspace/projects/<project>.md，
  再於專案目錄建立 symlink。支援 Windows / WSL / SSH。
  觸發時機：user 說「建立 CLAUDE.md」、「幫我建 md」、「init project md」。
---

# init-project-md

## Step 1：偵測環境

| 環境 | 判斷方式 | Base Path |
|---|---|---|
| Windows | PowerShell 內 `$IsWindows -eq $true` | `$env:USERPROFILE\.ai-workspace` |
| WSL | `uname -r` 含 `microsoft`（不分大小寫） | `~/.ai-workspace` |
| SSH/Linux | 其他 | `~/.ai-workspace` |

Windows 確認（PowerShell）：
```powershell
$IsWindows   # true = Windows
```

WSL / SSH 確認（bash）：
```bash
uname -r | grep -qi microsoft && echo WSL || echo SSH
```

## Step 2：衍生專案名稱

取 cwd 的最後一段目錄名，依規則轉換：
- 全部小寫
- 空格、底線 `_` 換成連字號 `-`

範例：
| cwd | 專案名 |
|---|---|
| `D:\GOOGLE_DRIVE_SYNC` | `google-drive-sync` |
| `/home/user/my_project` | `my-project` |
| `/workspace/NagraPlayer` | `nagraplayer` |

Windows：
```powershell
$projName = (Split-Path (Get-Location) -Leaf).ToLower() -replace '[_ ]', '-'
```

WSL / SSH：
```bash
proj_name=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr '_ ' '--')
```

## Step 3：確認目標路徑

**本體路徑（存到 ai-workspace）：**
- Windows：`$env:USERPROFILE\.ai-workspace\projects\<name>.md`
- WSL / SSH：`~/.ai-workspace/projects/<name>.md`

**symlink 路徑（專案目錄）：**
- `<cwd>/CLAUDE.md`（Windows 用反斜線）

檢查 `<cwd>/CLAUDE.md` 是否已存在：
- 若已是 symlink → 顯示目前指向，詢問是否覆蓋
- 若是真實檔案 → 警告，詢問是否備份後繼續
- 若不存在 → 直接繼續

## Step 4：分析 codebase 並生成 CLAUDE.md 內容

遵照 `/init` skill 的指示分析當前 codebase，草擬 CLAUDE.md 內容。

**關鍵：不要在 cwd 寫檔**，將內容暫存於 context，等 Step 5 寫到 ai-workspace 正確路徑。

## Step 5：建立 projects 目錄並儲存本體

**Windows（PowerShell）：**
```powershell
$base = "$env:USERPROFILE\.ai-workspace"
$dir  = "$base\projects"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
# 寫入內容
Set-Content -Path "$dir\<name>.md" -Value $content -Encoding UTF8
```

**WSL / SSH（bash）：**
```bash
base=~/.ai-workspace
dir="$base/projects"
mkdir -p "$dir"
# 用 Write tool 寫入 "$dir/<name>.md"
```

實際寫檔使用 Write tool，路徑為展開後的絕對路徑。

## Step 6：建立 symlink

**Windows（需 Developer Mode 或系統管理員）：**
```powershell
$target = "$env:USERPROFILE\.ai-workspace\projects\<name>.md"
$link   = "<cwd>\CLAUDE.md"
New-Item -ItemType SymbolicLink -Path $link -Target $target
```

若 symlink 建立失敗（權限不足），改以提示說明手動步驟：
```
請以系統管理員開啟 PowerShell，執行：
  New-Item -ItemType SymbolicLink -Path "<cwd>\CLAUDE.md" -Target "<target>"
或開啟 Windows 開發者模式後重試。
```

**WSL / SSH（bash）：**
```bash
target=~/.ai-workspace/projects/<name>.md
link=<cwd>/CLAUDE.md
ln -sf "$target" "$link"
```

## Step 7：輸出摘要

```
## CLAUDE.md 建立完成
- 本體  ：~/.ai-workspace/projects/<name>.md
- Symlink：<cwd>/CLAUDE.md → 本體
```

若此專案含公司資訊，提示：
```
※ 若此 CLAUDE.md 含公司 IP，請加入 gitignore 避免上傳：
   echo "/projects/<name>.md" >> ~/.ai-workspace/.gitignore
```
