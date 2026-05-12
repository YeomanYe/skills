---
name: producthunt-launch
description: Use when automating Product Hunt launch submission with playwriter or playwright — especially when the form keeps navigating away, dropdown selections jump to top nav, text input scrambles, or file upload silently fails. 用 playwriter/playwright 自动化操作 Product Hunt 发布表单时使用。
---

# Product Hunt 发布自动化

## Overview

Product Hunt 的发布表单有大量反自动化陷阱：顶部导航与表单内容同名，会拦截通用选择器；多步骤表单不能直接 navigate；Thumbnail 上传被安全保护拦截。本 skill 记录实测可用的操作路径。

## 快速参考：高危 vs 安全

| 操作 | ❌ 危险 | ✅ 安全 |
|------|---------|---------|
| 导航到下一步 | `click('text=Makers')` 触发顶部导航 | `click('button:has-text("Next step: Makers")')` |
| 选择 tag | `ArrowDown + Enter` 提交整个表单 | `evaluate()` 直接点击下拉选项 |
| 填写文本 | `page.type()` 字符乱序 | `page.fill()` |
| 页面滚动 | `scrollTo(0, body.scrollHeight)` 可能触发导航 | `scrollBy(0, 400)` |
| 恢复草稿 | `click('a:has-text("Ext Helper")')` | `click('button:has-text("Ext Helper")')` |

## 表单步骤顺序

只有 `/posts/new/submission` 可以直接 navigate，其余步骤必须点"Next step"按钮：

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
// evaluate 点击，避免触发顶部导航
await page.evaluate(() => {
  const opts = document.querySelectorAll('[class*="option"], li, [role="option"]')
  for (const o of opts) {
    if (o.textContent?.trim() === 'Browser Extensions') { o.click(); break }
  }
})
// 每次搜索新 tag 前先清空
await tagInput.fill('')
```

### Description 填写（限 500 字符）

```js
await page.fill('textarea', desc)
const count = await page.$eval('textarea', el => el.value.length)
// count 必须 <= 500，否则 PH 截断或报错
```

### Gallery 图片上传（可用）

```js
const galleryInput = await page.$('#file-input-media')
await galleryInput.setInputFiles([
  '/path/to/screenshot-1.png',
  '/path/to/screenshot-2.png',
])
await page.waitForTimeout(5000) // 等待上传完成
```

### Thumbnail 上传（受安全保护）

`setInputFiles` 在 `#file-input-thumbnailImageUuid` 上**静默失败**——调用成功但图片不实际上传。

替代方案：
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

### Extras（Pricing）

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

**Cloudflare 验证**：快速导航可能触发验证页面，必须让用户手动完成后再继续。

```js
await page.screenshot({ path: '/tmp/check.png' }) // 检查是否出现验证
```

**迷失导航后恢复**：

```js
await page.goto('https://www.producthunt.com/posts/new/submission')
await page.waitForTimeout(2000) // PH 自动恢复草稿数据
```

## 其他注意事项

- **草稿恢复入口**：`/posts/new` 显示草稿按钮是 `<button>` 而非 `<a>`
- **Launch Checklist**：Required 项全绿才能发布；Thumbnail 缺失时 PH 用默认字母图标，不阻塞发布
- **推荐发布时间**：太平洋时间周二或周三 00:01（PH 每日榜在太平洋时间 0 点重置）
