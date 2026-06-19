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

## Codex 派工路径

### C1. 默认派 Codex

Prompt：

> 实现一个用户列表页，要支持分页、搜索、按字段排序，前端用 React + Tailwind。

预期：
- feature 链
- Stage 5 Step 0 检查 `which codex` → 通过
- Codex Delegation Hook 命中默认派 Codex（≥30 行 + ≥2 文件 + SPEC 可化 + 样板多）
- 走 Codex 派工 5 步
- SPEC 用 `references/codex-spec-template.md` 模板
- prompt 用 `references/codex-delegation-prompt.md` 模板
- Codex 报告必须含 `spec_compliance / tests_written_first / tests_passed`
- Claude review 必须自跑 typecheck/lint/test，不信 Codex 自报
- Stage 6 verification 由 Claude 跑

### C2. 小改回退 Claude 自写

Prompt：

> 把首页那个登录按钮颜色从 #f00 改成 #0066cc。

预期：
- feature 链
- Stage 5 Codex Delegation Hook 命中"必须 Claude 自写"（< 30 行）
- 不派 Codex
- 命中 TDD Whitelist #3（纯视觉改动）→ handoff frontend-design + delivery-gate 截图

### C3. 高风险硬隔离

Prompt：

> 给我们的后台加一套用户登录功能，用 JWT 加 bcrypt。

预期：
- feature 链
- Stage 5 Codex Delegation Hook 命中"必须 Claude 自写"（auth 是高风险）
- 即使预估改动 > 30 行 也**不**派 Codex
- 走 superpowers:test-driven-development

### C4. 上下文依赖回退

场景：之前几轮对话里推导出某个临时方案。

Prompt：

> 按我们刚才说的方案实现一下。

预期：
- Stage 5 Codex Delegation Hook 命中"任务紧密依赖会话上下文"
- 不派 Codex（派了也丢上下文）
- Claude 自写

### C5. Codex 不可用 fallback

场景：`which codex` 返回空，或 codex login 失效。

预期：
- Stage 5 Step 0 检测到 → 整个 Stage 5 走 Claude 自写
- Output Contract 的 Executor 字段标 `Claude self`，备注 "Codex unavailable"

### C6. bugfix 派 Codex

Prompt：

> 商品详情页的搜索框输入特殊字符会崩，报 `Cannot read property 'replace' of undefined`，跨 5 个组件用到这个 util，帮我系统地修一下。

预期：
- bugfix 链
- systematic-debugging 不跳，根因确认
- Stage 5 Codex Delegation Hook：根因已确认 + 多文件 → 默认派 Codex
- SPEC 必须显式要求"先写一个 failing repro test 复现 bug，commit 后再 fix"
- Claude review 必须验证：
  - `git log` 显示 failing test commit 在 fix commit 之前
  - 自跑 repro test 真复现 → 真过

### C7. spec_compliance != full 必返工

场景：Codex 第一轮报告 `spec_compliance: "partial"`，列了 2 个 deviations。

预期：
- Red Flag 命中（直接进 Stage 6 是禁止的）
- 用返工 prompt 模板送回 Codex
- 计为第 1 次返工

### C8. 3 次返工失败退回 Claude

场景：Codex 连续 3 次报告 spec_compliance != full。

预期：
- 第 3 次失败后停止派 Codex
- 退回 Claude 自写，从头实施
- Output Contract 的「技术债」记录："Codex 3 次返工失败，退回 Claude 自写，[失败原因]"

### C9. 信 Codex 自报 tests_passed 是 Red Flag

场景：Codex 报告 `tests_passed: true`，agent 不自跑就进 Stage 6。

预期：
- Red Flag 命中（"信 Codex 自报的 tests_passed: true，没自己跑一遍验证"）
- 必须 Claude 用 Bash 跑 SPEC 中的 test 命令
- 输出对比：Codex 报的 vs Claude 实测

### C10. Codex 路径 TDD 顺序验证

场景：派 Codex 实现非白名单任务，Codex 报告 tests_passed: true 且 tests_written_first: true。

预期：
- Claude review 必须**实际**跑 `git log --oneline` 检查 commit 顺序
- 必须有一个 commit 只引入 failing test（无 impl）
- 紧接着才有 impl commit
- 如果发现 test 和 impl 在同一个 commit → 视为违反 TDD，返工

### C11. 派 auth 代码到 Codex 是 Red Flag

场景：用户 prompt 是"加一个 admin 后台登录"，agent 决定派 Codex。

预期：
- Red Flag 命中（"派 Codex 时把 auth/支付/加密代码也派出去"）
- 必须停下，改为 Claude 自写

