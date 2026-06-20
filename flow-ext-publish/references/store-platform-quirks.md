# 各平台上架细节与工具路由

本文档由 `flow-ext-publish` SKILL.md 引用，存放 Step 4b 实际提交所需的平台细节、工具路由规则和执行约束，不含执行流程主干。

---

## 工具路由规则

| 平台 | 工具 |
|------|------|
| Firefox AMO | `Playwriter`（接管用户已登录的浏览器） |
| Microsoft Edge | `Playwriter`（接管用户已登录的浏览器） |
| Chrome Web Store | 首选 `agent-browser --profile Default`；若 Google 安全策略 / 登录态隔离阻塞，则使用 `cdp-browser-control` 风格的 `scripts/cws-update-submit.mjs` |

**禁止**用普通 Playwriter / Playwright 新开无登录浏览器操作 Chrome Web Store（Google 会拦截自动化导航）。唯一例外是 `cdp-browser-control` 模式：复制真实 Chrome 登录态到临时 profile，再用 CDP 直连。
**禁止**用 agent-browser 操作 Firefox AMO 或 Edge（本流程 Firefox / Edge 固定走 Playwriter）。
**禁止**在 Firefox / Edge 路径上使用 Playwright MCP（`mcp__playwright__*`）或任何新开 chromium 实例的工具 — 那种方式拿不到用户已登录的 Partner Center / AMO 会话，必须通过 `npx playwriter@latest -s <session-id> -e "..."` 接管用户当前浏览器。

---

## Playwriter 执行约束

- 单次 `npx playwriter@latest -s <session-id> -e "..."` 有约 10s 总超时
- 一次 `-e` 内的 `await page.waitForTimeout(...)` 不要超过 ~2.5s
- 长等待必须拆成多次短调用，等待逻辑放在 Bash 端的 `sleep`，不要在 `-e` 内做长 polling
- 切忌为了绕开超时改回 Playwright MCP 新开浏览器，那会丢失登录态

## agent-browser 执行约束（Chrome Web Store）

- Chrome Web Store 必须优先且唯一使用 `npx agent-browser --profile Default ...`
- 若 agent-browser daemon 已运行并提示 `--profile ignored`，先执行 `npx agent-browser close --all`，再用 `--profile Default` 重开
- 打开入口：`npx agent-browser --profile Default open https://chrome.google.com/webstore/devconsole/`
- 若落到 Google 登录页，说明 Default profile 未登录或未复用；停下让用户手动登录这个 profile，不要切换到其他 Chrome 控制工具
- 若 snapshot 命中 Gemini / 侧栏 / 错误 tab，用 `npx agent-browser tab` 列出 tabs，再 `npx agent-browser tab t<N>` 切回 Chrome Web Store Dev Console
- 每次页面变化后刷新 snapshot refs，按最新 refs 点击和上传，不复用旧 ref

## cdp-browser-control 执行约束（Chrome Web Store 维护 / 受阻 fallback）

- 仅用于 Chrome Web Store 已有条目的字段修复、保存草稿、重提审，或 `agent-browser --profile Default` 因 Google 安全策略 / 登录态隔离无法继续时
- 使用 `node scripts/cws-update-submit.mjs ...`；该脚本只启动临时 Chrome，不关闭用户现有 Chrome
- dry-run 不得改字段；实际保存必须显式传 `--save`；实际提审必须显式传 `--submit`
- `--submit` 必须和 `--save` 同时出现，避免提交的草稿不是本次更新值
- 若 CWS 重定向到 Google 登录页，停止并让用户登录源 Chrome profile，不要改用新开 Chromium / Playwright MCP
- CWS 页面 DOM 变更后，先跑 dry-run 验证脚本仍能定位字段，再执行保存或提交

---

## 各平台上架步骤

对每个目标平台，依次执行：

1. **导航**：用对应工具打开该平台的开发者后台
2. **填写商店信息**：name、short description（从 manifest / README 抽取，不得凭空编造）、icon / logo、screenshots、promo tiles / marquee（路径来自 Step 2/3 确认的素材清单）、category、privacy policy URL、permissions justification（`management` 和 `<all_urls>` 等敏感权限必须写）
3. **上传产物 zip**：使用 preflight / Step 2 产出的 zip 路径
4. **提交审核**：点击提交按钮，等待确认页或审核 ID
5. **记录结果**：保存审核 ID / 提交 URL，供最终报告使用

### Firefox AMO

- AMO 的初次提交向导通常只覆盖分发方式、zip 上传、描述、隐私、许可、审核备注和源码附件；它可能**不会**在同一向导里要求 icon / screenshots
- 版本提交完成后，不要立刻把 Firefox 标记为完成；必须进入「管理上架 / 编辑产品页面」并检查「图像」区
- 若「附加组件图标」或「屏幕截图」为空，点击「图像」区的「编辑」，上传 Step 3 确认过的 icon / screenshots，再保存
- 截图上传后必须给每张截图填写说明；说明可以从截图用途生成，保持具体，例如 pause screen / options page / classic layout
- 保存后不要只看 a11y snapshot 的行文字；AMO 的截图缩略图常用 CSS `background-image`，快照可能只显示空行
- 必须用 DOM 验证：
  - icon: `#icon_preview_readonly img` 至少包含 `128/64/32` 三个 AMO 生成图标
  - screenshots: `#edit-addon-media .preview-thumb` 数量与已确认截图数量一致，且 `data-url` 指向 `user-media/previews`
