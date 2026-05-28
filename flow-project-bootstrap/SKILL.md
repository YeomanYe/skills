---
name: flow-project-bootstrap
description: Use when a user wants the **full multi-stage** project kickoff chain combining project prep, engineering rules, and design options together. Trigger on requests like "bootstrap this project", "项目初始化", "帮我定 MVP 和规范和设计", "从需求到 kickoff", "完整启动新项目", or any ask that combines MVP scoping, main interaction design, preview requirement decisions, engineering setup, and design direction. For only single-stage prep (MVP + tech stack alone), use `project-prep`. For only engineering rules, use `director-architect`. For only design, use `frontend-design` / `huashu-design`.
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)

# Orchestrating Project Bootstrap

## Overview

编排器，把原始产品需求转成**两阶段产物**，由用户在第一阶段末尾做关键选择后再进入第二阶段。

- **Stage 1 · 总设计文档（Discovery & Direction）**
  把 MVP、主流程、主交互、预览设计、设计系统候选、部署方案统一汇总成**一份总设计文档**。用户在该阶段末做四件锁定：选 MVP 切片、挑 1 个 preview mockup、确认部署目标、确认后续规划。
- **Stage 2 · 工程化产出（Build Scaffold）**
  基于 Stage 1 已锁定决策，产出工程规范、项目 logo、可访问的 preview 页（落地实现 Stage 1 描述的预览设计）。preview 页与总设计文档之间必须有双向链接。

核心原则：
- Stage 1 不写代码，不出工程脚手架；只产出设计文档
- Stage 2 以 Stage 1 的 written choices 为唯一输入；如果 Stage 1 决策未锁定，Stage 2 不得开始
- 两阶段间必须有显式 user gate，不允许从 Stage 1 直接连贯写到 Stage 2

本 skill 不替代下游 skill，它负责编排顺序、强制阶段门、保护用户容易漏提的属性（显式交互设计、preview decision、≥2 套候选设计、部署方案、logo、预览实现）。

## 角色信条

**我是 kickoff 编排器,不是产品经理替身;我把 Stage 1 锁死再让 Stage 2 跑,不允许穿越。**

**Kickoff 最容易死在"边讨论边动手"**——一旦我看到用户大概同意 MVP 切片就开始写代码,
**preview 设计 / 候选设计系统 / 部署方案这些"用户没主动提但应该问"的事就被跳过了**。
用户半年后回头看「为什么当初选了这个技术栈」、「为什么没做 logo」,**答不上来 = 我失职**。

我执行任务时心里只问一个问题:**"Stage 1 锁的 4 件事(MVP 切片 / preview mockup /
部署目标 / 后续规划),如果用户三个月后重读,能不能一眼看到他在哪天用什么理由做的决定?"**
不能 = 我编排错了。

**Stage 1 是 written choices,不是口头共识**。用户在群里说"那就这样吧"不是签字——
必须落到 docs/design.md 里,有具体取舍理由。**没写下来的决策等于没决策**。

最容易翻车的反模式（跳过 preview decision / 只给 1 套设计候选 / Stage 1 没锁就跑 Stage 2 /
越界做 PM 工作 / 写实际代码 / 出生产设计）→ 详见 `references/failure-modes.md`。

## When to Use

- 用户描述一个产品或项目需求并希望拿到完整 kickoff 包
- 用户要求 "MVP / 规范 / 设计 / preview / logo / 部署" 中至少两件 + 含 kickoff 意图
- Greenfield 或近 greenfield（大型重做、品牌重塑属此类）

## When NOT to Use

- 只要开发前准备（MVP / 主技术栈 / preview requirement）—— 直接用 `project-prep`
- 只要 MVP —— 直接写，不要编排
- 只要工程规范 —— 直接用 `director-architect`
- 只要设计系统建议 —— 直接用 `ui-ux-pro-max`
- 只要 logo 或 preview 页 —— 直接用 `huashu-design` / `frontend-design`
- 项目已进入实现中段，只想调整单一维度

---

## Stage 1 · Discovery & Direction（顶层概览）

> 全部派工细节、字段、降级路径见 `references/stage-1-discovery.md`。

**4 个 Phase**（详细执行顺序、3 路 mockup 派工 prompt、飞书推送、部署凭据检测都在 reference）：

- **1.1 项目前置准备** — 调 `project-prep` 锁 MVP / 目标用户 / 主交互 / 技术栈 / Preview decision
- **1.2 主流程 ASCII 图（可选）** — 用户明确要求时才出；默认跳过
- **1.3 设计方向 + Preview Mockup（核心）** — 两阶段 director-design：
  - **1.3a** 串行：派 1 个 director-design(variants) 出 3 方向卡（~2 min）
  - **1.3b** 3 路并行：基于方向卡派 3 路 director-design(mockup) 实现（~5 min）
  - **1.3c** 串行：调 `references/push-mockups.sh` 飞书推送 + 等用户挑选（不超时）
- **1.5 部署方案 + 凭据前置检测** — 按仓库可见性路由（public→GitHub Pages / private→Cloudflare Pages）；凭据缺失立刻提示用户配置，等用户回"配好了"才进 user gate
- **1.6 总设计文档拼装** — orchestrator 自己 reduce，按 8 节模板合并

**降级路径**：director-design 不可用 → 退回直调 `ui-ux-pro-max` + `huashu-design`；cc-connect 不可用 → 跳过飞书推送贴路径。

**重做命名硬规则**：`-v2` / `-v3` 递增，**禁止**覆盖原目录（用户要对比 v1/v2）。

**Stage 1 输出物** = 一份总设计文档（`docs/design.md` 或 `DESIGN.md`），8 节模板见 `references/output-contract-template.md`。

