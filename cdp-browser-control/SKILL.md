---
name: cdp-browser-control
description: >
  DEPRECATED(2026-06-16 起): 本 skill 已并入 [[mem]](unblock 分类)。
  不要主动触发本 skill,新触发请走 mem。
  原触发症状(此浏览器或应用可能不安全 / computer-use read-only /
  Chrome DevTools MCP session 隔离 / ECONNREFUSED 9222 /
  Browser context management is not supported / WebSocket 404)
  已收进 mem 的 browser-automation 召回卡。
  本 SKILL.md 保留作过渡期重定向,2026-09-12 后考虑删除目录。
  迁移清单见同目录 MIGRATED.md。
---

> ⚠️ **DEPRECATED — 已并入 [[mem]]**
>
> 本 skill 的完整流程已迁入 mem,触发改走 mem(unblock 分类,tag `browser-automation`)。
>
> - **完整操作流程**(4 步 + 错误速查 + 重连 + 元素定位): 中心仓库 mem 的 references 目录下 recipes 子目录,文件 cdp-browser-control.md
> - **召回卡**(症状→解法): 中心仓库 mem 的 data 目录下 unblock 子目录,文件 cdp-browser-control-blocked.md
> - **INDEX 反向索引**: 中心仓库 mem 根目录的 INDEX.md(unblock 分类 / browser-automation tag)
> - **迁移清单**: 见同目录 MIGRATED.md
>
> 本目录保留到 **2026-09-12** 作为历史引用 + 过渡期 redirect,届时考虑彻底删除。
> 期间所有新触发请用 mem;遇到"安全站点自动化被拦"的死路签名 → lookup mem(它会路由到本流程)。

# cdp-browser-control —— CDP 直连浏览器控制 (DEPRECATED, 见 mem)

**核心心智**:标准自动化(Playwright MCP / computer-use / Chrome DevTools MCP)在需登录的安全站点失效时,复制用户真实 Chrome cookies → 调试端口启动 Chrome → `playwriter --direct` 接入,获得完整控制且保留登录态。

完整流程已搬到 mem,见上方 banner 的路径。本文件不再维护操作步骤,避免与 mem 副本漂移。
