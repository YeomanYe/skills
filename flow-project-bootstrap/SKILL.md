---
name: flow-project-bootstrap
description: Use when a user wants a full project kickoff bundle that combines project prep, engineering rules, and design options in one chain. Trigger on requests like "bootstrap this project", "项目初始化", "帮我定 MVP 和规范和设计", "从需求到 kickoff", or any ask that combines MVP scoping, main interaction design, preview requirement decisions, engineering setup, and design direction. Use this orchestrator when the user wants the whole package, not just prep, rules, or design alone.
---

# Orchestrating Project Bootstrap

## Overview

编排器，把原始产品需求转成三件套 kickoff 包：

1. **项目前置准备** —— 通过 `project-prep` 锁定 MVP、主交互设计、主要技术栈、preview decision
2. **工程规范脚手架** —— 通过 `project-rules-design` 产出
3. **候选设计系统** —— 通过 `ui-ux-pro-max` 返回 2–4 套

核心原则：前置准备同时驱动规范（技术栈 → 规则域布局）与设计（产品类型 → 视觉语言）。必须先锁定项目前置准备，再调用两个下游 skill，最后汇总并附开放决策清单。

本 skill 不替代下游 skill。它负责编排顺序、强制前置准备先行，并保护三个用户容易漏提的属性：显式交互设计、preview decision、≥2 套候选设计。

## When to Use

- 用户描述一个产品或项目需求并希望拿到完整 kickoff 包
- 用户要求 "MVP / 规范 / 设计" 中至少两件 + 含 kickoff 意图
- Greenfield 或近 greenfield（大型重做、品牌重塑属此类）

## When NOT to Use

- 只要开发前准备（MVP / 主技术栈 / preview requirement）—— 直接用 `project-prep`
- 只要 MVP —— 直接写，不要编排
- 只要规范 —— 直接用 `project-rules-design`
- 只要设计系统建议 —— 直接用 `ui-ux-pro-max`
- 项目已进入实现中段，只想调整单一维度

## Mandatory Workflow

### Step 1 —— 先完成项目前置准备

在调用任何下游 skill 之前，必须先运行 `project-prep`，并把它的输出作为本次 kickoff 的唯一前置定义。

Step 1 的完成标准不是“有一份大概的 MVP”，而是已经明确拿到：

- **MVP 范围**
- **主交互设计**
- **主要技术栈**
- **Preview decision**：`Required` / `Not needed` / `Already satisfied`

如果 `project-prep` 因需求过于含糊而停下澄清，本 skill 也必须停下，不能跳过。

### Step 2 —— 工程规范脚手架

以锁定的项目前置准备为上下文，调用 `project-rules-design`。传给它：

- 由 Step 1 确认的技术栈 / 框架
- 由 Step 1 推断的主要业务域（如 auth、billing、content、dashboard、checkout）
- 是 greenfield（新起 CONTRIBUTING 脚手架）还是 adjacent-to-existing（audit + patch）

原样接收规则 skill 的产出；不要改述，也不要把其内容吸收到本 skill 的 voice 里。

### Step 3 —— 候选设计系统

以锁定的项目前置准备为上下文，调用 `ui-ux-pro-max`。传给它：

- 由 Step 1 推断的产品类型（admin / e-commerce / landing / dashboard / tool / marketing 等）
- 目标用户
- 品牌调性（若用户声明）；未声明时请对方给出覆盖合理区间的 2–3 个选项
- 硬性视觉约束（暗色主题对等、无障碍等级、响应式断点）

请求 2–4 套候选（用户明说数量时取用户数量）。每套候选至少包含：

- Style 名称与一句话定位
- 配色方向
- 排版字体组合
- 布局 / 密度思路
- 与其他候选相比的核心 tradeoff

对 `ui-ux-pro-max` 的请求框架原话：**"Return candidates for user selection with tradeoffs. Do NOT implement or commit to a single direction."** 这是为了抵消该 skill action-oriented 的默认模式。

永远不要单方面挑一套。选择权归用户。

### Step 4 —— 汇总并浮出开放决策

两个下游 skill 都返回后，按以下顺序交付：

1. **项目前置准备**（Step 1 产出）—— 着重记录：交互设计、in-scope / non-goals、技术栈约束
   同时保留 preview decision；若为 `Required` 或 `Already satisfied`，要写清对应策略或现状
2. **后续规划**（post-MVP roadmap）—— 把 Step 1 期间与用户讨论过、但本期不做的事项单独落档。来源包括：
   - 被划入 non-goals 的功能
   - 被用户提及但暂缓的方向（"先不做但以后要做"）
   - MVP 交互中埋下的扩展点（预留 slot、未来再细化的分支）
   - 对规模 / 用户量 / 增长路径的预期
   如果这期根本没探讨到后续，必须显式写一行 "本期未讨论后续规划"，不得留空
3. 规则脚手架（`project-rules-design` 产出）
4. **候选设计系统 —— 全量清单**（`ui-ux-pro-max` 产出）：
   - 原样记录 ui-ux-pro-max 返回的**所有**候选（通常 2–4 套，用户指定数量时取用户数量）
   - 用户即使已在对话中偏好某一套，也不得在最终交付里删除其他候选
   - 每套完整保留 style 名、配色、字体、布局、tradeoff
