# Platform: 少数派 (sspai.com)

> 由 `director-promote` 的 dispatch 模式调用。原独立 skill `sspai-publish` 已合并到本文件。

通过 playwriter MCP 在 sspai.com/write 编辑器里草拟、上传图片、设置题图,
**最后停在「待发布」状态由用户亲自点发布**。整个流程的关键不在「自动发」,而在四件事:

- 选对**发布通道**(立即发布 vs 投稿编辑部)
- 适配 sspai 自定义的 **CKEditor 5** 编辑器 API
- 内嵌图片必须走 **uploadImage command + base64 File**,不能塞 `<img>` HTML
- 题图替换走的是 **「替换图片」按钮 + filechooser + 「裁切并使用」** 三步

## Required Tools

- `mcp__playwriter__execute` / `mcp__playwriter__reset` — 浏览器自动化
- Node `fs` (通过 playwriter) — 读 PNG → base64 → File 对象

## Prerequisites Check

发布前必须满足:
- playwriter MCP 已加载且当前 tab 已打开 `https://sspai.com/write`
- 用户已在浏览器登录 sspai 账号
- 项目至少备齐:标题、正文素材、3 张以内的内嵌截图(本地路径)、1 张题图(本地路径)
- **题图建议尺寸 1600×1200(4:3)**——sspai 题图按 4:3 裁剪,1280×640 这种 2:1 横图会被裁掉上下

任一不满足:告诉用户缺什么让他们补齐,**不要自己 mock 内容**。

## Core Workflow

### 1. 决策发布通道

| 通道 | 适用 | 代价 |
|---|---|---|
| **立即发布** | 自家项目宣传贴、版本上线、转载分发、短篇分享 | 自家项目自荐**默认走这条**——立刻公开 |
| **投稿编辑部** | 原创深度长文、评测、教程、特约稿件 | 几天到一两周审稿;对作者推自家工具更挑 |

**默认推荐立即发布** 当文章是自家项目宣传贴。

立即发布的文章事后仍有机会被编辑部捞起来精选——「优质文章有机会被精选或收录」不是只有走编辑部那条路才行。

### 2. 起草中文文案

少数派调性硬性要求(与 Appinn 类似但更偏「发布稿」体感):

- 用「这是一个 X」「我做了 X,解决 Y 问题」开头都可以;自家项目要在前两段说清自己是作者
- 痛点切入:先说**用户场景下的具体问题**,再说工具如何解决
- **结构清晰**:建议 6-8 个 H2 小节(功能拆解 + 安装 + 反馈渠道)
- **不要堆超链接**:正文链接控制在 3-5 条
- **禁用过度营销词**:「神器」「秒杀」「吊打」「黑科技」等会被读者反感
- 功能点列表化时,**优先「H2 + 一段话」而不是 bullet list 堆叠**——sspai 排版偏长文阅读

### 3. 准备图片素材

- **题图**:1600×1200 PNG,全画布构图(不要白边或圆角,sspai 渲染会再裁一次)
- **内嵌截图**:建议每张 1280×800 左右,PNG / JPG,3 张以内为宜
- 在正文里**先留占位段**,文字写「图片占位:xxx」,方便后续脚本通过文本匹配定位插入点

### 4. **用户确认门**(不可跳过)

把以下内容呈现给用户:
- 标题
- 完整正文 HTML(含「图片占位」段)
- 选定的发布通道(立即发布 / 投稿编辑部) + 该通道说明
- 题图路径 + 内嵌图片路径列表

**等用户明确说「确认 / OK / 发吧」再进入第 5 步**。如果用户提修改意见,回到第 2 步。

未经确认就操作编辑器是这个 dispatch 最严重的违规——见 Red Flags。

### 5. 填标题

```js
document.querySelector('input[placeholder*="标题"]').value = title;
document.querySelector('input[placeholder*="标题"]').dispatchEvent(new Event('input', {bubbles:true}));
```

或用 playwriter 的 fill 接口直接打到标题输入框。

### 6. 灌正文 HTML(CKEditor setData)

sspai 的正文编辑器是 customized CKEditor 5:

```js
const ed = document.querySelector('.ck-editor__editable').ckeditorInstance;
ed.setData(htmlString);
```

**playwriter MCP 单行代码约束**:单次 `mcp__playwriter__execute` 不接受多行 JS,
且对长字符串会截断。把 HTML 分段塞到 `state.<key>` 上,最后拼接:

```js
state.h1 = '<h2>...</h2><p>...</p>';
state.h2 = '<h2>...</h2><p>...</p>';
state.html = state.h1 + state.h2;
document.querySelector('.ck-editor__editable').ckeditorInstance.setData(state.html);
```

### 7. 插入内嵌图片(uploadImage command)

**不要**直接在 setData 的 HTML 里写 `<img src="data:..." />`——CKEditor 会把它当 unsupported
content 删掉或转成空段。

正确做法:先在文中放占位段(「图片占位:card view」),通过 Node fs 读 PNG → base64 →
在浏览器里组装 `File` 对象 → 调用 `uploadImage` command:

