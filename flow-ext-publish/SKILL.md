---
name: flow-ext-publish
description: >
  Use for the **end-to-end** browser extension submission flow (preflight check + asset
  preparation + store upload) to Chrome Web Store / Firefox AMO / Edge Add-ons.
  Trigger on phrases like "上架扩展", "发布扩展", "提交到商店", "准备上架", "帮我上架",
  "submit extension", "publish extension", "上架到 Chrome Store", "Chrome Web Store
  隐私政策链接被拒", "CWS 重提审". Especially when assets (icons, screenshots, promo
  tiles, descriptions, permissions justifications, version bumps) need to be discovered,
  composed, confirmed, and submitted per each platform's rules.
  For a single-shot readiness check without uploading, use `ext-preflight` instead.
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)
> 本 skill 对齐 `../_shared/flow-template.md`(flow-* 元规范)。Executor Selection 引 `references/executor-selection-template.md`。Output Contract 引 `references/output-contract-schema.md`(sync from `_shared/`)

# 扩展发布编排

## Overview

这个 skill 编排「浏览器扩展从 preflight 到提交」的完整链路。

它不替代 `ext-preflight`、`web-image` 或各平台上传工具。它的职责是：

- 先用 preflight 查出所有待完成项
- 对缺失的商店营销位图默认直接进入补齐分支，并将固定尺寸网页出图工作路由给 `web-image`
- 在所有缺口补齐前阻止发布
- 用户明确确认生成结果和剩余缺口后，整理好分平台 payload 并**停在上架闸门**；只有用户再明确授权「自动上传 / 一把梭 / 直接提交」时，才按顺序真正上架：Firefox AMO → Edge → Chrome Web Store
- 对 Chrome Web Store 已有条目的“小修字段 + 保存草稿 + 重提审”提供维护快路径；这条路径只操作商店后台，不负责 build、官网部署、素材生成或 zip 上传

## 执行原则

**本 skill 的职责是上架编排,不是快速交付;其核心价值是替用户拦截商店审核拒,而非抢在 preflight 之前点提交。**

**上架最容易死在"差不多了直接发"**——商店审核拒一次就是 3-7 天等下次,而拒的理由
往往是 "screenshot 1280×800 但你给的是 1271×799" / "permissions justification 太短"
这种几分钟能修但**没修就发**的细节。多花 10 分钟跑 preflight = 用户少等 1 周。

执行每次提交前,必须先回答:**"这次提交,审核员会不会因为'材料明显是拼凑'就直接拒?"**
若答案是"会",则尚未准备好——与用户的紧迫程度、扩展功能好坏、版本号是否正确**一点关系都没有**。

**preflight 不是建议,是闸门**。preflight 没全绿就不能进上架分支。"用户说 screenshot
之后补" = **没补就发** = 商店审核回来后用户得改+重提+再等 3-7 天。

**3 个商店顺序写死**:Firefox AMO → Edge → Chrome。Firefox 最严但反馈最快,踩坑早暴露;
Chrome 最宽松放最后,前面踩的坑这边已经修了。**不要按"用户主用 Chrome"就跳过 Firefox**——
跨平台一致性是审核员看你专业不专业的第一信号。

以下每条都是"看起来在加速上架,实际在送商店拒信"的高危操作,必须避免:

- **跳 preflight 直接走上架** — 未跑校验直接发 = 商店审核员跑校验时发现某个尺寸差 1px,
  拒。preflight 是 Step 1,不是"如果有时间"。
- **AI 生成主视觉 / 假 UI 截图** — A 路径明确禁止用文生图凑素材。
  商店审核员能一眼看出假图,直接拒"misleading representation"。素材必须从项目真实截图
  + 真实资产来,占位也行,但**禁止生成假产品视觉**。
- **permissions justification 写一句话** — 每个 permission 必须答清楚"为什么需要 /
  不要会怎样 / 用户数据怎么处理"三件事,少一件审核员会要求详细重写。
- **3 商店一稿通发** — Firefox AMO 要求 source code review,Edge 要 publisher 验证,
  Chrome 要 1280×800 promo tile —— **每个商店的 quirks 不一样,材料必须按平台调整**。
  一稿通发省的是编排时间,**烧的是用户的发版周期**。
