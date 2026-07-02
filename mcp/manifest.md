# MCP Manifest

各主機安裝狀態清單。由 `sync.sh` 自動偵測、自動 push（此檔案是唯一允許自動 push 的例外，其餘檔案維持手動 `sync.sh push`）。

不強制每台主機都安裝相同的 MCP 清單（如 SSH 遠端可能不需要 Google Drive MCP），改用「清單提醒」取代「內容強制同步」。

## 格式範例

```markdown
## gitlab
- 安裝指令：claude mcp add gitlab ...
- 已安裝主機：桌機, 筆電-WSL
```

---

（目前無安裝紀錄，第一次跑 `sync.sh` 時自動補上）
