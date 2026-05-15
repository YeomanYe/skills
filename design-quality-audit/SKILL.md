---
name: design-quality-audit
description: Use when the user asks to check design quality, visual polish, UI effect, layout quality, product feel, screenshots, prototypes, landing pages, apps, dashboards, or whether a design looks professional; 触发于“检查设计质量/设计效果/页面观感/像不像专业设计/帮我从设计师角度看一下/截图审查/视觉审查/UX 审查”。
---

# Design Quality Audit

## Overview

这个 skill 用于从设计师视角审查一个已有界面或设计产物。核心原则：先拿到真实视觉证据，再给可执行的设计判断。

它不是创意发散 skill，也不是代码实现 skill。它输出问题、原因、优先级和修正方向。

## When to Use

使用于：

- 用户要求检查设计质量、设计效果、页面观感、UI polish、产品感
- 用户给了截图、页面 URL、本地应用、Figma 截图、落地页或 dashboard
- 用户问“这个看起来专业吗”“像不像 AI 生成”“哪里不协调”
- 完成前需要设计 gate，判断是否还需要截图、录屏或视觉返工

不要用于：

- 用户只要求实现功能、不涉及视觉质量判断
- 纯代码 API review、性能 review、安全 review
- 从零设计新页面；这类应使用专门的 frontend/design 生成流程
- 只检查 WCAG 或 Web Interface Guidelines；这类可用对应 accessibility / web-design skill

## Required Evidence

审查前必须尽量取得真实证据，优先级如下：

1. 用户提供的截图或设计稿
2. Playwright/浏览器打开真实页面后的截图，至少包含桌面视口；响应式风险高时补移动视口
3. 代码结构和样式文件，仅作为辅助证据

如果没有视觉证据，不要假装已经看过效果。应明确标记 `evidence: missing`，只输出基于代码的风险判断，并要求补截图或启动页面。

## Audit Workflow

1. 明确审查对象：页面、组件、截图、交互流程或整站
2. 收集证据：截图、视口尺寸、关键状态、可交互路径
3. 判断产品类型：SaaS/工具、营销页、内容页、游戏、移动端、插件 popup 等
4. 按设计维度逐项审查
5. 按严重度输出 findings
6. 给出最小修正路径，不直接重写整套设计，除非用户要求

## Design Dimensions

至少检查这些维度：

- 信息层级：主次是否清楚，标题、数据、操作是否抢层级
- 布局与密度：间距、对齐、栅格、容器宽度、滚动区域是否稳定
- 视觉节奏：页面是否过空、过挤、卡片过多、重复装饰过重
- 字体与可读性：字号、行高、字重、按钮文字是否适配容器
- 色彩与对比：是否单一色系过度、语义色是否滥用、暗色/亮色是否可读
- 组件一致性：按钮、输入框、卡片、标签、图标、弹窗是否同一系统
- 交互状态：hover/focus/disabled/loading/empty/error 是否完整
- 响应式：移动端是否溢出、遮挡、文字换行失控、固定尺寸破版
- 产品气质：是否符合目标场景；工具类界面应克制高效，营销页应有明确第一屏信号
- 完成度：是否有临时感、AI 生成感、占位痕迹、无意义装饰或视觉噪声

## Severity

- `must-fix`: 影响理解、操作、可读性、响应式、品牌专业度，或会让用户认为产品不可用
- `should-fix`: 不阻塞使用，但降低质感、一致性或扫描效率
- `nice-to-have`: 风格增强，不影响当前交付

不要把个人审美偏好包装成 `must-fix`。每条 finding 必须说明它如何影响用户判断或使用。

## Output Format

默认使用：

```md
evidence: <screenshot/url/code-only + viewport>
verdict: <pass / pass-with-fixes / needs-redesign>

Findings
- [must-fix] <位置/元素>: <问题>。影响：<为什么重要>。建议：<怎么改>
- [should-fix] ...

Design Direction
- <保留什么>
- <优先改什么>
- <不要做什么>
```

如果审查代码，使用文件行号；如果审查截图，使用可见区域描述，如“popup footer 的 Complete all 按钮区”。

## Guardrails

- 不要只说“更现代”“更高级”“更干净”。必须说清楚具体元素和修正动作
- 不要在没有截图时断言视觉效果已通过
- 不要把 landing page 规则套到工具型 dashboard 上
- 不要把所有问题都归结为颜色；优先看信息层级、布局、密度和交互状态
- 不要要求大重做，除非现有结构无法通过局部修复达标
- 如果用户要的是最终验收，必须说明是否需要补 Playwright 截图或录屏

## Fast Checklist

快速审查时至少回答：

1. 第一眼知道这是什么、要做什么吗？
2. 最重要的内容和操作是否最突出？
3. 间距、对齐、字号是否稳定且一致？
4. 是否存在遮挡、溢出、错位、文字挤压？
5. 是否像目标产品类型，而不是模板或 demo？
6. 修三个点以内，最该先修什么？