---

## Stage 1 / Stage 2 之间的 User Gate

Stage 2 不得自动启动。必须显式问用户：

> Stage 1 总设计文档已就绪。请确认以下决策后我再进入 Stage 2：
> 1. MVP 切片 OK 吗？
> 2. **挑选 1 个 preview mockup**？（mockup-1 / 2 / 3 / "都不行 重做" / "方向 N 改 X"）
> 3. 部署目标确认？
> 4. 后续规划方向 OK 吗？

**v5 简化**：从 5 问降为 4 问（合并原"preview 策略"和"设计系统"为单一"挑 mockup"）。
得到至少 1 / 2 / 3 三项明确回答前不进入 Stage 2。4 可以推断默认。

如果用户回 "都不行 重做" / "方向 N 改 X"：回 1.3 重派（用 `-v2` 后缀，不覆盖原 mockup）。

---

## Stage 2 · Build Scaffold（顶层概览）

> 全部派工细节、A/B 模式选择、部署 wrangler 脚本见 `references/stage-2-build.md`。

进入 Stage 2 的硬前置：Stage 1 总设计文档已落盘 + 用户已挑 1 个 mockup + 部署目标已确认。

**2.1 / 2.2 / 2.3 三路完全独立并行**（按 `references/parallelization-template.md` 派工，prompt 字段集遵循 `references/dispatcher-template.md`）：

| Slot | 调用 skill | 写入目录 |
|---|---|---|
| `engineering-rules` | `director-architect`（显式） | `CONTRIBUTING.md` / `AGENTS.md` / `docs/<domain>/` |
| `logo-design` | `huashu-design`（显式，≥2 方向） | `assets/logos/` 或 `branding/` |
| `preview-impl` | `frontend-design`（A 模式显式） 或直接 `cp`（B 模式） | `preview/` 或项目内 preview 路由 |

**2.3 模式选择**：有前端栈 → A 模式（frontend-design 重写）；无前端栈 → B 模式（直接拷 mockup 目录）。

**2.4 部署接线**（必须 3 路全 ok 才开始，串行）：按 Stage 1 第 6 节锁定的目标接线（GitHub Pages / Cloudflare Pages / Vercel / Netlify / 自托管）。**凭据二次校验防漂移**，部署完成后**必须回写 URL** 到总设计文档第 5 节 + preview 页头部"返回总设计文档"链接（双向链接硬性要求）。

---

## Handoff Contract

路由给下游 skill 时：

- 传**紧凑版**前置准备摘要（~6 bullets），不是完整文档
- 明确请求："为 X 产出规则脚手架"、"为 Y 提出 N 套候选设计"、"为 Z 出 2 个 logo 方向"
- 带上用户声明的硬约束
- **用户声明的数值约束覆盖默认值**（候选数、设计候选数、logo 方向数）
- 不要重复追问 Stage 1 已确认的信息——下游 skill 应继承上下文

不要把下游 skill 的内部文档复制到本 skill 输出里；让它们自己说话并注明出处。

派工 prompt 字段集 + subagent 行为约束 → `references/dispatcher-template.md`（单次 dispatch）+ `references/parallelization-template.md`（并行决策）。

## Output Contract

最终交付（两阶段累计）必须包含 7 项产物 + Delivery Check 清单，全文见 `references/output-contract-template.md`：

- Stage 1：总设计文档（8 节） + ASCII 流程图（如要求）+ 3 路 mockup 全量保留
- Stage 2：工程规范脚手架 + ≥2 logo 方向 + 可访问 preview 页（已部署）+ 双向链接已建立

任一缺失视为未完成。

## Red Flags / Rationalizations / Common Mistakes / Delivery Check

→ 详见 `references/failure-modes.md`。

包括：Stage 1 没锁就跑 Stage 2、私有仓库默认部署到 GitHub Pages、token 写进 git、部署后没回填 URL、只给 1 套设计候选、logo 用 emoji 占位等典型反模式 + 自欺台词 + 易翻车清单。

## Codex Delegation Hook

Codex 是对等 agent，能做本 skill 的所有执行工作。是否派工取决于 **ROI**（净收益 = 省 Claude token + 并行性 - SPEC 成本 - 协调成本 - review 成本 - 质量风险）。

### 🟢 高 ROI 推荐派
- **Stage 2.1 工程脚手架配置文件**（tsconfig / eslint / prettier / commitlint 等，≥ 30 行 / ≥ 2 文件）
- **Stage 2.4 部署接线 YAML/config**（GitHub Actions workflow / Cloudflare config，≥ 30 行）

### 🟡 中 ROI 视情况派
- **Stage 2.3 preview 页实现**：handoff 给 frontend-design 后由其判断（通常 ≥ 200 行落地页才划算）
- **Stage 2.1 规则文档**（CONTRIBUTING / AGENTS.md）：仅当模板化结构 + 规则项 ≥ 20 条时；写决定权在 Claude

### 🔴 低 / 负 ROI 不建议派
- **Stage 1 全部**：设计决策类（MVP 切片 / 流程图 / 设计系统候选 / 部署目标），无执行单元，需要 Claude 推断
- **Stage 2.2 logo 设计**：视觉工作走 `huashu-design`，Codex 调它和 Claude 调它没差别
- **User gate 之间的决策同步**：依赖会话上下文，Codex 起新进程拿不到

派工细则（SPEC 模板、prompt 模板、review checklist、错误分类、Red Flags）**全部以 `flow-dev-task` 的 "Codex Delegation Hook" 为唯一规范**，不在本 skill 重复。

## Reuse

本 skill 的测试场景保留在 `tests/cases.md`。未来修订本 skill 时以这些用例为基线。
