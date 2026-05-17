# Platform: V2EX

> 由 `director-promote` 的 dispatch 模式调用。原独立 skill `post-to-v2ex` 已合并到本文件。

通过 playwriter 控制用户当前已登录的 Chrome,在 V2EX 指定节点发主题贴。
素材(标题/正文/配图链接)从当前项目仓库提炼,配图通过 GitHub raw 链接嵌入,
发布前必须截图预览给用户确认。

## Required Tools

- `mcp__playwriter__execute` 或本地 `npx playwriter@latest` CLI — 执行浏览器自动化
- `mcp__playwriter__reset` — 浏览器/上下文断开时重连
- `Read` / `Bash`(grep)— 在项目中查找 README 和宣传素材

## Why playwriter, not standard Playwright MCP

playwriter 直连用户当前 Chrome,保留 V2EX 登录 cookie。
Playwright MCP / Chrome DevTools MCP 都会开新会话,发帖时跳到登录页。

## Workflow

### 1. 确认会话连得上

```bash
npx playwriter@latest session list
# 没有就:
npx playwriter@latest session new
```

定位 V2EX 标签页:

```javascript
const pages = context.pages();
state.page = pages.find(p => p.url().includes('v2ex')) || pages[0];
```

### 2. 询问节点(除非用户已指定)

V2EX 不同节点的发帖 URL:

| 节点 | 用途 | URL |
|---|---|---|
| `create` | 分享创造 — 自己做的项目/工具 | `https://www.v2ex.com/new/create` |
| `share` | 分享发现 — 推荐别人的好东西 | `https://www.v2ex.com/new/share` |
| `qna` | 问与答 | `https://www.v2ex.com/new/qna` |
| `programmer` | 程序员 | `https://www.v2ex.com/new/programmer` |
| 其它 | `https://www.v2ex.com/new/<节点名>` |

宣传自己开源项目优先选 `create`,介绍别人的优先 `share`。

### 3. 提炼内容素材

- **标题**:项目名 + 一句价值(中文,控制在 50 字内)
- **正文**:从 `README.md` 提炼功能列表 + 安装链接 + 仓库 URL
- **配图**:按以下优先级在仓库里查找:
  ```
  1. website/public/hero-poster.{png,jpg}
  2. promotion-assets/generated/*overview*.png
  3. website/public/screenshots/*.png
  4. assets/icon.png(兜底)
  ```

### 4. 校验外链可达(关键!)

V2EX 用户对死链特别敏感。**所有商店/官网/截图链接发布前必须 200 验证**:

```bash
curl -sI -L "<URL>" -o /dev/null -w "%{http_code}\n" --max-time 10
```

常见踩坑:
- README 里的 Firefox/Edge/Chrome 商店链接可能还是 placeholder(`#` 或 `YOUR_EXTENSION_ID`),
  先 grep 项目 `.env` 和 `config.ts` 拿真实 URL
- README 写"coming soon"的商店要么省略要么显式标注"审核中",不要给死链

### 5. 配图用 GitHub raw 链接嵌入

V2EX 不支持上传图片到正文(只支持外链 markdown)。用项目仓库的 raw URL:

```
https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>
```

获取仓库信息:

```bash
git -C <project> remote -v       # 取 owner/repo
git -C <project> branch --show-current  # 一般是 master 或 main
git -C <project> ls-files <path>  # 确认图片已 commit
```

发帖前 `curl -sI` 校验每个 raw 链接 200。**没 commit 的图片不能用**。

### 6. 进入发帖页并填表单

V2EX 发帖表单结构:

| 元素 | 选择器 |
|---|---|
| 标题 | `#topic_title` |
| 正文 | `#topic_content` |
| 语法选择 | `#select_syntax`(`0`=Default,`1`=Markdown) |
| 预览按钮 | `onclick="previewTopicContent()"` |
| 提交按钮 | `form#topic_form button[type="submit"]` |

```javascript
await state.page.goto('https://www.v2ex.com/new/create');
await state.page.locator('#topic_title').fill(title);
await state.page.locator('#topic_content').fill(content);

// 切 Markdown(用图片/列表/加粗时必须切)
await state.page.evaluate(() => {
  const sel = document.querySelector('#select_syntax');
  sel.value = '1';
  sel.dispatchEvent(new Event('change', { bubbles: true }));
});
```

