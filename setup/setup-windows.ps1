# ai-workspace Setup — Windows
# 支援：全新安裝 / 從舊版 ai_refrence 或 second-brain 遷移
# 需要以「系統管理員」身份執行，或開啟開發者模式
# 使用方式: pwsh -ExecutionPolicy Bypass -File setup-windows.ps1
#
# 注意：此腳本只負責「本機還沒有 clone」的一次性 bootstrap（建立 symlink）。
# 日常更新（pull / symlink 校驗 / push）請改用 setup/sync.sh（WSL/SSH）。

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

# ── 設定（依實際路徑調整）─────────────────────────────
$GDriveRoot   = "d:\GOOGLE_DRIVE_SYNC\ai-workspace"
# 若從舊版遷移，請先將 Google Drive 內的資料夾更名為 ai-workspace
# 舊名通常是 second-brain、AI_參考資料 或 ai_refrence
$UserHome     = $env:USERPROFILE
$AiWorkspace  = "$UserHome\.ai-workspace"
$ClaudeHome   = "$UserHome\.claude"
$GeminiHome   = "$UserHome\.gemini"
$CodexHome    = "$UserHome\.codex"
# ──────────────────────────────────────────────────────

# 舊版路徑特徵（用來識別需要遷移的舊 symlink）
$OldPattern = "ai-context|ai_refrence|AI_參考資料|second-brain"

function Write-OK($msg)      { Write-Host "[OK]      $msg" -ForegroundColor Green }
function Write-Skip($msg)    { Write-Host "[SKIP]    $msg" -ForegroundColor Yellow }
function Write-Migrate($msg) { Write-Host "[MIGRATE] $msg" -ForegroundColor Cyan }
function Write-Backup($msg)  { Write-Host "[BACKUP]  $msg" -ForegroundColor Cyan }
function Write-Err($msg)     { Write-Host "[ERROR]   $msg" -ForegroundColor Red }

function Smart-Symlink {
    param([string]$LinkPath, [string]$Target)

    $item = Get-Item $LinkPath -Force -ErrorAction SilentlyContinue

    if ($item -and $item.LinkType -eq "SymbolicLink") {
        $current = $item.Target

        # 已是正確 symlink，跳過
        if ($current -eq $Target) {
            Write-Skip "$LinkPath (已是最新)"
            return
        }

        # 偵測到舊版 symlink
        if ($current -match $OldPattern) {
            Write-Host ""
            Write-Migrate "偵測到舊版 symlink，需要更新："
            Write-Host "    舊 → $current" -ForegroundColor Gray
            Write-Host "    新 → $Target" -ForegroundColor Gray
            $ans = Read-Host "    更新？[Y/n]"
            if ($ans -ne "n" -and $ans -ne "N") {
                Remove-Item $LinkPath -Force
                $parentDir = Split-Path $LinkPath -Parent
                if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir | Out-Null }
                New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target -Force | Out-Null
                Write-OK "已更新: $LinkPath"
            } else {
                Write-Skip "$LinkPath (保留舊版，注意：功能可能異常）"
            }
            return
        }

        # 指向未知路徑的 symlink
        Write-Host ""
        Write-Host "[!] symlink 指向未知路徑: $LinkPath" -ForegroundColor Yellow
        Write-Host "    目前 → $current" -ForegroundColor Gray
        Write-Host "    預期 → $Target" -ForegroundColor Gray
        $ans = Read-Host "    覆蓋？[y/N]"
        if ($ans -eq "y" -or $ans -eq "Y") {
            Remove-Item $LinkPath -Force
            New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target -Force | Out-Null
            Write-OK "已覆蓋: $LinkPath"
        } else {
            Write-Skip "$LinkPath (保留)"
        }
        return
    }

    # 存在但不是 symlink（真實檔案/目錄）
    if ($item) {
        Write-Host ""
        Write-Host "[!] 偵測到現有路徑: $LinkPath" -ForegroundColor Yellow
        Write-Host "    1) 備份後建立 symlink → $Target"
        Write-Host "    2) 忽略（保留現有內容）"
        $choice = Read-Host "    請選擇 [1/2]"
        if ($choice -ne "1") {
            Write-Skip "$LinkPath (忽略)"
            return
        }
        $ts = Get-Date -Format "yyyyMMdd-HHmmss"
        $bak = "${LinkPath}.backup-${ts}"
        Move-Item $LinkPath $bak -Force
        Write-Backup "備份完成: $bak"
    }

    $parentDir = Split-Path $LinkPath -Parent
    if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir | Out-Null }
    New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target -Force | Out-Null
    Write-OK "$LinkPath -> $Target"
}

Write-Host ""
Write-Host "=== ai-workspace Setup (Windows) ===" -ForegroundColor Cyan
Write-Host ""

# 確認 Google Drive 路徑存在
if (-not (Test-Path $GDriveRoot)) {
    Write-Err "Google Drive 路徑不存在: $GDriveRoot"
    Write-Err "請確認："
    Write-Err "  1. Google Drive 已同步完成"
    Write-Err "  2. 資料夾已更名為 ai-workspace"
    Write-Err "  3. 或修改腳本頂端的 `$GDriveRoot 變數"
    exit 1
}

