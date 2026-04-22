---
name: flow-jsx-ui
description: Use when handling JSX UI creation, modification, or refactoring in React, Preact, Fresh, or similar frameworks and you need one orchestrator to first define component boundaries, then judge local conventions, route writing to the right best-practice source, and loop back through review until the UI is acceptable; 用于处理 React、Preact、Fresh 等 JSX UI 的新建、修改或重构，并由一个编排 skill 先确定组件边界，再判断本地规范，把写法路由给合适的 best-practice 来源，最后反复复查直到可接受。
---

# JSX UI 开发编排

## 概览

这个 skill 用于编排完整的 JSX UI 开发闭环。

它不替代 `ui-component-extraction`、`jsx-ui-authoring` 或任意 best-practice skill。
它的职责是决定何时调用这些能力、何时回环复查，以及在什么情况下继续修正。

默认行为是执行到“可交付 UI 修改方案”，不是只给流程建议。

## 适用时机

以下情况使用本 skill：

- 新建 JSX UI 组件
- 修改已有 JSX UI 组件
- 对 JSX UI 做结构重构、样式整改或 API 整理
- AI 生成的 UI 需要进入真实维护状态
- 任务同时涉及组件边界、编码规范、best-practice 写法和复查

以下情况通常不要使用：

- 只做纯性能优化
- 只做纯视觉创意设计，不落 JSX 代码
- 只抽取普通函数或后端模块
- 用户只要你执行一个已经完全明确的微小改动

## 角色分工

这个编排 skill 必须遵守以下分工：

- `ui-component-extraction`
  - 负责确定范围和组件边界
- `jsx-ui-authoring`
  - 负责判定项目规范、参考源和当前实现问题
- best-practice skill
  - 负责具体写法
  - 例如 `vercel-react-best-practices`
  - 也可以是未来新增的其他 React / Preact / UI 编写规则源

不要让 `jsx-ui-authoring` 直接承担完整写法。
不要让 best-practice skill 直接跳过范围判断。

## 必要流程

必须按顺序执行：

1. 判定任务类型
2. 判断是否需要先做组件边界分析
3. 若需要，先走 `ui-component-extraction`
4. 调用 `jsx-ui-authoring` 做项目规范和问题判定
5. 选择合适的 best-practice skill
6. 执行真实代码修改
7. 再次调用 `jsx-ui-authoring` 复查结果
8. 若复查不通过，回到 best-practice 修正
9. 直到复查通过或明确卡点

在完成第 7 步之前，不要宣称 UI 写好了。

## Step 1: 判定任务类型

先判断当前任务属于哪一类：

- `new-ui`
- `modify-ui`
- `refactor-ui`
- `extract-components`
- `style-cleanup`
- `api-cleanup`

如果一个任务同时包含多项，应按“范围 -> 判定 -> 写法 -> 复查”的顺序处理。

## Step 2: 是否需要先做组件边界分析

满足以下任一条件时，必须先走 `ui-component-extraction`：

- 页面或组件明显臃肿
- 用户明确提到组件拆分、组件抽取、边界不清
- 需要区分 page-local、business、shared、primitive
- AI 生成代码中重复视觉块很多
- 你不确定某块 UI 应该放在哪一层

若满足以下条件，可跳过：

- 修改范围已明确落在单个稳定组件内部
- 本次只是微调已有组件，不涉及层级和边界

若跳过，必须在最终报告中说明为什么能跳过。

## Step 3: 用 `ui-component-extraction` 确定范围

当边界分析是必需项时，至少要产出：

- 组件候选
- 每个候选的层级归类
- 建议文件位置
- 抽取或不抽取的理由

没有这一层输入时，不要直接进入 best-practice 写法阶段。

## Step 4: 用 `jsx-ui-authoring` 做判定

在动代码前，必须让 `jsx-ui-authoring` 判断：

- 项目规范强度
- 是否已有可直接复用的本地模式
- 当前任务应沿用本地模式，还是回退到外部参考源
- 如果是修改/重构，当前实现的问题属于“偏离规范”还是“规范缺失”
- 建议回退方向

这里的输出是写法路由依据，不是最终实现。

## Step 5: 选择 best-practice skill

根据 `jsx-ui-authoring` 的判定，选择下游写法来源。

示例：

- React / Next.js 侧重性能、状态和实现细节
  - `vercel-react-best-practices`
- Tailwind / primitive / variant / shadcn 风格
  - 由 `jsx-ui-authoring` 指定按 shadcn 模式写
- 其他框架或规则源
  - 选择对应 best-practice skill

如果当前环境没有完全对应的 best-practice skill，应：

- 保留 `jsx-ui-authoring` 的判定结果
- 按最接近的规则源执行
- 在最终报告中说明缺失项

## Step 6: 执行真实代码修改

这一阶段必须做真实文件修改，而不是只输出建议。

执行时应遵守：

- 优先复用项目现有实现
- 保持目录分层与组件层级一致
- 不把业务组件误塞进 `components/ui`
- 不为了复用而创造万能组件
- 不绕过前面已经得到的范围和判定结论

## Step 7: 用 `jsx-ui-authoring` 复查

代码修改后，必须再次让 `jsx-ui-authoring` 检查：

- 当前实现是否仍偏离项目规范
- API 是否一致
- 样式组织是否一致
- 组件层级是否正确
- 是否存在 props 爆炸或过度抽象
- 是否仍需要回退到 best-practice 再修正

如果 `jsx-ui-authoring` 仍判定有问题，不得提前收尾。

## Step 8: 回环修正

当复查不通过时：

1. 保留问题列表
2. 回到对应 best-practice 规则源
3. 继续修改
4. 再复查

不要在第一次复查失败后直接结束。

## 输出要求

最终报告至少包含：

- 任务类型
- 是否做了组件边界分析
- `jsx-ui-authoring` 的前置判定结果
- 使用了哪个 best-practice 来源
- 是否经过复查
- 复查结论
- 若仍有问题，卡在哪一层

## 常见错误

- 跳过 `ui-component-extraction` 直接开始拆组件
- 把 `jsx-ui-authoring` 当成写法规则库
- 没有先判定项目规范，就直接照抄外部参考
- best-practice skill 没有拿到范围和判定结果就直接写
- 写完后不复查
- 复查发现问题后不回环修正

## 完成判定

只有同时满足以下条件，才可认为本次编排完成：

- 若需要边界分析，则已完成 `ui-component-extraction`
- 已完成 `jsx-ui-authoring` 前置判定
- 已选择并使用合适的 best-practice 来源
- 已做真实代码修改
- 已完成至少一次 `jsx-ui-authoring` 复查
- 若复查不通过，已继续回环或明确说明阻塞原因
