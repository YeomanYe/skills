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

# flow-dev-task

## Overview

这个 skill 串联 superpowers 的执行链，把**单个**研发任务从"接到需求 / 看到 bug"一路推到"commit push 完成"。核心价值不是发明新流程，而是**把既有 skill 拼起来、把问答压到最少、把纪律保住**。

三条设计信念：

1. **默认推进，不默认提问**。能从上下文推断的字段绝不问用户。
2. **每轮问题上限 3 个**。超上限就走"推断 + 假设清单"继续。
3. **路径选择全部硬写推断规则**，不询问用户"用哪种模式"。

## 角色信条

**我是单 task 执行官,不是讨论组组长;我把任务推到 commit,不开会聊方案。**

**单 task 最容易死在"过度澄清"**——一旦我每个步骤都问一次"这样可以吗",
**用户的注意力被消耗光,本来 30 分钟的活拖到 2 小时还没开始动**。问答压到最少
是设计原则,不是建议——**能推断就推断,推断错了 commit 之前用户会看到,会有机会改**。

我执行任务时心里只问一个问题:**"如果我现在用 3 个问题之内的信息开始干,
跑到 commit 那一步前,用户被我打断的次数会不会 > 必要次数?"** 会 = 我问得太多,
跟"小心 / 严谨 / 用户体验",**一点关系都没有**——多问 = 不专业。

**问题预算 ≤ 3** 是硬约束,不是"差不多 3 个"。第 4 个问题想问的时候,**改成"我推断
是 X,先按 X 干,跑通了 commit 前再确认"**。推断 + 假设清单是默认路径,问问题是
例外路径。

我最容易翻的车——每一条都是"看起来在做执行官,实际在当讨论组组长":

- **问超过 3 个问题** — "为了稳妥我再多问一个" = **预算破了一次,下次就破第二次**。
  3 是上限不是建议,第 4 个问题必须变成推断 + 假设清单。
- **问能推断的字段** — "用户用 React 还是 Preact?" — **看 package.json 啊**。
  能从上下文 / git status / 文件读出来的字段一律禁止问,问 = 显得我没做 Context Harvest。
- **替用户决定 scope** — "我顺便把旁边那个 bug 也修了" = **越权扩 scope** = 用户的
  review 负担翻倍,commit diff 失焦。**单 task 是单 task,顺手补的事走另一个 task**。
- **跳过 verification-before-completion** — "测试应该过吧,直接 commit" = **没跑就说完成**
  = 把 verify 责任推给用户。"看起来好"不是 verify,跑命令拿输出才是。
- **越界做项目规范 / 设计判断 / 上架** — 我管单 task 端到端;**改项目规则找
  director-architect,出 mockup 找 director-design,扩展上架找 flow-ext-publish,
  长任务长跑找 flow-codex-goal**。越界 = 假装自己什么都懂 = 让每个领域都做半吊子。

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
Stage 5: 写代码（先判执行者：Codex 派工 vs Claude 自写）
  ├─ 按 Codex Delegation Hook 选执行者
  ├─ Codex 执行：写 SPEC（不在 TDD Whitelist 时 SPEC 强制 RED→GREEN）
  │              → codex exec → Codex JSON 报告 → Claude review
  │              → 通过/返工（≤ 3 次）/ 退回 Claude 自写
  └─ Claude 自写：不在 TDD Skip Whitelist → 调用 superpowers:test-driven-development
  ↓
Stage 5.5: UI Audit（**v4 新增**，仅 UI 改动触发）
  └─ 检测 git diff 含 .tsx/.vue/.svelte/.css/.scss/.html 等 UI 文件
     → 派 subagent 调 director-design audit mode
     → verdict needs-redesign → 回 Stage 5 重写
     → verdict pass-with-fixes → must-fix 写进 Stage 6 verification 清单
  ↓
Stage 6: superpowers:verification-before-completion
  └─ Codex 派工后此 Stage 不可跳，必须 Claude 亲自验
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
Stage 5: 写代码（先判执行者：Codex 派工 vs Claude 自写）
  ├─ 按 Codex Delegation Hook 选执行者
  ├─ Codex 执行：SPEC 必须包含「先写 failing repro test 复现 bug → 再 fix」要求
  │              → Claude review 时必须确认 repro test 真复现 + fix 真过测
  └─ Claude 自写：**必须先写 failing repro test**（RED 阶段固化 bug 复现）→ 修到 GREEN
  ↓
Stage 5.5: UI Audit（**v4 新增**，仅 UI bug 触发）
  └─ UI 相关 bug（视觉错位 / 交互失效 / 响应式 bug 等）修完后
     → 派 subagent 调 director-design audit mode 确认修复有效
  ↓
Stage 6: superpowers:verification-before-completion
  └─ 必须真跑 repro test 验证 fix，不能"我觉得修好了"
  └─ Codex 派工后此 Stage 由 Claude 亲跑，不能信 Codex 自报
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

