#!/usr/bin/env bash
# ai-workspace Setup — SSH Remote Host
# 使用方式: bash setup-ssh.sh <git-remote-url>
# 範例:     bash setup-ssh.sh git@github.com:yourname/ai-workspace.git
# 支援：全新安裝 / 從舊版 ai_refrence 或 second-brain 遷移
#
# 注意：此腳本只負責「本機還沒有 clone」的一次性 bootstrap（clone + 建立 symlink）。
# 日常更新（pull / symlink 校驗 / push）請改用 setup/sync.sh。
set -euo pipefail

# ── 設定 ──────────────────────────────────────────────
GIT_REMOTE="${1:-}"
AI_WORKSPACE_GIT="$HOME/.ai-workspace-git"   # git clone 位置
AI_WORKSPACE="$HOME/.ai-workspace"           # AI 工具讀取路徑（symlink）
CLAUDE_HOME="$HOME/.claude"
GEMINI_HOME="$HOME/.gemini"
CODEX_HOME="$HOME/.codex"
# ──────────────────────────────────────────────────────

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
ok()      { echo -e "${GREEN}[OK]     ${NC} $*"; }
skip()    { echo -e "${YELLOW}[SKIP]   ${NC} $*"; }
migrate() { echo -e "${CYAN}[MIGRATE]${NC} $*"; }
backup()  { echo -e "${CYAN}[BACKUP] ${NC} $*"; }
err()     { echo -e "${RED}[ERR]    ${NC} $*" >&2; }

OLD_PATTERN="ai-context|ai_refrence|AI_參考資料|second-brain"

if [ -z "$GIT_REMOTE" ]; then
    echo "用法: $0 <git-remote-url>"
    echo "範例: $0 git@github.com:yourname/ai-workspace.git"
    exit 1
fi

smart_link() {
    local src="$1" target="$2"

    if [ -L "$src" ]; then
        local current
        current="$(readlink "$src")"

        if [ "$current" = "$target" ]; then
            skip "$src (已是最新)"
            return
        fi

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
echo -e "${CYAN}=== ai-workspace Setup (SSH Remote) ===${NC}"
echo ""

# ── 遷移清理 ──────────────────────────────────────────
OLD_SKILLS_LINK="$CLAUDE_HOME/skills/gdrive"
if [ -L "$OLD_SKILLS_LINK" ]; then
    old_target="$(readlink "$OLD_SKILLS_LINK")"
    if echo "$old_target" | grep -qE "$OLD_PATTERN"; then
        rm "$OLD_SKILLS_LINK"
        migrate "移除舊版 skills/gdrive symlink"
    fi
fi

OLD_CODEX_LINK="$CODEX_HOME/instructions.md"
if [ -L "$OLD_CODEX_LINK" ]; then
    old_target="$(readlink "$OLD_CODEX_LINK")"
    if echo "$old_target" | grep -qE "$OLD_PATTERN"; then
        rm "$OLD_CODEX_LINK"
        migrate "移除舊版 codex/instructions.md symlink"
    fi
fi

# 1. Clone 或 pull git repo
if [ -d "$AI_WORKSPACE_GIT/.git" ]; then
    echo "[GIT] 更新 $AI_WORKSPACE_GIT ..."
    if ! git -C "$AI_WORKSPACE_GIT" pull --ff-only; then
        err "git pull 失敗，請手動處理："
        err "  git -C \"$AI_WORKSPACE_GIT\" fetch && git -C \"$AI_WORKSPACE_GIT\" reset --hard origin/main"
        exit 1
    fi
    ok "git pull 完成"
else
    echo "[GIT] Clone $GIT_REMOTE ..."
    git clone "$GIT_REMOTE" "$AI_WORKSPACE_GIT"
    ok "git clone 完成"
fi

# 2. ~/.ai-workspace → git clone 目錄
smart_link "$AI_WORKSPACE" "$AI_WORKSPACE_GIT"

# 3. Claude: ~/.claude/CLAUDE.md
mkdir -p "$CLAUDE_HOME"
smart_link "$CLAUDE_HOME/CLAUDE.md" "$AI_WORKSPACE_GIT/adapters/claude/CLAUDE.md"

# 4. Claude: ~/.claude/skills/<name>（per-skill，來源為 skills/global/*）
mkdir -p "$CLAUDE_HOME/skills"
if [ -d "$AI_WORKSPACE_GIT/skills/global" ]; then
    for skill_dir in "$AI_WORKSPACE_GIT/skills/global"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name="$(basename "$skill_dir")"
        smart_link "$CLAUDE_HOME/skills/$skill_name" "$AI_WORKSPACE_GIT/skills/global/$skill_name"
    done
fi

# 5. Claude: ~/.claude/statusline.sh
smart_link "$CLAUDE_HOME/statusline.sh" "$AI_WORKSPACE_GIT/config/statusline.sh"

# 6. Gemini CLI: ~/.gemini/GEMINI.md
mkdir -p "$GEMINI_HOME"
smart_link "$GEMINI_HOME/GEMINI.md" "$AI_WORKSPACE_GIT/adapters/gemini/GEMINI.md"

# 7. Codex CLI: ~/.codex/AGENTS.md
mkdir -p "$CODEX_HOME"
smart_link "$CODEX_HOME/AGENTS.md" "$AI_WORKSPACE_GIT/adapters/codex/AGENTS.md"

# 8. cron 自動 git pull
CRON_LOG="$HOME/.ai-workspace-pull.log"
if [ -t 0 ]; then
    echo ""
    read -rp "設定每日 09:00 自動 git pull？[y/N]: " ans
    if [[ "${ans,,}" == "y" ]]; then
        CRON_CMD="0 9 * * * git -C \"$AI_WORKSPACE_GIT\" pull --ff-only >> \"$CRON_LOG\" 2>&1"
        ( crontab -l 2>/dev/null | grep -v "ai-workspace-git"; echo "$CRON_CMD" ) | crontab -
        ok "cron 已設定（log: $CRON_LOG）"
    else
        echo "跳過。手動更新: bash \"$AI_WORKSPACE_GIT/setup/sync.sh\""
    fi
fi

# ── 驗證 ──────────────────────────────────────────────
echo ""
echo -e "${CYAN}=== 驗證結果 ===${NC}"
for f in \
    "$AI_WORKSPACE" \
    "$CLAUDE_HOME/CLAUDE.md" \
    "$CLAUDE_HOME/statusline.sh" \
    "$GEMINI_HOME/GEMINI.md" \
    "$CODEX_HOME/AGENTS.md"
do
    if [ -L "$f" ]; then
        echo -e "  ${GREEN}$f${NC} -> $(readlink "$f")"
    else
        echo -e "  ${RED}[MISSING] $f${NC}"
    fi
done
echo "  Skills:"
for skill_dir in "$AI_WORKSPACE_GIT/skills/global"/*/; do
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
echo "日後更新: bash \"$AI_WORKSPACE_GIT/setup/sync.sh\"（或 sync.sh push 上傳變更）"
