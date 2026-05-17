# Platform: Twitter / X

> 由 `director-promote` 的 dispatch 模式调用。原独立 skill `post-to-twitter` 已合并到本文件。

通过 playwriter 控制用户的 Chrome(已登录态)在 X.com 发推文。配图优先从当前项目中查找,
文字必须 ≤ 280 字符,发布前必须截图给用户预览确认。

## Required Tools

- `mcp__playwriter__execute` — 执行浏览器自动化代码
- `mcp__playwriter__reset` — 浏览器/上下文断开时重连
- `Glob` / `Read` — 查找项目里的 hero 图

playwriter 不可用 → 告知用户安装/激活 playwriter 浏览器扩展,**不要**回退 Playwright headless
(那是另一个 Chrome 实例,没有用户登录态)。

## Prerequisites Check

发布前必须:
- playwriter MCP 已加载且至少有一个 tab 启用
- 用户已在 Chrome 登录 X / Twitter
- 已有 hero 图(可选,X 允许纯文本推文)

## Workflow

### 1. 查找配图(hero 图)

按以下优先级在项目中查找配图,找到第一个就用:

```
1. **/hero-poster.{png,jpg,jpeg,webp}
2. **/hero.{png,jpg,jpeg,webp}
3. store-assets/generated/*overview*.png
4. store-assets/generated/*marquee*.png
5. website/public/screenshots/*.png
6. assets/icon.png   (兜底,最后选)
```

用 `Glob` 找,然后用 `Read` 看一眼图,确认是宣传图(不是 logo / 占位图)。
找不到合适图片 → 问用户"先调 director-design 生成一张,还是跳过配图"。

### 2. 编写推文文案

**总字符数 ≤ 280**(X 限制)。emoji 一般算 2 字符,hashtag / 空格 / 换行都算字符。

推荐结构:
```
钩子句(一行点出痛点 / 价值)

产品名 + 简介:
✅ 核心功能 1
✅ 核心功能 2
✅ 核心功能 3

尾句(一句话特性)

#Tag1 #Tag2
```

emoji 用作 bullet 点(✅ 🔧 🔒)能让推文显得更有结构。

### 3. 导航到发推页面

```javascript
await page.goto('https://x.com/compose/post', {waitUntil: 'domcontentloaded', timeout: 20000});
await new Promise(r => setTimeout(r, 2000));
```

注意:`waitUntil: 'load'` 默认值会超时(X 的 load 事件触发很慢),必须用 `domcontentloaded`。

跳转到 `/login` → 用户没登录,停下来让用户先登录。

### 4. 填写推文文字(关键踩坑点 ⚠️)

**X 的编辑器是 ProseMirror(tiptap),普通 type / fill 都不可靠**:

- ❌ `editor.type(text)` — 会丢换行、丢字符(实测 "Too many" 变成 "oo many"),emoji 和 `\n` 都可能丢
- ❌ `editor.fill(text)` — ProseMirror 的 contenteditable 不接受 fill
- ❌ `page.keyboard.type` — 同样会丢字符
- ❌ `navigator.clipboard.writeText + Cmd+V` — 沙箱里 clipboard 经常没权限

✅ **唯一可靠的方法:`document.execCommand('insertText', false, text)`**

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

会把换行、emoji、所有特殊字符完整保留。

### 5. 上传配图

```javascript
const fileInput = await page.$('input[data-testid="fileInput"]');
await fileInput.setInputFiles('/absolute/path/to/hero.png');
await new Promise(r => setTimeout(r, 3000));  // 等图片处理完
```

必须用绝对路径。X 的图片处理需要 2-3 秒。

### 6. 截图预览(必须步骤)

```javascript
await page.screenshot({path: '/tmp/twitter-preview.png'});
```

用 `Read` 工具读这张图给用户看。**不要跳过这步直接发**——字数计数器、按钮状态都要靠截图确认:

- 右下角圆形进度环旁会显示**剩余字符**(正数)或**超出字符**(负数,红色,如 `-42`)
- Post 按钮 `[data-testid="tweetButton"]` 的 `aria-disabled` 属性:
  - `"true"` = 不可点(字数超限或编辑器空)
  - `"false"` = 可点

### 7. 等用户确认后再发布

⚠️ **严禁跳过预览直接发布**。即使用户说"直接发吧不用给我看",也必须先把截图给用户看一眼字数 /
配图 / 文案是否正确——推文一旦发出无法编辑。

```javascript
// 用户看完截图明确说"发"之后再执行
await page.click('[data-testid="tweetButton"]');
await new Promise(r => setTimeout(r, 3000));
return page.url();  // 成功后会跳转到 home 或推文详情页
```

用户改主意保存草稿:点右上角 `Drafts` / `保存草稿`,或关掉弹窗(X 会自动提示保存草稿)。

## Common Pitfalls

### 推文残留:清空编辑器没清干净

`document.execCommand('selectAll')` + `insertText` 会**替换**当前内容,但若之前用了 `editor.type`,
再 `insertText` 会拼接到末尾。

✅ 正确清空:
```javascript
await page.evaluate(() => {
  const editor = document.querySelector('[data-testid="tweetTextarea_0"]');
  editor.focus();
  document.execCommand('selectAll');
  document.execCommand('delete');
});
```

### 浏览器/页面断开

playwriter 可能报 `Target page, context or browser has been closed`。处理:

1. 先调用 `mcp__playwriter__reset`
2. reset 报 `No Playwright pages are available` → 让用户在 Chrome 里点 playwriter 扩展图标激活当前 tab
3. 用户激活后再 `mcp__playwriter__reset`
4. reset 成功后看 `Current page URL`:若不是 `x.com/compose/post`,需要重新 `page.goto` 并重填内容

### `waitForLoadState('networkidle')` 卡死

X 是长连接 SPA,networkidle 永远不触发。所有等待用:
- `domcontentloaded`(导航)
- 固定 `setTimeout`(等 UI 渲染)
- `page.waitForSelector`(等具体元素出现)

### 图片上传后字符数没刷新

X 的字符计数器是异步更新的,上传图片后等 1-2 秒再截图。

## Quick Reference

| 操作 | 选择器 / 方法 |
|---|---|
| 文本编辑器 | `[data-testid="tweetTextarea_0"]` |
| 发布按钮 | `[data-testid="tweetButton"]` |
| 文件上传 input | `input[data-testid="fileInput"]` |
| 填文字(可靠) | `document.execCommand('insertText', false, t)` |
| 清空文字 | `selectAll` + `document.execCommand('delete')` |
| 导航 | `goto(url, {waitUntil: 'domcontentloaded'})` |

## Dispatch Output(由 director-promote 汇总)

完成后回报给 director-promote:
- 推文文案(最终发布的版本,含字符数)
- 用的哪张配图(项目相对路径)
- 发布结果:URL(成功)/ 草稿状态 / 失败原因
- 预览截图路径