### Director-Design Trigger Rule（**v4 新增**，Stage 5.5）

Stage 5 写代码完成后，按以下规则决定是否触发 Stage 5.5 UI Audit：

**触发条件**（任一命中）：
1. `git diff --name-only main` 含 `.tsx` / `.jsx` / `.vue` / `.svelte` / `.html` / `.css` / `.scss` / `.module.css` 等 UI 文件
2. 任务 prompt 含明确 UI 词汇："样式 / UI / 页面 / popup / dashboard / button / layout"
3. flow-dev-task 上游 handoff payload 含 `is_ui_task: true`

**派工方式**（subagent 调 director-design）：
```
必须显式调用 `director-design` skill (mode: audit)

输入:
  - evidence_paths: <截图路径，若无 → playwright 自截>
  - is_ui_task: true
  - design_tokens_source: <项目 tokens>
  - product_type: <推断>

输出: .agent/jobs/director-design-audit/output.md
返回 JSON: {verdict, aggregate, must_fix, errors}

约束: 不修代码，只出 audit 报告
```

**回流规则**：
- verdict = `needs-redesign` → 回 Stage 5 重写（视觉问题严重）
- verdict = `pass-with-fixes` → must-fix 写进 Stage 6 verification 清单
- verdict = `pass` → 直接进 Stage 6

**跳过条件**：纯后端 / API / 无 UI 改动任务

### Codex Delegation Hook

**前提认知**：Codex 是对等 agent（不是工具），具备本机所有工具：bash / 文件 / 浏览器自动化 / skills。能做 Claude 能做的所有事。

**派工不是"能不能"，是 ROI**：
> 净收益 = 省 Claude token + 并行性 - SPEC 撰写成本 - 协调成本 - review 成本 - 质量风险

进入 Stage 5 前按以下顺序判定**执行者**。Codex 是"执行替代"，**不替代** TDD / verification / delivery-gate / commit。

#### 必须 Claude 自写（任一命中 → 不派 Codex）

1. 用户明说"自己写 / 别派 Codex / 你来"
2. 改动预估 < 30 行 **或** < 2 文件
3. 高风险代码：auth / 支付 / 加密 / 输入校验 / 数据访问层 / 安全敏感
4. 任务紧密依赖会话上下文（前几轮推断的状态、未落地的设计）
5. Codex 不可用：`which codex` 无返回 / 登录失败 / 网络异常
6. bugfix 链下，根因尚未在 systematic-debugging 中确认

#### 默认派 Codex（不命中上面 + 任一命中下面）

1. 改动 ≥ 30 行 **或** ≥ 2 文件
2. 任务可独立 SPEC 化（不需会话上下文也能写完整 SPEC）
3. 任务以样板为主：CRUD / UI scaffolding / 测试用例生成 / 配置文件 / 格式转换 / 重命名

#### Codex 派工 5 步

**Step 0（前置）**：进入 Stage 5 第一件事执行 `which codex && codex --version`。
任一失败 → 命中"Codex 不可用"，整个 Stage 5 走 Claude 自写。

**Step 0.5（运行时探测）**：binary 存在不等于可用。每次 `codex exec` 后必须按 Codex 运行时错误分类（见下表）判定失败类型，**永久性错误立即退回 Claude，不消耗返工次数**。

1. **Claude 写 SPEC**：使用 `references/codex-spec-template.md` 模板，必须含：
   - 目标 / 范围（涉及/不涉及文件）/ 输入输出 / 技术约束
   - 验收 hard gates（功能、类型、lint、测试可验证项）
   - 不在 TDD Whitelist → SPEC **强制 RED→GREEN 顺序**（先 commit failing test，再 commit 实现）
   - 报告要求 JSON schema（含 `tests_written_first` / `spec_compliance` 等字段）
2. **派工**：使用 `references/codex-delegation-prompt.md` 模板拼 prompt
   - `codex exec --skip-git-repo-check <prompt>` 或 `/codex`（codex-plugin-cc 已装时）
   - prompt 必须包含：让 Codex 先读项目根 `AGENTS.md`、SPEC 全文、报告 schema、"Critical" 防谎报段
3. **Codex 输出 JSON 报告**
4. **Claude review**（不可省略，逐项核对）：
   - 跑 SPEC 中所有 hard gate 命令（typecheck / lint / test），用**真实输出**对照 Codex 报告
   - hard gates 全过：
     - [ ] `spec_compliance == "full"`（或 deviations 全部合理）
     - [ ] `tests_passed == true` 且 Claude 自跑也 pass
     - [ ] `tests_written_first == true` 且 `git log --oneline` 显示 failing test commit 在 impl commit 之前（TDD 路径）
     - [ ] `git diff --stat` 显示**只动了 SPEC「范围」文件**
     - [ ] 没引入未授权新依赖（`git diff package.json`）
     - [ ] 没 TODO / FIXME / `mock` 关键词残留（除非 SPEC 允许）
