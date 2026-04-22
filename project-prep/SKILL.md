---
name: project-prep
description: Use when a user wants project prep before implementation: define the MVP, main interaction design, primary tech stack, and decide whether to add a preview requirement such as a mock web preview, demo surface, or preview route. Trigger on requests like "开工前准备", "项目开发前准备", "定 MVP 和技术栈", "要不要加 preview requirement", "need a preview plan before building", or when browser extensions, native apps, embedded surfaces, and integration-heavy tools need UI walkthroughs before real-environment testing.
---

# Project Prep

## Overview

这个 skill 负责把“开工前的模糊想法”收敛成一份可执行的前置准备简报。它固定四件事：

1. **MVP 范围**
2. **主交互设计**
3. **主要技术栈**
4. **Preview requirement 决策**

这里的 preview requirement 不是默认强加一层 web 壳，而是判断：在真实运行环境之外，是否值得补一个更快、可 mock、可做 UI 走查的预览面。典型例子是浏览器扩展：真实能力最终仍要在浏览器里验，但可以先补一份 web preview，用 mock 数据做界面和状态流转走查，最后再做真实测试。

本 skill 可单独使用，也可作为 `orchestrating-project-bootstrap` 的前置步骤。

## When to Use

- 用户要在开发前先定 MVP、主流程和技术栈
- 用户明确问“这个项目要不要单独做 preview / demo / mock web 展示”
- 项目的真实运行环境不适合承担早期 UI 走查
- 需要给下游规范或设计工作先提供稳定的项目定义

## When NOT to Use

- 用户已经只差工程规范或设计系统选择
- 项目已进入实现后期，只是在补单个页面或功能
- 纯后端、基础设施、脚本型项目，没有可感知的交互面
- 用户只要功能列表，不需要交互设计或预览决策

## Mandatory Workflow

### Step 1 —— 锁定 MVP（必须含交互设计）

显式产出：

- **产品意图**：一句话目标
- **目标用户**：谁使用、当前怎么完成这件事
- **核心流**：从入口到交付价值的 happy path，3–7 步
- **主交互设计**：
  - 屏幕 / 视图清单
  - 每屏关键动作
  - 状态流转
  - 影响流向的决策点
- **In-scope / out-of-scope**
- **Non-goals**

如果连用户、核心流、关键屏幕都无法合理推断，必须停下发定向澄清。不要拿功能列表硬凑交互设计。

### Step 2 —— 确定主要技术栈

产出一份粗粒度、足以指导开工的主技术栈清单。优先级：

1. 用户明确声明的栈
2. 从项目类型直接推断的运行面和主框架
3. 明确不可推断时，列为开放决策，不要瞎猜

这里追求的是“主要技术栈”，不是把所有可能的库都提前写死。至少回答：

- 主要运行面：web / extension / mobile / desktop / backend / hybrid
- 前端框架或 UI 宿主（若需要）
- 主要语言
- 数据与 mock 策略的基线假设（若 preview 会用到）

### Step 3 —— 决定是否增加 Preview Requirement

必须显式给出以下三种结果之一：

- **Required**：应新增 preview requirement
- **Not needed**：不需要额外 preview
- **Already satisfied**：已有配置已覆盖，不必再加

判断顺序：

0. **Hard exclusion — 纯 web 项目直接判 `Not needed`**
   - 如果主产品本身就是一个"跑 `dev server` 就能直接看到效果"的 web 项目（Vite / Next.js / Nuxt / Remix / CRA / 普通 React 或 Vue SPA / SaaS 管理后台 / 纯 marketing site / 纯文档站 等），**直接判 `Not needed`**，不要进入后面的"已满足 / 值得新增"判断。
   - 理由：这类项目本身就是**持续可迭代的 preview** ——改代码、存盘、浏览器里直接看。再单独搭一个 mock shell = 重复造轮子 + 双倍维护负担。
   - **例外**：即使是 web 项目，若同时命中以下任一条件，才可以重新进入后续判断：
     - 产品最终只在**嵌入式宿主**里可用（iframe / embed widget / 第三方平台内 / 邮件 HTML 渲染），主工程 `dev server` 无法复现该宿主
     - UI 严重依赖**真实的登录 / 支付 / 设备 / 第三方鉴权**，本地既开不通也难以完整 mock
     - 需要同时走查**多个角色 / 权限 / 状态维度**，在主工程里切换开销过高
   - 没有命中任一例外 → 保持 `Not needed`，即使用户主动要求加 preview 也应先指出重复造轮子的风险，由用户确认后再考虑。
