---
name: flow-dev-task
description: >
  Use when the user hands a single concrete development task — either a new
  feature to implement or a bug to fix — and expects it driven end-to-end
  from intake through plan, code, test, verify, delivery review, and commit,
  without being asked every routing decision mid-way. Trigger on phrases like
  "开始做这个功能", "实现一下 X", "修一下这个 bug", "报错了你看看", "从 0 到提交",
  "全流程做完", "ship this", "implement X end-to-end", "fix this and commit".
  Do NOT use for: project kickoff (→ flow-project-bootstrap), skill authoring
  (→ flow-skill-dev), pure UI visual design (→ frontend-design / huashu-design),
  open-ended exploration without a concrete target, or multi-task parallel
  coordination.
---

# flow-dev-task

## Overview

这个 skill 串联 superpowers 的执行链，把**单个**研发任务从"接到需求 / 看到 bug"一路推到"commit push 完成"。核心价值不是发明新流程，而是**把既有 skill 拼起来、把问答压到最少、把纪律保住**。

三条设计信念：

1. **默认推进，不默认提问**。能从上下文推断的字段绝不问用户。
2. **每轮问题上限 3 个**。超上限就走"推断 + 假设清单"继续。
3. **路径选择全部硬写推断规则**，不询问用户"用哪种模式"。

## When to Use

- 用户给了一个**具体**的开发任务（功能或 bug），期待从头推到 commit
- 用户说"做一下 / 修一下 / ship 这个 / 全流程走完"
- 用户已有明确目标，不是在探索方向

## When NOT to Use

- 项目启动 / 定 MVP / 挑技术栈 → `project-prep` 或 `flow-project-bootstrap`
- 写 / 改 skill 本身 → `flow-skill-dev`
- 纯视觉设计 / 原型 / 动画 → `frontend-design` / `huashu-design`
- 用户还在发散探索，没有明确任务 → 直接 `superpowers:brainstorming`
- 多任务并发编排 → 本 skill 只处理**单任务**；多任务拆开逐个调用

## Scenario Classification（开场必做）

根据用户初始 prompt 判定分支：

| 关键词 | 分支 |
|---|---|
| bug / 报错 / 错了 / 不对 / fix / 修 / 故障 / 挂了 / 异常 / broken | **修复链** |
| 实现 / 做一个 / 加一个 / 新功能 / 需求 / feature / build / ship | **功能链** |
| 同时命中 / 完全模糊 | 停下追问**一句**："这是修现有 bug 还是做新功能？" |

判定结果固定分支，后续流程不再切换。

## Context Harvest（减问的关键）

进入任何提问之前，**必须先自动提取**下列信息。能推断的绝不问：

- 用户 prompt 里显式的目标 / 约束 / 非目标
- 当前 git 分支名 + 最近 3 条 commit message
- `git status --short`（脏改动 / 未提交文件）
- 用户已指出的文件路径 / 行号 / 错误栈
- 最近一次 agent 的改动范围（从对话历史）
- 项目根目录有没有 `package.json` / 测试框架配置（vitest/jest/pytest 等）

用这些推断：
- 任务范围（小 / 中 / 大）
- 是否已有测试框架
- 是否已开 worktree / 是否在 non-default 分支
- 是否"做到一半"

## Question Budget（硬约束）

- 一轮追问**最多 3 个问题**。超了必须停下，用"最佳推断 + 明确假设清单"继续
- 禁止 Socratic 挤牙膏。**所有问题一次性批量列出**（编号 + 建议默认值）
- 用户回复模糊（"随意 / 都行"）→ 取默认，不再回问
- 用户说"直接做 / 别问了 / 按你的理解来" → 立即停止提问，推进
- 禁止以"为了更准确"为借口开第二轮问答

## Workflow — 功能链

```
Stage 0: Classify = feature
  ↓
Stage 1: Brainstorm（条件跳过，见 Skip Rules）
  └─ 调用 superpowers:brainstorming，传入 Context Harvest 做预填
     产出：一句话目标 / 一个 happy path / 非目标（合一起 ≤ 3 项问）
  ↓
Stage 2: Writing Plan（条件跳过）
  └─ 调用 superpowers:writing-plans
  ↓
Stage 3: Worktree 判定（条件启用）
  └─ 文件数 > 10 → 调用 superpowers:using-git-worktrees
  ↓
Stage 4: Execute Mode 自动判定
  └─ 按 Execute Mode Rules 表选一种，不问
  ↓
Stage 5: 写代码（TDD 硬 handoff）
  └─ 不在 TDD Skip Whitelist → 调用 superpowers:test-driven-development
  ↓
Stage 6: superpowers:verification-before-completion
  ↓
Stage 7: delivery-gate（验收）
  ├─ PASS → 推进
  └─ must-fix → 回 Stage 2 或 Stage 5，**禁止**直接到 Stage 8
  ↓
Stage 8: clean-commit
  └─ IM 会话下由它自动 push（无需再额外处理）
  ↓
Stage 9: finishing-a-development-branch（条件跳过）
  ↓
Output: Flow Dev Task Report
```

## Workflow — 修复链

```
Stage 0: Classify = bugfix
  ↓
Stage 1: superpowers:systematic-debugging
  └─ **必走，不可跳**。先定位根因
  ↓
Stage 2: Writing Plan（多数跳过）
  └─ 根因明朗 + 单点修复 → 跳；跨模块修才走
  ↓
Stage 3: Worktree（多数跳过，bug 修复通常小）
  ↓
Stage 4: Execute Mode
  └─ 单点修复通常走 direct；复杂场景按 Execute Mode Rules
  ↓
Stage 5: 写代码（TDD 硬 handoff）
  └─ **必须先写 failing repro test**（RED 阶段固化 bug 复现）→ 修到 GREEN
  ↓
Stage 6: superpowers:verification-before-completion
  └─ 必须真跑 repro test 验证 fix，不能"我觉得修好了"
  ↓
Stage 7: delivery-gate
  ↓
Stage 8: clean-commit
  ↓
Stage 9: finishing-a-development-branch（条件跳过）
  ↓
Output: Flow Dev Task Report
```

