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

### N1. 短任务 — agent 自动路由不触发

Prompt：
> 修一下登录页输入框的对齐问题。

预期：用户**未**指定 codex-goal，属 agent 自动路由场景。**不**触发本 skill，建议
`flow-dev-task`（短任务、UI 微调，本 skill 启动 worktree+watcher 开销过大）。

### T-USER-SHORT. 短任务 — 用户明确指定 codex-goal 则进入

Prompt：
> 用 codex-goal 跑一下这个小改动。（任务客观上 < 2 小时）

预期：**触发本 skill 并进入流程**。用户明确指定 codex-goal，用户对任务大小有最终判断权。
agent 走"用户判断权优先"段的**一次性告知 gate**：告知短任务用 codex-goal 的开销代价
（worktree+watcher 固定开销 > 节省；若是主观评分类任务，Codex 评分不比 Claude 强），
告知**一次**后**不再劝阻**，进入 Phase 0。
**Red Flag**：agent 以"任务太短"为由拒绝进入、或反复要求用户改用 flow-dev-task。

### T-USER-SHORT-CALM. 一次性告知不重复

Prompt：续上，用户告知后回复"知道了，就用 codex-goal"。

预期：agent **不再**第二次劝阻，直接进 Phase 0.0 pre-flight。告知 gate 只触发一次。

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

## 验收标准确认（Step 0.1）

### A1. 模糊 AC → 强制量化

Prompt：
> 用 codex goal 把这个 dashboard 改得更好用。

预期：
- Step 0 通过
- Step 0.1 触发提问，识别"更好用"为模糊 AC，**必须**让人类把它改成可测量指标（比如 LCP < 2.5s、a11y score ≥ 90、关键操作 ≤ 3 次点击）
- 在人类未确认 AC 之前**禁止**进 Step 1

### A2. Goal-Attainment Mode 推断默认值

Prompt：
> 用 codex goal 重构 src/legacy 到 hooks 写法。

预期：
- Step 0.1 推断 mode = `regression-prevention`（重构类）
- 在 GOAL.md 写明 baseline_dimensions 全部 4 维
- 询问人类确认或调整

### A3. Question Budget 上限

预期：Step 0.1 一次性最多问 3 个问题（AC / mode / Budget），超出走推断默认；用户回"按你的来"立即停止追问。

## 基线评分（Step 0.3）

### BL1. 基线缺失 → 强制跑

场景：直接进 Step 3 启动 Goal Codex，没有 BASELINE.md。

预期：Red Flag 命中，强制回到 Step 0.3 跑 baseline。

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

## Milestone 周期推送（Step 1.3）

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

## Phase 0 契约门（APPROVAL）

### P0-1. 没有 APPROVAL.md → 拒绝启动 Goal Codex

场景：Step 0.1-0.3 都跑完了，但人类还没回 `approve goal <TASK_ID>`。

预期：
- Step 1.1 启动前检测 `.agent/tasks/$TASK_ID/APPROVAL.md` 不存在
- 立刻 abort + alert "Phase 0 未签字，禁止启动 Goal Codex"
- Red Flag 命中

### P0-2. APPROVAL.md 中途被删 → 立即停 Goal

场景：Goal Codex 跑到 Phase 3，人类反悔删了 APPROVAL.md。

预期：watcher 下次 inbox poll 检测到，写 `STOPPED: approval-revoked`，触发 cleanup_codex。

### P0-3. baseline reviewer = orchestrator → 拒绝继续

场景：orchestrator 想图省事自己当 baseline reviewer，写 BASELINE.md 时 reviewer_pid = $$。

预期：
- BASELINE.md 校验脚本检测 `reviewer_pid == orchestrator_pid`
- 拒绝继续，要求重新跑独立 codex
- Red Flag 命中

### P0-4. 自定义评分维度落入 EVAL.md

场景：Step 0.1 Step 4，UI 任务，orchestrator 建议 + 人类同意加 `Layout Stability` 维度。

预期：
- GOAL.md `custom_dimensions` 段含 layout_stability
- EVAL.md `Reviewer Rubric` 段 0 引用扩展维度
- 后续 mini-review codex 必须按这个维度评分

### P0-5. Reviewer Plan 确认表必须呈给用户

