# Platform: Product Hunt

> 由 `director-promote` 的 dispatch 模式调用。原独立 skill `producthunt-launch` 已合并到本文件。

Product Hunt 的发布表单有大量反自动化陷阱:顶部导航与表单内容同名,会拦截通用选择器;
多步骤表单不能直接 navigate;Thumbnail 上传被安全保护拦截。本模块记录实测可用的操作路径。

## Required Tools

- `mcp__playwriter__execute` / `mcp__playwriter__reset` — 浏览器自动化
- 用户已登录 producthunt.com 账号

## Prerequisites Check

发布前必须:
- playwriter MCP 已加载,至少一个 tab 在 producthunt.com
- 用户已登录 PH(可通过页面右上角头像 / `document.querySelector('[data-test="user-avatar"]')` 验证)
- 项目已备好:产品名 / Tagline / Description(≤ 500 字符)/ Gallery 图(5 张内)/ Thumbnail / 至少一个 Topic
- 已选好发布时间(推荐**太平洋时间周二或周三 00:01**,PH 每日榜在 PT 0 点重置)

## 快速参考:高危 vs 安全

| 操作 | ❌ 危险 | ✅ 安全 |
|------|---------|---------|
| 导航到下一步 | `click('text=Makers')` 触发顶部导航 | `click('button:has-text("Next step: Makers")')` |
| 选择 tag | `ArrowDown + Enter` 提交整个表单 | `evaluate()` 直接点击下拉选项 |
| 填写文本 | `page.type()` 字符乱序 | `page.fill()` (**Tagline / Title 用 fill**) |
| 文本输入仍乱 | `page.fill()` 在某些 field 仍乱(已知 PH bug) | 退化为 `page.type()` 慢速 ≥50ms 间隔 |
| 页面滚动 | `scrollTo(0, body.scrollHeight)` 可能触发导航 | `scrollBy(0, 400)` |
| 恢复草稿 | `click('a:has-text("产品名"))` | `click('button:has-text("产品名"))` |

## 表单步骤顺序

只有 `/posts/new/submission` 可以直接 navigate,其余步骤必须点 "Next step" 按钮:

```
submission → Images and media → Makers → Shoutouts → Extras → Launch checklist
```

```js
await page.click('button:has-text("Next step: Images and media")')
await page.click('button:has-text("Next step: Makers")')
await page.click('button:has-text("Next step: Shoutouts")')
await page.click('button:has-text("Next step: Extras")')
await page.click('button:has-text("Next step: Launch checklist")')
```

## 关键操作模式

### Launch Tags 选择

```js
const tagInput = await page.$('input[placeholder="Select a launch tag"]')
await tagInput.focus()
await page.keyboard.type('Browser')
await page.waitForTimeout(1000)
// evaluate 点击,避免触发顶部导航
await page.evaluate(() => {
  const opts = document.querySelectorAll('[class*="option"], li, [role="option"]')
  for (const o of opts) {
    if (o.textContent?.trim() === 'Browser Extensions') { o.click(); break }
  }
})
// 每次搜索新 tag 前先清空
await tagInput.fill('')
```

### Description 填写(限 500 字符)

```js
await page.fill('textarea', desc)
const count = await page.$eval('textarea', el => el.value.length)
// count 必须 <= 500,否则 PH 截断或报错
```

### Gallery 图片上传(可用)

```js
const galleryInput = await page.$('#file-input-media')
await galleryInput.setInputFiles([
  '/path/to/screenshot-1.png',
  '/path/to/screenshot-2.png',
])
await page.waitForTimeout(5000) // 等待上传完成
```

### Thumbnail 上传(受安全保护)

`setInputFiles` 在 `#file-input-thumbnailImageUuid` 上**静默失败**——调用成功但图片不实际上传。

替代方案:
- 让用户手动点击 "Select an image"
- 或使用 "Paste a URL" 填入公开可访问的图片 URL

### Makers 步骤

