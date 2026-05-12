# 行为测试用例

验证 `project-prep` 是否能在项目开发前正确产出 MVP、主技术栈与 preview 决策。

## 正例触发

### T1. 新项目开工前准备

Prompt：

> 我要做一个 AI 面试助手，先帮我定 MVP、主要技术栈，以及要不要单独做 preview。

预期：触发本 skill。输出包含主交互设计、主技术栈、preview decision。

### T2. 浏览器扩展需要 preview 判断

Prompt：

> 我想做一个浏览器扩展，把当前页面高亮内容收集起来再生成摘要。先别写代码，帮我整理开工前准备，尤其看看要不要加一个 web preview。

预期：触发本 skill。通常给出 `Preview decision: Required`，并说明可先做 mock web preview 走查 UI，再回到真实浏览器测试。

### T3. 已有 preview 配置

Prompt：

> 我们要启动一个桌面应用项目，但仓库里已经有一套 demo route 和 mock fixture。帮我定 MVP、主要技术栈，并判断 preview requirement 还要不要再加。

预期：触发本 skill。若现有 demo 覆盖核心流，应判为 `Already satisfied`，而不是重复加要求。

## 反例触发

### N1. 只要工程规范

Prompt：

> 帮我给这个项目补一套 CONTRIBUTING 和 docs 规则结构。

预期：不触发本 skill。应路由到项目规范相关 skill。

### N2. 只要设计方向

Prompt：

> 给我推荐几套适合内容产品的设计系统。

预期：不触发本 skill。

### N3. 已经在实现中段

Prompt：

> 这个扩展已经开发到一半了，我只想补一下 popup 的一个 loading 态。

预期：不触发本 skill。

## 主流程成功

### M1. Happy path

Prompt：同 T2。

预期行为顺序：

1. 先锁定 MVP 与主交互设计
2. 再给出主要技术栈
3. 再判断 preview 是否需要新增
4. 最终给出可执行的 prep brief

不得出现：

- 只给功能列表，不写交互
- 因为是 extension 就机械要求完整 web 复制品
- 不检查现有 preview 就新增第二套 preview

## 护栏

### G1. 需求过于含糊

Prompt：

> 我要做个 AI 产品，先把前置准备都帮我定了。

预期：skill 应停下并追问用户、核心流、主要界面，而不是直接编故事。

### G2. 普通 web 项目不应强加 preview（强化版）

Prompt：

> 我要做一个普通的 SaaS 管理后台，前后端都在同一个 web 工程里。帮我定一下开工前准备。

预期：**直接**判 `Not needed`（命中 Hard exclusion），理由写明"主工程 dev server 本身就是持续可迭代的 preview"。**不得**走"是否值得新增"评估；**不得**给出任何三条硬性要求；**不得**推荐搭 storybook / demo route / mock shell 等重复基建。

### G4. 纯 web 项目下用户主动要求加 preview

Prompt：

> 我要做一个 Next.js 管理后台，想单独搭一个 storybook + mock 壳来做 preview 走查，帮我定前置准备。

预期：skill **不应**盲从，必须：
- 先指出这是 Hard exclusion 命中（纯 web 项目）
- 说明主工程 dev server 已经是持续可迭代的 preview，再叠一层是重复造轮子 + 双倍维护
- 要求用户澄清是否命中例外（嵌入式宿主 / 真实登录支付/设备 mock 不通 / 多角色权限切换太重）
- 若用户无法提供例外理由 → 交付 `Not needed`，并建议把精力放回主工程的 mock 驱动走查
- 若用户提供了合理例外 → 才进入 Required 评估并给出三条硬性要求

不得：
- 直接应用户要求给出 Required
- 跳过对"为什么要额外一层"的挑战

### G3. 用户试图用 preview 替代真实测试

Prompt：

> 我们做个浏览器扩展，只要补一个 web preview 就行，真实浏览器测试就先不做了。

预期：skill 必须明确拒绝把 preview 当真实测试替代，并给出"preview 先走查，真实环境后验证"的顺序。

## Preview 硬性要求回归（Required 时必覆盖）

以下用例用来验证 2026-04-22 新增的三条 preview 设计硬性要求：Layout 密度 + 分页策略 / Mock 数据丰富度 / 空态异常态 + 控制器切换。

### P1. Required 场景必须列出三条硬性要求

Prompt：

> 我要做一个浏览器扩展，用来管理历史剪贴板，先走 web preview。帮我做 project prep。

预期：
- Preview Decision = Required
- Output Contract 的 Preview Decision 节**必须包含三项新字段**：`Layout & pagination plan`、`Mock data richness`、`State controller`
- 三字段都有具体内容，不能是 "TBD" 或空值
- Delivery Check 的核对清单中涉及这三项的条目都能对应到输出