1. **先看是否已满足**
   - 如果当前项目或用户描述里已经有可用于走查的预览面，例如 `storybook`、`demo/`、`playground/`、`examples/`、单独的 preview route、mock web shell，且覆盖核心流，就判为 `Already satisfied`
   - 不要为了"形式完整"再叠一层新的 preview 要求
2. **再看是否值得新增**
   - 满足任一条件，通常应判为 `Required`：
     - 真实运行环境启动慢、联调重、反馈链长
     - UI 流程可以用 mock 数据高保真模拟
     - 平台能力验证和 UI 走查应该分阶段完成
     - 产品主界面不在常规 web 里，例如 extension popup、embedded surface、native shell
   - 典型高命中场景：
     - 浏览器扩展
     - 桌面 / 原生应用
     - 依赖复杂登录、支付、设备、第三方平台的前端
3. **否则判为 Not needed**
   - 项目没有独立 UI 面，不值得人为制造 preview 壳

若结果为 `Required`，必须同时定义：

- **预览目标**：这份 preview 用来提前验证什么
- **预览载体**：web page / demo route / standalone shell / storybook-like surface
- **功能覆盖范围**：与真实产品保持哪部分一致，哪部分可以省略
- **数据策略**：mock / fixture / fake service worker / static seed
- **验收顺序**：先 preview 走查什么，再去真实环境验证什么

#### Preview 设计硬性要求

Required 的 preview 必须同时满足以下三条设计要求。这些不是"最佳实践建议"，而是交付判定门槛。

1. **Layout 密度 + 分页策略**
   - 默认追求在**一屏或一个页面**里尽可能密集呈现核心流，让走查者一眼看到主要界面与状态之间的关系
   - 但"尽可能排满"不是"硬塞"——如果一个页面里确实放不下，必须拆成多个页面 / 路由 / tab，不得通过以下方式强行塞入：超长单页无限滚动、字号缩到不可读、控件堆叠到相互遮挡、移除必要的空白和分隔。
   - 分页原则：按**场景或流程节点**切分（例如 "列表 / 详情 / 编辑 / 设置" 分页），而不是按不相关的功能堆在不同页。

2. **Mock 数据丰富度**
   - Mock 数据必须反映**真实使用压力**，不能只有 "Item 1 / Item 2 / Item 3" 或 "Lorem ipsum" 占位。
   - 列表类至少 **10–20 条**，覆盖典型分页或滚动行为。
   - 字段多样性必须覆盖：长文本 / 短文本 / 空字段 / 特殊字符 / 多语言（若涉及）/ 边界数值（0、极大、负数、小数精度）/ 时间分布（含今天、昨天、去年、未来等）。
   - 关联关系（作者、标签、分类、状态）要有合理分布，不能所有条目都指向同一个值。
   - 目的：让布局、截断、对齐、排序、过滤在真实数据压力下就被看出问题，而不是上线后才暴露。

3. **空态 / 异常态 + 控制器切换**
   - Preview 必须内置至少这几个态的 mock 场景：`normal` / `empty` / `loading` / `error`。
   - 如有登录态、权限、特殊角色、离线、限流等维度，也应预置对应 mock。
   - 界面上必须有**显式、可见的控制器**让走查者手动切换状态，例如：
     - 固定位置的切换按钮 / dropdown（常在页头或侧边调试栏）
     - URL query 参数（`?state=empty`、`?state=error&code=403`）
     - 设置面板
   - 不允许只提供 happy path。preview 的主要价值之一就是**在建站之前**把空态和异常态的 UI 先暴露出来。

禁止把 preview 说成"完整替代真实测试"。preview 的作用是提前暴露 UI 和状态流问题，不是跳过真实环境验证。

### Step 4 —— 交付前置准备简报