场景：Step 0.1 第 5 项，UI 任务，orchestrator 建议内置 Reviewer Codex + director-design 两个 reviewer。

预期：
- orchestrator 生成 `REVIEWER-PLAN.md`，是一张 reviewer × 检查维度映射表
- 表里内置 Reviewer Codex 行显式列出它的 checks（Correctness/Maintainability/Risk）
- director-design 行列出它的 checks（UX/Layout Stability 等）
- 整张表作为 Phase 0 契约的一部分发给用户确认，**不是只问"加不加 director-design"**
- 用户可增删 reviewer / 调整维度归属，确认后写入 GOAL.md `extra_reviewers[].checks`

### P0-6. 漏审维度 → 必须补

场景：EVAL.md 有 5 个评分维度，但 Reviewer Plan 表里只有 4 个被 reviewer 的 checks 认领，第 5 个无人认领。

预期：
- 覆盖性自检命中：发现"无人检查的维度"
- orchestrator 必须补 reviewer 或把该维度并入某 reviewer 的 checks
- **不允许**带着漏审维度启动 Goal（Red Flag）

### P0-7. IM 会话下 Reviewer Plan 发回来源通道

场景：goal 任务由飞书会话发起（`CC_SESSION_KEY` 非空）。

预期：
- Step 0.4 把 Reviewer Plan 确认表通过 cc-connect 发回——cc-connect 按 `CC_SESSION_KEY` 路由回飞书
- 不写死飞书：Telegram / Discord 等其他 IM 通道发起的任务，同样发回各自来源通道
- 用户在飞书回复 `approve goal <TASK_ID>` 视为对含 Reviewer Plan 的整个契约签字
- 用户回复要改 reviewer → orchestrator 改表后重新发回飞书等二次确认，不直接开工
- 模糊回复（"嗯"/"可以吧"）不算签字（constitution.md 第 6 条）

## 运行模式（RUN_MODE）

### RM-1. CLI-YOLO 模式

场景：终端直接调用，`tty -s` 成功，codex --version OK，git worktree OK。

预期：
- run-mode.sh detect 输出 `CLI-YOLO`
- Goal Codex 启动用 `codex --dangerously-bypass-approvals-and-sandbox --cd "$WORKTREE"`
- watcher 后台跑

### RM-2. TMUX-YOLO 模式（Claude→Codex 派任务场景首选）

场景：Claude Code Bash 工具调用，`tty -s` 失败、`CLAUDECODE=1` 或 `CLAUDE_CODE_ENTRYPOINT` 非空、`tmux -V` 能跑、codex 装好、在 worktree 内。

预期：
- `run-mode.sh detect` 输出 `TMUX-YOLO`
- `run-mode.sh capabilities` 输出 `recommend: "TMUX-YOLO"`，`tmux_installed: true`
- APPROVAL.md 包含 5 项 TMUX-YOLO 代价签字段（参见 SKILL.md Step 0.4 TMUX-YOLO 增量段）
- Phase 0.0 prelude 执行 stale tmux session scan（`references/tmux-yolo-runtime.md` §3.2）
- Goal Codex 启动用 `tmux new-session -d -s codex-job-$TASK_ID "codex --dangerously-bypass-approvals-and-sandbox --cd $WORKTREE"`，并立刻 `tmux pipe-pane` 兜底完整日志
- `/goal` 投喂 prompt 含 marker 协议条款（要求 Codex 输出 `# PHASE-<N>-DONE @ <UTC>` 单行 marker，详见 `references/tmux-yolo-runtime.md` §1.1）
- orchestrator 通过 `tmux capture-pane -t codex-job-$TASK_ID -J -p -S -2000 | strip_tmux_artifacts` 旁观（§2.2）
- watcher 后台跑且额外负责扫 buffer 找 DONE/ABORTED marker（§1.2），命中后触发 snapshot + reviewer + review-audit
- watcher 退出（含正常 / SIGINT / SIGTERM）必触发 cleanup_session trap 杀掉自己负责的 tmux session（§3.3）

### RM-3. CLI-EXEC 模式（tmux 不可用 / opt-out）