### 7. 调用页面自带预览(不要新开标签)

V2EX 自带 `previewTopicContent()` JS 函数,会在表单下方注入"主题内容预览"区,**不跳页**:

```javascript
await state.page.evaluate(() => {
  if (typeof previewTopicContent === 'function') previewTopicContent();
});
await state.page.waitForTimeout(2000);  // 等图片加载
await state.page.screenshot({ path: '/tmp/v2ex-preview.png', fullPage: true });
```

用 `Read` 工具读截图给用户看:标题、正文渲染、配图、链接是否都对。

### 8. 等用户确认后再发布(默认停在预览)

⚠️ **默认不替用户点"创建主题"**。V2EX 主题发出后只有短时间可编辑,且 24 小时内不能删除。

只有用户在看完预览截图后明确说"发"/"提交"/"发布"才执行:

```javascript
await state.page.locator('form#topic_form button[type="submit"]').click();
await state.page.waitForLoadState('domcontentloaded');
console.log('posted url:', state.page.url());  // 成功后跳到 /t/<id>
```

发布失败(节点权限不足、内容触发审核),URL 仍是 `/new/<node>`,页面顶部会有红色错误条。
截图回报给用户。

## Common Pitfalls

### Markdown 没切,正文渲染成 raw 文本
V2EX 默认语法是 `Default`(纯文本),列表/加粗/图片/链接都不解析。一定要切 `#select_syntax` 到 `1`。

### `once` token 过期
`<input name="once">` 是 CSRF token。表单页打开超过几小时后再提交会失败。
报"once 过期"时刷新页面重填即可(playwriter 不需要重启)。

### V2EX 截图链接被防盗链
某些图床(微博图床、知乎图床)有 referer 防盗链,V2EX 渲染会变成裂图。解决:
- 优先用 GitHub raw(不防盗链)
- 自有图床需确认允许 v2ex.com referer
- 实在不行:上传到项目 repo,用 raw 链接

### Firefox/Edge 商店链接的 placeholder 陷阱
很多项目 README 里写商店链接但实际是占位(`#` / `YOUR_ID`)。
**发帖前 grep `.env` / `config.ts` 拿真链,再 curl 验证 200**。否则发出去就是脸打肿。

### 一帖只能改 10 分钟
V2EX 主题的"编辑"按钮在发布后 10 分钟内可见,之后只能由用户花积分申诉修改。
**预览这关一定要让用户亲自看**。

### 正文长度上限
V2EX 正文有 20000 字符上限(Markdown 源码),实际很难触及,但贴大段代码 / 长 changelog 时注意。

### 浏览器 / 页面断开
处理:
1. 调 `mcp__playwriter__reset`(或 `npx playwriter@latest session new`)
2. 仍报无可用页 → 让用户在 Chrome 里点 playwriter 扩展图标激活当前 tab
3. reset 成功后检查 `state.page.url()`:若不在 `/new/<节点>` 页面,重新 `goto` 并**重填标题、正文、Markdown 切换**
4. 不要静默失败,告诉用户"重新填一次表单"

### 区分"在 v2ex 发帖"与"问 v2ex 的问题"
触发动词必须是"发/提交/发布/post"。用户只是问"v2ex 怎么用 markdown / v2ex API 是什么",
**不要**触发本平台,正常答疑即可。

## Quick Reference

| 操作 | 选择器 / 方法 |
|---|---|
| 标题输入 | `#topic_title` |
| 正文输入 | `#topic_content` |
| 切 Markdown | `#select_syntax` 值设 `1` + dispatch `change` |
| 预览(不跳页) | `previewTopicContent()` |
| 提交 | `form#topic_form button[type="submit"]` |
| 发帖 URL 模板 | `https://www.v2ex.com/new/<节点>` |
| 成功后跳转 | `/t/<topic_id>#reply0` |

## Dispatch Output(由 director-promote 汇总)

完成后回报给 director-promote:
- 选定的节点(如 `create`)
- 标题(最终版本)
- 正文摘要(前 200 字 + 配图数量 + 链接数量)
- 所有外链的 200 校验结果
- 当前状态:**预览待确认** / 已发布(含 `/t/<id>` URL) / 失败原因
- 预览截图路径