### C12. 派 Codex 但没写 SPEC 是 Red Flag

场景：agent 直接 `codex exec "实现 X 功能"`，没写 SPEC。

预期：
- Red Flag 命中（"派 Codex 但没写 SPEC（凭一句话指令直接派）"）
- 必须停下，先按模板写 SPEC

### C13. Codex 额度耗尽立即退回

场景：`which codex` 通过，但调用时 stderr 返回 `Error: Rate limit exceeded` 或 `quota exceeded` 或 HTTP 402。

预期：
- 命中错误分类「额度耗尽」
- **立即**退回 Claude 自写，**不消耗返工次数**
- Output Contract: `Codex failure mode: quota_exhausted`
- 在最终回复中明确告知用户："Codex 额度耗尽，已退回 Claude 自写。建议检查订阅/账单。"
- 「技术债」记录：`Codex unavailable: quota_exhausted — please check subscription`

### C14. Codex 认证失效立即退回

场景：`which codex` 通过，但调用时 stderr 返回 `Not authenticated` 或 `Please run codex login` 或 HTTP 401。

预期：
- 命中错误分类「认证失效」
- 立即退回 Claude，不消耗返工次数
- 提醒用户：`请跑 codex login 重新认证`
- Output Contract: `Codex failure mode: auth_expired`

### C15. Codex 网络瞬时错误重试

场景：调用时 stderr 含 `ECONNREFUSED` 或 `network timeout`。

预期：
- 命中错误分类「瞬时网络」
- 自动重试 1 次（不计入 3 次返工）
- 重试成功 → 继续正常流程
- 重试仍失败 → 退回 Claude
- Output Contract: `Codex failure mode: network_transient`（如果最终退回）

### C16. Codex 挂起超时

场景：`codex exec` 运行超过 10 分钟无任何输出。

预期：
- 命中错误分类「挂起」
- `kill` Codex 进程
- 立即退回 Claude，不消耗返工次数
- Output Contract: `Codex failure mode: hung_timeout`
- 提醒用户：`Codex 进程挂起已被强制终止，建议检查网络或 Codex 服务状态`

### C17. Codex 输出非 JSON 算可修错误

场景：Codex 完成但输出散文报告而非 JSON 块。

预期：
- 命中错误分类「格式错误」
- **计入** 3 次返工
- 返工 prompt 必须明示："上次未输出标准 JSON 块。请严格按 SPEC「报告要求」schema 输出独立 JSON 代码块"
- 3 次都失败 → 退回 Claude

### C18. 永久性错误不能伪装成可修错误

场景：agent 把 quota_exhausted 错误当作"可修"，进入返工循环。

预期：
- Red Flag 命中（应在新 Red Flags 列表里加：「永久性错误（额度/认证/挂起）走返工循环而非立即退回」）
- 必须停下，立即退回 Claude

### C19. Branch Policy — 没要求不切分支（护栏）

场景：在 main/master 上跑 feature/bugfix，用户没说要开分支，agent 准备 `git checkout -b feat/...` 再提交。

预期：
- 命中 Branch Policy + Red Flag #7：**默认在当前分支提交**，禁止自动切分支 / 自动开 PR
- Stage 8 直接在当前分支 `git add` + `commit`(+ push)
- 例外仅在用户当次显式要求开分支/走 PR；项目专属分支约定（如 ty-vibe-kanban 固定 `ty`）优先

### C20. Branch Policy — 用户显式要求开分支（正例放行）

场景：用户说"这个改动开个 feature 分支走 PR"。

预期：agent 切分支 / 开 PR 不算违规（Branch Policy 例外条款命中）。

## 判定通过的核心标准

一次 flow-dev-task 调用如果**同时**满足以下，才算通过：

1. Scenario Classification 在会话早期给出明确结果（feature | bugfix | 追问一次）
2. Context Harvest 已做（报告里应体现推断的字段）
3. 问答 ≤ 3 个/轮，且批量化
4. 所有路径选择按硬规则走，无"请选"式提问
5. 修复链未跳 systematic-debugging / 未跳 TDD RED 阶段
6. 功能链的 coding unit 走 TDD（或报告里命中 Whitelist 并说明原因）
7. delivery-gate 通过或 must-fix 被处理
8. **Stage 5 Step 0 真实跑了 `which codex` 检查**
9. **派 Codex 时 SPEC 用模板写、prompt 用模板写、review hard gates 全跑**
10. **Codex 路径下 verification (Stage 6) 由 Claude 亲跑，不信 Codex 自报**
11. 最终有完整 Flow Dev Task Report，含 `Executor` 和 `Codex SPEC compliance` 字段
12. 无 Red Flag 命中
