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

**X 的编辑器是 ProseMirror(tiptap)。`execCommand('insertText')` 看起来成功,
但** 实际只更新了 contenteditable 的 DOM,**不会同步进 ProseMirror doc model**——
结果就是点 Post 后推文**只发图没文字**(X 后端只读 ProseMirror doc,不要 DOM 文本)。
本节下方会详细解释;下面是**真正可靠**的方法。

**❌ 不要用的方法(经验证都不可靠):**

- ❌ `document.execCommand('insertText', false, text)` — DOM 看着有 256 字符,
  点 Post 后推文**没文字**只有图。**这是最坑的陷阱**——看起来工作了
- ❌ `editor.type(text)` / `page.keyboard.type` — 丢换行、丢字符
  (实测 "Too many" 变成 "oo many")
- ❌ `editor.fill(text)` — ProseMirror 的 contenteditable 不接受 fill
- ❌ `navigator.clipboard.writeText + Cmd+V` — Playwright 沙箱里 clipboard 没权限

**✅ 唯一可靠的方法:`page.click(editor) + page.keyboard.insertText(...)`**

```javascript
await page.click('[data-testid="tweetTextarea_0"]');
await new Promise(r => setTimeout(r, 800));  // 等 focus + ProseMirror 初始化
await page.keyboard.insertText('Part 1 of tweet...');
// 多段文本:用 page.keyboard.press('Enter') 加换行,不要在 insertText 里塞 \n\n
await page.keyboard.press('Enter');
await page.keyboard.press('Enter');
await page.keyboard.insertText('Part 2...');
```

`page.keyboard.insertText` 由 Playwright 转发成 input event,
ProseMirror 的 input rule 能正确识别,doc model 同步更新。

**字符数注意:**
- X 计字符数是按 ProseMirror doc,**不是** `editor.innerText.length`
- 两者在简单文本场景下基本一致,但**带链接、@mention、emoji 时 innerText 会偏低**
- 上限 280 字符,留 5-10 字符 buffer 避免 Post 按钮被禁用

**为什么 execCommand 看起来成功实则失败(细节):**
1. `editor.innerText.length` 报告 256 — contenteditable 真的写进去了
2. `tweetButton.aria-disabled === null` — 字符未超限,Post 按钮亮
3. **但 ProseMirror 的 state.doc 还是空**(因为没走 input rule)
4. 点 Post → X 读 state.doc → 发空文本推文
5. 推文线上检查:`article[data-testid="tweet"] [data-testid="tweetText"]` 元素**不存在**
   或 `textLength === 0`,只有 `<img>` 元素(图片是 setInputFiles 走的另一条路,不受影响)

### 5. 上传配图

**⚠️ X 的 compose 弹层里有 2 个 file input**(`[data-testid="fileInput"]` 各出现 2 次,
`accept`/`multiple` 完全相同),分别对应 X 的两个媒体槽位。`page.$()` 拿到的
是第一个,实际 setInputFiles 触发的 React onChange handler **会把同一个 FileList
分发到两个 input**,导致 `tweetPhoto` 计数翻倍(1 次 setInputFiles 出 2 张图)。

**正确做法:用 evaluateHandle 拿第 0 个,然后用 JSHandle.asElement().setInputFiles()**
(配合 React 内部状态,只会插入到第一个槽):

```javascript
const fileHandle = await page.evaluateHandle(
  () => document.querySelectorAll('input[type="file"]')[0]
);
await fileHandle.asElement().setInputFiles('/absolute/path/to/hero.png');
await new Promise(r => setTimeout(r, 7000));  // X 图片处理慢,7s 起步
```

**不要用 `page.$('input[data-testid="fileInput"]')` — 第一个 input 走了 React 会被复制。**

**验证是否真的只有 1 张图(关键步骤):**
X 不会显示 `tweetPhoto` 计数(那是从整个 home timeline 算的,包括背后其他推文)。
**真正能区分"有 1 张图 vs 0 张 vs 多张"的是 Edit/Remove media 按钮**:

```javascript
const hasOneImage = await page.evaluate(() => {
  const edits = document.querySelectorAll('button[aria-label="Edit media"]').length;
  const removes = document.querySelectorAll('button[aria-label="Remove media"]').length;
  return { edits, removes };  // 都是 1 = 1 张图
});
```

如果 `edits`/`removes` > 1,说明累积了多张图——点 "Remove media" 删到剩 1 张再发。

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
await new Promise(r => setTimeout(r, 6000));  // 等提交完成
return page.url();  // 成功后会跳转到 home
```

### 7.5 发布后必须做线上验证(关键步骤,2026 经验)

**点完 Post 不代表真的发出去了。** 历史上 X 后端会接收带图无文 / 带文无图 /
带文有图但链接被吞的"半残推文"。**每次发布后必须访问推文 URL,验证 3 件事**:

```javascript
await page.goto(tweetUrl, {waitUntil: 'domcontentloaded'});
await new Promise(r => setTimeout(r, 4000));

const verify = await page.evaluate(() => {
  const article = document.querySelector('article[data-testid="tweet"]');
  if (!article) return { error: 'NO_ARTICLE' };
  const textEl = article.querySelector('[data-testid="tweetText"]');
  const mediaImgs = article.querySelectorAll('img[src*="pbs.twimg.com/media"]');
  const tcoLinks = article.querySelectorAll('a[href*="t.co/"]');
  return {
    text: textEl?.innerText || 'NO_TEXT',
    textLength: textEl?.innerText.length || 0,
    imageCount: mediaImgs.length,
    linkCount: tcoLinks.length,
  };
});
```

**3 项必须全部 > 0 才算成功:**
- `textLength > 0` — 文字进去了(最常丢)
- `imageCount > 0` — 图进去了
- `linkCount > 0` — 链接被 t.co 短链化(可选,如果你文案有 URL 的话)

**任一项为 0:** 立刻 `page.click('button[aria-label="More"]')` → 选 "Delete" →
确认 → 重新发,不要让半残推文留在时间线上。

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
| 文件上传 input(第 0 个) | `document.querySelectorAll('input[type="file"]')[0]` (走 evaluateHandle) |
| 填文字(**唯一可靠**) | `await page.click(editor); await page.keyboard.insertText(t)` |
| 验证图数量(1 张 = 1 个 Edit + 1 个 Remove media 按钮) | `button[aria-label="Edit media"]` / `button[aria-label="Remove media"]` |
| 验证推文发出 | 访问推文 URL → 查 `[data-testid="tweetText"]` + `img[src*="pbs.twimg.com/media"]` + `a[href*="t.co/"]` |
| 清空文字 | `page.keyboard.press('Control+a')` + `page.keyboard.press('Delete')` |
| 导航 | `goto(url, {waitUntil: 'domcontentloaded'})` |

## 优先调用 `scripts/post-tweet.mjs`(2026 新增)

**⚠️ 不要直接手写上面这些 Playwright 代码。** 改用本目录下新增的封装脚本:

```bash
node scripts/post-tweet.mjs --text "..." --image /path/to/img.png --session 1
```

脚本封装了"click editor → keyboard.insertText → 上传 1 张图 → 截图 → 等确认 → Post →
线上验证 text+image+link 全在"全流程,带返回值。详见 `scripts/post-tweet.mjs` 顶部的
JSDoc / CLI help(`node scripts/post-tweet.mjs --help`)。

## Dispatch Output(由 director-promote 汇总)

完成后回报给 director-promote:
- 推文文案(最终发布的版本,含字符数)
- 用的哪张配图(项目相对路径)
- 发布结果:URL(成功)/ 草稿状态 / 失败原因
- 预览截图路径