```js
// browser side
const b64 = '<from-node-fs>';
const bytes = atob(b64);
const arr = new Uint8Array(bytes.length);
for (let i = 0; i < bytes.length; i++) arr[i] = bytes.charCodeAt(i);
const file = new File([arr], 'card.png', { type: 'image/png' });
const ed = document.querySelector('.ck-editor__editable').ckeditorInstance;
ed.execute('uploadImage', { file: [file] });
```

上传成功后图片会被插到**当前选区位置**,不是占位段所在位置。常见做法:

1. 先把所有图片上传完(不用管位置)
2. 遍历 root 的子节点,把含「图片占位」文本的段删掉:

```js
const root = ed.model.document.getRoot();
ed.model.change(writer => {
  for (let i = root.childCount - 1; i >= 0; i--) {
    const node = root.getChild(i);
    let txt = '';
    for (const c of node.getChildren()) txt += c.data || '';
    if (txt.includes('图片占位')) writer.remove(node);
  }
});
```

**必须从后往前删**——索引会变。

### 8. 上传题图

题图 UI 不在 CKEditor 里,是页面上独立的上传区。流程是三步:

1. 点 `.upload-image-container button:has-text("替换图片")` 唤起文件选择器
2. 等 filechooser 事件,`setFiles([coverPath])`
3. 等裁切弹窗,点 `button:has-text("裁切并使用")` 确认

```js
const fileChooserPromise = page.waitForEvent('filechooser');
await page.click('.upload-image-container button:has-text("替换图片")');
const fileChooser = await fileChooserPromise;
await fileChooser.setFiles(coverPath);
await page.waitForSelector('button:has-text("裁切并使用")');
await page.click('button:has-text("裁切并使用")');
```

**别用 `.upload-input` 的 setInputFiles 直接替换** —— 那条路径不会触发裁切弹窗,最终成图比例错乱。

### 9. 停在待发布状态

正文、图片、题图都到位后,**不要点发布按钮**。把以下信息报告给用户:

- 当前编辑器状态(标题、正文行数、图片数、题图)
- 推荐的发布通道(立即发布 / 投稿编辑部) + 理由
- 让用户**自己**点对应按钮

少数派发布是单向、公开、立刻可见的操作(立即发布通道),由 agent 替按是最高风险动作——
必须由用户手动确认。

## Red Flags — STOP

出现以下情况立即停下:

- 想要「先把图传完再让用户确认」——不行,确认门在第 4 步,操作编辑器之前
- 想自动点「发布」按钮——**永远不要**,无论用户之前是否说过「就这样发吧」,
  发布的最后一击必须由用户本人完成
- 内嵌图片想用 `<img src="data:image/png;base64,...">` 塞 setData——CKEditor 会丢弃
- 题图用 `<input>.setInputFiles()` 而不点「替换图片」按钮——不会走裁切流程,比例错
- playwriter 报 `No Playwright pages are available`——不要重试,让用户重连扩展
- 用户说「差不多就行」——不是明确确认,再问一次「标题、正文、题图都 OK 吗?发哪个通道?」
- 想把内容直接发到「投稿编辑部」——除非用户文章是深度评测/教程/特约稿件,否则默认走立即发布

## Common Mistakes

| 错误 | 修正 |
|---|---|
| `setData` 一次塞超长 HTML 被 playwriter 截断 | 拆 `state.h1 / h2 / h3` 后拼接,再 `setData(state.html)` |
| 内嵌图片直接写 `<img>` HTML | 走 `uploadImage` command + 浏览器内构造 `File` |
| `uploadImage` 后图片位置不对 | 先全部上传,再扫 root 删占位段(从后往前) |
| 题图用 setInputFiles 跳过裁切 | 点「替换图片」按钮 + filechooser + 「裁切并使用」 |
| 题图用 1280×640 (2:1) | 改用 1600×1200 (4:3),与 sspai 渲染裁剪比一致 |
| 自家项目宣传贴想走投稿编辑部 | 默认走立即发布;想走编辑部要先把行文改成「使用心得 / 评测」体感 |
| Agent 替用户点了发布按钮 | **永远禁止**——停在编辑器、报告状态、由用户点 |

## Real-World Reference

成功案例:Ext Helper(浏览器扩展管理器)首发宣传贴
- 通道:立即发布
- 内嵌图:3 张(card / bisect / rules)
- 题图:1600×1200 自定义 promo 海报
- 流程:起草 → 用户确认 → setData 正文 → uploadImage × 3 → 删占位段 → 题图替换 → 停在待发布 →
  用户审阅后自己点发布

## Dispatch Output(由 director-promote 汇总)

完成后回报给 director-promote:
- 选定通道(立即发布 / 投稿编辑部)
- 当前编辑器状态(标题、正文段数、图片数、题图)
- 状态:**编辑器待发布**(由用户最后点) / 失败原因
- 不要返回"已发布" — 本平台永远不替用户点发布
