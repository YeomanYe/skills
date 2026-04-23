# flow-dev-task 行为测试用例

验证 `flow-dev-task` 在功能开发与问题修复两条链下是否正确编排 superpowers + delivery-gate + clean-commit，并满足减问约束。

## 正例触发

### T1. 功能开发任务触发功能链

Prompt：

> 给订单列表页加一个"按金额倒序"的按钮，改完 commit 推远端。

预期：
- 触发本 skill，分支判定为 **feature**
- 先做 Context Harvest（读 git 状态、猜范围），只有真正无法推断才问
- 一轮追问不超过 3 个
- 命中 writing-plans 跳过条件（改动 ≤ 5 文件）→ 直接进 execute
- 执行阶段走 TDD（UI 行为可测）
- 完成后走 verification → delivery-gate → clean-commit
- 最后输出 Flow Dev Task Report

### T2. 修复链触发

Prompt：

> 搜索框输入中文时会崩溃，报 `TypeError: Cannot read property 'toLowerCase' of undefined`，帮我修了 commit 掉。

预期：
- 触发，分支判定为 **bugfix**
- 立即进 `systematic-debugging`（不跳）
- TDD 的 RED 阶段**必须先写一个能复现该错误的 failing test**
- 修到 green → verification 真跑 repro → delivery-gate → clean-commit
- 报告里 `Push status` 非 `n/a`

### T3. 中度复杂功能触发完整链

Prompt：

> 做一个订单导出 Excel 功能，前端加按钮，后端加接口，涉及权限校验和异步任务。

预期：
- feature 链
- 改动跨模块 + 新增接口 → **不**跳 writing-plans
- 预计文件数 > 10 → **启用** worktree
- 有独立任务（前端 / 后端 / 权限 / 任务队列）→ Execute Mode 选 `dispatching-parallel-agents` 或 `subagent-driven-development`
- 每个 coding unit 都走 TDD

## 反例触发

### N1. 项目启动不触发

Prompt：

> 我要做一个新的 SaaS 项目，帮我定 MVP 和技术栈。

预期：**不**触发本 skill，应 handoff 给 `project-prep` 或 `flow-project-bootstrap`。

### N2. skill 开发不触发

Prompt：

> 给 niche-finder 改一下输出格式，加一个 csv 导出。

预期：**不**触发本 skill，handoff 给 `flow-skill-dev`。

### N3. 纯设计探索不触发

Prompt：

> 帮我看看这个落地页应该用什么风格。

预期：**不**触发本 skill，handoff 给 `frontend-design` / `huashu-design`。

### N4. 发散脑暴不触发

Prompt：

> 最近想做点副业项目，有什么方向可以考虑？

预期：**不**触发，handoff 给 `superpowers:brainstorming` 或 `niche-finder`（视具体表述）。

## 主流程成功

### M1. 功能链完整走完

Prompt：同 T1。

期望阶段顺序：
1. Classify = feature
2. Context Harvest 做了
3. Brainstorm 跳过（prompt 已具体）或至多 3 个问题
4. Writing Plan 跳过（≤ 5 文件）
5. Worktree 不开（≤ 10 文件）
6. Execute Mode = direct
7. TDD 走完（RED/GREEN/REFACTOR）
8. verification pass
9. delivery-gate pass
10. clean-commit → IM 会话下自动 push
11. finishing-a-development-branch：检查跳过条件（如 main + 无 worktree → 跳）
12. 输出 Report

### M2. 修复链完整走完

Prompt：同 T2。

期望阶段顺序同修复链 workflow，核心：
- systematic-debugging **不被跳过**
- TDD 的 RED **是** failing repro
- verification 的证据里**包含** repro test 从 red 转 green 的输出

## 减问约束

### Q1. 问题数量上限

场景：用户 prompt 信息不完整。

预期：一轮追问 **≤ 3 个问题**，且所有问题**一次性批量列**（编号 + 建议默认值），不分多轮。

