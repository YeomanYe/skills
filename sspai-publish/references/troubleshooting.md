# sspai-publish 故障排查

## playwriter 报 `No Playwright pages are available`

意味着浏览器扩展掉线或没绑定到当前 tab。

**不要**重试 API、不要重启 playwriter，先让用户：

1. 在 Chrome 里打开一个新 tab，确保是 active 的
2. 在 playwriter 扩展里**重新绑定**（点击扩展图标 → 选当前 tab）
3. 确认 `https://sspai.com/write` 在 active tab 里
4. 重试

如果反复掉线，可能是 sspai 后台 SPA 路由切换导致的——让用户手动 reload 一下 `/write`。

## `setData` 后正文是空的 / 只剩一个段落

**原因**：HTML 里有 CKEditor 不识别的标签或属性，被全部丢弃。

排查：

1. `getData()` 看实际写进去的是什么
2. 检查 HTML 里有没有 `<img>` `<iframe>` `<style>` 等
3. 内嵌图片必须走 `uploadImage`，不要塞 `<img>`

如果 setData 完全没反应：

```js
// 确认实例还在
typeof document.querySelector('.ck-editor__editable')?.ckeditorInstance
// 应该是 'object'
```

## `uploadImage` 调用了但图片没出现

可能原因：

1. **selection 跑到 modal 外**：弹窗 / 别的 input 抢走了焦点。先 `ed.focus()` 再 execute
2. **File 对象损坏**：检查 `file.size > 0`、`file.type` 是 `image/png` 或 `image/jpeg`
3. **网络上传失败**：扫一眼 console / network panel
4. **占位段没删，图插在末尾**：先全部 upload 完再扫 root 删占位段

## 图片插入位置全错

`uploadImage` 插到 selection 当前位置，不是占位段位置。

**可靠做法**：

1. 不管位置，先 `for` 循环把所有图片都 upload 完
2. 全部完成后，扫一遍 `root.childCount`，**从后往前**删带「图片占位」文本的段落
3. 这样图片虽然顺序可能乱，但**段落顺序由图本身在 root 里的索引决定**——通常 upload 顺序和最终顺序一致

如果对图片顺序非常严格：上传后立刻查 `root.childCount - 1` 这一段是不是新图，记下索引；后续可以用 `writer.move()` 调整位置。

## 「替换图片」按钮找不到

页面状态可能是「未上传过」——按钮文字是「上传题图」或类似。

排查：

```js
document.querySelectorAll('.upload-image-container button').forEach(b => console.log(b.textContent));
```

调整 selector：

```js
'button:has-text("替换图片"), button:has-text("上传题图"), button:has-text("替换")'
```

## 「裁切并使用」点了没反应

可能是裁切弹窗 DOM 结构变了，或者裁切区还在加载。

排查：

```js
document.querySelectorAll('button').forEach(b => {
  if (b.textContent.includes('裁切') || b.textContent.includes('使用')) {
    console.log(b.textContent, b);
  }
});
```

如果按钮存在但点了没动作：检查弹窗是否在 iframe 里，如果是要先 frame.locator() 再点。

## state 跨调用丢失

playwriter MCP 的 `state.<key>` 在同一会话内持久化。如果 `state.html` 突然 undefined：

- 检查 playwriter 是否被重启（看 console 有没有 reload 日志）
- 检查上一步是否真的赋值了（每一步赋值后立刻 `console.log(state.html?.length)` 验证）
- 如果 state 真丢了，重新分段塞回去

## 单行约束被截断

playwriter 一次 execute 只接受单行 JS，且对超长字符串会截断。判断标准：

- 如果你的字符串超过 ~3000 字符，**必须**拆段
- 拆完再用 `state.foo + state.bar + state.baz` 拼

不要试图用换行符 / 模板字符串绕过——会被解析失败。

## 发布失败 / 一直转圈

少数派偶尔会有后台问题。如果点「立即发布」转圈超过 30 秒：

1. **不要重复点击**——可能后台已成功，重复点击会出现重复发布
2. 刷新当前页 → 进个人主页看文章是否已发布
3. 如果已发，恭喜；如果没发，30 秒后再试一次
4. 如果反复失败，让用户保存草稿，过段时间再发
