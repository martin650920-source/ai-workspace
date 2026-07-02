# CLAUDE.md

MediaTek Symphony6 SDK — Nagra3x TEE/CA 整合開發環境。所有建置均在 Docker 容器（Ubuntu 16.04）內執行，host 只負責驅動 `build_menu.sh`。

## 程式碼歸屬

- `ddk/pesi/` — **我方自行開發維護**，唯一可自由修改的範圍
- **其餘所有路徑**（含 `ddk/Brief_Sample/`、`kernel`、`msp`、`buildroot`、`nagra_modules`、`tee` 等）— MTG / Nagra 第三方；碰 `ddk/pesi/` 以外的檔案前必須**先停下詢問**，問題需聯繫 MTG 或 Nagra

## 重要規則

- `ddk/pesi/pesi_def.h` **禁止手動修改**（由 `make` 自動產生）
- Config flag 的**唯一修改位置**：`ddk/pesi/oemmake/mtg/pv_cfg.inc`
- 切換 ABI / toolchain 後必須完整 clean build

## Build 入口

```bash
bash build_menu.sh cpesi  # 預設：只 build pesi，驗證改動用這個（快）
bash build_menu.sh csample # 驗證最終 link（會抓 undefined reference）
bash build_menu.sh call   # 完整 clean build，耗時 >2h，跑前必須先問使用者
bash build_menu.sh        # 互動式選單
```

## Git Commit 規則

每次 commit 前**必須詢問使用者**第一行要補充什麼（例如：`martin 20260522 fixed warring for apps --Wshadow`），再組成完整訊息後執行。

## 參考指令

需要細節時輸入對應 slash command：

| 指令 | 內容 |
|------|------|
| `/build` | 所有 build target 用法、config 設定檔、build log |
| `/docker` | Docker 進入、image 管理、compile_commands.json |
| `/pesi` | PESI config flags、make targets、目錄結構 |