- **越界做产品文案 / 写代码 / 跑测试** — 本 skill 职责边界是 preflight + 素材补齐 + 上架顺序;
  **宣传文案找 director-promote,扩展代码改动找 flow-dev-task,功能测试找项目自己的
  test 框架,固定尺寸出图找 web-image**。越界会让每个环节都做半吊子。

## When to Use

- 准备把扩展上架到 Chrome Web Store / Firefox AMO / Edge Add-ons
- 准备发布一个新版本（version bump + 提交 review）
- 用户说「帮我发布这个扩展」「准备上架了」「submit to the store」「更新扩展版本」
- 有多个素材项不确定状态，需要一次性梳理
- Chrome Web Store 因隐私政策链接、metadata 字段等可定位问题被拒，需要更新已有草稿并重提审

## When NOT to Use

- 只讨论扩展代码实现，不涉及发布
- 只做扩展内部功能调试
- 发布 VSCode extension / Obsidian plugin / 其他非浏览器扩展（本 skill 锁定浏览器扩展）
- 只是想跑一次 preflight 看看状态（直接用 `ext-preflight` 即可）
- 只是发布官网、部署隐私政策页面、构建静态网站（这不属于商店提交）

## Executor Selection

执行者选择遵循 `references/executor-selection-template.md`:默认当前 agent 自写;大体量纯样板派便宜档 subagent(haiku/sonnet)/ fast;高风险代码 / 决策仲裁 / 评分 / 强会话上下文不下放。

## Execution Default

默认一路推进到「已补齐可自动生成的营销素材、Step 3 用户明确确认素材就绪后，进入 Step 4 **填好分平台 payload 并停在上架闸门**，输出最终报告」。

### Chrome Web Store 维护快路径

若用户明确只要求处理 Chrome Web Store 已有条目的后台字段更新 / 保存草稿 / 重提审，且**不涉及**
扩展 build、官网部署、素材生成、zip 上传、跨平台提交，则走维护快路径：

1. 确认目标是 CWS 已有 item，拿到 publisher id、item id、要更新的字段和值
2. 若只是查看状态，运行 dry-run；若要保存或提审，必须有用户明确授权
3. 使用 `scripts/cws-update-submit.mjs`（详见 `references/cws-update-submit.md`）操作 CWS 后台
4. 输出更新值、是否保存、是否提交、最终状态

这条快路径**不要求**运行完整 preflight，也不触发 Step 2 的素材补齐；它只用于“材料已经在外部准备好，只需要修 CWS 后台并提交”的维护场景。

**两道闸门，缺一不可：**

1. **Step 3 素材确认闸门**：在缺失项补齐 + 用户明确确认自动生成素材和剩余缺口前，不得进入 Step 4。
2. **Step 4 上架闸门（安全默认）**：实际向商店提交（调 store API / 带 OAuth 的上传 / Playwriter / agent-browser 点提交）是**高风险动作**，需用户**明确**授权。Step 3 的「素材可用」确认**不等于**授权实际上传。
   - **默认**：Step 4 只 build + `web-ext lint` + 填好每个平台的 payload（信息、素材路径、zip 路径），然后**停在上架闸门**，输出 payload + 报告，并问用户是否要实际提交。
   - **仅当**用户明确说「自动上传 / 一把梭 / 调 API / 直接提交到商店 / 帮我发上去」这类无歧义授权时，才越过上架闸门，按 Firefox AMO → Edge → Chrome 顺序真正提交并收集审核 ID。
   - 含糊回应（嗯 / ok 吧 / 随便 / 继续）既不算 Step 3 确认，也不算上架授权。

若用户最初的请求里已含无歧义的「准备好就直接提交 / publish it / 最后提交上去」这类全自动授权，可在 Step 3 确认后连同上架闸门一并越过——但越过的依据必须是用户原话里的明确授权，而非自行推断。

## Required Workflow

默认完整发布按顺序执行；若命中上面的 Chrome Web Store 维护快路径，则只执行维护快路径，不进入下面的端到端流程。