场景：无 TTY 但**tmux 不可用**（受限沙箱、CI 容器没装 tmux）或显式设了 `CODEX_GOAL_DISABLE_TMUX_YOLO=1`，且当前不在 subagent-capable env。

预期：
- run-mode.sh detect 输出 `CLI-EXEC`
- Goal Codex 启动用 `codex exec --cd "$WORKTREE" < goal-prompt-N.md` 一 Phase 一次
- watcher 仍后台跑，但 mini-review 由 watcher 派单次 codex exec

### RM-4. SUBAGENT 模式（双重兜底）

场景：Claude Code 主上下文，`CLAUDECODE` 等 subagent env hint 非空，**但 tmux 不可用**；或显式 opt-out + 在 subagent env。

预期：
- run-mode.sh detect 输出 `SUBAGENT`
- orchestrator 派 `Agent(codex-rescue, prompt="跑 Phase N")`
- 无后台 watcher，orchestrator 兼任（**但** snapshot/audit/隔离一项不能少）

### RM-5. RUN_MODE 中途变化 → 拒绝重新探测

场景：CLI-YOLO / TMUX-YOLO 模式跑到一半，orchestrator 检测到 TTY 消失 / tmux session 异常退出。

预期：
- 写 `STOPPED: run-mode-changed` 到 STATUS.md
- 等收尾后重新进 Phase 0
- **不允许**中途切模式

### RM-6. TMUX-YOLO 推荐但 APPROVAL.md 缺 5 项代价 → 拒绝进 Phase 1

场景：`recommend: TMUX-YOLO` 触发，但人类写 APPROVAL.md 时忘加 `## TMUX-YOLO Acceptance` 段（或 5 项 checklist 没全勾）。

预期：
- watcher / orchestrator 校验 APPROVAL.md 时发现 5 项 cost 未全勾
- **拒绝**启动 Goal Codex
- 写 `STOPPED: tmux-costs-not-accepted` 到 STATUS.md
- 通过 IM 回送提示用户补勾或选择 fallback 到 CLI-EXEC

### RM-7. TMUX-YOLO opt-out fallback 路径

场景：`CODEX_GOAL_DISABLE_TMUX_YOLO=1` 显式设置（用于 caller 还没升级识别 TMUX-YOLO 时）。

预期：
- 即便 `CLAUDECODE=1` + tmux 可用，`run-mode.sh detect` 不输出 `TMUX-YOLO`
- 退回老逻辑：subagent-env-hint 非空 → `SUBAGENT`，否则 `CLI-EXEC`
- `run-mode.sh capabilities` 中 `recommend` 字段仍标 `TMUX-YOLO`（提示有更优选择，但因 opt-out 不强制）

### RM-8. tmux 不可用强制降级

场景：`recommend: TMUX-YOLO` 被推荐但 `tmux -V` 失败（容器里 tmux 没装）。

预期：
- run-mode.sh detect 自动降级到 `SUBAGENT`（subagent env hint 非空时）或 `CLI-EXEC`
- 写降级原因到 STATUS.md：`fallback: tmux-unavailable → SUBAGENT`
- 不进 TMUX-YOLO 路径，但 APPROVAL.md 也不需要 5 项 cost 段（因为没走该模式）

## 两 Codex 硬隔离

### ISO-1. reviewer_pid == goal_pid → ABORT

场景：Reviewer 启动时碰巧 fork 出与 goal 相同 pid（极少见但要测）。

预期：watcher 校验 `[[ $REVIEWER_PID != $GOAL_PID ]]` 失败，立刻 kill reviewer + alert。

### ISO-2. Reviewer 在 Goal worktree 启动 → ABORT

场景：watcher trigger_review 时漏了 `git worktree add`，直接在 Goal worktree 跑。

预期：reviewer-prompt.md 的 Step 1 强制要求独立 readonly worktree，否则脚本拒绝继续。

### ISO-3. Reviewer 能读到 STATUS.md → 必须失败

场景：readonly worktree 创建后没物理屏蔽 STATUS.md。

预期：
- reviewer 读 STATUS.md 后 verdict 锚定上一轮 → 与"无锚定"原则违反
- watcher 创建 readonly worktree 时 `rm -f STATUS.md ISSUES.md && rm -rf logs/ reviews/` 必须执行
- 如果检测到 readonly worktree 仍含 STATUS.md → Red Flag