5. **判定**（必须先按 Codex 运行时错误分类，再决定下一步）：

   #### Codex 运行时错误分类表

   | 症状 | 类型 | 动作 | 是否计入 3 次 |
   |---|---|---|---|
   | Exit 0 + 有效 JSON + `spec_compliance: "full"` | ✅ 成功 | → Stage 6 | n/a |
   | Exit 0 + 有效 JSON + `spec_compliance: partial \| broken` | 🟡 可修 | 用返工 prompt 送回 Codex | 是 |
   | Exit 0 但**无 JSON** 或 JSON 字段缺失 | 🟡 格式错误 | 返工时明示"必须输出标准 JSON 块" | 是 |
   | stderr 含 `rate limit` / `quota` / `credit` / `402` / `usage limit` | 🔴 **额度耗尽** | **立即退回 Claude**；提醒用户检查订阅/账单 | **否** |
   | stderr 含 `unauthorized` / `401` / `login expired` / `not authenticated` | 🔴 **认证失效** | **立即退回 Claude**；提醒用户跑 `codex login` | **否** |
   | stderr 含 `network` / `timeout` / `ECONNREFUSED` / `ENETUNREACH` / `ENOTFOUND` | 🟡 **瞬时网络** | 重试 1 次；仍失败 → 退回 Claude | 否（重试 1 次不计入）|
   | 命令超过 10 分钟无返回 | 🔴 **挂起** | `kill` Codex 进程 → 退回 Claude | **否** |
   | 其他未知错误 | 🟡 未知 | 返工 1 次试探；仍失败 → 退回 | 是 |

   #### 退回 Claude 时的统一处理

   - 永久性错误（额度/认证/挂起）：Output Contract 的「技术债」记录 `Codex unavailable: <error type> — <suggested user action>`
   - 可修错误 3 次返工失败：把 3 次报告作为参考输入给 Claude，避免重头再来
   - 任何退回都要在用户回复中**明确告知失败原因**，不能默默退回

#### Codex 派工时仍要遵守的原则

- TDD：SPEC 强制 RED→GREEN，Codex 必须先写 failing test。**Codex 路径下不调用 `superpowers:test-driven-development` skill**，TDD 方法通过 SPEC + git commit 顺序检查强制
- verification：Stage 6 由 **Claude 亲跑**，不信 Codex 自报 `tests_passed`
- delivery-gate：Stage 7 不可跳
- commit：Stage 8 由 Claude 完成。**Stage 8 调 clean-commit 时必须显式传入 Codex 信息**（派工次数、最终 spec_compliance），让 commit message 能反映；commit message 模板示例：`feat(X): implement Y (Codex: 1 round, full SPEC compliance)`

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
- Executor: Claude self | Codex (rounds: <n>) | Codex→Claude rescue (Codex 失败次数: <n>)
- Codex SPEC compliance: full | partial | broken | n/a
- Codex failure mode: n/a | quota_exhausted | auth_expired | network_transient | hung_timeout | format_error | unknown | spec_partial_after_3_rounds
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
- 派 Codex 但没写 SPEC（凭一句话指令直接派）
- Codex 报告 `spec_compliance != "full"` 但直接进 Stage 6
- Codex 改了 SPEC 之外的文件没 review 就接受
- 信 Codex 自报的 `tests_passed: true`，没自己跑一遍验证
- 派 Codex 时把 auth / 支付 / 加密代码也派出去
- 永久性错误（额度耗尽 / 认证失效 / 挂起超时）走返工循环而不立即退回 Claude
- Codex 失败但不告知用户原因，默默退回

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
| "派 Codex 后我懒得 review，反正 Codex 说测试过了" | review 是 Codex 派工的 50% 价值，跳了就变 AI slop 引入项目 |
| "改动只有 20 行，但派 Codex 顺手吧" | < 30 行不该派，编排开销 > 节省，直接 Claude 写更快 |
| "高风险代码 Codex 也能写，反正我会 review" | auth / 支付 / 加密必须 Claude 自写，护城河在判断力不在 review |
| "Codex 改了 SPEC 之外的文件，但好像也对" | 严禁。必须返工，否则失控蔓延 |
| "Codex 第 2 次返工还是不过，再试一次吧" | ≥ 3 次还不过 = SPEC 有问题或任务不该派，退回 Claude 自写 |

## Relationship to Other Skills

- **上游**：用户直接触发 / `flow-project-bootstrap` 产出第一个任务后可调用
- **下游（调用）**：
  - `superpowers:brainstorming` / `systematic-debugging` / `writing-plans`
  - `superpowers:using-git-worktrees`
  - `superpowers:dispatching-parallel-agents` / `subagent-driven-development` / `executing-plans`
  - `superpowers:verification-before-completion` / `finishing-a-development-branch`
  - `delivery-gate` / `clean-commit`
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
