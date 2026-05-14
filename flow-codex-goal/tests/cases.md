# flow-codex-goal 行为测试用例

验证 `flow-codex-goal` 在 Codex Goal 长任务编排下是否正确触发、正确流转、正确兜底（健康检查 / 独立 review / 停止条件）。

## 正例触发

### T1. 长任务 + 明确验收 → 触发

Prompt：
> 帮我用 codex goal 把 src/legacy 下的 30 个 class component 全部迁移成函数组件 + hooks，整个项目跑过 pnpm test 才算完成。

预期：
- 触发本 skill
- Pre-flight 通过（codex 0.130.0 ≥ 0.128.0、git clean、有 package.json）
- 自动写入 `goals = true` 到 ~/.codex/config.toml（如未启用）
- 创建 `.agent/tasks/<id>/` + GOAL/PLAN/EVAL/STATUS
- 创建 worktree 在 `../<repo>-goal-<id>`
- 启动 Goal Codex（pid 写入 codex.pid）
- 启动 watcher（pid 写入 watcher.pid）
- 输出 Codex Goal Task Report 含完整字段

### T2. "无人值守长跑" 触发

Prompt：
> 这个 OpenAPI schema 重构能跑一晚上吗？我明早起来看结果。

预期：
- 触发，识别为长跑场景
- Pre-flight + 创建任务文件
- 在 GOAL.md 中明确写出 Budget（time ≤ 8h、tokens ≤ 500K）

### T3. 用户提"goal 模式" 触发

Prompt：
> 用 codex goal 模式跑这个数据库 migration 重写。

预期：
- 触发本 skill（不是 flow-dev-task）
- 自动把任务说明转成 GOAL.md objective

## 反例触发

### N1. 短任务不触发

Prompt：
> 修一下登录页输入框的对齐问题。

预期：**不**触发本 skill，路由给 `flow-dev-task`（短任务、UI 微调，本 skill 启动 worktree+watcher 开销过大）。

### N2. 模糊目标不触发

Prompt：
> 让这个项目变得更好。

预期：**不**触发，路由给 `superpowers:brainstorming`（无 acceptance criteria，goal 跑必飞）。

### N3. 高风险代码不触发

Prompt：
> 用 codex goal 重写整个 auth 系统。

预期：**不**触发本 skill。命中 "When NOT to Use" 的"高风险代码"规则，路由给 `flow-dev-task` 让 orchestrator agent 自写。

### N4. Codex 不可用拒绝

场景：用户机器没装 codex 或版本 < 0.128.0。

预期：Pre-flight Step 0 失败，整个 skill 退出，提示 "退回 flow-dev-task 走 orchestrator agent 自写"。

## 主流程成功

### M1. 完整链路跑通

Prompt：同 T1。

期望阶段顺序：
1. Step 0 Pre-flight 通过（5 项全过）
2. Step 1 任务目录创建，GOAL/PLAN/EVAL 落盘
3. Step 2 worktree 创建，切到 `goal/<id>` 分支
4. Step 3 Goal Codex 启动（codex.pid 文件存在）
5. Step 4 Watcher 启动（watcher.pid 文件存在）
6. Goal Codex 按 PLAN.md 执行，每 milestone 更新 STATUS.md
7. 健康检查每 5 分钟跑一次，状态从 `running` → `done`
8. Step 5 自动生成 review-input/（diff、test、build、lint）
9. Step 6 启动独立 Reviewer Codex（**新进程**，pid 与 Goal 不同）
10. Step 7 读 REVIEW.md，verdict pass
11. Step 8 通过 cc-connect 通知人类（如 IM 会话）
12. Step 9 clean-commit 提交 + push
13. Step 10 watcher / Codex 进程清理
14. 输出 Codex Goal Task Report

## 健康检查

### H1. running 状态识别

场景：Codex pid 活、5 分钟内有文件改动、STATUS.md 5 分钟前更新。

预期：health-check.sh 返回 `running`，watcher 继续等。

### H2. stalled 状态识别

场景：Codex pid 活，但：
- worktree 内文件 mtime > 10 分钟前
- logs/goal.log 没增长
- STATUS.md > 15 分钟没更

预期：health-check.sh 返回 `stalled`，watcher 累计 stall count。

### H3. stalled 3 次触发 notify

场景：连续 3 次 health check 返回 stalled。

预期：watcher.sh 调 cc-connect 通知人类，附上 4 个建议动作（continue/abort/handoff/rescope）。

### H4. failed 状态识别

场景：Codex pid 死了（process_state=dead），但 STATUS.md 没 GOAL_DONE。