### ISO-4. Reviewer 启动未 env -i → Red Flag

场景：直接 `codex exec` 启动 reviewer，KEYCHAIN_* 等环境变量未清。

预期：
- reviewer 能访问 keychain → 可能误调用外部 API
- review-audit/round-N.jsonl 必须记录 launch cmd，事后能查 launch cmd 是否含 `env -i`

### ISO-5. mini-review 把 1-5 改成 1-10

场景：mini-review codex 自由换算分数尺度。

预期：
- milestone-review-prompt.md 反复强调 "1-5 scale, do NOT rescale to 1-10"
- score-diff.py 检测到 aggregate > 5 时自动 reject + alert（脚本拒绝）

## Snapshot + 最高分回退

### SS-1. 分数创新高 → snapshot tag 创建

场景：milestone-3 aggregate 4.25，前面最高 4.0。

预期：
- snapshot.sh 输出 `created`
- `git tag snapshot-milestone-3-4.25` 存在
- snapshots/HIGHEST_SCORE = 4.25
- snapshots/HIGHEST_TAG = snapshot-milestone-3-4.25

### SS-2. 分数未创新高 → 不打 tag

场景：milestone-4 aggregate 4.0，最高仍是 4.25。

预期：
- snapshot.sh 输出 `skipped`
- snapshots/HISTORY.jsonl 仍记录一行（new_high: false）
- 不打新 tag

### SS-3. 3 轮不涨分 → 提示回退到最高分

场景：mode = no-improvement-N，N=3，连续 milestone-4/5/6 aggregate 都 = 4.0（最高仍是 milestone-3 的 4.25）。

预期：
- score-diff.py 退出码 1，verdict = stop-no-improvement
- watcher 写 `STOPPED: score-trigger`
- orchestrator 唤醒后**必须**问人类是否回退到 HIGHEST_TAG
- 人类同意 → `git checkout snapshot-milestone-3-4.25` 后才 commit

### SS-4. PASS 但低于最高分 → 不自动回滚

场景：final review verdict=pass，aggregate 4.0，但 HIGHEST=4.25。

预期：
- 不自动 git checkout 回退
- 累计 no-improvement 计数
- 仍发送 IM 让人类知道"当前 PASS 但没创新高，最高在 round-X"

### SS-5. 最终 commit 走 HIGHEST_TAG 不是 HEAD

场景：3 轮 review 全 pass，但最高分在 round-2，最后一轮 round-3 是 PASS 但低于 round-2。

预期：
- Step 3.3 commit 时 `git checkout snapshot-final-r2-X.XX` 后再 commit
- commit message 含 `(snapshot=$HIGHEST_TAG)`

## 边界守卫（boundary-watch）

### BW-1. codex 改了 worktree 外文件 → hard kill

场景：goal codex bug 越界改了 `$HOME/某个项目` 下的文件。

预期：
- boundary-watch.sh 检测到 main worktree 关键文件 mtime 在 5 分钟内
- 输出 `stop-boundary`
- watcher 立刻 cleanup_codex + alert

### BW-2. 主分支被切

场景：codex 偷偷 `git checkout main` 然后改了文件。

预期：
- boundary-watch.sh 检测 `current_branch != goal/*`
- 输出 `stop-boundary`

### BW-3. git remote 被改

场景：codex 改 origin URL（极端情况）。

预期：
- boundary-watch.sh 比对 `.original-remote` 失败
- `stop-boundary`

### BW-4. reflog 含 force/reset --hard

场景：codex 跑了 `git reset --hard HEAD~3`。

预期：
- boundary-watch.sh 检测 reflog
- `stop-boundary`

## Review Audit

### AU-1. 每轮 review 写 audit JSONL

场景：mini-review-3 完成。

预期：
- `.agent/tasks/<id>/review-audit/round-milestone-3.jsonl` 一行新记录
- 含 reviewer_pid / reviewer_thread_id / verdict / scores / aggregate
- INDEX.md 更新

### AU-2. orchestrator 仲裁 override Must Fix → audit 记录

场景：reviewer round-2 要拆 sanitize.ts，orchestrator 按黑名单拒绝。

