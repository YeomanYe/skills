---
name: flow-ext-publish
description: >
  Use for the **end-to-end** browser extension submission flow (preflight check + asset
  preparation + store upload) to Chrome Web Store / Firefox AMO / Edge Add-ons.
  Trigger on phrases like "上架扩展", "发布扩展", "提交到商店", "准备上架", "帮我上架",
  "submit extension", "publish extension", "上架到 Chrome Store". Especially when assets
  (icons, screenshots, promo tiles, descriptions, permissions justifications, version bumps)
  need to be discovered, composed, confirmed, and submitted per each platform's rules.
  For a single-shot readiness check without uploading, use `ext-preflight` instead.
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)

# 扩展发布编排

## Overview

这个 skill 编排「浏览器扩展从 preflight 到提交」的完整链路。

它不替代 `ext-preflight`、`web-image` 或各平台上传工具。它的职责是：

- 先用 preflight 查出所有待完成项
- 对缺失的商店营销位图默认直接进入补齐分支，并将固定尺寸网页出图工作路由给 `web-image`
- 在所有缺口补齐前阻止发布
- 用户明确确认生成结果和剩余缺口后，按顺序执行上架：Firefox AMO → Edge → Chrome Web Store

## 角色信条

**我是上架人,不是马上交付员;我替用户挡商店审核拒,不抢在 preflight 之前点提交。**

**上架最容易死在"差不多了直接发"**——商店审核拒一次就是 3-7 天等下次,而拒的理由
往往是 "screenshot 1280×800 但你给的是 1271×799" / "permissions justification 太短"
这种几分钟能修但**没修就发**的细节。我多花 10 分钟跑 preflight = 用户少等 1 周。

我执行任务时心里只问一个问题:**"这次提交,审核员会不会因为'材料明显是拼凑'就直接拒?"**
会 = 我没准备好,跟用户多急着发、扩展功能多牛、版本号多正确,**一点关系都没有**。

**preflight 不是建议,是闸门**。preflight 没全绿就不能进上架分支。"用户说 screenshot
之后补" = **没补就发** = 商店审核回来后用户得改+重提+再等 3-7 天。

**3 个商店顺序写死**:Firefox AMO → Edge → Chrome。Firefox 最严但反馈最快,踩坑早暴露;
Chrome 最宽松放最后,前面踩的坑这边已经修了。**不要按"用户主用 Chrome"就跳过 Firefox**——
跨平台一致性是审核员看你专业不专业的第一信号。

我最容易翻的车——每一条都是"看起来在加速上架,实际在送商店拒信":

- **跳 preflight 直接走上架** — "我看清单都填了,直接发吧" = **没跑校验** = 商店审核员
  跑校验时发现某个尺寸差 1px,拒。preflight 是 Step 1,不是"如果有时间"。
- **AI 生成主视觉 / 假 UI 截图** — "我让 AI 画个 hero 图凑数" = **A 路径明确禁止**。
  商店审核员能一眼看出假图,直接拒"misleading representation"。素材必须从项目真实截图
  + 真实资产来,占位也行,但**禁止生成假产品视觉**。
- **permissions justification 写一句话** — "需要 storage 权限存数据" = **审核员看到这种
  会要求详细写**。每个 permission 必须答清楚"为什么需要 / 不要会怎样 / 用户数据怎么处理"
  三件事,少一件都拒。
- **3 商店一稿通发** — Firefox AMO 要求 source code review,Edge 要 publisher 验证,
  Chrome 要 1280×800 promo tile —— **每个商店的 quirks 不一样,材料必须按平台调整**。
  一稿通发省的是我的时间,**烧的是用户的发版周期**。
- **越界做产品文案 / 写代码 / 跑测试** — 我管 preflight + 素材补齐 + 上架顺序;
  **宣传文案找 director-promote,扩展代码改动找 flow-dev-task,功能测试找项目自己的
  test 框架,固定尺寸出图找 web-image**。越界 = 假装自己什么都懂 = 让每个环节都做半吊子。

## When to Use

- 准备把扩展上架到 Chrome Web Store / Firefox AMO / Edge Add-ons
- 准备发布一个新版本（version bump + 提交 review）
- 用户说「帮我发布这个扩展」「准备上架了」「submit to the store」「更新扩展版本」
- 有多个素材项不确定状态，需要一次性梳理

