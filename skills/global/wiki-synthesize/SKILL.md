---
name: wiki-synthesize
description: >
  掃描 knowledge/wiki-inbox/ 各主題子資料夾，
  用 Claude 合成 wiki 條目，寫入 knowledge/wiki/<topic>.md。
  每週五中午 12:00 自動觸發，或手動呼叫 /wiki-synthesize [topic]。
---

# Wiki Synthesize Skill

## 觸發方式

- **自動**：每週五 12:00（排程呼叫）
- **手動**：`/wiki-synthesize` 或 `/wiki-synthesize <topic>`

---

## Step 1：確認路徑

```
VAULT  = D:\GOOGLE_DRIVE_SYNC
INBOX  = VAULT\knowledge\wiki-inbox
OUTPUT = VAULT\knowledge\wiki
```

若 `INBOX` 不存在，建立並提示：
```
wiki-inbox/ 資料夾已建立於 knowledge/。
請將要合成的 clips 依主題放入子資料夾，例如：
  knowledge/wiki-inbox/
    transformer/
      article1.md
      article2.md
```
然後結束。

---

## Step 2：掃描 inbox

列出 `INBOX\` 下所有非空的子資料夾（每個資料夾 = 一個主題）。

若沒有任何子資料夾或全部為空 → 輸出：
```
wiki-inbox 無資料，跳過。
```
然後結束。

---

## Step 3：逐主題合成

對每個主題資料夾：

### 3a. 讀取所有 clips

讀取該資料夾內所有 `.md` 檔案內容。

### 3b. 檢查是否已有舊版 wiki

若 `OUTPUT\<topic>.md` 已存在，讀取作為「現有知識」。

### 3c. 合成

Prompt 結構：
```
你是知識整理助手。請根據以下來源資料，{新建 / 更新} 一篇關於「<topic>」的 wiki 條目。

【現有 wiki（若有）】
<existing content>

【新增來源】
--- 來源 1：<filename> ---
<content>
...

輸出格式（繁體中文，Markdown）：
# <Topic>

> <一句話定義>

## 核心概念
<bullet points>

## 重要細節
<段落式說明>

## 應用與案例
<具體例子>

## 來源
- [<標題>](<url>) — <這篇貢獻的重點>

## 更新紀錄
- <YYYY-MM-DD>: <新增/更新，來源數量與主要貢獻>（新增在最上方）
```

### 3d. 寫入 wiki

將合成結果寫入 `OUTPUT\<topic>.md`（覆蓋舊版）。

---

## Step 4：輸出摘要

```
## Wiki Synthesize 完成 — <YYYY-MM-DD>

| 主題 | 狀態 | 來源數 |
|---|---|---|
| transformer | 更新 | 3 篇 |
| rag | 新建 | 2 篇 |

輸出位置：knowledge\wiki\
```