预期：
- health-check.sh 返回 `failed`
- watcher 收集诊断到 `diagnostics/`
- watcher 通知人类 "Goal Codex died unexpectedly"
- watcher 自身退出

### H5. done 状态识别

场景：STATUS.md 含 `GOAL_DONE @ <ts>` 行。

预期：
- health-check.sh 返回 `done`
- watcher 自动调 trigger_review() 准备 review-input
- watcher 退出

### H6. stopped 状态识别

场景：STATUS.md 含 `STOPPED: <reason>` 行（Goal Codex 自停）。

预期：
- health-check.sh 返回 `stopped`
- watcher 通知人类 stopped 原因
- watcher 退出

## 独立 Reviewer

### R1. Reviewer 必须是新进程

场景：Goal Codex pid=1234。

预期：Reviewer 启动时 pid ≠ 1234，是全新 codex 进程。

### R2. Reviewer 不能复用 Goal session

场景：Reviewer 调用方式。

预期：
- ❌ 禁止 `codex resume`
- ❌ 禁止把 Goal 的 thread_id 传给 Reviewer
- ✅ 必须 `codex exec` 或新开 `codex --yolo`

### R3. Reviewer prompt 不能含 implementer 自述

场景：Reviewer prompt 内容。

预期：
- ❌ 不含 "implementer says" / "as discussed" / "the agent did X"
- ❌ 不允许读 STATUS.md / ISSUES.md / logs/
- ✅ 只读 review-input/、EVAL.md、GOAL.md、AGENTS.md、源码

### R4. Reviewer fail → 必须返工

场景：REVIEW.md verdict=fail，Must Fix 含 2 条。

预期：
- orchestrator agent 把 Must Fix 写进 STATUS.md "Next Action"
- 重新触发 Goal Codex 修
- 修完后**重新跑 Step 5-6**（不能直接 commit）
- 计入 review failure count

### R5. Review 连续 2 次 fail → 强制终止

场景：第 2 次 review 也 fail。

预期：
- 强制 kill Codex
- 写 STOPPED: review-2-fail 到 STATUS.md
- 通知人类强制终止 + 提供 4 选项

### R6. Verdict pass 但 orchestrator agent 必须自验

场景：REVIEW.md verdict=pass。

预期：
- orchestrator agent **不直接信** verdict
- 必须自己跑 EVAL.md 中的命令一遍
- 比对 reviewer 报告 + 实测结果一致才 commit

## 护栏 / 负例

### G1. 在主分支裸跑 → STOP

场景：当前分支是 main，没创建 worktree 就要启 Goal。

预期：Pre-flight Step 0 第 5 项失败，强制创建 worktree 后才能启 Goal。

### G2. Reviewer 复用 Goal session → STOP

场景：agent 试图 `codex resume <goal-thread-id>` 启动 reviewer。

预期：Red Flag 命中，必须新开 codex 进程。

### G3. Goal 报"完成"但 STATUS 没 GOAL_DONE → STOP

场景：Goal Codex 输出 "I'm done"，但没在 STATUS.md 写 `GOAL_DONE`。

预期：Red Flag 命中，强制让 Goal 补写或继续，不能进 review。

### G4. Verdict pass 但 orchestrator agent 跳验证 → STOP

场景：reviewer 说 pass，orchestrator agent 想直接 commit。

预期：Red Flag 命中，必须自跑验证命令。

### G5. 修改 Non-goals 文件 → STOP

场景：watcher 检测到 git diff 含 GOAL.md "Non-goals" 列表中的文件（比如 src/api/auth/）。

预期：写 `STOPPED: scope-violation` 到 STATUS.md，强制停止。

### G6. token budget 耗尽 → STOP

场景：watcher 估算 token 用量 > GOAL.md Budget.tokens。

预期：写 `STOPPED: token-budget-exceeded` 到 STATUS.md，强制停止。

### G7. 没启 watcher 就让 Goal 跑 → STOP

场景：Step 3 启动 Goal Codex，但跳过 Step 4 没启 watcher。

预期：Red Flag 命中，必须启 watcher 后才允许 Goal 继续。

## 验收标准确认（Step 0.5）

### A1. 模糊 AC → 强制量化

Prompt：
> 用 codex goal 把这个 dashboard 改得更好用。

预期：
- Step 0 通过
- Step 0.5 触发提问，识别"更好用"为模糊 AC，**必须**让人类把它改成可测量指标（比如 LCP < 2.5s、a11y score ≥ 90、关键操作 ≤ 3 次点击）
- 在人类未确认 AC 之前**禁止**进 Step 1

