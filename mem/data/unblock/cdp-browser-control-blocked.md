---
slug: cdp-browser-control-blocked
symptoms:
  - "站点提示 此浏览器或应用可能不安全 无法登录"
  - "computer-use 浏览器 read-only tier 无法点击"
  - "Chrome DevTools MCP / Playwright 打开新浏览器不共享登录 cookie"
  - "ECONNREFUSED port 9222 CDP 自动化"
  - "Browser context management is not supported"
  - "WebSocket 404 Not Found CDP session"
first_seen: 2026-06-16
last_hit: 2026-06-16
hit_count: 1
tags: [browser-automation]
---

## cdp-browser-control-blocked — 安全站点自动化被拦,走 CDP 直连

### 症状信号
标准自动化在需登录的安全站点失效。
- 错误片段: `此浏览器或应用可能不安全` / `ECONNREFUSED` 9222 / `Browser context management is not supported` / `WebSocket 404`
- 行为: Playwright MCP / computer-use(只读)/ Chrome DevTools MCP 拿不到用户登录态或无法点击
- 上下文: 需复用用户真实 Chrome 登录态做自动化

### 常见错法
直接用 Playwright MCP / computer-use / Chrome DevTools MCP → 被 Google 拦"不安全"、只读、或 session 隔离丢登录 cookie。

### 正确做法
CDP 直连:复制用户 Chrome cookies→临时 profile → `--remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug-profile` 启动 → `npx playwriter session new --direct` 接入。⚠️ `pkill Chrome` 破坏性,先告知用户。**完整 4 步 + 错误速查见 `mem/references/recipes/cdp-browser-control.md`**。

### 出处
- 首次发现: 2026-06-16 / 从 cdp-browser-control skill 建召回入口
- 复现: 1 次
