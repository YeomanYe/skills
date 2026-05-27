---
slug: lark-project-url-needs-meegle-cli
symptoms:
  - "project.larksuite.com 链接 WebFetch 拿不到内容"
  - "302 Found 重定向到 meegle.com 营销页"
  - "Lark Project / Meegle workObjectView / workitem URL 鉴权失败"
  - "ecommerce-strapi 等 Lark space 链接抓出营销首页 utm_source=in_meegle"
first_seen: 2026-05-27
last_hit: 2026-05-27
hit_count: 1
tags: [meegle]
---

## lark-project-url-needs-meegle-cli — Lark/Meegle 链接抓不到要走 CLI

### 症状信号
- 错误信息典型片段: `Redirect URL: https://www.meegle.com/?utm_source=in_meegle&utm_medium=meegle`、`Status: 302 Found`
- 行为模式: 用 WebFetch 跟 redirect 后只拿到 meegle.com 营销页 / 反复换 URL 都跟到营销页
- 上下文条件: URL host 是 `project.larksuite.com` / `project.feishu.cn`,path 含 `workObjectView` / `story` / `bug` / `test_cases` / `workitem` 等 Lark Project 资源

### 常见错法
继续 WebFetch 跟 redirect、改 URL 参数、放弃后让用户贴内容。Lark Project 内部数据**必须鉴权**,WebFetch 拿不到。

### 正确做法
用 `meegle` CLI(本机 `/Users/falcom/.nvs/default/bin/meegle`):
1. `meegle url decode --url "<原 URL>"` 离线解析 url_kind / view_id / work_item_id / project_key
2. 按 url_kind 走对应命令: `view get` / `workitem` / `comment list` / `chart` 等(`--select` 投影减 token)
3. 分页加 `--page-num`(`page_size` 不识别但默认 50 够用)

### 出处
- 首次发现: 2026-05-27 / 在 payment-landing-page 项目里要分析 Lark `test_cases` 视图与代码差异
- 复现: 1 次