## When NOT to Use

- 只讨论扩展代码实现，不涉及发布
- 只做扩展内部功能调试
- 发布 VSCode extension / Obsidian plugin / 其他非浏览器扩展（本 skill 锁定浏览器扩展）
- 只是想跑一次 preflight 看看状态（直接用 `ext-preflight` 即可）

## Codex Delegation Hook

Codex 是对等 agent，**也能跑 Playwriter / cdp-browser-control**（对等机器，对等工具）。是否派工取决于 **ROI**（净收益 = 省 Claude token + 并行性 - SPEC 成本 - 协调成本 - review 成本 - 质量风险）。

### 🟡 中 ROI 视情况派
- **Step 4 各平台上架**：Codex 能跑 Playwriter / cdp 操作浏览器，但每平台之间需用户确认（"这张图可以吗？"、"是否要发 Edge？"），Codex 不能等用户回话——只能跑完一段就退出。**协调成本通常 > 节省**。仅在用户明确"全自动化提交，不要中途确认"时值得派工
- **Step 1 preflight**：能派，但 ext-preflight 自己就一条命令，Claude 自跑更快

### 🔴 低 / 负 ROI 不建议派
- **Step 2A 营销位图（web-image）**：web-image 是专用 HTML/CSS 出图工具，Codex 调它和 Claude 调它没差别，省不了 token
- **Step 2B user-must-provide**：等用户提供素材，本质是 user gate，无执行单元
- **Step 2C 文本 checklist**：抽取/整理需要 Claude 判断信息真实性（哪些来自 README 哪些瞎编）
- **Step 3 用户确认**：interactive，Codex 拿不到对话上下文
- **Step 5 报告**：依赖会话上下文（preflight 结果、用户确认对话、各平台审核 ID）

### 工具路由约束（不可绕过，与派工正交）
即使派 Codex，**Step 4 工具路由仍是硬约束**：
- Firefox AMO / Edge → 必须 `Playwriter`（接管用户已登录浏览器）
- Chrome Web Store → 必须 `cdp-browser-control`（Google 拦截 Playwriter）

**派工时必须把这些工具约束写进 SPEC**，否则 Codex 可能改用其他工具导致登录态丢失。

派工细则全部以 `flow-dev-task` 的 Codex Delegation Hook 为唯一规范，不在本 skill 重复。

## Execution Default

默认一路推进到「已补齐可自动生成的营销素材、Step 3 用户明确确认后，直接执行分平台上架并输出最终报告」。

在缺失项补齐 + 用户明确确认自动生成素材和剩余缺口前，不得进入 Step 4。

## Required Workflow

按顺序执行：

1. 运行 `ext-preflight`
2. 分类缺失项 → 可补齐的位图交给 `web-image` / 素材不足项列入 user-must-provide / 非图片列入 checklist
3. 输出已生成素材 + 缺口清单 → 等待用户明确确认「生成结果可用且全部就绪」
4. 执行上架：填写信息 + 提交，顺序为 **Firefox AMO（Playwriter）→ Edge（Playwriter）→ Chrome（cdp-browser-control）**
5. 输出最终报告

Step 3 前不得进入 Step 4。不允许「看起来都 OK」就自己补全再提交。

## Step 1: 运行 preflight

调用 `ext-preflight`，拿到待完成项清单。

调用时把已知信息显式传入，避免下游重复追问：

- 用户已指定的目标平台（例如 `上架 Chrome` → 传 `[Chrome Web Store]`）
- 从 `package.json` / `README` 能读到的构建产物路径与构建命令
- 从 `manifest.json` 能读到的 name / version / permissions

至少应从 preflight 获取：

- 缺失的素材项（图标 / 截图 / 宣传图 / 描述 / 权限理由 / 隐私政策链接）
- 版本号与 manifest 的一致性
- 分平台独有要求的覆盖情况
- 阻塞项与建议项

若 preflight 未安装：fallback 到手工检查 `manifest.json` + `store-assets/` + 每个平台官方 checklist 最小集，并在最终报告中注明降级。

## Step 2: 分类缺失项（A / C 路可**并行**，B 路串行）

### Step 2 并行编排

