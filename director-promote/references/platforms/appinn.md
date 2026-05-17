# Platform: 小众软件论坛 (Appinn)

> 由 `director-promote` 的 dispatch 模式调用。原独立 skill `appinn-forum-post` 已合并到本文件。

通过 playwriter MCP + Discourse REST API 在 meta.appinn.net 发布项目分享贴。
整个流程的关键不在 API 调用,而在三件事:**选对板块**、**写对调性**、**用户确认后再提交**。

## Required Tools

- `mcp__playwriter__execute` / `mcp__playwriter__reset` — 浏览器自动化
- Discourse REST API(通过浏览器内 `fetch()` 调用,带 CSRF token)

## Prerequisites Check

发帖前必须满足:
- playwriter MCP 已加载且至少有一个 tab 启用
- 用户已在浏览器登录 meta.appinn.net 账号 — 通过 `document.querySelector('#current-user')` 验证
- 项目至少有:标题概念 + 简介 + 一个外部链接(GitHub / 商店 / 官网)

任一不满足:告诉用户缺什么让他们补齐,**不要自己 mock**。

## Core Workflow

按顺序执行,每一步都有可能因为下一步的反馈而回退:

### 1. 决策板块

只有两个候选板块(其余不适合发新项目分享):

| 板块 | id | 适用 | 代价 |
|---|---|---|---|
| 发现频道 (faxian) | 10 | **成熟产品**:已上架商店 / 有真实用户 / 功能完整 | 人工审核,几小时到几天才公开 |
| alpha | 82 | **早期产品**:MVP / 周末项目 / 还在快速迭代 | 立即可见,曝光小(约 285 帖 vs faxian 的 5000+ 帖) |

**默认推荐 faxian** 当产品已上架或有正式发布。

### 2. 自动发现项目素材图

扫描位置(按优先级):
1. README 中 `![](...)` 引用的图片
2. `website/public/screenshots/`
3. `screenshots/`
4. `assets/screenshots/`、`store/`、`docs/images/`
5. 项目已部署的公网 URL(如 GitHub Pages 上的 `screenshots/*.png`)

文件名→中文 alt 的启发式映射:
- `screenshot-card.png` / `card.png` → "卡片视图" / "分组卡片视图"
- `screenshot-bisect.png` / `bisect.png` → "Bisect 调试"
- `screenshot-rules.png` / `rules.png` → "自动规则"
- `screenshot-main.png` / `home.png` → "主界面"
- 无法识别的:用文件名做候选 alt,让用户改

### 3. 起草中文文案

**调性硬性要求**:
- 用"推荐一个 X"开头,**不要**用"我搓了个 / 周末做了个 / 闲来无事写了"——发现频道是推荐频道,不是开发日记
- 痛点切入:先说**用户遇到什么问题**,再说软件如何解决
- 作者身份透明:在第一句明确"我开发的",不要假装第三方
- 链接精简:商店 + 源码 即可,不要堆砌
- 结尾低调:"欢迎反馈 / 欢迎建议和拍砖",不要"求支持 / 求 star"

### 4. **用户确认门**(不可跳过)

把以下内容呈现给用户:
- 拟定标题
- 拟定正文(含图片占位)
- 选定板块(faxian 或 alpha) + 该板块的代价说明
- 已发现的图片清单及对应 alt

**等用户明确说"确认 / OK / 发吧"再进入第 5 步**。如果用户提修改意见,回到第 3 步。

未经确认就提交是这个 dispatch 最严重的违规——见 Red Flags。

### 5. 上传图片到 Discourse

每张图独立上传 `POST /uploads.json`,记录返回的 `short_url`(形如 `upload://abc.png`)。

本地路径 → 浏览器 fetch 不到 → 用 base64 通过 page.evaluate 注入再上传。
公网 URL → 直接在浏览器内 `fetch()` 后 POST。

### 6. 提交帖子

`POST /posts.json` with:
- `title`、`raw`、`category`、`archetype: 'regular'`
- header `X-CSRF-Token` 从 `document.querySelector('meta[name="csrf-token"]').content` 读

**两种成功响应**:
- `{"action":"create_post", ..., "topic_id": N}` → 直接可见,告知用户主题 URL
- `{"action":"enqueued", "success": true, "pending_post":{"id": N}}` → **进入审核队列(faxian 必经)**,
  告知用户等待,**不要重发**

### 7. 验证 + 报告

faxian 排队:报告 pending_post.id,告知"几小时到几天"。
直接发布:用 page.reload + page.evaluate 检查图片是否正常嵌入,报告 topic URL。

## Red Flags — STOP

出现以下情况立即停下:

- 想要"先把图传了再让用户确认"——不行,确认门在传图前
- API 返回 `enqueued` 后想"改文案再发一次"——重复提交,会被版主合并/拒绝
- playwriter 报 `No Playwright pages are available`——不要重试 API,先让用户重连扩展
- 用户说"差不多就行"——不是明确确认,再问一次"标题和正文都 OK 吗?发到 [板块] 对吗?"
- 想发到非 faxian / alpha 板块——其他板块(求助、闲聊、灌水)不适合项目分享

## Common Mistakes

| 错误 | 修正 |
|---|---|
| 文案以"我做了个 / 我搓了个"开头 | 改为"推荐一个我开发的 X" |
| 把 GitHub、商店、官网、文档、PayPal 链接都堆上 | 只留 2-3 条主链接 |
| 板块凭直觉乱选 | 走第 1 步的决策表 |
| 跳过用户确认 | 见 Red Flags |
| 把 enqueued 当失败重发 | enqueued 是正常状态,等审核 |
| 图片直接用 GitHub raw URL 嵌入 | 上传到 Discourse 取 `upload://` short_url,CDN 加速且防失链 |

## Real-World Reference

成功案例:topic 84782(Ext Helper,浏览器扩展管理器)
- 板块:faxian(已上架 Chrome Web Store)
- 流程:起草 → 用户确认 → 提交(enqueued)→ 审核通过 → 补图(upload + 编辑帖子)
- URL: https://meta.appinn.net/t/topic/84782

## Dispatch Output(由 director-promote 汇总)

完成后回报给 director-promote:
- 选定板块(faxian / alpha)
- 标题 + 正文摘要 + 配图清单
- 提交结果:
  - 直接可见 → topic URL
  - 进入审核队列 → `pending_post.id` + 等待说明
- 预览截图路径