```js
await page.evaluate(() => {
  const radios = document.querySelectorAll('input[type="radio"]')
  for (const r of radios) {
    const wrapper = r.closest('label, div')
    if (wrapper?.textContent?.includes('I worked on this product')) { r.click(); return }
  }
})
```

### Extras(Pricing)

```js
await page.evaluate(() => {
  const radios = document.querySelectorAll('input[type="radio"]')
  for (const r of radios) {
    const wrapper = r.closest('label, div')
    if (wrapper?.textContent?.includes('Free') && wrapper?.textContent?.includes('free to use')) {
      r.click(); return
    }
  }
})
```

## 常见陷阱与恢复

**Cloudflare 验证**:快速导航可能触发验证页面,必须让用户手动完成后再继续。

```js
await page.screenshot({ path: '/tmp/check.png' }) // 检查是否出现验证
```

**迷失导航后恢复**:

```js
await page.goto('https://www.producthunt.com/posts/new/submission')
await page.waitForTimeout(2000) // PH 自动恢复草稿数据
```

## 其他注意事项

- **草稿恢复入口**:`/posts/new` 显示草稿按钮是 `<button>` 而非 `<a>`
- **Launch Checklist**:Required 项全绿才能发布;Thumbnail 缺失时 PH 用默认字母图标,不阻塞发布
- **推荐发布时间**:太平洋时间周二或周三 00:01(PH 每日榜在太平洋时间 0 点重置)

## Red Flags(本平台特有,override 主 SKILL.md 时优先)

- **跳过 Launch Checklist Required 项就 publish** — PH 会拒,且草稿状态不可逆
- **未经用户确认直接点 Publish** — 必须截图给用户看完整 Listing preview 后才发
- **用户已设定 schedule 但用立即发布** — 会破坏 GoToMarket 时间窗
- **多次切换标签页导致草稿丢失** — PH 草稿恢复在 /posts/new 但有时延,切错就丢
- **截图含其他用户 / 隐私信息** — 发布前必须裁掉(同主 SKILL.md 9 维 #5)
- **未在 dev tools 关掉 GoogleAnalytics 等 Playwright 检测** — PH 反爬可能直接 ban
- **用同一 IP 反复提交** — PH 风控会标记账号

## Common Failure Modes

### 1. 文本输入被打乱(典型 PH bug)
处理:用 `page.type()` 一字一字慢速输入,间隔 ≥ 50ms;不要 `page.fill()` 一次性塞。
**注**:跟"快速参考表"里 `page.fill()` 安全的建议有出入——实际是**字段相关**:
Tagline / Title 通常 `fill()` OK,Description / Long-form 字段触发率高,首选 `type()` 慢速。

### 2. 下拉选择跳到顶部导航
处理:点击下拉前先 `page.locator('selector').scrollIntoViewIfNeeded()`,再用 keyboard 输入过滤。

### 3. 文件上传"上传成功"但其实失败
处理:上传后 `await page.waitForSelector('[data-uploaded]', {timeout: 10000})`,超时即重试。

### 4. 表单导航莫名跳走
处理:每填一个 field 立刻 `page.evaluate(() => window.scrollY)` 记位置,
跳走立刻 `goBack` + 重读草稿。

## Dispatch Output(由 director-promote 汇总)

完成后回报给 director-promote:
- 产品名称
- 计划发布时间(PT 周二/周三 00:01 推荐)
- 表单填写各步状态:
  - Step 1 基本信息: pass / fail(含 Tagline / Description / Topics)
  - Step 2 媒体: pass / fail(gallery / 视频 / thumbnail)
  - Step 3 Makers: pass / fail
  - Step 4 Extra: pass / fail(pricing / launch date)
- Draft ID / URL
- Required 项全绿: yes / no(缺哪些)
- 实际状态: `draft-only` / `scheduled` / `published`(由用户最后点 Publish 决定)
- 已踩的坑及恢复方式
- 草稿页 final screenshot 路径
