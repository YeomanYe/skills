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

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)
> 本 skill 对齐 `../_shared/flow-template.md`(flow-* 元规范)。Executor Selection 引 `../_shared/executor-selection-template.md`(2026-06 改版:Codex 重委派降级为可选,默认便宜档 subagent)

# flow-dev-task

## Overview

这个 skill 串联 superpowers 的执行链，把**单个**研发任务从"接到需求 / 看到 bug"一路推到"commit push 完成"。核心价值不是发明新流程，而是**把既有 skill 拼起来、把问答压到最少、把纪律保住**。

三条设计信念：

1. **默认推进，不默认提问**。能从上下文推断的字段绝不问用户。
2. **每轮问题上限 3 个**。超上限就走"推断 + 假设清单"继续。
3. **路径选择全部硬写推断规则**，不询问用户"用哪种模式"。

## 角色信条

**我是单 task 执行官,不是讨论组组长;我把任务推到 commit,不开会聊方案。**

核心原则：

- **能推断就推断**，推断错了 commit 之前用户会看到，会有机会改
- **问题预算 ≤ 3 是硬约束**。第 4 个问题想问的时候，**改成"我推断是 X，先按 X 干，跑通了 commit 前再确认"**
- 心里只问一个问题：**"如果我现在用 3 个问题之内的信息开始干，跑到 commit 那一步前，用户被我打断的次数会不会 > 必要次数？"** 会 = 我问得太多，跟"严谨"无关

最容易翻的 5 个车（详尽自我合理化拆穿 → `references/failure-modes.md`）：

1. **问超过 3 个问题** — 预算破一次，下次破第二次
2. **问能推断的字段** — 用 React 还是 Preact？看 package.json 啊
3. **替用户决定 scope** — "顺便把旁边那个 bug 也修了" = 越权，单 task 是单 task
4. **跳过 verification** — "测试应该过吧" = 没跑就说完成
5. **越界** — 改项目规则找 director-architect / 出 mockup 找 director-design / 扩展上架找 flow-ext-publish / 长跑找 flow-codex-goal

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

| 关键词 | 分支 | task_type(给 change-recap 用) |
|---|---|---|
| bug / 报错 / 错了 / 不对 / fix / 修 / 故障 / 挂了 / 异常 / broken | **修复链** | `bugfix` |
| 实现 / 做一个 / 加一个 / 新功能 / 需求 / feature / build / ship | **功能链** | `feature` |
| 解冲突 / merge conflict / rebase 冲突 / conflict marker / `<<<<<<<` | **修复链** | **`merge-resolve`** |
| 按 reviewer / 处理 review 意见 / must-fix / 改 review / address feedback / 改 review 反馈 | **修复链** | **`accept-review-feedback`** |
| 同时命中 / 完全模糊 | 停下追问**一句**："这是修现有 bug 还是做新功能？" | — |

判定结果固定分支,后续流程不再切换。**`task_type` 在 Stage 7.5 Auto-Recap Rule 使用,决定是否调 change-recap**。

## Context Harvest（减问的关键，**并行 Bash 执行**）

进入任何提问之前，**必须先自动提取**下列信息。能推断的绝不问。

**并行执行**：以下 7 项探测全部独立只读 Bash，按 `references/parallelization-template.md` 在**一个 message 里多个 Bash 调用**真并行（不需要派 subagent，Claude Code Bash 工具天然支持）：

| 探测 | 命令 | 用途 |
|---|---|---|
| 1. git 分支 | `git branch --show-current` | 是否在 non-default 分支 |
| 2. 脏改动 | `git status --short` | 是否"做到一半" |
| 3. 最近 commits | `git log --oneline -3` | 最近 agent 改动 |
| 4. 项目类型 | `ls package.json Cargo.toml go.mod pyproject.toml 2>/dev/null` | 技术栈 |
| 5. 测试框架 | `ls **/vitest.config.* **/jest.config.* pytest.ini 2>/dev/null` 或 `grep -l "vitest\|jest" package.json` | TDD 路径选择 |
| 6. 已修改文件 | `git diff --stat` | 改动范围估算 |
| 7. worktree 状态 | `git worktree list` | 是否已隔离 |

外加从 prompt + 对话历史提取（无需 Bash）：
- 用户显式的目标 / 约束 / 非目标
- 用户指出的文件路径 / 行号 / 错误栈

**性能**：原 7 次串行 Bash ~15s → 1 次并行 ~3s。Context Harvest 是最污染上下文的阶段（输出全部进对话），并行后单 message 一次性出结果，对话压力小很多。

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

