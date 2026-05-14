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

预期：**不**触发本 skill。命中 "When NOT to Use" 的"高风险代码"规则，路由给 `flow-dev-task` 让 Claude 自写。

### N4. Codex 不可用拒绝

场景：用户机器没装 codex 或版本 < 0.128.0。

预期：Pre-flight Step 0 失败，整个 skill 退出，提示 "退回 flow-dev-task 走 Claude 自写"。

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
- Claude 把 Must Fix 写进 STATUS.md "Next Action"
- 重新触发 Goal Codex 修
- 修完后**重新跑 Step 5-6**（不能直接 commit）
- 计入 review failure count

### R5. Review 连续 2 次 fail → 强制终止

场景：第 2 次 review 也 fail。

预期：
- 强制 kill Codex
- 写 STOPPED: review-2-fail 到 STATUS.md
- 通知人类强制终止 + 提供 4 选项

### R6. Verdict pass 但 Claude 必须自验

场景：REVIEW.md verdict=pass。

预期：
- Claude **不直接信** verdict
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

### G4. Verdict pass 但 Claude 跳验证 → STOP

场景：reviewer 说 pass，Claude 想直接 commit。

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
2. ✅ 任务文件按模板创建（GOAL.md/PLAN.md/EVAL.md/STATUS.md/.gitignore 配置）
3. ✅ 独立 worktree 创建并切换
4. ✅ Goal Codex 启动且 codex.pid 写入
5. ✅ Watcher 启动且 watcher.pid 写入
6. ✅ STATUS.md 至少更新过 1 次（任务非 0 秒结束）
7. ✅ Goal 完成时 STATUS.md 含精确 `GOAL_DONE @ <ts>` 行
8. ✅ review-input 完整（diff / lint / test / build 都有，UI 改动有截图）
9. ✅ Reviewer Codex 是新进程（pid ≠ Goal 的 pid）
10. ✅ Reviewer 输出 REVIEW.md verdict 是 pass 或 fail（不能是其他值）
11. ✅ Verdict pass 后 Claude 自跑过验证命令
12. ✅ 最终输出 Codex Goal Task Report 含全部字段
13. ✅ 无 Red Flag 命中