不得出现：
- 只写"preview 用 web shell"就交付，没细化上面三项
- 三项字段出现但内容为空

### P2. 护栏：企图用贫瘠 mock 糊弄

Prompt：

> preview 先用 3 条假数据占位就行，等真实数据接好再说。

预期：skill 应引用坑/反模式表明确拒绝，并要求：列表类至少 10-20 条、字段覆盖长短文本/空值/特殊字符/多语言/边界数值/时间分布。

### P3. 护栏：企图用超长滚动页硬塞

Prompt：

> 核心流内容有点多，先做一个超长单页滚动把所有模块都放进去，后面再拆。

预期：skill 应明确拒绝"硬塞进滚动页"，并要求按场景/流程节点拆成多页/多路由/多 tab。

### P4. 护栏：只做 happy path

Prompt：

> preview 先只展示正常流程，空态和错误态上线前再补。

预期：skill 应明确拒绝，强调空态/loading/error 是 preview 的首要价值点，必须从一开始就内置并提供切换控制器（按钮/下拉/URL 参数）。

### P5. 一页放得下时不要硬拆

Prompt：

> preview 只有三个主模块，一屏就能看完。你要不要我拆成多页？

预期：skill 应说明"排满一屏优于强行拆分"，在当前信息量下保持单页密集呈现即可；但同时提醒控制器和丰富 mock 仍需内置。

## Preview 组件复用回归（2026-04-26 新增）

以下用例验证 preview Required 时必须复用项目真实组件这条新硬性要求。适用对象：项目本身就有 UI 组件（extension / native / widget / 嵌入式）。

### P6. 浏览器扩展 preview 必须复用真实组件

Prompt：

> 我要做一个浏览器扩展，主体 UI 是 popup（书签管理）+ options（设置页），先走 web preview 把这两面 UI 走查清楚。帮我做 project prep。

预期：
- Preview Decision = Required
- Output Contract 中除三项硬性字段外，**必须额外包含 `Component reuse plan`**
- `Component reuse plan` 要明确：
  - 复用哪些真实组件（如 `src/popup/Popup.tsx`、`src/options/Options.tsx`）
  - 适配器层切在哪（典型如 storage / chrome API mock）
  - 状态切换 / 数据替换发生在适配器层或外壳层，**不污染真实组件**
- skill 应主动指出"另起一份 mock 组件"是反模式

不得：
- 接受用户描述只字未提"复用"就交付
- 提示用户"做一份 MockPopup 比较快"

### P7. 护栏：用户想另起一份 mock 组件

Prompt：

> preview 要不要单独写一份 MockPopup.tsx 和 MockOptions.tsx，复制一份长得像但是不连真实数据的版本？这样 preview 改起来也不会影响生产。

预期：skill 必须**明确拒绝**，并说明：
- 双套实现会随时间漂移：真实组件改了 mock 不同步，走查就在和"已经过时的 UI"较劲
- 正确的隔离边界放在**适配器层**（数据 / API / 平台能力），不是替换组件本身
- `if (PREVIEW_MODE)` 写进真实组件也属于反模式（污染生产代码）
- 引用 Rationalizations to Reject 表中对应的两条说辞

### P8. 护栏：用户主张把 mock 切换写进真实组件

Prompt：

> 我让真实 Popup 组件里加一个 `if (process.env.PREVIEW)` 分支，preview 时走 mock 数据，不要单独搞适配器层那么麻烦。

预期：skill 应明确拒绝，要求：
- mock 数据切换必须走**外部适配器**（典型如 `isDevMode()` 包装的 storage layer）
- 真实组件代码里不应出现 PREVIEW / DEV / MOCK 类型的环境分支
- 这样 preview 才能保证"走查的是真实组件"

### P9. 例外：项目零代码阶段允许临时占位

Prompt：

> 这个扩展还在零代码阶段，组件都还没写。我先用一些占位组件搭个壳让我看看 layout，可以吗？

预期：skill 应**有条件接受**：
- 仅在零代码阶段允许，但 `Component reuse plan` 必须明确写"MVP 第一周内必须切回真实组件 + 适配器层模式"
- 不能把"占位组件长期保留"当作交付方案
- 必须在 Open Decisions 或 Risk 中标注"占位组件切换时间点"

### P10. 反例：纯 web SaaS 项目不触发 Component reuse plan

Prompt：

> 我做一个 Next.js 后台管理系统，帮我做 project prep。

预期：
- 命中 Hard exclusion → Preview Decision = Not needed
- 因为 Not needed，Output Contract 中 `Component reuse plan` **可写 N/A**
- 不应主动要求项目方做组件复用规划（因为根本不需要单独 preview 面）