## Workflow（功能链 + 修复链统一视图）

两条链 Stage 编号一致，仅 Stage 1 / Stage 5 内部要求不同。下表逐 Stage 对比：

| Stage | 功能链（feature） | 修复链（bugfix / merge-resolve / accept-review-feedback） |
|---|---|---|
| **0** Classify | `task_type=feature` | `task_type=bugfix \| merge-resolve \| accept-review-feedback` |
| **1** 探索 | **Brainstorm**（条件跳过，见 Brainstorm Skip Signals）— 调 `superpowers:brainstorming`，产出一句话目标 / happy path / 非目标 | **systematic-debugging**（**必走不可跳**）— 先定位根因 |
| **2** Writing Plan | 条件跳过（Writing-Plans Skip Rule），否则调 `superpowers:writing-plans` | 多数跳过：根因明朗 + 单点修复 → 跳；跨模块才走 |
| **3** Worktree | 文件数 > 10 → 调 `superpowers:using-git-worktrees` | 多数跳过（bug 修复通常小） |
| **4** Execute Mode | 按 Execute Mode Rules 表自动选，不问 | 单点修复通常 direct；复杂场景按表 |
| **5** 写代码 | 先按 Executor Selection 选执行者：<br>• Claude 自写（默认）：不在 TDD Skip Whitelist → 调 `superpowers:test-driven-development`<br>• 大体量纯样板：派便宜档 subagent(haiku/sonnet)，产出回来 Claude 验收<br>• 可选 Codex 重路径（≥2h+清晰验收才走）：写 SPEC → `codex exec` → JSON 报告 → Claude review → 通过/返工(≤3)/退回 | 同左，但**都必须先写 failing repro test 复现 bug** → 再 fix；外派时 review 须确认 repro test 真复现 + fix 真过测 |
| **5.5** UI Audit | `git diff` 含 `.tsx/.vue/.svelte/.css/.scss/.html` 等 → 派 subagent 调 `director-design`（mode=audit）。`needs-redesign` → 回 Stage 5；`pass-with-fixes` → must-fix 进 Stage 6 清单 | UI bug（视觉错位 / 交互失效 / 响应式）修完后同上派 audit，确认修复有效 |
| **6** Verification | 调 `superpowers:verification-before-completion`。**Codex 派工后此 Stage 由 Claude 亲跑**，不信 Codex 自报 | 同左，且**必须真跑 repro test 验证 fix**，不能"我觉得修好了" |
| **7** delivery-gate | PASS → 推进；must-fix → 回 Stage 2 / Stage 5，**禁止**直接 Stage 8 | 同左 |
| **7.5** change-recap pre-hook | 默认**跳过**（task_type=feature，新功能走 CHANGELOG 更合适），`--auto-recap=true` 强开 | **默认调**（bugfix / merge-resolve / accept-review-feedback），除非 `--auto-recap=false`。3 段讲解 + 推 IM（IM 会话）+ 拼 commit body |
| **8** clean-commit | IM 会话下自动 push（无需额外处理） | 同左 |
| **9** finishing-a-development-branch | 条件跳过（Finishing-a-Development-Branch Rule） | 同左 |
| **Output** | Flow Dev Task Report（schema → `references/output-contract-template.md`） | 同左 |

## Decision Rules（硬写死，不询问）

### Execute Mode Rules

| 规则 | 命中 | 选 |
|---|---|---|
| 1 | plan 有 ≥ 2 个独立任务且**无顺序依赖** | `superpowers:dispatching-parallel-agents` |
| 2 | plan 有顺序依赖且 ≥ 3 步 | `superpowers:subagent-driven-development`（当前 session） |
| 3 | plan 单步 或 纯局部改动 | **直接自己写**，不调 execute skill |
| 4 | 用户显式说"开新会话跑 / fresh session" | `superpowers:executing-plans` |

### Auto-Recap Rule(Stage 7.5 pre-hook,2026-05 新增)

**触发**: Stage 7 delivery-gate PASS 后,Stage 8 clean-commit **之前**,按下面表决定要不要调 `change-recap`:

| task_type | `--auto-recap` 默认 | 行为 |
|---|---|---|
| `bugfix`(修复链) | **true** | 调 change-recap,生成 3 段用户视角讲解 + 推 IM(若 IM 会话) |
| `merge-resolve`(刚解完合并冲突) | **true** | 同上 |
| `accept-review-feedback`(按 delivery-gate / reviewer must-fix 改完) | **true** | 同上 |
| `feature`(功能链) | **false** | 默认不调(新功能用 CHANGELOG / release notes 更合适);用户可 `--auto-recap=true` 强开 |
| 其他 | **false** | 不调 |