- 若页面显示「正在处理图像更改」，记录为「媒体已上传，AMO 后台处理中」；但必须已经看到 icon URL 和 screenshot preview URL，才能把 Firefox 记为已补齐媒体
- 使用源码构建工具（WXT / Vite / TypeScript / bundler / minifier）时，AMO 源码步骤必须选「是」并上传 source archive；不要把未公开仓库链接填为公开源码 URL

### Chrome Web Store

- 入口：`https://chrome.google.com/webstore/devconsole/`
- 列表页进入目标扩展后，先确认当前 published / draft version，避免把素材上传到错误条目
- 文件包上传：在 Package / 软件包区域上传本次 build zip；若 button 上传失败，查找 `input[type=file][accept*=".zip"], input[type=file][accept*=".crx"]`，确认上下文后再上传
- Store listing 截图 / 宣传图上传：查找 `input[type=file][accept*=".png"], input[type=file][accept*=".jpg"], input[type=file][accept*=".jpeg"]`，必须读取父级区域文字识别槽位，不要盲传第一个 input
- 当前页面常见槽位顺序可能包含 icon / screenshots / small promo / marquee，但顺序不是契约；每次都按 DOM 上下文和尺寸说明确认
- 需要时可用 eval 给已确认的正确 input 临时加 id，然后用 agent-browser upload 对准该 id
- 保存草稿后再提交审核；最终弹窗若出现 auto publish checkbox，按用户要求保留或切换
- 成功信号：出现"已将您的扩展程序提交送审"或状态进入"待审核 / In review"，记录提交 URL 和状态
- 若只是修复隐私政策 URL 等已知字段并重提审，优先用 `scripts/cws-update-submit.mjs --privacy-url <url> --save --submit`，不要顺手触发 build、官网部署或素材生成

### Microsoft Edge Add-ons

**入口与计划注册**

- 提交入口：`https://partner.microsoft.com/en-us/dashboard/microsoftedge/<product-id>/packages/dashboard`
- 若账号未注册 Microsoft Edge 计划，访问 `/dashboard/microsoftedge/overview` 会被重定向回 dashboard 主页
- 最稳的注册入口是 `https://partner.microsoft.com/en-us/dashboard/registration?stage=1&accountProgram=MicrosoftEdge`；aka.ms 短链多数已失效，不要依赖
- 计划注册需用户手动完成（同意条款 / 选择账户类型），不要自动点同意

**表单使用 Microsoft Fluent Web Components（Shadow DOM）**

- 按钮多为 `v6_he-button`，侧边导航 tab 为 `v6_he-task-item[aria-label="<TabName>"]`，外壳是 `HE-SHELL`
- 普通 `button:has-text(...)` 经常拿不到，要改用 `v6_he-button:has-text("Continue")`、`v6_he-task-item[aria-label="Packages"]` 这类「自定义元素 + 文本/属性」选择器

**Store listing 的 4 个上传槽位**

- 页面里有 4 个 `input[type=file][name="fileuploader"]`，分别对应 Extension logo / Small promotional tile / Screenshots / Large promotional tile
- **不要按 `nth(0..3)` 假设顺序**；每个 input 必须往上找父级 label 识别它属于哪一槽位，再按文件实际尺寸匹配
- 顺序错位会被 Edge 在保存时直接拒（例如把 1280×800 传到 1400×560 槽位会报 `File size is incorrect... must be 1400 x 560`）
- 截图槽位的 input **不是 multiple**：3 张 1280×800 必须拆成 3 次 `setInputFiles`，传数组会报 `Non-multiple file input can only accept single file`

**提交流程顺序（侧边 tab）**

- Packages（上传 zip）→ Availability → Properties → Store listings → 回 Extension overview → 顶部 Publish → 填 Certification notes → 再 Publish → 状态变 In review

**Store listing 必填字段**

- name / description / extension logo / small promotional tile / screenshots / large promotional tile
- search terms：最多 7 条，每条 ≤ 30 字符，所有词加起来 ≤ 21 个英文单词
- 输入第一条后会出现 `id="last-search-item"` 的新空 input，下一条往这里填、再点 `Add Term`，循环到 7 条

**Certification notes（提交时最后一页）**

- 不要留空；显式说明：是否需要登录 / 各敏感权限的用途 / 源码地址 / 复现步骤
- 解释好 `<all_urls>`、`management` 等敏感权限的合理性，能显著加速审核

---

## 提交失败处理

- 若工具无法访问该平台登录态 → 记录为「需用户手动完成」，继续下一个平台
- 若平台报表单错误 → 就地修正后重试一次，仍失败则记录并跳过
- 不因单平台失败中断其他平台的提交
