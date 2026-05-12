# 故障排查

## playwriter 断线

### 症状

`page.evaluate()` 报：
```
Error: No Playwright pages are available. Enable Playwriter on a tab or set PLAYWRITER_AUTO_ENABLE=1 to auto-create one.
```

或：
```
HINT: If this is an internal Playwright error, page/browser closed, or connection issue, call reset to reconnect.
```

### 处理

1. **不要重试 API 调用**——会一直失败
2. 告诉用户：**"playwriter 和论坛标签页断了连接，请在浏览器里点一下 appinn 标签页上的 playwriter 扩展图标重新启用，启用后告诉我继续"**
3. 等用户回复"继续 / 已启用 / 好了"
4. 用 `page.url()` 验证连上了正确的标签页（应该是 meta.appinn.net 域名）
5. 必要时调用 `mcp__playwriter__reset` 重建连接

### 不要做的事

- 不要每次断线就 reset——会清空 state 里的临时数据（如已上传的 short_url 列表）
- 不要假定用户没看到提示就反复发 API 探活

## CSRF token 失败

### 症状

POST/PUT 返回 403 或 `{"errors":["CSRF token expired"]}`。

### 处理

1. `page.reload({waitUntil:'domcontentloaded'})` 让页面重新拉一遍 token
2. 重新读 `meta[name="csrf-token"]`
3. 重试请求

如果 reload 后仍然失败：检查用户是否仍处于登录态（`#current-user` 元素）。可能 session 已过期，需要重新登录。

## 图片上传失败

### 症状 A：返回 `{"errors": ["File too large"]}`

Discourse 默认单文件上限通常是 4MB。

处理：
1. 告诉用户具体哪张图过大
2. 建议用 `pngquant` 或在线工具压缩到 < 2MB
3. 或者跳过这张图

### 症状 B：返回 200 但没有 short_url

服务器接受了但还没处理完。检查响应里是否有 `pending` 字段。处理：
- 加 `synchronous: true` 表单字段（强制等到处理完才返回）
- 或者轮询 `/uploads/{id}.json` 检查状态

### 症状 C：服务器返回 short_url，但帖子里图片不显示

最常见原因：在 `![](url)` 的 `url` 部分用了完整 URL（如 `https://h2cdn.appinn.me/...`）而不是 `upload://` 短链。

处理：始终用 `upload://hash.ext` 形式，让 Discourse 自己渲染成 CDN URL。

## 发帖失败

### 症状 A：`{"errors": ["Title is too short"]}` / `["Body is too short"]`

Discourse 有最小长度限制（标题约 ≥ 15 字符，正文约 ≥ 20 字符）。

处理：扩充标题或正文，**不要**靠重复字符或填空白绕过——会被识别为低质量。

### 症状 B：`{"errors": ["You have included too many links"]}`

新用户或低等级用户有外链数量限制（通常每帖 ≤ 2-3 条外链）。

处理：
1. 减少外链（最多保留商店 + 源码两条）
2. 把次要链接改为不带 https:// 的纯文本（如 `项目主页：example.github.io/proj`，可点性差但合规）
3. 或者用裸域名提示用户去 Google 搜

### 症状 C：`{"action":"enqueued", ...}` 后用户反复问"为什么没看到"

这是 faxian 板块的**正常状态**，不是错误。

处理：
1. 解释：发现频道走人工审核，几小时到几天
2. 提供 pending_post.id，用户可以在 https://meta.appinn.net/review 自己查看（如果有 trust level 权限）
3. **不要重发**——会被判重复或合并

如果超过 3 天还没审核：
- 可以让用户在 https://meta.appinn.net/about 上联系版主
- 不要从 skill 这边自动 ping 版主

## enqueued 状态判定

不要简单用 HTTP status 判断成功，要看 body：

| `action` 值 | 含义 |
|---|---|
| `create_post` | 直接发布成功，有 topic_id |
| `enqueued` | 进入审核队列，pending_post.id 但无 topic_id |
| 其他 | 检查 errors 字段 |

```js
const data = await response.json();
if (data.action === 'enqueued') {
  // 走"审核中"分支
} else if (data.topic_id) {
  // 走"已发布"分支
} else {
  // 走"失败"分支，显示 data.errors
}
```

## 重复发帖怎么办

如果不小心发了两遍（或 enqueued 后又发了一次普通版本）：

1. **不要继续发**
2. 列出当前用户的所有帖：
   ```js
   page.evaluate(async () => {
     const r = await fetch('/u/<username>/activity.json');
     return await r.json();
   })
   ```
3. 删除其中一份：`DELETE /t/{topic_id}.json` 或 `DELETE /posts/{post_id}.json`
4. 如果是 pending_post 重复了：通过 `/review.json` 找到那条 reviewable，调 `PUT /review/{id}/perform/reject_post` 自己撤回

但更好的做法是：**第一次就别发重**。enqueued 状态明确就是已经在队列里。