**CLI 参数**:
- `--auto-recap=true|false`(覆盖默认)
- `--audience end-user|pm|dev`(默认 `end-user`,透传给 change-recap)
- `--no-im`(若不想推 IM,只生成本地 markdown 拼 commit body)

**Fallback**:change-recap 生成失败(LLM 错 / token 超 / cc-connect IM 推失败)→ flow-dev-task **不阻断** Stage 8,跳过钩子继续走 commit,但在 Final Report `errors[]` 标记 `change-recap failed: <reason>`。

**clean-commit 纯净**:本 pre-hook 在 flow-dev-task **内部**实现,**不** require clean-commit 调 change-recap(clean-commit 保持单一职责)。

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

### Branch Policy（提交分支,硬写死）

**默认在当前分支提交,不切分支**。没有特别说明时,Stage 8 直接 `git add` + `git commit`(+ push)在**当前分支**(含 main / master),**禁止**自动 `git checkout -b feat/...` 新建 feature 分支、**禁止**自动开 PR。

- 这条**覆盖**基础运行时 "if on the default branch, branch first" 的默认 —— 用户已明确不要那个行为。
- **只有**用户在当次显式要求才切分支 / 走 PR:典型措辞"开个分支 / 切个 feature 分支 / 走 PR / 别动 main / don't commit to main"。
- 项目专属分支规则**优先于本条**:若该项目有固定开发分支约定(如 ty-vibe-kanban 固定提交在 `ty` 分支),按项目约定走,不在 main 上提交。
- **唯一的"建分支"合法例外 = Worktree Rule(>10 文件)**:此时 Stage 3 `superpowers:using-git-worktrees` 会 `git worktree add -b <新分支>`——这是 git 硬约束(worktree 必须挂独立分支,不能复用当前分支),属设计内隔离,**允许**;随后 Stage 9 `superpowers:finishing-a-development-branch` 负责 merge 回 base + 删分支。本 Branch Policy 约束的是**非 worktree 的默认路径**(≤10 文件 / 没开 worktree):别为了"隔离"或"保护 main"而自作主张 `checkout -b`。之前 loop-engine/node-scripts(均 ≤10 文件,worktree 没触发)被切分支,就是违反本条的典型。

### Director-Design Trigger Rule（**v4 新增**，Stage 5.5）

Stage 5 写代码完成后，按以下规则决定是否触发 Stage 5.5 UI Audit：

**触发条件**（任一命中）：
1. `git diff --name-only main` 含 `.tsx` / `.jsx` / `.vue` / `.svelte` / `.html` / `.css` / `.scss` / `.module.css` 等 UI 文件
2. 任务 prompt 含明确 UI 词汇："样式 / UI / 页面 / popup / dashboard / button / layout"
3. flow-dev-task 上游 handoff payload 含 `is_ui_task: true`

**派工**：按 `references/dispatcher-template.md` 标准字段拼 prompt 派 subagent 调 `director-design`（mode=`audit`）。flow-dev-task 在标准 handoff payload 之上额外传入字段：

| 字段 | 值 |
|---|---|
| `evidence_paths` | 截图路径；若无 → 让 subagent 用 playwright 自截 |
| `is_ui_task` | `true` |
| `design_tokens_source` | 项目 tokens 文件路径（推断） |
| `product_type` | 推断（dashboard / landing / form 等） |
| `mode` | `audit` |
| 约束 | 不修代码，只出 audit 报告 |

subagent 返回 JSON（`verdict` / `aggregate` / `must_fix` / `artifact_path`），完整报告落盘 `.agent/jobs/director-design-audit/output.md`。

**回流规则**：
- verdict = `needs-redesign` → 回 Stage 5 重写（视觉问题严重）
- verdict = `pass-with-fixes` → must-fix 写进 Stage 6 verification 清单
- verdict = `pass` → 直接进 Stage 6

**跳过条件**：纯后端 / API / 无 UI 改动任务

### Executor Selection（Stage 5 执行者选择）

通用规范见 `../_shared/executor-selection-template.md`。Stage 5 默认**当前 agent(Claude)自写**，按下面分流（不询问）：

**必须自写**（任一命中 → 不外派任何执行者）：
1. 改动 < 30 行 **或** < 2 文件
2. 高风险代码：auth / 支付 / 加密 / 输入校验 / 数据访问层
3. 强依赖会话上下文（未落地的设计、推断的状态）
4. bugfix 链下，根因尚未在 systematic-debugging 中确认