1. 运行 `ext-preflight`
2. 分类缺失项 → 可补齐的位图交给 `web-image` / 素材不足项列入 user-must-provide / 非图片列入 checklist
3. 输出已生成素材 + 缺口清单 → 等待用户明确确认「生成结果可用且全部就绪」
4. 整理 payload + 停在上架闸门：build + `web-ext lint` + 填好每平台 payload（信息 / 素材 / zip）；**默认到此停下**输出 payload。**仅当**用户明确授权「自动上传 / 一把梭 / 直接提交」时，才越过闸门，按 **Firefox AMO（Playwriter）→ Edge（Playwriter）→ Chrome（agent-browser --profile Default）** 顺序真正提交
5. 输出最终报告

Step 3 前不得进入 Step 4。不允许「看起来都 OK」就自己补全再提交。**无明确上架授权时，Step 4 止于填好 payload，不实际调用任何 store API / OAuth 上传 / 浏览器点提交。**

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

输出一份结构化清单（格式见 `references/report-templates.md` → Step 3 模板），覆盖：目标平台 / 产物 zip 路径 / 已补齐素材 / 待确认的自动生成素材 / 需用户手动提供项 / 非图片缺口 / 注意事项。

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

## Step 4: 整理 payload + 上架闸门（填写信息 → 闸门 → 提交）

Step 3 用户明确确认素材后进入本步骤。本步骤分两段，**中间有一道上架闸门**：

### Step 4a：整理 payload（默认止步于此）

无论是否会实际提交，先做这些无副作用的准备：

- build 产物 + `web-ext lint`（允许执行）
- 对每个目标平台填好 payload：商店信息（name / description）、素材路径（icon / screenshots / promo tiles，均来自 Step 2/3 确认清单）、category、privacy policy URL、permissions justification、zip 路径
- 若 `package.json` 有 `release:chrome` 之类发布脚本，优先复用，不自己拼上传命令

**默认到此停下**：输出整理好的 payload + Step 5 报告，并明确询问用户「是否要我现在实际提交到商店？（这会真正调用上传 / 浏览器自动化）」。**此时不得**执行任何 store API、带 OAuth 的上传命令、或用 Playwriter / agent-browser 点提交。

### Step 4b：实际提交（仅在明确上架授权后）

**仅当**用户明确说「自动上传 / 一把梭 / 调 API / 直接提交 / publish it / 帮我发上去」这类无歧义授权（或最初请求里已含此类全自动授权）时，才越过上架闸门执行实际提交。含糊回应（嗯 / ok 吧 / 继续 / 随便）不算授权，应再次澄清。

越过闸门后，按下述提交顺序与工具路由真正提交。

### 提交顺序

**必须按以下顺序依次提交，不得颠倒：**

1. Firefox AMO
2. Microsoft Edge Add-ons
3. Chrome Web Store（最后）

每个平台提交完成后再进入下一个。若某个平台失败，记录错误后继续下一个，不中断整体流程。

### 工具路由规则 & 执行约束

详见 `references/store-platform-quirks.md`（工具路由表 / Playwriter 约束 / agent-browser 约束 / cdp-browser-control 约束）。关键原则摘要：
- Firefox AMO / Edge → Playwriter（接管已登录浏览器），禁止新开 chromium
- Chrome Web Store → 首选 `agent-browser --profile Default`，受阻时 fallback 至 `scripts/cws-update-submit.mjs`
- Playwriter 单次 `-e` 超时约 10s，长等待拆多次调用 + Bash `sleep`

### 各平台上架步骤 & 平台特定要点

详见 `references/store-platform-quirks.md`（各平台上架步骤 / Firefox AMO / Chrome Web Store / Microsoft Edge Add-ons / 提交失败处理）。

每个平台核心步骤：导航开发者后台 → 填写商店信息（name/description/icon/screenshots/promo tiles/category/privacy URL/permissions justification）→ 上传产物 zip → 提交审核 → 记录审核 ID。

## Step 5: 最终报告

按 `references/report-templates.md` → Step 5 模板输出，覆盖：目标扩展/版本/平台 / preflight 结果摘要 / 素材补齐情况 / 各平台提交情况（payload 就绪 / 已提交+ID / 已跳过原因）/ 上架闸门状态 / 遗留与下一步建议。

## Fallbacks