# ── 遷移清理：移除舊版 skills\gdrive 整目錄 symlink ──
$OldSkillsLink = "$ClaudeHome\skills\gdrive"
$oldSkillsItem = Get-Item $OldSkillsLink -Force -ErrorAction SilentlyContinue
if ($oldSkillsItem -and $oldSkillsItem.LinkType -eq "SymbolicLink" -and $oldSkillsItem.Target -match $OldPattern) {
    Remove-Item $OldSkillsLink -Force
    Write-Migrate "移除舊版 skills\gdrive symlink（改為 per-skill）"
}

# ── 遷移清理：移除舊版 codex instructions.md ──────────
$OldCodexLink = "$CodexHome\instructions.md"
$oldCodexItem = Get-Item $OldCodexLink -Force -ErrorAction SilentlyContinue
if ($oldCodexItem -and $oldCodexItem.LinkType -eq "SymbolicLink" -and $oldCodexItem.Target -match $OldPattern) {
    Remove-Item $OldCodexLink -Force
    Write-Migrate "移除舊版 codex\instructions.md symlink（改為 AGENTS.md）"
}

# 1. ~/.ai-workspace → Google Drive 根目錄
Smart-Symlink -LinkPath $AiWorkspace -Target $GDriveRoot

# 2. Claude: ~/.claude/CLAUDE.md
if (-not (Test-Path $ClaudeHome)) { New-Item -ItemType Directory -Path $ClaudeHome | Out-Null }
Smart-Symlink -LinkPath "$ClaudeHome\CLAUDE.md" -Target "$GDriveRoot\adapters\claude\CLAUDE.md"

# 3. Claude: ~/.claude/skills/<name>（per-skill symlink，來源為 skills/global/*）
$skillsDir = "$ClaudeHome\skills"
if (-not (Test-Path $skillsDir)) { New-Item -ItemType Directory -Path $skillsDir | Out-Null }
$skillsSource = "$GDriveRoot\skills\global"
if (Test-Path $skillsSource) {
    Get-ChildItem $skillsSource -Directory | ForEach-Object {
        Smart-Symlink -LinkPath "$skillsDir\$($_.Name)" -Target $_.FullName
    }
}

# 4. Claude: ~/.claude/statusline.sh
Smart-Symlink -LinkPath "$ClaudeHome\statusline.sh" -Target "$GDriveRoot\config\statusline.sh"

# 5. Gemini CLI: ~/.gemini/GEMINI.md
if (-not (Test-Path $GeminiHome)) { New-Item -ItemType Directory -Path $GeminiHome | Out-Null }
Smart-Symlink -LinkPath "$GeminiHome\GEMINI.md" -Target "$GDriveRoot\adapters\gemini\GEMINI.md"

# 6. Codex CLI: ~/.codex/AGENTS.md
if (-not (Test-Path $CodexHome)) { New-Item -ItemType Directory -Path $CodexHome | Out-Null }
Smart-Symlink -LinkPath "$CodexHome\AGENTS.md" -Target "$GDriveRoot\adapters\codex\AGENTS.md"

# 7. Google Drive 根目錄 CLAUDE.md（project-level symlink）
$GDriveParent = Split-Path $GDriveRoot -Parent
$projectsDir = "$GDriveRoot\projects"
if (-not (Test-Path $projectsDir)) { New-Item -ItemType Directory -Path $projectsDir | Out-Null }
Smart-Symlink -LinkPath "$GDriveParent\CLAUDE.md" -Target "$GDriveRoot\projects\google-drive-sync.md"

# ── 驗證 ──────────────────────────────────────────────
Write-Host ""
Write-Host "=== 驗證結果 ===" -ForegroundColor Cyan
@(
    $AiWorkspace,
    "$ClaudeHome\CLAUDE.md",
    "$ClaudeHome\statusline.sh",
    "$GeminiHome\GEMINI.md",
    "$CodexHome\AGENTS.md",
    "$GDriveParent\CLAUDE.md"
) | ForEach-Object {
    $i = Get-Item $_ -Force -ErrorAction SilentlyContinue
    if ($i -and $i.LinkType) {
        Write-Host "  $_ -> $($i.Target)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $_" -ForegroundColor Red
    }
}
Write-Host "  Skills:"
if (Test-Path $skillsSource) {
    Get-ChildItem $skillsSource -Directory | ForEach-Object {
        $f = "$skillsDir\$($_.Name)"
        $i = Get-Item $f -Force -ErrorAction SilentlyContinue
        if ($i -and $i.LinkType) {
            Write-Host "    $f -> $($i.Target)" -ForegroundColor Green
        } else {
            Write-Host "    [MISSING] $f" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "完成！請重啟 Claude Code / Gemini CLI / Codex CLI 讓變更生效。" -ForegroundColor Green
Write-Host "日常更新請改用 WSL/SSH 上的 setup/sync.sh（pull + symlink 校驗 + push）。" -ForegroundColor Cyan