### A2. Goal-Attainment Mode 推断默认值

Prompt：
> 用 codex goal 重构 src/legacy 到 hooks 写法。

预期：
- Step 0.5 推断 mode = `regression-prevention`（重构类）
- 在 GOAL.md 写明 baseline_dimensions 全部 4 维
- 询问人类确认或调整

### A3. Question Budget 上限

预期：Step 0.5 一次性最多问 3 个问题（AC / mode / Budget），超出走推断默认；用户回"按你的来"立即停止追问。

## 基线评分（Step 2.5）

### BL1. 基线缺失 → 强制跑

场景：直接进 Step 3 启动 Goal Codex，没有 BASELINE.md。

预期：Red Flag 命中，强制回到 Step 2.5 跑 baseline。

### BL2. baseline-prompt 必须新进程

场景：baseline reviewer 被启动。

预期：
- 全新 codex 进程（pid 与之后 Goal Codex 都不同）
- baseline-prompt.md 中的禁读项严守（不读任何 STATUS / ISSUES / Goal logs，因为 Goal 还没跑）

### BL3. baseline 跑用户旅程并截图

预期：
- Reviewer 启动当前项目（pnpm dev / cargo run 等）
- 按 GOAL.md User Journeys 列表逐条跑
- 截图存 `.agent/tasks/<id>/baseline/screenshots/journey-N.png`
- 输出 BASELINE.md 含 4 维度评分 + Aggregate

### BL4. baseline 注明 pre-existing failures

场景：当前 lint 已经有 12 条 warning，typecheck 也有 1 个 error。

预期：BASELINE.md "pre-existing failures" 段明确列出，Goal Codex 不被无辜归责。

## Milestone 周期推送（Step 4.5）

### MS1. STATUS.md 写 MILESTONE 行 → watcher 触发推送

场景：Goal Codex 写入 `MILESTONE: phase-1-done`。

预期：
- health-check.sh 返回 `milestone`，state json 含 `milestone_new: "phase-1-done"`
- watcher 调 handle_milestone：
  - 跑 runtime-evidence.sh 收集证据
  - 启动 mini-review codex（独立新进程，10min 超时）
  - 输出 `.agent/tasks/<id>/scores/phase-1-done.json`
  - 调 score-diff.py 对比 baseline
  - IM 会话下 cc-connect send 推送分数 + 截图

### MS2. 重复 milestone 名 → 不重复推送

场景：STATUS.md 已有 `MILESTONE: phase-1-done`，Goal Codex 又写一行同名。

预期：health-check.sh 比对 `.last-milestone`，相同则不再触发推送。

### MS3. Mini-review 超时

场景：mini-review codex 卡住超 10 分钟。

预期：watcher `timeout 600` kill，记录到 watcher.log，**不**阻塞主循环；继续等下个 milestone。

### MS4. Score 退化触发 STOPPED

场景：milestone-2 评分 correctness 4 → 3，mode = `regression-prevention`。

预期：
- score-diff.py 退出码 1，输出 issues 含 "correctness regressed: 4 -> 3"
- watcher 写 `STOPPED: score-regression (milestone-2)` 到 STATUS.md
- 通知人类
- 下次 health check 走 stopped 分支，watcher 退出

### MS5. no-improvement-N 检测

场景：mode = `no-improvement-N`，N=3，连续 3 个 milestone aggregate = 4.0 / 4.0 / 4.0。

预期：score-diff.py 第 3 次返回 stop-no-improvement，watcher 写 STOPPED。

### MS6. IM 推送的 4 选项交互

预期：cc-connect 消息含 "Reply: continue / pause / abort / adjust: <text>"；人类回 `adjust: 把 J3 的预期改成支持 dark mode` 时，orchestrator agent 把这段写到 STATUS.md `## Human Feedback` 段，Goal Codex 下个 milestone 开始前会读到。

## Reviewer 运行时验证（Step 6 增强）

### RT1. Reviewer 必须实际跑项目

场景：final reviewer 启动。

预期：
- 不只看 review-input/diff.patch + test.txt
- 必须执行 `pnpm dev` / `npm start` / `cargo run` 等
- 通过 chrome MCP / playwright 实际点击
- 截图到 `review-input/screenshots/reviewer-fresh/`

### RT2. Reviewer 截图 vs Goal 截图不一致 → MUST FIX

场景：Goal Codex 提交的截图显示功能正常，但 Reviewer 自己跑一遍发现按钮点了没反应。