**派便宜档 subagent（haiku/sonnet）或 fast**（省钱手段，命中下面才外派）：
- 改动**大体量**（≳数百行 / 多文件）**且**性质是**纯样板**：CRUD / UI scaffolding / 测试夹具 / 配置 / 格式转换 / 批量重命名
- 收益来自**模型单价**，不需要 SPEC/review 往返：直接把任务给便宜档 subagent，产出回来 Claude 验收

**可选 Codex 重委派**（默认**不走**）：仅当任务 ≥2h + 有清晰验收 + 可并行/跨工程批量时才考虑。具体 SPEC / 派工 prompt / review / 错误分类（重路径，按需 lazy-load）见 `references/codex-delegation-detailed.md`、`references/codex-delegation-prompt.md`、`references/codex-spec-template.md`。长跑 Codex 任务的元方法是 `flow-codex-goal`。

**无论谁执行**，Stage 6 verification / delivery-gate / Stage 8 commit **仍由 Claude 亲跑**，不信执行者自报；走 Codex 重路径时 commit 须带 `(Codex: N round, <spec_compliance>)`。

## Output Contract

- **机器读 JSON schema**（基线字段 + 主流程裁决用）：见 `references/output-contract-schema.md`
- **人类读 markdown 模板**（完整 Flow Dev Task Report 字段表）：见 `references/output-contract-template.md`
- subagent 派工**返回 JSON**（含 `artifact_path`），完整 markdown **落盘**到 `.agent/jobs/flow-dev-task-<slug>/output.md`，主流程展示时 `Read artifact_path` lazy load
- flow-dev-task **必填**扩展字段（除基线外）：`task_type` / `executor` / `codex_rounds` / `codex_spec_compliance` / `codex_failure_mode` / `tdd_done` / `verification_passed` / `delivery_gate_verdict` / `change_recap_status` / `commit_sha` / `push_status` —— 完整语义见 `references/output-contract-template.md` 自定义字段表

## Failure Modes — STOP / Rationalizations

完整 Red Flags 清单 + Rationalizations 拆穿表见 `references/failure-modes.md`。

**主体只保留 6 条最高频 trip-wire**——命中任一立即停下回上一阶段，禁止合理化继续：

1. 一轮追问 > 3 个问题
2. 跳过 systematic-debugging 直接改 bug
3. verification-before-completion 未跑就进 delivery-gate
4. delivery-gate 返 must-fix 但直接 commit
5. 派 Codex 但没写 SPEC / Codex 报告 `spec_compliance != full` 还进 Stage 6
6. 信 Codex 自报 `tests_passed: true`，没 Claude 自跑验证
7. 用户没要求就 `git checkout -b` 切新分支提交（违反 Branch Policy，默认在当前分支提交）

其余反模式（"小改动跳 TDD"、"高风险也派 Codex"、"Codex 改了 SPEC 外文件也接受"、"永久错误走返工循环" 等）→ 查 `references/failure-modes.md`。

## Relationship to Other Skills

- **上游**：用户直接触发 / `flow-project-bootstrap` 产出第一个任务后可调用
- **下游（调用）**：
  - `superpowers:brainstorming` / `systematic-debugging` / `writing-plans`
  - `superpowers:using-git-worktrees`
  - `superpowers:dispatching-parallel-agents` / `subagent-driven-development` / `executing-plans`
  - `superpowers:verification-before-completion` / `finishing-a-development-branch`
  - `delivery-gate` / `change-recap`(Stage 7.5 pre-hook,bugfix/merge/accept-review 默认调) / `clean-commit`
- **下游（仅 Claude 自写路径调用）**：
  - `superpowers:test-driven-development`
  - **Codex 派工路径不调此 skill**，TDD 方法改由 SPEC 强制 + git commit 顺序检查
- **执行替代（不是流程替代）**：
  - **Codex**（通过 `codex exec` 或 codex-plugin-cc）：在 Stage 5 作为执行者代替 Claude
  - 替代后 verification/delivery-gate/commit 仍由 Claude 走，缺一不可
  - Codex 须读项目根 `AGENTS.md` 当作常驻规则
  - Stage 8 调 clean-commit 时必须显式传入 Codex 派工次数和 spec_compliance
- **不 handoff**：`flow-skill-dev`（那是 skill 开发）/ `flow-project-bootstrap`（那是项目级）

## Reuse

测试用例保留在 `tests/cases.md`，后续修订以这些用例为回归基线。