按 `references/parallelization-template.md`：

| Slot | 任务 | 并行性 | 必须调用的 skill |
|---|---|---|---|
| `web-image-batch` | A 路 - `web-image` 出多张营销图（promo tile / marquee / 1280×800 等）| **并行**（每张图一个 subagent，互不依赖）| `web-image`（必须显式）|
| `text-checklist` | C 路 - 整理描述文本 / 权限理由 / 版本号 checklist | **并行**（与 A 路同时跑，纯文本抽取无冲突）| 无 |
| `user-must-provide-list` | B 路 - 列出需要用户提供的资产清单 | **串行**（必须 A 路评估完才知道哪些是真正需要用户提供的）| 无 |

**派工 prompt 必填**（每个 A 路 subagent）：
- 目标尺寸 + 平台槽位
- 项目素材路径（截图 / logo / 文案来源）
- 输出目录（每张图独立子目录避免冲突，如 `store-assets/chrome/promo-440x280/`）
- **必须调用 `web-image` skill**（subagent 默认不会用）
- 返回 JSON：`{slot, size, source_paths, output_path, html_source_path, status, errors}`

orchestrator 派 A 路 + C 路并行后**进入 idle**，等所有 A 路 subagent 返回后再决定 B 路（已经被 A 自动补齐的就不进 B）。期间不主动 poll，由 subagent 返回触发唤醒。

**Reduce 策略**：方式 2（独立目录写完整文件），每张 A 路输出图独立子目录避免冲突。

**收益**：A 路 5 张图原 ~10min 串行 → ~3min 并行（含每张 web-image 调用开销）。

---

对 preflight 的缺失清单做三路分流：

先执行一个默认判断：

- 只要 preflight 报告缺失 promo tile、marquee、feature graphic、商店截图等营销位图，就不要先停下来问用户“要不要做图”
- 应先判断项目内现有素材是否足以自动补齐；足够就直接创建第一版成品，不足才列入 `user-must-provide`
- “没有营销图”本身不构成停顿理由；只有“没有足够项目素材做出可信营销图”才构成 `user-must-provide`
- 自动补齐完成后，再把生成结果拿给用户确认；确认前不得进入 Step 4

### A. 路由给 `web-image` 直接补齐

满足以下条件的图片，直接交给 `web-image` 在当前工作区用 HTML/CSS 生成并导出位图：

- preflight 已报告对应营销位图缺失、过时，或项目中根本没有现成营销图
- 属于商店宣传图、promo tile、marquee、feature graphic，或可由项目现有截图排版得到的 1280×800 商店图
- 可以基于项目现有截图、文字、icon、背景、logo、品牌色或 UI 片段进行编排
- 项目里能读到足够的关键说明（如 README、manifest、landing copy、变更说明），可以支撑标题和卖点文案
- 不要求引入任何项目外的新视觉素材，且允许把真实项目素材重新排版成营销图

执行这一路时，传给 `web-image` 的素材来源必须限制在项目中已有内容：

- 截图：popup、options、dashboard、landing page、录屏帧、已有 store 截图
- 文字：`README`、`manifest.json`、发布说明、官网文案、权限说明、隐私政策中的卖点或功能描述
- 图形：logo、icon、现有背景、品牌色、现有 UI 片段
- 落位目录：优先项目已有的 `store-assets/`、`assets/store/`、`docs/store-assets/` 等目录；若没有，再按项目现状新建清晰目录

生成规则必须显式遵守：

- 使用 `web-image`，而不是在本 skill 内重新发明出图流程
- `web-image` 的输入中必须显式带上尺寸、平台槽位、项目素材路径、目标输出目录、信息层级约束和截图约束
- 视觉目标是“展示效果舒服，特色能力重点突出”，优先强调数字、速度、效率、规模感等可感知信号
- 文案和视觉都必须从项目内现有资产抽取，不得引入项目外的新主视觉
- `1280×800` 成品**必须以项目中真实截图为主体**，围绕截图做排版、标注、文字、装饰、设备框都可以，但主体不能是纯文字、icon、假 UI 或抽象背景
- 若项目没有可复用的真实截图，`1280×800` 直接降级为 user-must-provide，不得伪造或用 stock 图顶替
- 生成完成后必须把 HTML 源文件和导出的 PNG 一并保存回项目目录
- 生成完成后必须记录每张图的用途、尺寸、源素材路径和输出路径，供 Step 3 给用户确认

