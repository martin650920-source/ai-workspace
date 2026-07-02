## 語言
永遠使用**繁體中文**回覆。

## Bootstrap
Session 開始時，執行 `/context-loader` skill 載入 ai-workspace context。

`~/.claude/settings.json` 的 SessionStart hook 會自動觸發此步驟（SSH 主機會先 git pull）。若 hook 未觸發，請手動執行 `/context-loader`。

若 `~/.ai-workspace` 不存在，停止並回報：
```
`~/.ai-workspace` not found — 請先執行安裝腳本：
- WSL:     bash setup/setup-wsl.sh
- SSH:     bash setup/setup-ssh.sh <git-url>
- Windows: setup\setup-windows.ps1
```
