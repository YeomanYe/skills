---
slug: webfetch-blocked-use-browser
symptoms:
  - "WebFetch 返回'当前环境异常,完成验证后即可继续访问'(微信公众号文章)"
  - "mp.weixin.qq.com/s/<id> 拉到的内容全是导航按钮和验证提示,没有正文"
  - "公开 web 链接 WebFetch 拿不到正文,但同一 URL 浏览器打开正常"
  - "知乎专栏 / 小红书 web / 部分 Medium 等反爬墙后的公开页"
first_seen: 2026-06-08
last_hit: 2026-06-08
hit_count: 1
tags: [web-fetch]
---

## webfetch-blocked-use-browser — 反爬指纹墙换真实浏览器

### 症状信号
WebFetch / HTTP GET 拉公开 URL 拿不到正文,但浏览器打开正常。
- 错误片段:返回页含"环境异常"/"完成验证后即可继续访问"/导航按钮组,没有 `#js_content` 等正文容器
- 行为模式:重试 / 改 UA 不解决(服务端按浏览器指纹 + JS 执行环境检测)
- 上下文:微信公众号 / 知乎专栏 / 小红书 web / 任何 JS 渲染 + 反爬墙的公开页

### 常见错法
重试 WebFetch / 让用户手动粘贴正文 / 放弃说"拉不到"。区别于鉴权类(401 跳登录页)— 反爬是 **200 + 假内容**,服务端没拒绝你,只是给了个验证墙。

### 正确做法
切 `agent-browser` 用真实 Chrome via CDP 加载(完整浏览器指纹 + JS 引擎):
```bash
agent-browser open "<url>"
agent-browser wait 3000                  # 等 JS 渲染完
agent-browser get text "#js_content"     # WeChat 正文;其他站换对应 selector
agent-browser get text "#activity-name"  # 可选:标题
```
反指征:服务端 API 已返 JSON(慢 10×无意义)/ 公开静态站(WebFetch 够用)/ 需登录态(agent-browser 也救不了,得 session 持久化)。

### 出处
- 首次发现: 2026-06-08 / 用户请总结哥飞写的 Codex 玩法长文(mp.weixin.qq.com)
- 复现: 1 次
