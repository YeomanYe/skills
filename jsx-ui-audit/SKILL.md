---
name: jsx-ui-audit
description: Use when writing or refactoring JSX-based UI in React, Preact, Fresh, or similar frameworks, especially when you must first detect project-specific conventions and only fall back to external design-system references like antd, shadcn, or radix when local standards are missing or weak; 用于编写或重构 React、Preact、Fresh 等 JSX UI，尤其是在落代码前需要先识别项目约定，并在本地规范缺失或较弱时再回退到 antd、shadcn、radix 等优秀参考项目。
---

# JSX UI 判定参照

## 概览

这个 skill 用于指导 agent 在编写、修改或重构 JSX UI 之前，先判断项目中是否已经存在明确的 UI 编写约定，再决定应该复用什么模式、参考什么例子，以及当前实现是否需要回退到某类 best-practice 重写。

它是判定器，不是主写作规则库，也不是设计生成器。

它的职责是帮助 agent 在“开始写组件之前”和“写完之后复查”做出一致、可维护、可扩展的 UI 编码判断。

## 适用时机

以下情况使用本 skill：

- 要在 React、Preact、Fresh 或相似 JSX 框架中新增 UI 组件，并且需要先判断该怎么写
- 要重写、补写或重构已有 UI 组件，并且需要先判断当前实现哪里有问题
- 项目中风格不完全明确，需要先判断规范再写
- 用户要求参照 antd、shadcn、radix 等成熟项目
- 项目在 Tailwind、shadcn 风格、design system、组件库封装之间需要做取舍
- agent 需要先看项目有没有“特殊约定风格”

以下情况通常不要使用：

- 只做纯视觉创意设计，且不涉及落 JSX 代码
- 只优化 React/Next 性能，不做 UI API 或样式层面的决策
- 只抽取普通函数、hooks、service、后端逻辑
- 项目已经给了明确实现规范，且用户只要求机械跟随已有模板

## 核心优先级

写任何 JSX UI 前，必须按以下优先级判断：

1. 项目现有规范
2. 项目内现成实现
3. 团队当前技术栈约定
4. 外部优秀参考项目
5. 通用最佳实践

不要跳过前 3 层直接照搬外部参考。

## 必要流程

必须按顺序执行：

1. 扫描项目现有 UI 约定
2. 评估约定强弱
3. 找项目内相似例子
4. 判断当前任务是“直接复用本地模式”还是“需要外部 best-practice 参与”
5. 如果是修改或重构，判断当前实现是否存在结构、API、样式或层级问题
6. 只有在本地规范缺失或不足时，才选择外部参考源
7. 输出实现决策摘要
8. 再交给下游 best-practice 或实现流程写代码
9. 写完后再复查一次是否达标

如果上下文不足，至少先说明“当前依据是什么”，不要直接发明一套新风格。

## Step 1: 扫描项目现有 UI 约定

优先检查：

- 组件目录结构
- 命名方式
- 受控/非受控组件写法
- props 命名习惯
- hooks 使用方式
- 状态管理方式
- className 组织方式
- 是否已有 `cn`、`cva`、`tv`、`clsx`
- 是否在用 Tailwind、CSS Modules、styled-components、vanilla-extract
- 是否已有 design system、`components/ui`、`features/*/components`
- 是否已有 antd、shadcn、radix、headless ui、react-aria 等依赖

需要先判断项目规范强弱：

- `strong`: 目录、命名、API、样式模式都较稳定
- `medium`: 有部分模式，但不完全统一
- `weak`: 基本没有明确规范，或同类组件写法高度分裂

## Step 2: 先复用项目内相似实现

开始写新组件前，必须先找项目内相似例子。

例如：

- 表单输入框
- 按钮组
- Modal / Drawer / Popover
- Table / List / Card
- Section 标题
- 空状态 / 错误状态 / loading 状态

如果项目中已有可用模式，应优先沿用，而不是重新设计 API。

## Step 3: 判断是否需要外部参考源

优先判断：

- 当前任务能否直接跟随项目现有模式完成
- 当前实现的问题是否主要来自项目内模式本身，还是来自实现偏离模式
- 当前组件是否缺少稳定的 API、样式或交互模式

只有当本地规范 `weak` 或局部不足时，才使用外部参考。

如果项目模式已经足够强，应输出“沿用本地模式”，而不是强行引用外部项目。

## Step 4: 选择外部参考源

选择规则：

- **API 设计优先参考 antd**
  - 参考点：命名一致性、受控/非受控边界、状态命名、组合关系、事件回调命名