## Decision Rules（硬写死，不询问）

### Execute Mode Rules

| 规则 | 命中 | 选 |
|---|---|---|
| 1 | plan 有 ≥ 2 个独立任务且**无顺序依赖** | `superpowers:dispatching-parallel-agents` |
| 2 | plan 有顺序依赖且 ≥ 3 步 | `superpowers:subagent-driven-development`（当前 session） |
| 3 | plan 单步 或 纯局部改动 | **直接自己写**，不调 execute skill |
| 4 | 用户显式说"开新会话跑 / fresh session" | `superpowers:executing-plans` |

### TDD Skip Whitelist

进入任何 coding unit 前，除非命中以下一条，**必须调用 `superpowers:test-driven-development`**：

1. 纯配置 / 纯文档 / 纯 typo / 纯 lint 修复
2. POC / spike（用户**显式**声明）
3. 纯视觉改动（只动 CSS / 图像 / 样式） → handoff 给 `frontend-design` + `delivery-gate` 截图验证替代测试
4. 项目无测试框架 → 报告用户，**交付报告里必须标为技术债**，本次走 manual smoke test

**禁止**以"这块不好写测试 / 时间紧 / 小改动"自我合理化跳过。

### Writing-Plans Skip Rule

跳过 writing-plans 的条件（任一命中即跳）：

- 改动 ≤ 5 文件 且 无新增模块 / 无跨层改动
- 修复链下：根因明朗 且 单点修复

否则强制调用 `superpowers:writing-plans`。

### Worktree Rule

- 改动文件数 ≤ 10 → **不**开 worktree
- 改动文件数 > 10 或跨多个包 → 启用 `superpowers:using-git-worktrees`

### Brainstorm Skip Signals

命中任一即跳过 `superpowers:brainstorming`，直接进 writing-plans：

- prompt ≥ 200 字 且 含"怎么做 / 步骤 / 实现"等实施级关键词
- 用户明说"直接做 / 别问了 / 按你的理解来"
- 修复链下：`systematic-debugging` 已经替代 brainstorm 的探索作用

### Finishing-a-Development-Branch Rule

- 无 worktree 且 当前分支 ∈ {main, master, dev} → **跳过**
- 有 worktree 或 非 default 分支 → 调用 `superpowers:finishing-a-development-branch`

## Output Contract

完成后必须输出（不得省略任何字段）：

```md
## Flow Dev Task Report

### 目标
- 任务类型: feature | bugfix
- 一句话目标:
- 改动范围: <文件数> 文件 / <模块>

### 执行路径
- Brainstorm: done | skipped (reason)
- Writing Plan: done | skipped (reason)
- Worktree: used | not used
- Execute Mode: parallel | subagent | direct | executing-plans
- TDD: done | skipped (reason ∈ whitelist)

### 交付
- verification-before-completion: pass | fail + reason
- delivery-gate: pass | fail + must-fix list
- Commit SHA:
- Push status: pushed | skipped | failed | n/a
- Branch handling: merged | PR | cleanup | no-op

### 技术债 / 风险
- <项>: <说明>

### 结论
- 可交付: yes | no
- 剩余问题:
```

## Red Flags — STOP

命中任一必须**停下并返回上一阶段**，不允许合理化继续：

- 同一轮追问超过 3 个问题
- 未做 Context Harvest 就开始提问
- 跳过 systematic-debugging 直接改 bug
- verification-before-completion 未跑就进 delivery-gate
- delivery-gate 返回 must-fix 但直接进 commit
- 以"时间紧"或"这块不好测"为由跳 TDD
- "我觉得修好了" 就宣告完成

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "这块不好写测试，跳 TDD 吧" | 不在 Whitelist 就不能跳。白名单是穷举的 |
| "计划太简单就不走 writing-plans 了" | 跳 plan 看文件数规则，不看感觉 |
| "bug 不复杂，跳 systematic-debugging" | 修复链不可跳 debug，skill 原文硬门槛 |
| "delivery-gate 过了，不用再 verify" | 顺序是 verify → delivery-gate，互不替代 |
| "分支就在 main，不用 finishing" | 要检查跳过条件是否真满足（worktree/分支名） |
| "先问一下用户用哪种模式吧" | 命中推断规则就直接走，禁止回问 |
| "改动看起来小，跳 TDD 直接写" | 小改动不在白名单。白名单只认 4 种 |
| "我理解的用户意图应该没错，直接写代码" | 新功能链至少一次 Context Harvest + brainstorm（除非命中跳过信号）|

## Relationship to Other Skills

- **上游**：用户直接触发 / `flow-project-bootstrap` 产出第一个任务后可调用
- **下游（调用）**：
  - `superpowers:brainstorming` / `systematic-debugging` / `writing-plans`
  - `superpowers:test-driven-development` / `using-git-worktrees`
  - `superpowers:dispatching-parallel-agents` / `subagent-driven-development` / `executing-plans`
  - `superpowers:verification-before-completion` / `finishing-a-development-branch`
  - `delivery-gate` / `clean-commit`
- **不 handoff**：`flow-skill-dev`（那是 skill 开发）/ `flow-project-bootstrap`（那是项目级）

## Reuse

测试用例保留在 `tests/cases.md`，后续修订以这些用例为回归基线。
