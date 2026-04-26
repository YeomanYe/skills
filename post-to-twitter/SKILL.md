---
name: post-to-twitter
description: Use when 用户要在 Twitter / X 上发宣传贴、推文，或要求 "tweet about / post to twitter / 发推 / 在 Twitter 发"。通过 playwriter MCP 操作用户已登录的 Chrome，从当前项目中查找 hero 图作为配图，编写并预览推文内容，等用户确认后再发布。
---

# Post to Twitter / X

通过 playwriter 控制用户的 Chrome（已登录态）在 X.com 发推文。配图优先从当前项目中查找，文字必须 ≤ 280 字符，发布前必须截图给用户预览确认。

## When to Use

- 用户要求"发推文"、"在 Twitter 发宣传贴"、"tweet about this project"
- 要为某个项目 / 产品 / 文章在 X 上做推广
- 用户已经在 Chrome 里登录了 X / Twitter（playwriter 用的是用户当前浏览器）

不要用于：
- 通过 Twitter API 编程发推 — 那是另一回事
- 用户没登录的情况下发推 — 跳出来让用户先登录

## Required Tools

- `mcp__playwriter__execute` — 执行浏览器自动化代码
- `mcp__playwriter__reset` — 浏览器/上下文断开时重连
- `Glob` / `Read` — 查找项目里的 hero 图

如果 playwriter 不可用，告知用户安装 playwriter 浏览器扩展并激活，不要回退到 Playwright headless 浏览器（那是另一个 Chrome 实例，没有用户登录态）。

## Workflow

### 1. 查找配图（hero 图）

按以下优先级在项目中查找配图，找到第一个就用：

```
1. **/hero-poster.{png,jpg,jpeg,webp}
2. **/hero.{png,jpg,jpeg,webp}
3. store-assets/generated/*overview*.png
4. store-assets/generated/*marquee*.png
5. website/public/screenshots/*.png
6. assets/icon.png   （兜底，最后选）
```

用 `Glob` 找，然后用 `Read` 看一眼图，确认是宣传图（不是 logo / 占位图）。

如果项目里完全没有合适图片，问用户：要不要先生成一张？或者跳过配图（X 允许纯文本推文）。

### 2. 编写推文文案

文案约束（必须遵守）：

- **总字符数 ≤ 280**（X 限制）
- 如果用户没指定，根据项目的 README / package.json description / CLAUDE.md 提炼一段宣传文案
- 推荐结构：
  ```
  钩子句（一行点出痛点 / 价值）
  
  产品名 + 简介:
  ✅ 核心功能 1
  ✅ 核心功能 2
  ✅ 核心功能 3
  
  尾句（一句话特性）
  
  #Tag1 #Tag2
  ```
- emoji 用作 bullet 点（✅ 🔧 🔒）能让推文显得更有结构

**字符数预估方法**：emoji 一般算 2 字符，hashtag、空格、换行都算字符。写完后心算一下，超长就先精简再上传。

### 3. 导航到发推页面

```javascript
// 使用 mcp__playwriter__execute
await page.goto('https://x.com/compose/post', {waitUntil: 'domcontentloaded', timeout: 20000});
await new Promise(r => setTimeout(r, 2000));
```

注意：`waitUntil: 'load'` 默认值会超时（X 的 load 事件触发很慢），必须用 `domcontentloaded`。

如果跳转到了 `/login`，说明用户没登录，停下来让用户先在浏览器里登录。

### 4. 填写推文文字（关键踩坑点 ⚠️）

**X 的编辑器是 ProseMirror（tiptap），普通 type / fill 都不可靠**：

- ❌ `editor.type(text)` — 会丢换行、丢字符（实测 "Too many" 变成 "oo many"），emoji 和 `\n` 都可能丢
- ❌ `editor.fill(text)` — ProseMirror 的 contenteditable 不接受 fill
- ❌ `page.keyboard.type` — 同样会丢字符
- ❌ `navigator.clipboard.writeText + Cmd+V` — 沙箱里 clipboard 经常没权限

✅ **唯一可靠的方法：`document.execCommand('insertText', false, text)`**

```javascript
const text = `Too many Chrome extensions? 🔧

Ext Helper:
✅ Bulk toggle on/off
✅ Group by context (work/dev)
✅ Bisect: find which ext breaks your page