最终交付按顺序包含：

1. **MVP 范围**
2. **主交互设计**
3. **主要技术栈**
4. **Preview decision**
5. **开放决策**

如果 preview 为 `Required` 或 `Already satisfied`，要把对应的 preview 方案或现状写清楚；不能只写一个结论词。

## Output Contract

最终输出至少包含以下节：

```md
## Project Prep Brief

### Product Intent

### Target Users

### Core Flow

### Main Interaction Design

### MVP Scope
- In scope:
- Out of scope:
- Non-goals:

### Primary Tech Stack

### Preview Decision
- Status: Required / Not needed / Already satisfied
- Why:
- Surface:
- Data strategy:
- Validation sequence:
- Layout & pagination plan: （Required 必填：单页还是多页？分页怎么切？）
- Mock data richness: （Required 必填：条数、字段多样性、关联分布）
- State controller: （Required 必填：预置哪些态 + 切换方式）

### Open Decisions
```

若 `Status` 为 `Not needed`，`Surface` / `Data strategy` 可写 `N/A`，但 `Why` 不能省。

## Relationship to Other Skills

- 用户只要“开工前准备”时，直接用本 skill
- 用户还要工程规范和设计方向时，由 `orchestrating-project-bootstrap` 先调用本 skill，再路由到下游 skill
- 本 skill 不产出工程规则正文，也不产出设计系统候选

## Red Flags

- 只给功能列表，没有显式主交互设计
- 技术栈写成一长串库名，但没有主运行面和主框架
- 没检查现有 preview 就直接要求再建一个
- 因为项目是 extension / native 就机械地强制 preview，却没说明它提前验证什么
- 把 preview 当成真实测试的替代品
- 用户需求太含糊，却没有停下来澄清

## Rationalizations to Reject

| 说辞 | 现实 |
|------|------|
| "先把功能列出来就算准备好了" | 没有主交互设计，后续规范和设计都会漂 |
| "预览肯定都要做" | 预览是条件化决策，不是模板动作 |
| "有了 preview 就不用做真实环境测试" | preview 只负责提前走查，不替代真实验证 |
| "浏览器扩展没法 preview" | 很多 extension 的 UI 层可以先在 web 上用 mock 数据对齐 |
| "项目已经有 demo，但再加一个也没坏处" | 重复预览面会分散维护精力，先判断是否已满足 |
| "页面内容不多，随便撑一撑就行" | 尽可能密集排满才能在一屏暴露更多问题 |
| "内容多就做个超长滚动页硬塞下去" | 塞不下应当拆成多个页面/路由/tab，不能靠挤压让界面不可用 |
| "先用 3 条假数据撑一下，后面再补" | 贫瘠 mock 会漏掉真实数据压力下的 UI 问题，这就是 preview 存在的意义 |
| "先只做正常流程，空态和错误态以后再说" | preview 的首要价值就是提前暴露异常态，必须从第一天就带切换控制器 |
| "web 项目也配一个独立 preview 壳显得流程完整" | 纯 web 项目的 dev server 本身就是 preview；再叠一层 mock shell 等于重复造轮子且双倍维护。除非命中嵌入式宿主 / 真实依赖不可 mock / 多角色切换太重，否则 Not needed |

## Delivery Check

宣称完成前，核对：

- 有显式的主交互设计，而不是只写范围
- 主要技术栈足够指导开工，但没有过度锁死实现细节
- Preview decision 明确是 `Required`、`Not needed`、`Already satisfied` 之一
- 若为 `Required`，已定义 preview 目标、载体、数据策略、验收顺序
- 若为 `Required`，已写明 **Layout 密度 + 分页策略**（单页 or 多页？怎么拆？）
- 若为 `Required`，已写明 **Mock 数据丰富度**（条数、字段多样性、关联分布）
- 若为 `Required`，已写明 **空态 / 异常态 + 控制器切换**（至少 normal/empty/loading/error + 切换方式）
- 若为 `Already satisfied`，已说明现有预览面的证据或依据
- 开放决策清单存在

## Reuse

本 skill 的测试场景保留在 `tests/cases.md`。后续修订以这些用例为回归基线。