这一路**禁止**用大模型凭空生成新的主视觉、角色插画、假 UI 或替代截图。A 路径的核心是“读项目、取项目资产、调用 `web-image` 用 HTML/CSS 排版并导出落盘”，不是“文生图”。

### B. 必须用户提供的图片

以下图片不要交给设计补齐流程，直接列入 **user-must-provide**：

- 项目里根本没有可复用真实截图时，`1280×800` 商店图所需的原始截图本身
- 项目里根本没有可复用的一手素材（logo / icon / 截图 / 关键文案）时，所缺的原始资产本身
- 用户明确要求使用尚未存在于项目中的新视觉素材时，对应源素材或设计定稿

给用户时列清：

- 需要几张
- 每张的尺寸要求
- 建议的取景或排版重点
- 落位目录

不要替用户用占位图蒙混过关，也不要在项目素材不足时擅自拿通用 stock 图或大模型生成图顶上。

### C. 非图片缺口

描述文本、权限理由、隐私政策链接、版本号等，整理成一份 checklist，列明：

- 字段名
- 目标平台
- 当前状态（缺 / 过时 / OK）
- 建议内容（能从 README / manifest / CHANGELOG 直接抽取的就抽，不能的只写「待用户填」）

## Step 3: 汇总并等待用户确认

输出一份结构化清单：

```md
## 扩展发布前检查

### 目标平台
- Chrome Web Store: ...
- Firefox AMO: ...
- Edge Add-ons: ...

### 产物 zip 路径
- Chrome: <路径>
- Firefox: <路径>
- Edge: <路径>

### 已补齐素材
- <文件路径>: <用途>

### 待你确认的自动生成素材
- <文件路径>: <用途> - <尺寸> - <使用的项目素材>

### 需要你手动提供
- <项目>: <要求> → <落位>

### 非图片缺口
- <字段>: <平台> - <状态> - <建议>

### 注意事项
- <manifest version vs package.json 一致性>
- <permissions 是否触发 review 加严>
- <content_security_policy 变更>
- <隐私政策是否需要更新>
```

如果 Step 2 自动生成了营销素材，Step 3 必须显式展示这些成品，并把确认对象说清楚：

- 哪些图是自动生成的
- 每张图对应的平台槽位和尺寸
- 每张图引用了哪些项目内素材
- 用户现在需要确认的是“这些生成结果是否可用”，不是笼统地回一句“继续”

输出后明确询问：**「以上自动生成素材和剩余缺口都确认好了吗？确认这些生成结果可用后，我才会进入提交阶段。」**

以下含糊回应**不算**确认，收到时应再次澄清：

- 「嗯」「嗯嗯」「哦」
- 「ok 吧」「行吧」「好像可以」
- 「随便」「都行」「你看着办」

明确确认应类似「这些图可以，用这个提交」「都处理好了」「可以提交」「go ahead」「开始发布」。

收到用户明确回复「某项还没好」「这张图要改」或「先不发 X 平台」时，更新素材或 payload 范围，再次等待确认；不要跳过。

## Step 4: 执行上架（填写信息 + 提交）

Step 3 用户明确确认后，直接进入本步骤，不需要再次征询授权。

### 提交顺序

**必须按以下顺序依次提交，不得颠倒：**

1. Firefox AMO
2. Microsoft Edge Add-ons
3. Chrome Web Store（最后）

每个平台提交完成后再进入下一个。若某个平台失败，记录错误后继续下一个，不中断整体流程。

### 工具路由规则

| 平台 | 工具 |
|------|------|
| Firefox AMO | `Playwriter`（接管用户已登录的浏览器） |
| Microsoft Edge | `Playwriter`（接管用户已登录的浏览器） |
| Chrome Web Store | `cdp-browser-control` |

**禁止**用 Playwriter 操作 Chrome Web Store（Google 会拦截自动化导航）。
**禁止**用 cdp-browser-control 操作 Firefox AMO 或 Edge。
**禁止**在 Firefox / Edge 路径上使用 Playwright MCP（`mcp__playwright__*`）或任何新开 chromium 实例的工具 — 那种方式拿不到用户已登录的 Partner Center / AMO 会话，必须通过 `npx playwriter@latest -s <session-id> -e "..."` 接管用户当前浏览器。