- `ext-preflight` 不可用 → 手工对照每个平台官方 checklist 做最小集检查，报告中注明降级
- 项目内截图 / 文字 / icon / 背景不足以支撑 HTML 渲染素材 → 把对应图片列入 user-must-provide，并明确缺的是哪些原始素材
- 缺失的是营销图本身，但项目内已有足够截图 / 文案 / icon → 不要先问用户要不要做，直接先生成第一版再进入确认
- manifest 与 package.json 版本不一致 → 停在 Step 2，先让用户对齐版本，再继续
- 用户只发一个平台 → 只提交该平台，不操作其它平台
- `Playwriter` 无法访问目标平台登录态 → 记录为「需用户手动完成」，继续下一平台；不要降级为 Playwright MCP 新开浏览器
- `agent-browser --profile Default` 无法访问 Chrome Web Store → 若是 CWS 维护/重提审场景，改用 `scripts/cws-update-submit.mjs`；若是完整上架且脚本覆盖不了当前操作，记录为「需用户手动完成」，输出需填字段清单
- Edge 计划未注册 → 不要继续提交 Edge，先把注册入口给用户手动完成，再回到 Step 4
- Playwriter 单次 `-e` 触达 10s 总超时 → 拆成多次短调用 + Bash `sleep` 等待，不要在 `-e` 内做长 polling，也不要改用新开浏览器的工具

## 禁止行为

- 跳过 Step 3 的用户确认直接进入 Step 4
- 把含糊回应（嗯 / ok 吧 / 随便）当作 Step 3 确认
- **在用户未明确授权「自动上传 / 一把梭 / 调 API / 直接提交」时，越过 Step 4 上架闸门实际调用 store API / OAuth 上传 / Playwriter / agent-browser 点提交**（默认只整理 payload 并停下）
- 把 Step 3 的「素材可用」确认当作实际上架授权（两道闸门是独立的）
- 用普通 Playwriter / Playwright 新开无登录浏览器提交 Chrome Web Store（Google 拦截自动化）；只有 `cdp-browser-control` 临时 profile + CDP 直连模式例外
- 用 agent-browser 提交 Firefox AMO 或 Edge（Firefox / Edge 固定走 Playwriter）
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
- Firefox AMO 显示「提交完成」后不回到「编辑产品页面 → 图像」检查并补齐 icon / screenshots
- 在 Edge Store listing 按 `nth(0..3)` 假设 4 个 file input 槽位顺序（必须按父级 label 识别）
- 把 Edge 截图 input 当作 multiple 一次性传 3 张（必须拆 3 次 `setInputFiles`）
- 一次 Playwriter `-e "..."` 中 `await page.waitForTimeout(...)` 超过 ~2.5s 触发 10s 总超时（应拆调用并把等待放到 Bash `sleep`）
- Edge 计划未注册时仍尝试自动「同意条款 / 选择账户类型」绕过注册（必须让用户手动完成）

## 完成判定

编排有两种合法终态，取决于用户是否给出明确上架授权：

**终态 A — 停在上架闸门（默认，无明确上架授权时）：**

- 已运行 preflight（或明确降级）
- 已分流缺失项并生成 / 整理所需素材
- 已收到用户对 Step 3 素材和缺口的明确确认
- 已对所有目标平台填好 payload（信息 / 素材路径 / zip），并执行了 build + `web-ext lint`
- **未**调用任何 store API / OAuth 上传 / 浏览器点提交
- 已输出最终报告，报告里把各平台标为「payload 已就绪，待用户授权后提交」，并明确询问是否要实际上架

**终态 B — 已实际提交（仅在用户明确授权「自动上传 / 一把梭 / 直接提交」后）：**

- 满足终态 A 的全部素材 / 确认前提
- 已按顺序（Firefox → Edge → Chrome）对所有目标平台执行填写 + 提交，或记录了跳过原因
- Firefox AMO 若在目标平台内，已验证「图像」区存在 icon 和已确认截图，或明确记录为用户手动补齐项
- 已输出最终报告（含各平台审核 ID 或手动跳过说明）

若用户在 Step 3 或 Step 4（含上架闸门）暂停任务，报告中如实记录停在哪一步。