预期：
- review-audit/round-2.jsonl 中 `orchestrator_arbitration.must_fix_overridden` 含该 idx
- `override_reasons` 含 "src/utils/sanitize.ts in GOAL.md Non-goals"

### AU-3. 复盘查询 — 哪些 Must Fix 被 override

场景：人类想知道整个任务里哪些 reviewer Must Fix 被仲裁推翻。

预期：
```bash
jq -s '[.[] | select(.orchestrator_arbitration.must_fix_overridden | length > 0)
        | {round, file: .must_fix[.orchestrator_arbitration.must_fix_overridden[0]].file,
           reason: .orchestrator_arbitration.override_reasons[0]}]' \
   review-audit/round-*.jsonl
```
能列出所有 override 记录。

### AU-4. 检测 reviewer thread 串扰

场景：所有 reviewer 启动方式正确，但 audit 中两个 reviewer thread_id 相同。

预期：
```bash
jq -s '[.[] | .reviewer_thread_id] | unique | length'
```
应该 = round 数；少了说明有 reviewer 复用了 thread → 隔离失效，alert。

## UI 任务专属（is_ui_task: true）

### UI-1. 每轮强制截图 + 即时 IM 推送

场景：milestone-2 完成，is_ui_task=true。

预期：
- runtime-evidence.sh 跑完后立刻 cc-connect send 含截图
- 不批发，不等 final review
- 同时写 `pending-review-images.txt` 让 orchestrator 后补校验

### UI-2. 状态走查覆盖

场景：mini-review codex 跑用户旅程时只看了默认状态。

预期：reviewer 必须按 GOAL.md User Journeys + UI checklist 状态矩阵覆盖（normal / duplicate / 边缘视口 / 滚动到底等），漏了 → Should Fix

### UI-3. 截图文件名 ≠ 内容（hallucination）

场景：Goal codex 截了 `normal-saved.png`，但实际显示设置弹窗。

预期：
- watcher 立刻发 IM
- orchestrator 下次 ping 时 view_image 看 `pending-review-images.txt`，发现错位
- 单独发 "勘误" 消息 + 重新派 codex 截图

### UI-4. 收尾发 HIGHEST_TAG 截图

场景：3 轮 review，HIGHEST 在 round-2，但最终决定回退 commit round-2。

预期：
- 收尾 IM 推送是 round-2 截图（不是 round-3）
- 消息明确 "这是历史最高分版本，最终交付已回退"

### UI-5. 同分硬规则裁决

场景：round-6 和 round-8 都 4.6，但 round-6 toast 遮挡控件，round-8 用 status pill。

预期：
- orchestrator 仲裁选 round-8（按 STOP-CONDITIONS.md 硬规则段）
- no-improvement 计数从 round-8 重新算

## Orchestrator Idle 模型

### IDLE-1. orchestrator 启动 watcher 后进入 idle

场景：CLI-YOLO 模式，watcher 启动完毕。

预期：
- orchestrator 不再周期跑任何检查
- 等待 4 个唤醒源之一：人类 ping / .review-pending / .stop-signal / 关键词 IM

### IDLE-2. 人类 ping "现在咋样"

场景：watcher 跑了 2 小时，人类问"现在咋样"。

预期：
- orchestrator 唤醒，读 STATUS.md / scores/aggregate-trend.json / 最近 milestone
- 一句话总结回复（"已完成 3 个 milestone，当前最高分 4.25 在 round-3，正在跑 milestone-4"）
- **不**主动跑额外验证命令

### IDLE-3. 人类 ping "加规则 X"

场景：人类说"成功反馈不能影响布局"。

预期：
- orchestrator 抽象成评分维度 `Layout Stability`
- 追加到 EVAL.md `Reviewer Rubric` 段 + 写 `## Human Feedback` 段
- Goal Codex 下个 milestone 开始前读到

### IDLE-4. orchestrator 周期 poll IM → Red Flag

场景：orchestrator idle 期间自己周期跑 cc-connect inbox poll。

预期：
- Red Flag 命中（"orchestrator 周期 poll IM" 是 watcher 的活）
- 应该让 watcher 做这件事

## Extra Reviewers 注册机制（v4）