#### Playwriter 执行约束

- 单次 `npx playwriter@latest -s <session-id> -e "..."` 有约 10s 总超时
- 一次 `-e` 内的 `await page.waitForTimeout(...)` 不要超过 ~2.5s
- 长等待必须拆成多次短调用，等待逻辑放在 Bash 端的 `sleep`，不要在 `-e` 内做长 polling
- 切忌为了绕开超时改回 Playwright MCP 新开浏览器，那会丢失登录态

### 各平台上架步骤

对每个目标平台，依次执行：

1. **导航**：用对应工具打开该平台的开发者后台
2. **填写商店信息**：
   - name、short description（从 manifest / README 抽取，不得凭空编造）
   - screenshots（路径来自 Step 2/3 确认的素材清单）
   - promo tiles / marquee（同上）
   - category、privacy policy URL
   - permissions justification（`management` 和 `<all_urls>` 等敏感权限必须写）
3. **上传产物 zip**：使用 preflight / Step 2 产出的 zip 路径
4. **提交审核**：点击提交按钮，等待确认页或审核 ID
5. **记录结果**：保存审核 ID / 提交 URL，供最终报告使用

### 平台特定要点

#### Microsoft Edge Add-ons

- 入口与计划注册
  - 提交入口：`https://partner.microsoft.com/en-us/dashboard/microsoftedge/<product-id>/packages/dashboard`
  - 若账号未注册 Microsoft Edge 计划，访问 `/dashboard/microsoftedge/overview` 会被重定向回 dashboard 主页
  - 最稳的注册入口是 `https://partner.microsoft.com/en-us/dashboard/registration?stage=1&accountProgram=MicrosoftEdge`；aka.ms 短链多数已失效，不要依赖
  - 计划注册需用户手动完成（同意条款 / 选择账户类型），不要自动点同意

- 表单使用 Microsoft Fluent Web Components（Shadow DOM）
  - 按钮多为 `v6_he-button`，侧边导航 tab 为 `v6_he-task-item[aria-label="<TabName>"]`，外壳是 `HE-SHELL`
  - 普通 `button:has-text(...)` 经常拿不到，要改用 `v6_he-button:has-text("Continue")`、`v6_he-task-item[aria-label="Packages"]` 这类「自定义元素 + 文本/属性」选择器

- Store listing 的 4 个上传槽位
  - 页面里有 4 个 `input[type=file][name="fileuploader"]`，分别对应 Extension logo / Small promotional tile / Screenshots / Large promotional tile
  - **不要按 `nth(0..3)` 假设顺序**；每个 input 必须往上找父级 label 识别它属于哪一槽位，再按文件实际尺寸匹配
  - 顺序错位会被 Edge 在保存时直接拒（例如把 1280×800 传到 1400×560 槽位会报 `File size is incorrect... must be 1400 x 560`）
  - 截图槽位的 input **不是 multiple**：3 张 1280×800 必须拆成 3 次 `setInputFiles`，传数组会报 `Non-multiple file input can only accept single file`

- 提交流程顺序（侧边 tab）
  - Packages（上传 zip）→ Availability → Properties → Store listings → 回 Extension overview → 顶部 Publish → 填 Certification notes → 再 Publish → 状态变 In review

- Store listing 必填字段
  - name / description / extension logo / small promotional tile / screenshots / large promotional tile
  - search terms：最多 7 条，每条 ≤ 30 字符，所有词加起来 ≤ 21 个英文单词
  - 输入第一条后会出现 `id="last-search-item"` 的新空 input，下一条往这里填、再点 `Add Term`，循环到 7 条

- Certification notes（提交时最后一页）
  - 不要留空；显式说明：是否需要登录 / 各敏感权限的用途 / 源码地址 / 复现步骤
  - 解释好 `<all_urls>`、`management` 等敏感权限的合理性，能显著加速审核

### 提交失败处理

- 若工具无法访问该平台登录态 → 记录为「需用户手动完成」，继续下一个平台
- 若平台报表单错误 → 就地修正后重试一次，仍失败则记录并跳过
- 不因单平台失败中断其他平台的提交

