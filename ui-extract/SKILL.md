---
name: ui-extract
description: Use when refactoring UI code by extracting visual and interactive components, especially after AI-generated pages become bulky, hard to maintain, or have unclear boundaries between page-local, business, shared, and primitive components; 用于重构 UI 代码并抽取包含视觉与交互的组件，尤其是 AI 生成页面臃肿、可维护性差、业务组件与公共组件边界不清时。
---

# UI 组件抽取

## 概览

这个 skill 用于指导 Codex 抽取包含视觉和交互的 UI 组件。

核心方法是：先从最内侧可交互焦点出发，向外寻找最近的视觉、交互、状态和语义边界，形成组件候选；再根据业务语义、复用性和 API 稳定性决定组件归属层级。

默认行为是先产出组件抽取计划，再修改代码。

## 适用时机

以下情况使用本 skill：

- AI 复刻页面后代码臃肿、JSX 过长、难以维护
- 用户要求做 UI 组件抽取、组件拆分、组件边界整理
- 页面中存在输入框、卡片、弹窗、表单、CTA、列表项、价格卡、功能块等可视交互单元
- Codex 需要判断哪些组件应该是页面局部组件、业务组件、公共组件或基础 UI 组件
- 重构目标是提升可读性、可维护性、复用性和测试边界

以下情况不要使用：

- 只抽取普通函数、算法逻辑或后端模块
- 只做样式微调，不改变组件结构
- 只需要使用已有 UI 组件，不需要判断抽取边界
- 用户明确要求先不要重构组件结构

## 必要流程

必须按顺序执行：

1. 读取现有页面、组件目录和项目约定
2. 找出最内侧可交互焦点和视觉焦点
3. 用焦点向外边界发现法生成组件候选
4. 对每个候选做层级归类
5. 输出组件抽取计划
6. 用户要求执行或上下文已明确要求实现时，再修改代码
7. 修改后验证行为、样式和导入边界

不要跳过组件抽取计划直接改代码。

## 焦点向外边界发现法

从页面中最内侧的焦点开始，向外扩张，直到找到最近的完整 UI 边界。

焦点可以是：

- 可交互元素：`input`、`button`、`select`、`tab`、`dialog trigger`
- 状态元素：错误信息、loading、active、selected、expanded、disabled
- 视觉焦点：图标、数字、标题、价格、图片、徽章

每次向外扩张时检查：

- 视觉边界：border、background、shadow、radius、divider、spacing container
- 交互边界：focus ring、hover、pressed、open/close、validation、loading
- 状态边界：状态是否只服务当前范围
- 语义边界：这个外壳是否表达一个完整意图
- 布局边界：外层是否只是 grid/flex/section 排版

示例：

```text
input
-> input + border + label + error = TextField 候选
-> TextField + button + hint = SearchBox 候选
-> SearchBox + title + description + card shell = SearchPanel 候选
-> SearchPanel + section heading + marketing copy = 页面 section 候选
```

焦点向外发现法只产生候选，不自动决定公共组件。

## 最小抽取单元

最小抽取单元不是单个 DOM 标签，而是具备完整视觉、交互和状态边界的最小 UI 单元。

一个候选组件至少应满足：

- 有可识别的视觉边界，或明确属于已有 UI primitive
- 有完整交互语义，例如 focus、hover、disabled、loading、error
- 有稳定状态范围，状态只服务当前候选边界
- 能用一个清晰名称表达意图
- 抽出后不会让调用方更难读

判断示例：

- 裸 `input` 通常不是最小业务抽取单元；`input + border + label + error + help text` 才是 `TextField` 候选
- 裸 `button` 如果只是样式 primitive，可以是 `Button`；带 CTA 文案、业务事件或路由时，应保留在业务组件或调用方
- 孤立 `icon` 通常不是组件，除非它来自图标系统或有独立交互状态
- 只有 `margin`、`padding`、`flex`、`grid` 的 wrapper 不是组件
- `Card` 可以是 UI primitive；`PricingCard` 是业务组件，因为它包含价格、套餐和购买动作

如果最小单元无法被清晰命名，不应抽取；应继续向外寻找更完整的边界，或保留在调用方。

## 停止扩张条件

遇到以下情况应停止向外扩张：

