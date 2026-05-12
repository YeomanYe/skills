# sspai 编辑器 API（CKEditor 5 customized）

sspai 的 `https://sspai.com/write` 用的是定制版 CKEditor 5。本文件记录实战中验证可用的 API。

## 拿到编辑器实例

```js
const ed = document.querySelector('.ck-editor__editable').ckeditorInstance;
```

`.ck-editor__editable` 是 CKEditor 给编辑区根元素挂的 class；`ckeditorInstance` 是 CKEditor 5 暴露的 DOM → Editor 反向引用。

如果拿不到，常见原因：
- 页面还没加载完，等 `.ck-editor__editable` 出现再取
- 用户没登录，`/write` 重定向到登录页了
- sspai 改版（少见，但要警惕）

## 灌正文：setData

```js
ed.setData('<h2>...</h2><p>...</p>');
```

注意：
- 接受 HTML string
- 不支持的 inline tag（如 `<img src="data:..." />`）会被丢弃或转空段
- 不要塞 base64 图片，详见下文 uploadImage

### 拼长 HTML 的 playwriter 模式

`mcp__playwriter__execute` 一次只接受单行 JS。塞长 HTML 必须先拆段、用 `state.<key>` 跨调用持久化、最后拼接：

```js
// call 1
state.h1 = '<h2>第一节</h2><p>...</p>';
// call 2
state.h2 = '<h2>第二节</h2><p>...</p>';
// call 3
state.h3 = '<h2>第三节</h2><p>...</p>';
// call N
state.html = state.h1 + state.h2 + state.h3;
// call N+1
document.querySelector('.ck-editor__editable').ckeditorInstance.setData(state.html);
```

### getData 验证

```js
document.querySelector('.ck-editor__editable').ckeditorInstance.getData().length;
```

确认正文已写入：长度大于 0、包含关键 H2 文字。

## 内嵌图片：uploadImage command

**这是 sspai 内嵌图片唯一可靠方式**。

```js
const file = new File([uint8Array], 'card.png', { type: 'image/png' });
ed.execute('uploadImage', { file: [file] });
```

注意 `file` 字段是 **数组**——CKEditor 5 upload command 支持一次插入多张。

### 浏览器内组装 File 对象

playwriter 从本地 PNG 读 base64 → 注入浏览器 → atob 还原：

```js
// 主进程 Node 侧
const b64 = fs.readFileSync('card.png').toString('base64');
state.b64_card = b64;

// 浏览器侧
const bytes = atob(state.b64_card);
const arr = new Uint8Array(bytes.length);
for (let i = 0; i < bytes.length; i++) arr[i] = bytes.charCodeAt(i);
const file = new File([arr], 'card.png', { type: 'image/png' });
const ed = document.querySelector('.ck-editor__editable').ckeditorInstance;
ed.execute('uploadImage', { file: [file] });
```

### 上传后的位置

`uploadImage` 把图片插到**当前 selection 所在位置**。如果 selection 不在你想要的位置（默认在文档末尾或上次的位置），图片会插错。

实战可靠做法：**先无视位置全部上传，再扫 root 删占位段**。

## 删占位段（model.change writer.remove）

```js
const ed = document.querySelector('.ck-editor__editable').ckeditorInstance;
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

关键点：

- **从后往前**遍历——`writer.remove` 改变 `childCount`，从前往后会跳号
- 所有删除操作必须包在 `ed.model.change(writer => { ... })` 里——这是 CKEditor 5 的事务边界，不在里面会抛异常
- 用文本子串匹配（如 "图片占位"）比 attribute 匹配更稳

## 拿不到 ckeditorInstance 的兜底

如果 `.ck-editor__editable` 上拿不到 `ckeditorInstance`（极少见，可能是 sspai 升级了 CKEditor 版本或换了挂法）：

1. 在 console 试 `document.querySelectorAll('.ck-editor__editable')`，看有没有多个匹配
2. 试 `.ck-content`、`.ck-editor__main` 等其他 class
3. 找页面 globals：`Object.keys(window).filter(k=>/edit/i.test(k))`
4. 实在找不到——降级让用户手工粘贴正文，本 skill 只负责图片和题图

## 不要做的

- 不要 `setData` 包含 `<img>` 的 HTML，会被丢
- 不要 `setData` 后立刻 `uploadImage`——给 setData 一点时间渲染（200-500ms）
- 不要在 `model.change` 外面调 `writer.remove`/`writer.insert`——会抛
- 不要相信 `ed.execute('uploadImage', {...})` 返回值——是 void，要靠 `getData()` 或扫 root 验证