## Step 5: 最终报告

```md
## 扩展发布报告

### 目标
- 扩展: <名称>
- 版本: <版本号>
- 平台: ...

### preflight 结果摘要
- 阻塞: ...
- 建议: ...

### 素材补齐情况
- 已补齐素材: ...
- 用户提供: ...
- 非图片缺口: ...

### 提交情况
- <平台>: 已准备 payload / 已提交（<ID>）/ 已跳过（<原因>）

### 遗留
- 待用户跟进: ...
- 审核中: ...

### 下一步建议
```

## Fallbacks

- `ext-preflight` 不可用 → 手工对照每个平台官方 checklist 做最小集检查，报告中注明降级
- 项目内截图 / 文字 / icon / 背景不足以支撑 HTML 渲染素材 → 把对应图片列入 user-must-provide，并明确缺的是哪些原始素材
- 缺失的是营销图本身，但项目内已有足够截图 / 文案 / icon → 不要先问用户要不要做，直接先生成第一版再进入确认
- manifest 与 package.json 版本不一致 → 停在 Step 2，先让用户对齐版本，再继续
- 用户只发一个平台 → 只提交该平台，不操作其它平台
- `Playwriter` 无法访问目标平台登录态 → 记录为「需用户手动完成」，继续下一平台；不要降级为 Playwright MCP 新开浏览器
- `cdp-browser-control` 无法访问 Chrome Web Store → 记录为「需用户手动完成」，输出需填字段清单
- Edge 计划未注册 → 不要继续提交 Edge，先把注册入口给用户手动完成，再回到 Step 4
- Playwriter 单次 `-e` 触达 10s 总超时 → 拆成多次短调用 + Bash `sleep` 等待，不要在 `-e` 内做长 polling，也不要改用新开浏览器的工具

## 禁止行为

- 跳过 Step 3 的用户确认直接进入 Step 4
- 把含糊回应（嗯 / ok 吧 / 随便）当作 Step 3 确认
- 用 Playwriter 提交 Chrome Web Store（Google 拦截自动化）
- 用 cdp-browser-control 提交 Firefox AMO 或 Edge
- 颠倒提交顺序（必须 Firefox → Edge → Chrome）
- 用占位图 / 截图蒙混缺失的真实截图
- 在 A 路径里调用 `huashu-design`、`ai-image-generation` 或其他外部设计 / 文生图方式绕过项目资产约束
- 不读取项目现有截图 / 图标 / logo / 关键说明，就直接设计宣传图
- 生成 `1280×800` 时不使用项目中已有真实截图
- 文案、permissions justification 瞎编（只能从项目里抽取或明说「待用户填」）
- 跳过 preflight 直接进入 Step 2
- 在用户只要求某一个平台时顺带把其它平台也发了
- 重复追问 preflight 报告 / `manifest.json` / `package.json` / README 中已明确存在的信息（name、version、description、permissions 等）
- 在 Firefox / Edge 路径上使用 Playwright MCP（`mcp__playwright__*`）或任何新开 chromium 实例的工具操作 Partner Center / AMO（必须接管用户已登录浏览器）
- 在 Edge Store listing 按 `nth(0..3)` 假设 4 个 file input 槽位顺序（必须按父级 label 识别）
- 把 Edge 截图 input 当作 multiple 一次性传 3 张（必须拆 3 次 `setInputFiles`）
- 一次 Playwriter `-e "..."` 中 `await page.waitForTimeout(...)` 超过 ~2.5s 触发 10s 总超时（应拆调用并把等待放到 Bash `sleep`）
- Edge 计划未注册时仍尝试自动「同意条款 / 选择账户类型」绕过注册（必须让用户手动完成）

## 完成判定

同时满足以下条件才算本次编排完成：

- 已运行 preflight（或明确降级）
- 已分流缺失项并生成 / 整理所需素材
- 已收到用户对 Step 3 素材和缺口的明确确认
- 已按顺序（Firefox → Edge → Chrome）对所有目标平台执行填写 + 提交，或记录了跳过原因
- 已输出最终报告（含各平台审核 ID 或手动跳过说明）

若用户在 Step 3 或 Step 4 暂停任务，报告中如实记录停在哪一步。