- **样式组织优先参考 shadcn/ui**
  - 参考点：Tailwind 下的组件拆分方式、variant 设计、slot/primitive 包装、样式与语义的分层
- **交互与可访问性优先参考 radix**
  - 参考点：交互状态建模、触发器/内容区关系、键盘行为、ARIA 边界

不要照抄这些项目的目录结构、props 名称或实现细节。
参考的是模式，不是复制。

## Step 5: 判定当前实现问题

如果任务是修改、重构或 review，至少判断以下维度：

- 是否偏离项目现有 API 命名
- 是否偏离项目现有样式组织方式
- 是否把业务组件误放进 `components/ui`
- 是否 props 过多、职责不清
- 是否为了视觉差异创建了过多 variant
- 是否缺少受控/非受控边界
- 是否交互和可访问性模式不一致

输出时应指出：

- 问题属于项目规范缺失，还是实现偏离规范
- 应回退到哪类参考源
- 是需要轻量修正，还是需要按 best-practice 重写

## Step 6: best-practice 选择依据

本 skill 不负责展开完整写法，只负责指定“应该参照什么写”。

当需要回退到 best-practice 时，可使用这些依据：

- API 命名和受控边界问题
  - 参考 `antd`
- Tailwind / variant / primitive 包装问题
  - 参考 `shadcn/ui`
- 交互结构和可访问性问题
  - 参考 `radix`

具体 fallback 细节按需读取：

- [references/api-design-fallbacks.md](references/api-design-fallbacks.md)
- [references/style-fallbacks.md](references/style-fallbacks.md)

## Step 7: 组件层级判定

写 JSX UI 时，至少区分：

- `primitive`: 低语义基础件
- `shared`: 多处复用的通用 UI 组件
- `business`: 带业务语义和业务状态的组件
- `page-local`: 当前页面或当前 feature 内部组件

如果一个组件只服务当前页面或当前 feature，不要急着放进 `shared`。

## Step 8: 输出实现决策摘要

在动手写代码前，或在 review 现有实现后，应至少明确输出：

```md
项目规范强度:
项目内相似实现:
当前实现问题:
外部参考源:
建议回退方向:
组件层级:
建议文件位置:
风险点:
```

示例：

```md
项目规范强度: medium
项目内相似实现: 已有 Dialog、Button、Input 组件，可直接复用
当前实现问题: 当前 Popover 使用 `visible` / `setVisible`，且样式写法偏离项目现有 `cn` + `cva`
外部参考源: API 参照 antd；样式组织参照 shadcn；交互参照 radix
建议回退方向: 按 best-practice 重写 open 状态命名与 trigger/content 结构，但保留项目现有目录与样式工具
组件层级: shared component
建议文件位置: components/ui/command-palette.tsx
风险点: 若 props 继续增长，可能应拆出 page-local wrapper
```

## 组件写法红线

除判定层外，以下是对组件代码本身的硬性约束，写或复查时都必须检查：

- **不要写只返回 `null` 的组件**
  - 只返回 `null` 的"组件"本质上不产出 UI，应改写为工具函数、自定义 hook，或直接内联到调用点
  - 组件的职责是产出 JSX；纯逻辑、纯副作用不要包装成组件
- **避免只用 Fragment 包裹的组件**
  - 如果组件体只是 `<>...</>` 里若干段 JSX，且没有自身状态、语义或复用价值，通常应把内容直接并入调用方
  - 只有在多处复用、或需要独立 memo / 错误边界 / Suspense 边界时才保留
- **组件命名优先用最简单的词**
  - 避免生僻单词和冗余前缀；基础组件优先用 `Input`、`Button`、`Modal`，而不是 `BaseInput`、`CommonButton`、`CustomModal`
  - 只有在项目里确实同时存在多层封装需要区分时，才使用 `Base*` / `Raw*` / `Primitive*` 之类前缀
  - 命名应能让人一眼看出用途，不要让读者去猜

## 常见错误

- 明明项目已有明确模式，却照搬外部库写法
- 在一个项目里同时混用 antd 式 API 和 shadcn 式 API，导致命名不一致
- 把业务组件塞进 `components/ui`
- 把业务差异都放进 variant，导致组件变成万能配置器
- 项目不用 Tailwind，却强行按 shadcn 风格写
- 只看视觉，不看现有 hooks、状态、目录和导入边界
- 没有找项目内相似例子，就直接发明新模式
- 把本 skill 当成完整写法手册，而不是判定器

## 参考文件

按需读取：

- [references/project-convention-checklist.md](references/project-convention-checklist.md)
- [references/api-design-fallbacks.md](references/api-design-fallbacks.md)
- [references/style-fallbacks.md](references/style-fallbacks.md)