5. **开放决策** —— 显式列出用户在进入实现前必须确认的事项，至少：接受 MVP 切片、确认 preview 策略、确认后续规划方向、接受规则域、挑选一套设计

## Handoff Contract

路由给下游 skill 时：

- 传紧凑版前置准备摘要（~6 bullets），而不是完整文档
- 明确表达请求："为 X 产出规则脚手架"、"为 Y 提出 N 套候选设计"
- 带上用户声明的硬约束
- **用户声明的数值约束覆盖本 skill 的默认值。** 用户说 "至少 3 套设计系统" 时传 3，不是本 skill 默认的 2–4；用户封顶 2 套时传 2
- 不要向用户追问 Step 1 里已有的信息 —— 下游 skill 应继承上下文

不要把下游 skill 的内部文档或框架复制到本 skill 的输出里。让它们自己说话，并注明出处。

## Output Contract

最终交付按以下顺序必须包含：

1. 有显式 "主交互设计" 与 "Preview decision" 的项目前置准备文档
2. **后续规划（post-MVP roadmap）**一节 —— 列出暂缓事项、扩展点、规模预期；无则明写 "本期未讨论"
3. 工程规范脚手架（或 patch，若是 near-greenfield）
4. **候选设计系统全量清单** —— 2–4 套（或更多）带 tradeoff，即使用户已口头偏好也必须保留全量
5. 开放决策清单

1–4 任一缺失即视为未完成。

## Red Flags —— STOP 并重新考虑

- 将要调用 `project-rules-design` 但项目前置准备还没锁 → 停下，先完成 `project-prep`
- 将要给出单一设计系统并视为完成 → 停下，产出 ≥2 候选
- 跳过交互设计（"从功能列表自明"）→ 停下，显式写出来
- 跳过 preview decision（"实现时再说"）→ 停下，先明确它是 `Required`、`Not needed` 还是 `Already satisfied`
- 需求含糊到无法用 3 句话描述核心流 → 停下，发澄清问题
- 用户只问了三维之一 → 不该触发本 skill，直接路由到对应单 skill
- 最终交付只留选中那套设计、把未选中的砍掉 → 停下，恢复全量清单
- 交付里没有 "后续规划" 段落 → 停下，补上（或显式写 "本期未讨论"），不得留空

## Rationalizations to Reject

| 说辞 | 现实 |
|------|------|
| "交互设计会从功能列表自动浮现" | 功能列表 ≠ 交互设计。屏幕、动作、状态流转必须显式 |
| "preview 可以等做到一半再想" | 对 extension / native / embedded 这类项目，越晚决定 preview，越容易把 UI 走查和真实验证耦死 |
| "挑一套设计系统省时间" | 视觉方向归用户。Kickoff 阶段候选比意见重要 |
| "规范等实现时再说" | 规范驱动目录结构。早锁定可避免事后重构 |
| "MVP 就是砍功能" | MVP 回答 "用户拿它做什么"，不仅是 "发什么" |
| "需求已经够清楚，不用澄清" | 核心流无法用 3 句话写清，就是不够清楚 |
| "两个下游 skill 并行跑能省一轮" | 两个都需要前置准备上下文；前置准备先行不可跳过 |
| "用户已经口头选了 A 套设计，其他就不用写了" | 全量候选是交付档的一部分。口头偏好 ≠ 书面决策；要在"开放决策"里让用户书面确认 |
| "后续规划是实现阶段再说的事" | 后续规划记录在 kickoff 阶段，用来锁定 non-goals 的边界和扩展方向；实现阶段再补就会掺进功能蔓延 |

## Common Mistakes

- 把 MVP 当成范围裁剪，而不是交互承诺
- 前置准备未锁就调下游 skill
- 把下游 skill 的内容用自己的 voice 改述
- 声明 kickoff 完成却没列开放决策
- 用户说 "就挑一套" 就真的只给一套

## Delivery Check

宣称 bootstrap 完成前，核对：

- `project-prep` 真的运行过，且返回了项目前置准备
- 前置准备里有显式的 "主交互设计" 一节（屏幕 + 动作 + 状态流转）
- 前置准备里有 `Preview decision`
- 已列 Non-goals
- **"后续规划" 段落存在**——列出了暂缓事项 / 扩展点 / 规模预期，或显式写 "本期未讨论后续规划"
- `project-rules-design` 真的运行过（不是 "应该运行"）
- `ui-ux-pro-max` 真的运行过并返回了 ≥2 候选
- **全量候选设计都在最终交付里**——没有因为用户口头偏好就删掉其他候选
- 开放决策清单存在且可执行（含 MVP 切片、后续规划方向、规则域、设计选择四类至少一项）
- 没有把下游 skill 的内容改述到本 skill 的 voice 里

## Reuse

本 skill 的测试场景保留在 `tests/cases.md`。未来修订本 skill 时以这些用例为基线。
