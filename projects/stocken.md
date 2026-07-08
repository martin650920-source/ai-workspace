# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

LINE Bot 股票行情機器人，整合永豐 Shioaji API 提供台股即時報價與訂閱推播。

## 開發指令

```powershell
# 安裝依賴
.\venv\Scripts\pip install -r requirements.txt

# 本地直接執行（需 .env）
.\venv\Scripts\python app.py

# 啟動完整服務（Flask + Cloudflare Tunnel，會彈出 URL 提示）
powershell -ExecutionPolicy Bypass -File start_bot.ps1

# 啟動完整服務（Flask + Tailscale Funnel）
start_stocken.bat

# 停止所有服務
powershell -ExecutionPolicy Bypass -File stop_bot.ps1
```

## 環境設定

複製 `.env.example` 為 `.env`，填入四個必要金鑰：

| 變數 | 來源 |
|---|---|
| `LINE_CHANNEL_SECRET` | LINE Developers Console |
| `LINE_CHANNEL_ACCESS_TOKEN` | LINE Developers Console |
| `SHIOAJI_API_KEY` | 永豐金證券後台 |
| `SHIOAJI_SECRET_KEY` | 永豐金證券後台 |

## 架構

```
app.py               # Flask 入口：LINE webhook 接收、指令路由
config.py            # 從 .env 載入環境變數（startup 即失敗）
shioaji_service.py   # 永豐 API 封裝：登入、快照查詢、tick 訂閱
subscription_store.py # in-memory 訂閱狀態 + 推播限速（thread-safe）
```

**資料流：**
1. LINE 送 POST 到 `/webhook` → `app.py` 解析指令
2. 查詢報價：`shioaji_service.get_snapshot()` → 回 reply message
3. 訂閱：`subscription_store.add()` → `shioaji_service.subscribe_stock()` 向 Shioaji 訂閱 Tick
4. Tick 回調 `_on_tick()` → 查訂閱者 → `subscription_store.can_push()` 限速 → `_push_fn()` 送 push message

## 關鍵設計決策

- **Shioaji 以 daemon thread 初始化**（`app.py:158`），Flask 先起來再登入；`_api is None` 時所有查詢直接回錯誤訊息
- **訂閱狀態純 in-memory**，重啟後遺失；重啟後需用戶重新訂閱
- **推播限速**：同一用戶同一股票 60 秒最多推一次（`subscription_store.PUSH_INTERVAL_SECONDS`）
- **`simulation=True`**（`shioaji_service.py:22`）：目前以模擬帳號登入，改正式需移除此參數
- **expose 方式二擇一**：Cloudflare Tunnel（`start_bot.ps1`）或 Tailscale Funnel（`start_stocken.bat`）；兩者 Webhook URL 皆需手動更新至 LINE Developers Console

## 指令對應表

| 用戶輸入 | 動作 |
|---|---|
| `報價 2330` / `查詢 2330` / `2330` | 呼叫 `get_snapshot()` |
| `訂閱 2330` | 加入 store + 向 Shioaji 訂閱 Tick |
| `取消 2330` / `取消訂閱 2330` | 從 store 移除 + 無人訂閱時取消 Shioaji Tick |
| `我的訂閱` / `訂閱清單` | 列出該用戶訂閱股票 |
| `說明` / `help` / `?` | 回 `HELP_TEXT` |