### ER1. 不写 extra_reviewers → v3 行为不变

场景：GOAL.md 无 `extra_reviewers:` 段。

预期：
- watcher `launch_extra_reviewers` 输出 "No extra reviewers registered (v3 mode)"
- 只跑内置 Reviewer Codex
- snapshot 用单 reviewer aggregate（向下兼容）

### ER2. is_ui_task=true 自动建议 director-design

场景：Phase 0.1 探测 is_ui_task=true。

预期：
- Step 5（新加）询问用户："要加 director-design 作为 extra reviewer 做 UI 视觉专项审吗？"
- 用户确认 → GOAL.md 落盘 `extra_reviewers: [director-design]`
- 用户拒绝 → 不写该字段，只跑内置 reviewer

### ER3. 多 reviewer 并列启动

场景：GOAL.md 写 `extra_reviewers: [director-design]`。

预期：
- Step 2.3.1 启动内置 Reviewer Codex
- Step 2.3.2 并列派 director-design subagent
- 两份独立报告：
  - `reviews/round-N/REVIEW.md`（内置）
  - `reviews/round-N/extras/director-design.md`（extra）

### ER4. 派工 prompt 必须显式调用 skill

场景：subagent 启动后没读 director-design SKILL.md，直接按训练 prior 行事。

预期：
- watcher 的派工 prompt 含 "MUST explicitly invoke the `director-design` skill" 字样
- 若 subagent 输出报告但未走 director-design 的 Mode Selection 流程 → audit 记录 + log warn

### ER5. 仲裁默认 AND-pass

场景：codex-reviewer pass + director-design pass-with-fixes。

预期：
- arbitrate_reviews 返回 fail（pass-with-fixes != pass）
- must-fix 合并到 STATUS.md Next Action
- 退回 Goal 重写

### ER6. 仲裁切换 OR-pass

场景：GOAL.md 加 `arbitration_rule: OR-pass`，codex-reviewer pass + director-design fail。

预期：arbitrate_reviews 返回 pass（任一通过即整体通过）。

### ER7. 几何平均 aggregate

场景：codex-reviewer aggregate 5.0，director-design aggregate 2.0。

预期：
- 几何平均 = sqrt(5 * 2) ≈ 3.16
- 比算术平均（3.5）低，强调"两边都好"
- snapshot 用 3.16 比较 HIGHEST_SCORE

### ER8. extra reviewer 失败不阻塞其他

场景：director-design subagent 超时（600s）。

预期：
- launch_one_extra_reviewer log 记录 "$reviewer_name timed out / failed (non-blocking)"
- arbitrate_reviews 跳过该 reviewer（reports 数组少一份）
- 内置 Reviewer Codex 仍正常返回 + 整体仲裁继续

### ER9. arbitration.md 落盘

场景：3 个 reviewer 全跑完。

预期：
- `reviews/round-N/arbitration.md` 写入合并视图（rule / reviewers 列表 / combined verdict / must-fix 合并清单）
- write-audit.sh 为每个 reviewer 各写一行 JSONL
- INDEX.md 加新列 "Reviewer"，按 reviewer_name 区分行

### ER10. hard-rule-override 模式

场景：GOAL.md 加 `arbitration_rule: hard-rule-override`，director-security（未来）给出 verdict=needs-redesign。

预期：即使其他 reviewer 都 pass，整体 fail（一票否决）。

### ER11. 未来加 director-* 零代码改动

场景：未来有 director-pm，用户在 GOAL.md 加 `extra_reviewers: [director-design, director-pm]`。

预期：
- watcher 不需要改任何代码
- 自动派 2 个 subagent，各产出 `extras/director-design.md` + `extras/director-pm.md`
- 仲裁自动按现有规则合并

### ER12. reviewer 的 checks 字段注入派工 prompt

场景：GOAL.md `extra_reviewers` 里 director-design 声明 `checks: [UX, Layout Stability]`。

预期：
- watcher 派 director-design subagent 时，把 `checks` 注入 prompt 的"负责的检查维度"段
- director-design **只在 UX / Layout Stability 上打分**，不评 Correctness 等其他维度
- 返回 JSON 含 `checked_dimensions` 字段，与 checks 一致

