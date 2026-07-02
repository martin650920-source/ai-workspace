#!/usr/bin/env bash
# ai-workspace 日常同步腳本（WSL / SSH / Linux）
#
# 用法:
#   sync.sh                                   pull + symlink 校驗
#   sync.sh push                              pull（防覆蓋）→ commit → push
#   sync.sh link-project <path> <name>        建立/更新 projects/<name>.md 對應到 <path>/CLAUDE.md 的 symlink
#   sync.sh link-skill <project> <skill>      建立 skills/projects/<project>/<skill>/ symlink 到 <path>/.claude/skills/<skill>/
set -euo pipefail

AI_WORKSPACE="${AI_WORKSPACE:-$HOME/.ai-workspace}"
CLAUDE_HOME="$HOME/.claude"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
ok()    { echo -e "${GREEN}[OK]     ${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]   ${NC} $*"; }
info()  { echo -e "${CYAN}[INFO]   ${NC} $*"; }
err()   { echo -e "${RED}[ERROR]  ${NC} $*" >&2; }

cmd="${1:-sync}"

# ── 子指令：sync（預設，無參數）────────────────────────
do_sync() {
    cd "$AI_WORKSPACE"

    info "git pull ..."
    git pull --ff-only
    ok "pull 完成，目前 commit: $(git rev-parse --short HEAD)"

    echo ""
    info "symlink 校驗 ..."

    # 1) 斷鍊檢查：~/.claude/skills/<name> 等是否指向已不存在的路徑
    local dangling=0
    for link in "$CLAUDE_HOME/CLAUDE.md" "$CLAUDE_HOME/statusline.sh" \
                "$HOME/.gemini/GEMINI.md" "$HOME/.codex/AGENTS.md"; do
        if [ -L "$link" ] && [ ! -e "$link" ]; then
            warn "斷鍊: $link -> $(readlink "$link")"
            dangling=$((dangling+1))
        fi
    done
    if [ -d "$CLAUDE_HOME/skills" ]; then
        for link in "$CLAUDE_HOME/skills"/*/; do
            [ -L "${link%/}" ] || continue
            if [ ! -e "${link%/}" ]; then
                warn "斷鍊: ${link%/} -> $(readlink "${link%/}")"
                dangling=$((dangling+1))
            fi
        done
    fi
    [ "$dangling" -eq 0 ] && ok "無斷鍊"

    # 2) repo 有新 skill 但本機未建 symlink
    local missing=()
    if [ -d "$AI_WORKSPACE/skills/global" ]; then
        for d in "$AI_WORKSPACE/skills/global"/*/; do
            [ -d "$d" ] || continue
            name="$(basename "$d")"
            [ -e "$CLAUDE_HOME/skills/$name" ] || missing+=("$name")
        done
    fi
    if [ "${#missing[@]}" -gt 0 ]; then
        warn "發現 ${#missing[@]} 個尚未連結的 skill: ${missing[*]}"
        read -rp "    現在建立 symlink？[Y/n]: " ans
        if [[ "${ans,,}" != "n" ]]; then
            mkdir -p "$CLAUDE_HOME/skills"
            for name in "${missing[@]}"; do
                ln -sf "$AI_WORKSPACE/skills/global/$name" "$CLAUDE_HOME/skills/$name"
                ok "已連結: $name"
            done
        fi
    else
        ok "skill symlink 齊全"
    fi

    # 3) 本機孤兒 symlink：指向 ai-workspace/skills/global/ 但來源已被刪除
    local orphans=()
    if [ -d "$CLAUDE_HOME/skills" ]; then
        for link in "$CLAUDE_HOME/skills"/*/; do
            [ -L "${link%/}" ] || continue
            target="$(readlink "${link%/}")"
            case "$target" in
                "$AI_WORKSPACE/skills/global/"*)
                    [ -e "$target" ] || orphans+=("${link%/}")
                    ;;
            esac
        done
    fi
    if [ "${#orphans[@]}" -gt 0 ]; then
        warn "發現孤兒 symlink（來源已從 repo 刪除）:"
        for o in "${orphans[@]}"; do echo "    $o"; done
        read -rp "    清除？[y/N]: " ans
        if [[ "${ans,,}" == "y" ]]; then
            for o in "${orphans[@]}"; do rm "$o"; ok "已清除: $o"; done
        fi
    else
        ok "無孤兒 symlink"
    fi

    echo ""
    ok "同步完成 — commit: $(git rev-parse --short HEAD)（$(git log -1 --format=%cd --date=short)）"
}

# ── 子指令：push ───────────────────────────────────────
do_push() {
    cd "$AI_WORKSPACE"

    info "push 前先 pull（避免覆蓋其他主機的變更）..."
    if ! git pull --ff-only; then
        err "git pull 失敗（可能有衝突），請手動處理後再執行 sync.sh push："
        err "  cd \"$AI_WORKSPACE\" && git status"
        exit 1
    fi

    if [ -z "$(git status --porcelain)" ]; then
        info "沒有變更可 push。"
        return
    fi

    git add -A
    git commit
    git push
    ok "push 完成 — commit: $(git rev-parse --short HEAD)"
}

# ── 子指令：link-project ───────────────────────────────
do_link_project() {
    local project_path="${1:?用法: sync.sh link-project <path> <name>}"
    local name="${2:?用法: sync.sh link-project <path> <name>}"

    local body="$AI_WORKSPACE/projects/$name.md"
    if [ ! -f "$body" ]; then
        err "本體不存在: $body（請先用 /init-project-md 或手動建立）"
        exit 1
    fi

    ln -sf "$body" "$project_path/CLAUDE.md"
    ok "已連結: $project_path/CLAUDE.md -> $body"

    # CLAUDE.local.md：純 import stub，指向 rules/mem
    local local_md="$project_path/CLAUDE.local.md"
    if [ ! -e "$local_md" ]; then
        {
            echo "@$AI_WORKSPACE/rules/global.md"
            [ -f "$AI_WORKSPACE/rules/projects/$name/general.md" ] && \
                echo "@$AI_WORKSPACE/rules/projects/$name/general.md"
            echo "@$AI_WORKSPACE/mem/global.md"
            [ -f "$AI_WORKSPACE/mem/projects/$name.md" ] && \
                echo "@$AI_WORKSPACE/mem/projects/$name.md"
        } > "$local_md"
        ok "已建立: $local_md"
    else
        info "$local_md 已存在，未覆寫（手動確認 import 行是否齊全）"
    fi
}

# ── 子指令：link-skill ─────────────────────────────────
do_link_skill() {
    local project="${1:?用法: sync.sh link-skill <project> <skill>}"
    local skill="${2:?用法: sync.sh link-skill <project> <skill>}"

    local body="$AI_WORKSPACE/skills/projects/$project/$skill"
    if [ ! -d "$body" ]; then
        err "本體不存在: $body（請先建立 SKILL.md）"
        exit 1
    fi

    read -rp "專案目錄路徑（含 .claude/skills/ 的那個 repo 根目錄）: " project_root
    mkdir -p "$project_root/.claude/skills"
    ln -sf "$body" "$project_root/.claude/skills/$skill"
    ok "已連結: $project_root/.claude/skills/$skill -> $body"
}

case "$cmd" in
    sync)          do_sync ;;
    push)          do_push ;;
    link-project)  shift; do_link_project "$@" ;;
    link-skill)    shift; do_link_skill "$@" ;;
    *)
        err "未知指令: $cmd"
        echo "用法: sync.sh [sync|push|link-project <path> <name>|link-skill <project> <skill>]"
        exit 1
        ;;
esac
