---
slug: lark-wiki-docs-use-lark-cli
symptoms:
  - "Lark wiki 链接跳到 accounts.larksuite.com 登录页"
  - "需要读取/写入 Lark Wiki 文档但 WebFetch/Playwright 拿不到正文"
  - "ajx34x51402.sg.larksuite.com/wiki 文档编辑任务"
  - "lark-cli docs +update 报 --command is required"
first_seen: 2026-05-28
last_hit: 2026-06-01
hit_count: 5
tags: [lark]
---

## lark-wiki-docs-use-lark-cli — Lark 文档别走网页抓取

### 症状信号
Lark Wiki / Docs 链接用网页抓取只看到登录页。
- 错误片段: `accounts.larksuite.com/accounts/page/login`
- 行为: WebFetch/Playwright/Chrome bridge 反复拿不到正文
- 上下文: 按一个 wiki 格式写另一个 wiki

### 常见错法
先走 WebFetch/Playwright，误判为"需用户粘贴或登录"。

### 正确做法
读: `lark-cli docs +fetch --api-version v2 --doc <url>`；写(v2): `lark-cli docs +update --api-version v2 --doc <url> --command overwrite --doc-format markdown --content @file.md`。v2 用 `--command`/`--content`/`--doc-format`（不是 v1 的 `--mode`/`--markdown`，否则报 `--command is required`）；`--content @file` 须 CWD 内相对路径。

### 出处
- 首次发现: 2026-05-28 / payment-landing-page 部署文档写入 Lark Wiki
- 复现: 5 次（含 2026-06-01 按参照格式写冒烟测试报告到目标 wiki）