Local & private 🔒

#ChromeExtension #DevTools`;

await page.evaluate((t) => {
  const editor = document.querySelector('[data-testid="tweetTextarea_0"]');
  editor.focus();
  document.execCommand('selectAll');
  document.execCommand('insertText', false, t);
}, text);
```

这一步会把换行、emoji、所有特殊字符完整保留。

### 5. 上传配图

```javascript
const fileInput = await page.$('input[data-testid="fileInput"]');
await fileInput.setInputFiles('/absolute/path/to/hero.png');
await new Promise(r => setTimeout(r, 3000));  // 等图片处理完
```

必须用绝对路径。X 的图片处理需要 2-3 秒。

### 6. 截图预览（必须步骤）

```javascript
await page.screenshot({path: '/tmp/twitter-preview.png'});
```

然后用 `Read` 工具读这张图给用户看。**不要跳过这步直接发**——字数计数器、按钮状态都要靠截图确认：

- 右下角圆形进度环旁会显示**剩余字符**（正数）或**超出字符**（负数，红色，如 `-42`）
- Post 按钮 `[data-testid="tweetButton"]` 的 `aria-disabled` 属性：
  - `"true"` = 不可点（字数超限或编辑器空）
  - `"false"` = 可点

### 7. 等用户确认后再发布

⚠️ **严禁跳过预览直接发布**。即使用户说"直接发吧不用给我看"，也必须先把截图给用户看一眼字数 / 配图 / 文案是否正确——推文一旦发出无法编辑。给用户看截图只多花 5 秒钟，但能避免错字、超限、配图错误这类无法挽回的事故。

```javascript
// 用户看完截图明确说"发"之后再执行
await page.click('[data-testid="tweetButton"]');
await new Promise(r => setTimeout(r, 3000));
return page.url();  // 成功后会跳转到 home 或推文详情页
```

如果用户改主意要保存草稿：点右上角 `Drafts` / `保存草稿` 按钮，或者直接关掉弹窗（X 会自动提示保存草稿）。

## Common Pitfalls

### 推文残留：清空编辑器没清干净

`document.execCommand('selectAll')` + `insertText` 会**替换**当前内容，但如果你混用了 `editor.type` 之前打过字，再用 `insertText` 会拼接到末尾。

✅ 正确清空：
```javascript
await page.evaluate(() => {
  const editor = document.querySelector('[data-testid="tweetTextarea_0"]');
  editor.focus();
  document.execCommand('selectAll');
  document.execCommand('delete');
});
```

### 浏览器/页面断开

playwriter 可能报 `Target page, context or browser has been closed`。处理：

1. 先调用 `mcp__playwriter__reset`
2. 如果 reset 报 `No Playwright pages are available` → 让用户在 Chrome 里点一下 playwriter 扩展图标激活当前 tab
3. 用户激活后再 `mcp__playwriter__reset`
4. reset 成功后看 `Current page URL`：如果不是 `x.com/compose/post`，需要重新 `page.goto('https://x.com/compose/post')` 并重填内容（之前的输入会丢失）

### `waitForLoadState('networkidle')` 卡死

X 是长连接 SPA，networkidle 永远不触发。所有等待用：
- `domcontentloaded`（导航）
- 固定 `setTimeout`（等 UI 渲染）
- `page.waitForSelector`（等具体元素出现）

### 图片上传后字符数没刷新

X 的字符计数器是异步更新的，上传图片后等 1-2 秒再截图。

## Quick Reference

| 操作 | 选择器 / 方法 |
|---|---|
| 文本编辑器 | `[data-testid="tweetTextarea_0"]` |
| 发布按钮 | `[data-testid="tweetButton"]` |
| 文件上传 input | `input[data-testid="fileInput"]` |
| 填文字（可靠） | `document.execCommand('insertText', false, t)` |
| 清空文字 | `selectAll` + `document.execCommand('delete')` |
| 导航 | `goto(url, {waitUntil: 'domcontentloaded'})` |

## Output Contract

执行完成后，给用户的最终消息应包含：
- 推文文案（最终发布的版本，含字符数）
- 用的哪张配图（项目相对路径）
- 发布结果：URL（成功）/ 草稿状态 / 失败原因

不要在用户确认前就点发布。截图预览 → 等用户说"发"再发。
