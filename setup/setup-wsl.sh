#!/usr/bin/env bash
# ai-workspace Setup — WSL
# 使用方式: bash setup-wsl.sh
# 支援：全新安裝 / 從舊版 ai_refrence 或 second-brain 遷移
#
# 注意：此腳本只負責「本機還沒有 clone」的一次性 bootstrap（建立 symlink）。
# 日常更新（pull / symlink 校驗 / push）請改用 setup/sync.sh。
set -euo pipefail

# ── 設定（依實際路徑調整）─────────────────────────────
GDRIVE="/mnt/d/GOOGLE_DRIVE_SYNC/ai-workspace"
# 若從舊版遷移，請先將 Google Drive 內的資料夾更名為 ai-workspace
# 舊名通常是 second-brain、AI_參考資料 或 ai_refrence
AI_WORKSPACE="$HOME/.ai-workspace"
CLAUDE_HOME="$HOME/.claude"
GEMINI_HOME="$HOME/.gemini"
CODEX_HOME="$HOME/.codex"
# ──────────────────────────────────────────────────────

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
ok()      { echo -e "${GREEN}[OK]     ${NC} $*"; }
skip()    { echo -e "${YELLOW}[SKIP]   ${NC} $*"; }
migrate() { echo -e "${CYAN}[MIGRATE]${NC} $*"; }
backup()  { echo -e "${CYAN}[BACKUP] ${NC} $*"; }
err()     { echo -e "${RED}[ERROR]  ${NC} $*" >&2; }

# 舊版路徑特徵（用來識別需要遷移的舊 symlink）
OLD_PATTERN="ai-context|ai_refrence|AI_參考資料|second-brain"

smart_link() {
    local src="$1" target="$2"

    if [ -L "$src" ]; then
        local current
        current="$(readlink "$src")"

        # 已是正確的 symlink，跳過
        if [ "$current" = "$target" ]; then
            skip "$src (已是最新)"
            return
        fi

        # 偵測到舊版 symlink，提示遷移
        if echo "$current" | grep -qE "$OLD_PATTERN"; then
            echo ""
            migrate "偵測到舊版 symlink，需要更新："
            echo "    舊 → $current"
            echo "    新 → $target"
            read -rp "    更新？[Y/n]: " ans
            if [[ "${ans,,}" != "n" ]]; then
                rm "$src"
                mkdir -p "$(dirname "$src")"
                ln -s "$target" "$src"
                ok "已更新: $src"
            else
                skip "$src (保留舊版，注意：功能可能異常）"
            fi
            return
        fi

        # 指向未知路徑的 symlink
        echo ""
        echo -e "${YELLOW}[!] symlink 指向未知路徑: $src${NC}"
        echo "    目前 → $current"
        echo "    預期 → $target"
        read -rp "    覆蓋？[y/N]: " ans
        if [[ "${ans,,}" == "y" ]]; then
            rm "$src"
            mkdir -p "$(dirname "$src")"
            ln -s "$target" "$src"
            ok "已覆蓋: $src"
        else
            skip "$src (保留)"
        fi
        return
    fi

    # 存在但不是 symlink（真實檔案/目錄）
    if [ -e "$src" ]; then
        echo ""
        echo -e "${YELLOW}[!] 偵測到現有路徑: $src${NC}"
        echo "    1) 備份後建立 symlink → $target"
        echo "    2) 忽略（保留現有內容）"
        read -rp "    請選擇 [1/2]: " choice
        if [[ "$choice" != "1" ]]; then skip "$src (忽略)"; return; fi
        local bak="${src}.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$src" "$bak"
        backup "備份完成: $bak"
    fi

    mkdir -p "$(dirname "$src")"
    ln -s "$target" "$src"
    ok "$src -> $target"
}

echo ""
echo -e "${CYAN}=== ai-workspace Setup (WSL) ===${NC}"
echo ""

# 確認 Google Drive 掛載
if [ ! -d "$GDRIVE" ]; then
    err "Google Drive 路徑不存在: $GDRIVE"
    err "請確認："
    err "  1. D: 已掛載到 /mnt/d/"
    err "  2. Google Drive 內的資料夾已更名為 ai-workspace"
    err "  3. 或修改腳本頂端的 GDRIVE 變數"
    echo ""
    echo "  掛載指令: sudo mkdir -p /mnt/d && sudo mount -t drvfs D: /mnt/d"
    exit 1