- 再向外会引入另一个独立焦点区
- 再向外只剩布局容器
- 再向外会混入页面叙事、营销文案或一次性内容
- 再向外会让 props API 变成万能配置器
- 再向外会把多个变化原因绑在同一个组件里
- 组件名称开始变得模糊，例如 `FlexibleSection`、`MarketingBlock`、`CustomCard`

## 组件层级归类

### 基础 UI 组件

放置低语义、稳定 API、跨项目或跨页面通用的组件。

适合：

- `Button`
- `Input`
- `Card`
- `Badge`
- `Tabs`
- `Dialog`

不适合：

- 业务文案
- 业务路由
- 营销图片
- 价格、套餐、注册、支付等业务语义

### 公共组件

放置跨多个页面复用、语义稳定、但高于 UI primitive 的组件。

适合：

- `SectionHeader`
- `LogoCloud`
- `StatCard`
- `FeatureGrid`
- `TestimonialCard`

必须满足：

- 至少有明确的跨页面复用机会，或项目中已有相同模式
- props API 不绑定单个页面的业务数据
- 不包含固定文案、固定图片、固定 CTA 路由
- 样式变化可以通过有限、稳定的 variant 表达

### 业务组件

放置带业务语义、业务数据结构或业务动作的组件。

适合：

- `PricingCard`
- `PlanComparison`
- `SignupEmailCapture`
- `CheckoutCTA`
- `ProductFeatureCard`

判断信号：

- 名称里有业务名词
- props 与业务实体绑定
- 包含业务动作、埋点、路由或权限
- 复用范围主要在同一业务域内

### 页面局部组件

放置只服务当前页面叙事或当前页面布局的组件。

适合：

- `HeroSection`
- `PricingSection`
- `TestimonialsSection`
- `FinalCTASection`

判断信号：

- 包含页面独有文案、顺序或叙事节奏
- 复用价值不明确
- 抽成公共组件会导致大量配置 props

页面局部组件可以存在，不要为了“看起来像组件”强行放进 shared。

## 抽取计划要求

改代码前必须输出计划。

计划至少包含：

```md
候选组件:
当前边界:
焦点来源:
建议层级:
抽取理由:
不放入更高层级的理由:
建议文件位置:
props API:
保留在调用方的内容:
验证方式:
```

示例：

```md
候选组件: SignupEmailCapture
当前边界: input + button + validation message + loading state
焦点来源: email input
建议层级: business component
抽取理由: 它表达注册转化动作，包含输入、提交、校验和 loading 状态
不放入 shared/ui 的理由: CTA 文案、提交意图和事件属于业务语义
建议文件位置: features/signup/components/signup-email-capture.tsx
props API: value, onChange, onSubmit, status, error
保留在调用方的内容: hero 文案、section 背景、页面布局
验证方式: 提交、错误、loading、键盘 focus 顺序不变
```

## 抽取规则

- 优先抽取有完整视觉和交互边界的组件，而不是孤立标签
- 先确认最小抽取单元，再决定是否继续向外抽外层组件
- 优先按变化原因抽取，而不是按代码行数抽取
- 内层组件先稳定，再决定是否抽外层卡片或 section
- 业务文案、图片、路由和埋点默认留在业务层或页面层
- 公共组件必须有稳定语义和低业务耦合
- 如果复用证据不足，先放页面局部或业务目录，不要进入 shared
- props 应表达组件能力，不应暴露所有样式细节
- 保持抽取后的调用方可读，避免 props 过多导致更难维护

## 禁止行为

- 禁止看到 JSX 长就机械拆分
- 禁止把所有视觉块都抽进 `components/ui`
- 禁止把页面营销文案封进公共组件
- 禁止把业务路由、埋点、权限判断封进 UI primitive
- 禁止为了复用创建万能配置组件
- 禁止把 grid/flex 包装层误认为业务组件
- 禁止一次性大规模移动文件却不保留行为验证
- 禁止拆完后只报告“更清晰”，但不说明边界依据

## 完成判定

完成后必须确认：

- 抽取计划中的每个候选都有层级归类
- 组件文件位置符合归类
- 公共组件不含业务语义
- 业务组件没有伪装成 UI primitive
- 页面局部组件保留了页面叙事
- 交互状态、focus、hover、loading、error 没有丢失
- 视觉结构和响应式布局没有明显回归
- 导入路径没有形成循环依赖或反向依赖

如果无法验证视觉，应明确说明未验证视觉，只验证了结构或静态检查。