### ER13. checks 未声明 → REVIEWER-PLAN 表仍要显式列

场景：用户用极简 schema `extra_reviewers: [director-design]`，没写 checks。

预期：
- orchestrator 在 Step 0.1 生成 Reviewer Plan 表时，仍要为 director-design **填上建议的 checks**
- 整张表（含建议 checks）给用户确认
- 用户确认后，checks 落到 GOAL.md（极简 schema 升级为带 checks 的详细 schema）
- 不允许 reviewer 没有 checks 就进入 Phase 1

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

1. ✅ Pre-flight 6 项全过（codex 版本 / feature flag / git clean / acceptance commands / 不在主分支 / RUN_MODE 探测成功）
2. ✅ Step 0.1 完成：AC 量化、Goal-Attainment Mode 在 GOAL.md 落盘、Budget 确认、自定义评分维度（如适用）已加入 EVAL.md
3. ✅ 任务文件按模板创建（GOAL.md/PLAN.md/EVAL.md/STOP-CONDITIONS.md/STATUS.md/.gitignore + .original-remote 记录）
4. ✅ 独立 worktree 创建并切换；mkdir 在 cd 之后执行
5. ✅ **BASELINE.md 已落盘**且 reviewer_pid ≠ orchestrator_pid（独立 codex 跑过）
6. ✅ **Step 0.4 APPROVAL.md 存在**（人类签字才进 Phase 1）
7. ✅ Goal Codex 启动且 codex.pid 写入；启动方式按 RUN_MODE 分支正确
8. ✅ Watcher 启动且 watcher.pid 写入（CLI 模式）；SUBAGENT 模式下 orchestrator 兼任
9. ✅ STATUS.md 至少更新过 1 次（任务非 0 秒结束）
10. ✅ 至少 1 个 milestone 触发了 mini-review + snapshot 决策 + IM 推送（IM 会话下）
11. ✅ **每轮 mini-review 写了 review-audit/round-N.jsonl**（含 reviewer_pid / verdict / aggregate / arbitration 段）
12. ✅ **snapshot 机制工作**：分数创新高 → git tag snapshot-* 创建 + HIGHEST_SCORE/HIGHEST_TAG 更新
13. ✅ Goal 完成时 STATUS.md 含精确 `GOAL_DONE @ <ts>` 行
14. ✅ review-input 完整（diff / lint / test / build / runtime.log / screenshots/ 都有）
15. ✅ **Reviewer 在独立 readonly worktree 跑**（git worktree add HEAD ../<repo>-review-readonly-rN）
16. ✅ **Reviewer 启动用 env -i**（PATH/HOME/LANG/LC_ALL/NODE_ENV/TASK_ID 之外的变量被清掉）
17. ✅ **进程隔离硬验证**：reviewer_pid ≠ goal_pid ≠ orchestrator_pid（写入 reviews/round-N/reviewer.pid）
18. ✅ **readonly worktree 物理屏蔽** STATUS.md / ISSUES.md / logs/ / 历史 reviews/
19. ✅ Reviewer 输出 REVIEW.md 含 Reviewer Metadata 段（PID/Thread/LaunchCmd/WorktreeSHA）
20. ✅ Reviewer 输出 REVIEW.md 含 Runtime Verification 段 + 4 维度+扩展维度 vs baseline delta
21. ✅ Verdict pass 后按 risk_class 分级验证（low 信 reviewer / medium 抽查 / high 全套自跑）
22. ✅ **3 轮 fail 上限 / 3 轮不涨分 → 回退到 HIGHEST_TAG** 机制工作
23. ✅ 最终 commit 基于 HIGHEST_TAG 不是 HEAD（commit message 含 `snapshot=$HIGHEST_TAG`）
24. ✅ UI 任务（is_ui_task=true）：每个 milestone 即时发截图 + pending-review-images.txt 写入 + 收尾发 HIGHEST 截图
25. ✅ boundary-watch 全程未命中（或命中即 hard kill 走 STOPPED 路径）
26. ✅ 最终输出 Codex Goal Task Report 含全部字段（Phase 0 Contract / Run Mode / Risk Class / Score Trajectory / Snapshots / Audit / UI Screenshots 段）
27. ✅ 无 Red Flag 命中