fi

# ── 遷移清理：移除舊版 skills/gdrive 整目錄 symlink ──
OLD_SKILLS_LINK="$CLAUDE_HOME/skills/gdrive"
if [ -L "$OLD_SKILLS_LINK" ]; then
    old_target="$(readlink "$OLD_SKILLS_LINK")"
    if echo "$old_target" | grep -qE "$OLD_PATTERN"; then
        rm "$OLD_SKILLS_LINK"
        migrate "移除舊版 skills/gdrive symlink（改為 per-skill）"
    fi
fi

# ── 遷移清理：移除舊版 codex instructions.md ──────────
OLD_CODEX_LINK="$CODEX_HOME/instructions.md"
if [ -L "$OLD_CODEX_LINK" ]; then
    old_target="$(readlink "$OLD_CODEX_LINK")"
    if echo "$old_target" | grep -qE "$OLD_PATTERN"; then
        rm "$OLD_CODEX_LINK"
        migrate "移除舊版 codex/instructions.md symlink（改為 AGENTS.md）"
    fi
fi

# 1. ~/.ai-workspace → Google Drive 根目錄
smart_link "$AI_WORKSPACE" "$GDRIVE"

# 2. Claude: ~/.claude/CLAUDE.md
mkdir -p "$CLAUDE_HOME"
smart_link "$CLAUDE_HOME/CLAUDE.md" "$GDRIVE/adapters/claude/CLAUDE.md"

# 3. Claude: ~/.claude/skills/<name>（per-skill symlink，來源為 skills/global/*）
mkdir -p "$CLAUDE_HOME/skills"
if [ -d "$GDRIVE/skills/global" ]; then
    for skill_dir in "$GDRIVE/skills/global"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name="$(basename "$skill_dir")"
        smart_link "$CLAUDE_HOME/skills/$skill_name" "$GDRIVE/skills/global/$skill_name"
    done
fi

# 4. Claude: ~/.claude/statusline.sh
smart_link "$CLAUDE_HOME/statusline.sh" "$GDRIVE/config/statusline.sh"

# 5. Gemini CLI: ~/.gemini/GEMINI.md
mkdir -p "$GEMINI_HOME"
smart_link "$GEMINI_HOME/GEMINI.md" "$GDRIVE/adapters/gemini/GEMINI.md"

# 6. Codex CLI: ~/.codex/AGENTS.md
mkdir -p "$CODEX_HOME"
smart_link "$CODEX_HOME/AGENTS.md" "$GDRIVE/adapters/codex/AGENTS.md"

# 7. Google Drive 根目錄 CLAUDE.md（project-level symlink）
GDRIVE_PARENT="$(dirname "$GDRIVE")"
PROJECTS_DIR="$GDRIVE/projects"
mkdir -p "$PROJECTS_DIR"
smart_link "$GDRIVE_PARENT/CLAUDE.md" "$GDRIVE/projects/google-drive-sync.md"

# ── 驗證 ──────────────────────────────────────────────
echo ""
echo -e "${CYAN}=== 驗證結果 ===${NC}"
for f in \
    "$AI_WORKSPACE" \
    "$CLAUDE_HOME/CLAUDE.md" \
    "$CLAUDE_HOME/statusline.sh" \
    "$GEMINI_HOME/GEMINI.md" \
    "$CODEX_HOME/AGENTS.md" \
    "$GDRIVE_PARENT/CLAUDE.md"
do
    if [ -L "$f" ]; then
        echo -e "  ${GREEN}$f${NC} -> $(readlink "$f")"
    else
        echo -e "  ${RED}[MISSING] $f${NC}"
    fi
done
echo "  Skills:"
for skill_dir in "$GDRIVE/skills/global"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    f="$CLAUDE_HOME/skills/$skill_name"
    if [ -L "$f" ]; then
        echo -e "    ${GREEN}$f${NC} -> $(readlink "$f")"
    else
        echo -e "    ${RED}[MISSING] $f${NC}"
    fi
done

echo ""
echo -e "${GREEN}完成！請重啟 Claude Code / Gemini CLI / Codex CLI 讓變更生效。${NC}"
echo -e "${CYAN}日常更新請改用: bash setup/sync.sh${NC}"
