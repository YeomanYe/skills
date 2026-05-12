# Discourse REST API 速查（meta.appinn.net）

所有调用都通过 playwriter `page.evaluate()` 在已登录的浏览器上下文中跑——这样自动带上 cookie 和 session。**不要**用本地 curl 或 fetch（没有 session）。

## 共用：CSRF token

每次写操作（POST/PUT/DELETE）都需要从页面读 CSRF：

```js
const csrf = document.querySelector('meta[name="csrf-token"]').content;
```

如果 `meta[name="csrf-token"]` 返回 null：页面可能还在加载或用户已退出，先 `page.reload()` 再读。

## 1. 拉板块列表

```js
page.evaluate(async () => {
  const r = await fetch('/categories.json', {headers:{'Accept':'application/json'}});
  const j = await r.json();
  return j.category_list.categories.map(c => ({id: c.id, name: c.name, slug: c.slug, topic_count: c.topic_count}));
})
```

## 2. 验证已登录

```js
page.evaluate(() => {
  const u = document.querySelector('#current-user');
  return { loggedIn: !!u, avatar: document.querySelector('#current-user img')?.src };
})
```

`loggedIn === false` → 中止流程，让用户登录。

## 3. 上传图片（URL 来源）

来自公网 URL（如 GitHub Pages 已部署的截图）：

```js
page.evaluate(async () => {
  const csrf = document.querySelector('meta[name="csrf-token"]').content;
  const url = 'https://yeomanye.github.io/ext-helper/screenshots/screenshot-card.png';
  const blob = await (await fetch(url)).blob();
  const fd = new FormData();
  fd.append('file', blob, 'screenshot-card.png');
  fd.append('type', 'composer');
  fd.append('synchronous', 'true');
  const r = await fetch('/uploads.json', {
    method: 'POST',
    headers: {'X-CSRF-Token': csrf, 'Accept': 'application/json'},
    credentials: 'include',
    body: fd
  });
  return await r.json();
})
```

返回值关键字段：
- `short_url`：形如 `upload://abc.jpeg`，写帖子时用
- `width` / `height`：用于换算 `![alt|宽x高](upload://...)` 中的高度
- `original_filename`：服务器可能转码（PNG → JPEG），以这个为准

## 4. 上传图片（本地路径来源）

浏览器无法直接读本地文件，需要先在 shell 把文件 base64 编码，再注入到 page.evaluate：

```bash
base64 -i path/to/image.png > /tmp/img.b64
```

```js
// 把 b64 内容作为字符串注入（playwriter execute 支持较大 payload）
page.evaluate(async (b64) => {
  const csrf = document.querySelector('meta[name="csrf-token"]').content;
  const bin = atob(b64);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
  const blob = new Blob([arr], {type: 'image/png'});
  const fd = new FormData();
  fd.append('file', blob, 'image.png');
  fd.append('type', 'composer');
  fd.append('synchronous', 'true');
  const r = await fetch('/uploads.json', {
    method: 'POST',
    headers: {'X-CSRF-Token': csrf, 'Accept': 'application/json'},
    credentials: 'include',
    body: fd
  });
  return await r.json();
}, b64Content)
```

**优先用 URL 来源**，更简单。只有本地图未发布到公网时才用 base64 路径。

## 5. 创建主题（发新帖）

```js
page.evaluate(async () => {
  const csrf = document.querySelector('meta[name="csrf-token"]').content;
  const r = await fetch('/posts.json', {
    method: 'POST',
    headers: {'Content-Type':'application/json', 'X-CSRF-Token': csrf, 'Accept':'application/json'},
    credentials: 'include',
    body: JSON.stringify({
      title: '...',
      raw: '...',
      category: 10,             // faxian=10, alpha=82
      archetype: 'regular'
    })
  });
  return {status: r.status, body: await r.json()};
})
```

### 响应分支

**A. 直接发布（alpha 板块）**：
```json
{
  "id": 318895,
  "topic_id": 84782,
  "topic_slug": "topic",
  "post_number": 1,
  "raw": "...",
  ...
}
```
→ topic URL: `https://meta.appinn.net/t/topic/<topic_id>` 或带 slug

**B. 进入审核队列（faxian 板块）**：
```json
{
  "action": "enqueued",
  "success": true,
  "pending_count": 1,
  "pending_post": {
    "id": 32153,
    "raw": "...",
    "created_at": "..."
  }
}
```
→ 没有 topic_id，告知用户等待审核，**不要**重发。

## 6. 编辑已有帖子

```js
page.evaluate(async () => {
  const csrf = document.querySelector('meta[name="csrf-token"]').content;
  const r = await fetch(`/posts/${POST_ID}.json`, {
    method: 'PUT',
    headers: {'Content-Type':'application/json', 'X-CSRF-Token': csrf, 'Accept':'application/json'},
    credentials: 'include',
    body: JSON.stringify({post: {raw: '...新正文...', edit_reason: '补充截图'}})
  });
  return await r.json();
})
```

返回 `{post: {id, version}}`，`version` 自增 1 表示成功。

注意：审核队列中的 pending_post **不能**用这个端点编辑，要等通过审核生成正式 post 后再改。

## 7. 拉主题详情

```js
page.evaluate(async () => {
  const r = await fetch(`/t/${TOPIC_ID}.json`, {headers:{'Accept':'application/json'}, credentials:'include'});
  const j = await r.json();
  const p = j.post_stream.posts[0];
  return {topic_id: j.id, title: j.title, post_id: p.id, can_edit: p.can_edit};
})
```

`post_id` 是写操作（编辑、删除）需要的 ID，跟 `topic_id` 不一样。

## 8. 拉自己的待审核帖子

```js
page.evaluate(async () => {
  const csrf = document.querySelector('meta[name="csrf-token"]').content;
  const r = await fetch('/review.json?status=pending', {
    headers: {'Accept': 'application/json', 'X-CSRF-Token': csrf},
    credentials: 'include'
  });
  return await r.json();
})
```

用于检查 enqueued 帖是否已审核通过、被拒、还是仍在排队。

## 字段速查

| 字段 | 含义 |
|---|---|
| `topic_id` | 主题 ID（URL 用这个） |
| `post_id` / `id` | 单条帖子 ID（编辑用这个） |
| `category` | 板块 id（提交用） |
| `archetype` | `regular` 普通主题 / `private_message` 私信 |
| `raw` | markdown 源（提交和编辑用） |
| `cooked` | 渲染后的 HTML（不要写，只读） |
| `can_edit` | 当前用户是否能编辑此帖 |
| `version` | 编辑次数计数 |
