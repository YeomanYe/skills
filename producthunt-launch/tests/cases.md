# producthunt-launch 测试用例

## 测试类型：Reference Skill（检索 + 正确应用）

---

## Case 1：正例触发 — 自动化 PH 发布

**场景**：用户说"用 playwriter 帮我在 Product Hunt 上提交一个新产品"

**预期行为**：
- 触发本 skill
- 从 `/posts/new/submission` 开始，而不是其他步骤 URL
- 使用 `page.fill()` 而非 `page.type()`
- 使用"Next step: X"按钮导航步骤，而不是 `click('text=Makers')`
- 用 `evaluate()` 选择 Launch tag，而不是 ArrowDown+Enter

**反例（不应出现的行为）**：
- `page.click('text=Makers')` 直接触发顶部导航
- `page.goto('https://www.producthunt.com/posts/new/images-media')` 直接 navigate 到媒体步骤（会 404）
- `page.type()` 填写 description

---

## Case 2：反例触发 — 普通网页自动化

**场景**：用户说"用 playwriter 帮我自动填写 GitHub issue 表单"

**预期行为**：
- 不触发本 skill（PH 特定陷阱与 GitHub 表单无关）
- 正常使用 Playwright API

---

## Case 3：主流程成功 — 全步骤导航

**场景**：用户已经在 `/posts/new/submission` 页面，需要完成所有步骤

**预期行为**：
- 按照 `submission → Images and media → Makers → Shoutouts → Extras → Launch checklist` 顺序
- 每步使用 `button:has-text("Next step: X")` 导航
- Thumbnail 提示用户手动上传，而不是静默调用 `setInputFiles`
- Gallery 图片用 `setInputFiles` + `waitForTimeout(5000)` 上传

---

## Case 4：护栏场景 — Thumbnail 上传

**场景**：任务要求"上传 thumbnail 图片到 `#file-input-thumbnailImageUuid`"

**预期行为**：
- 不使用 `setInputFiles` 在 thumbnail input 上（会静默失败）
- 告知用户手动上传，或使用"Paste a URL"替代
- 明确说明为什么不能自动化这一步

**反例（不应出现的行为）**：
- 调用 `setInputFiles` 然后声称上传成功（静默失败）

---

## Case 5：护栏场景 — tag 选择时的 Enter 键

**场景**：选择 "Developer Tools" launch tag

**预期行为**：
- 搜索后用 `evaluate()` 点击下拉选项
- 不使用 `ArrowDown + Enter`（会提交整个表单，跳到下一步）

---

## 评估标准

| 用例 | 通过条件 |
|------|---------|
| Case 1 | 正确触发 skill，使用安全操作模式 |
| Case 2 | 未触发 skill |
| Case 3 | 全步骤按正确顺序完成，thumbnail 有正确提示 |
| Case 4 | 未使用 `setInputFiles` on thumbnail input |
| Case 5 | 未使用 `ArrowDown + Enter` 选 tag |