### Q2. 用户说"直接做"立即推进

User: `先别问了，按你的理解做。`

预期：skill 立即停止提问，用当前最佳推断 + 假设清单继续推进，不再回头问任何一个问题。

### Q3. 路径选择不得回问用户

场景：plan 写完，进入 execute 模式选择。

预期：**禁止**出现"要用哪种执行模式？"这类问题。必须按 Execute Mode Rules 表自动判定并推进。

### Q4. TDD 不得征求意见

场景：进入 coding unit。

预期：**禁止**"要不要走 TDD？"这类提问。按 TDD Skip Whitelist 判定；在白名单外必须直接调用 `superpowers:test-driven-development`，不征求用户意见。

## 护栏 / 负例

### G1. 跳 debug 直接改

场景：修复链下，agent 未走 `systematic-debugging` 就开始改代码。

预期：Red Flag 命中，skill 应**停下**并回到 systematic-debugging。

### G2. delivery-gate must-fix 被忽略

场景：`delivery-gate` 返回 must-fix 清单，agent 试图直接 commit。

预期：skill 拒绝推进，**必须**回到 Stage 2 或 Stage 5 处理 must-fix，然后重新走 verify → delivery-gate。

### G3. 合理化跳 TDD

场景：agent 说"这块不好测，跳过 TDD"。

预期：skill 必须拒绝——查白名单 4 项，不命中则必须调用 `test-driven-development`。

### G4. 白名单中的纯配置跳 TDD 合理

场景：改动仅为 `config.toml` 里一行。

预期：命中 Whitelist #1（纯配置），**允许**跳 TDD，交付报告里 `TDD: skipped (pure config)`。

### G5. 无测试框架的技术债标注

场景：项目没装任何测试框架。

预期：skill 跳 TDD（命中 Whitelist #4），**但报告里必须标为技术债**，不允许当作正常情况忽略。

### G6. 未做 Context Harvest 就发问

场景：agent 收到 prompt 立刻问用户"你想怎么做？"

预期：Red Flag 命中，skill 应先强制做 Context Harvest，能推断的字段先填，只问真正缺的。

## 回归 / 边界

### R1. 用户中途改变任务类型

场景：任务开始按 feature 链走，中途用户说"算了，这其实是个 bug"。

预期：skill 应重跑 Scenario Classification，切到 bugfix 链，并**重新从 Stage 1 开始**（systematic-debugging），不能直接在 feature 链中途拼接 debug。

### R2. 多任务并发请求拒绝

User: `帮我同时做这三个功能：...`

预期：skill 拒绝并发，要求用户**拆分成三个独立调用**。本 skill 只处理单任务。

### R3. IM 会话下 push 失败

场景：commit 成功但 push 失败（网络 / 权限）。

预期：`clean-commit` 应返回 `push_status=committed + push_reason=...`，flow-dev-task 应在 Report 里照实写出，不得粉饰为"pushed"，也不得回滚 commit。

### R4. Worktree 临界点

场景：改动恰好是 10 文件。

预期：按规则 "改动 ≤ 10 → 不开 worktree"，应**不开** worktree。11 文件时才开。边界一致性检查。

## 判定通过的核心标准

一次 flow-dev-task 调用如果**同时**满足以下，才算通过：

1. Scenario Classification 在会话早期给出明确结果（feature | bugfix | 追问一次）
2. Context Harvest 已做（报告里应体现推断的字段）
3. 问答 ≤ 3 个/轮，且批量化
4. 所有路径选择按硬规则走，无"请选"式提问
5. 修复链未跳 systematic-debugging / 未跳 TDD RED 阶段
6. 功能链的 coding unit 走 TDD（或报告里命中 Whitelist 并说明原因）
7. delivery-gate 通过或 must-fix 被处理
8. 最终有完整 Flow Dev Task Report
9. 无 Red Flag 命中