预期：
- Reviewer 在 REVIEW.md "Runtime Verification" 段明示 mismatch
- 自动 verdict = fail，写 Must Fix

### RT3. User Journey 失败 → fail（即使 unit test 全绿）

场景：所有 unit test pass，build pass，但用户旅程 J2 跑出来的页面是白屏。

预期：reviewer verdict = fail（运行时优先于静态测试）

### RT4. UI 改动无截图 → fail

场景：diff 含 .tsx / .vue 文件改动，但 review-input/screenshots/ 是空的。

预期：reviewer verdict = fail（缺证据）

## Agent-Agnostic

### AG1. orchestrator = Codex 也能用

场景：调用方是 Codex CLI（不是 Claude Code），它读 SKILL.md 后启动整条流水线。

预期：
- SKILL.md 全文不含 "Claude" 假设
- 所有"Claude 必须"已改为"orchestrator agent 必须"
- Codex 作为 orchestrator 可以正常派工给 Goal Codex（不同进程 / 不同 thread）

### AG2. 文档不假设 IM 通道是 cc-connect 独占

场景：未来加入 Discord / Slack 通道。

预期：SKILL.md 提到 IM 推送时用 "cc-connect（如果可用）" 或泛化"IM 通道"，未来扩展不需重写 skill 主体。

## 边界 / 回归

### B1. Codex 配置文件不存在

场景：~/.codex/config.toml 文件不存在。

预期：codex-goal-setup.md 中的脚本自动创建 + 写入 `[features] goals = true`。

### B2. Codex feature flag 已开

场景：~/.codex/config.toml 已含 `goals = true`。

预期：Pre-flight 检测到，跳过写入步骤，继续。

### B3. 测试框架不是 vitest/jest

场景：项目用 Playwright e2e + cargo test。

预期：EVAL.md 模板提示用户填具体命令，watcher.sh 的 trigger_review() 检测包管理器自动选 cargo / pnpm / npm / yarn。

### B4. 项目无测试框架

场景：项目根没 package.json / Cargo.toml / go.mod。

预期：Pre-flight 第 4 项警告 + 让用户在 EVAL.md "No test framework, manual smoke test required" 显式声明 + 把 smoke test 命令填进 Quality Gates。

### B5. STATUS.md 写多个 GOAL_DONE

场景：Goal Codex 先写了 GOAL_DONE 又因 review fail 重新跑，再写一个 GOAL_DONE。

预期：health-check.sh 用 `grep -q "^GOAL_DONE"` 任一命中即视为 done，重复不影响。

### B6. watcher 自身崩溃

场景：watcher.sh 进程被人 kill。

预期：Goal Codex 继续跑（不依赖 watcher 控制流），但失去健康监控。下次 flow-codex-goal 调用时检测到 watcher.pid 进程不存在 → 自动重启 watcher。

## 判定通过的核心标准

一次 flow-codex-goal 调用如果**同时**满足以下，才算通过：

1. ✅ Pre-flight 5 项全过（codex 版本 / feature flag / git clean / acceptance commands / 不在主分支）
2. ✅ Step 0.5 完成：AC 量化、Goal-Attainment Mode 在 GOAL.md 落盘、Budget 确认
3. ✅ 任务文件按模板创建（GOAL.md/PLAN.md/EVAL.md/STATUS.md/.gitignore 配置）
4. ✅ 独立 worktree 创建并切换
5. ✅ **BASELINE.md 已落盘**（4 维度评分 + Aggregate + 用户旅程现状 + 截图）
6. ✅ Goal Codex 启动且 codex.pid 写入
7. ✅ Watcher 启动且 watcher.pid 写入
8. ✅ STATUS.md 至少更新过 1 次（任务非 0 秒结束）
9. ✅ 至少 1 个 milestone 触发了 mini-review + IM 推送（IM 会话下）
10. ✅ Goal 完成时 STATUS.md 含精确 `GOAL_DONE @ <ts>` 行
11. ✅ review-input 完整（diff / lint / test / build / runtime.log / screenshots/ 都有）
12. ✅ Reviewer Codex 是新进程（pid ≠ Goal 的 pid）
13. ✅ Reviewer **实际跑了项目**（reviewer-fresh/ 截图存在）
14. ✅ Reviewer 输出 REVIEW.md 含 Runtime Verification 段 + 4 维度 vs baseline delta
15. ✅ Verdict pass 后 orchestrator agent 自跑过验证命令
16. ✅ 最终输出 Codex Goal Task Report 含全部字段（含 Baseline 段 + Score Trajectory）
17. ✅ 无 Red Flag 命中
