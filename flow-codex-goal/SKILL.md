---
name: flow-codex-goal
description: >
  Use when an orchestrator agent (Claude / Codex / any other) needs to drive a
  long-horizon Codex task end-to-end with: explicit Phase 0 contract signoff
  (acceptance criteria + stop conditions + custom score rubric), independent
  baseline scoring, hard-isolated fresh-process Reviewer Codex (separate process
  + separate read-only worktree + scrubbed env), per-round snapshot with
  max-score rollback, runtime evidence with mandatory UI screenshots pushed
  immediately to IM, full review audit log, and an orchestrator that stays
  mostly idle so the human can interrupt and adjust at any time. Trigger on
  phrases like "用 codex goal 跑这个长任务", "让 codex 后台跑", "无人值守长跑",
  "use codex goal mode", "long-horizon agent task", "background codex execution",
  "ralph loop", "codex 循环改造", "let codex run for hours". Do NOT use for short
  tasks (use `flow-dev-task` instead), exploratory work without acceptance
  criteria (use brainstorming), or tasks where the orchestrator itself should be
  the executor (use `flow-dev-task`).
type: workflow
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)

# flow-codex-goal

## Overview

编排「Phase 0 契约确认 → 基线评分 → Goal Codex 长跑 + 健康/边界看门狗 → 周期 mini-review + UI 截图即时推送 → 独立 Reviewer Codex（硬隔离）→ 每轮 snapshot + 最高分回退 → 风险分层验证 → 人类签字 → commit」一条流水线。

### 调用方角色 — orchestrator agent

本 skill 不假设调用方是 Claude——可以是 Claude Code、Codex CLI、Gemini 或任何其他能调用 Bash 的 agent。下文统一用 **orchestrator agent** 指代。

**orchestrator agent 是人类的副驾，不是流水线执行者**。大部分时间应保持 idle，只在 4 个时刻被唤醒：
1. Phase 0 契约门（一次性）
2. 人类主动 ping（"现在啥情况""我加个规则"）
3. final review 完成等签字
4. stop condition 触发（watcher 写 SIGNAL 文件，orchestrator 读到响应）

把"周期 poll IM inbound / mini-review / score-diff / 截图发送 / boundary 监督"全部交给 watcher 完成。详见下方「Orchestrator Idle Model」段。

### 核心信念

> 长任务不依赖对话上下文记忆，依赖**磁盘状态文件**、**事先签字的契约**、**独立 worktree**、**真实运行环境**、**硬隔离的独立 review**、**每轮快照 + 最高分回退**、**周期性人类校准**。

### Codex `/goal` 的硬限制 + 本 skill 的兜底

Codex `/goal` 是 Codex CLI 0.128.0+ 的实验功能（feature flag `goals = true`），让一个 Codex 围绕目标持续执行，但有 5 个硬限制必须靠本 skill 兜底：

| Codex 自身限制 | 本 skill 的兜底 |
|---|---|
| 没有自动循环 | watcher.sh 周期 poll + 触发 continuation |
| 没有花销上限 | GOAL.md Budget + score-diff 退化检测 + watcher 强停 |
| 完成检测不可靠 | health-check.sh 6 维度判定 + STATUS.md `GOAL_DONE` 信号 |
| 没有评分基线 | Step 0.3 强制独立 baseline scoring |
| 自报常失真（"完成"实际未跑、文件数虚报、截图错位）| watcher 跨证据交叉校验 + reviewer 独立运行时验证 |

## When to Use

进入本 skill 必须**全部**满足：

- 任务边界清晰，可拆步骤，有可验证的 acceptance criteria
- 预估执行时间 ≥ 2 小时
- 用户希望"无人值守长跑"或"后台跑"
- Codex CLI ≥ 0.128.0 且已启用 `goals` feature flag
- 项目工作区干净（git status clean）或可创建 worktree

## When NOT to Use

- 短任务（< 2 小时）→ `flow-dev-task`
- 模糊目标（"让 UI 更好看"无量化指标）→ `superpowers:brainstorming`
- 探索性任务，没有 stop condition → `superpowers:brainstorming`
- 高风险代码（auth/支付/加密）→ orchestrator agent 自写，不派 Codex
- Codex CLI 未装或版本 < 0.128.0 → 退回 flow-dev-task

## Run Modes（运行模式四分支）

orchestrator agent 调用本 skill 时所处的运行环境**决定能用哪种 Goal Codex 启动方式**。Step 0.0 必须先探测，后续步骤按模式选路径。

| 模式 | 探测条件 | Goal Codex 启动 | watcher 形态 | 适用场景 |
|---|---|---|---|---|
| **CLI-YOLO** | 有 TTY（`tty -s` 成功）+ 当前 shell 是终端 + worktree 隔离 OK | `codex --dangerously-bypass-approvals-and-sandbox --cd "$WORKTREE"` 长跑 | nohup 后台 watcher.sh | 终端直接调用 / cron / IM bridge 后台 daemon |
| **TMUX-YOLO** | 无 TTY + `CLAUDECODE` / `CLAUDE_CODE_ENTRYPOINT` / `CC_PROJECT` / `ANTHROPIC_AGENT_RUNTIME` 任一非空 + `tmux -V` 可用 + worktree 隔离 OK | `tmux new-session -d -s codex-job-$ID "codex --dangerously-bypass-approvals-and-sandbox --cd $WORKTREE"`；orchestrator 通过 `tmux capture-pane` / `send-keys` 旁观与投喂 | nohup 后台 watcher.sh，额外负责扫 buffer 找 `# PHASE-N-DONE` marker | **Claude→Codex 派任务场景的首选**：Claude Code Bash 工具 / IDE 沙箱里跑长任务 |
| **CLI-EXEC** | 无 TTY 但能 spawn 子进程，tmux 不可用 | `codex exec --cd "$WORKTREE" < goal-prompt-N.md` 单 Phase 跑完即止 | watcher 仍后台跑，但 mini-review 由 watcher 派单次 codex exec | 没装 tmux 的 Claude Code Bash 工具 / 受限沙箱 |
| **SUBAGENT** | 主进程能 spawn agent（如 Claude Code Agent 工具）但无 TTY、tmux 也不可用 | orchestrator 主动派 `Agent(codex-rescue, prompt="跑 Phase N")` 一次一 Phase | 无 watcher（orchestrator 兼任）；但**仍必须**有 review-audit + snapshot 机制 | Claude Code 主上下文 / Codex 调度子 codex（且容器里没 tmux） |

**判定脚本**见 `references/run-mode.md`。Phase 0 输出必须含 `run_mode` 字段。

**关键纪律**：
- CLI-YOLO 是终端直跑的首选（最接近"无人值守"）
- **TMUX-YOLO 是 Claude→Codex 派任务场景下的强烈建议**：tmux 一旦可用就应优先于 CLI-EXEC / SUBAGENT 选它，理由是保留 Codex 长跑的上下文连续性 + 仍由独立 watcher 守纪律。详细规则与降级条件见 `references/run-mode.md` 的「强烈建议规则」节。`run-mode.sh capabilities` 输出 `recommend: "TMUX-YOLO"` 时 Phase 0 必须把"是否采纳建议"写入 APPROVAL.md。
- CLI-EXEC 是 tmux 不可用时的次选（仍用 watcher 但每轮启停 codex）
- SUBAGENT 是双重兜底（连 tmux 也没有；orchestrator 必须自己做 watcher 的活，但 review 隔离 / snapshot / audit 一项不能少）

## Required Workflow（按 Phase 顺序执行）

### Phase 0：Contract Gate（契约确认门，**必须人类签字才能进 Phase 1**）

#### Step 0.0：Pre-flight + 运行模式探测

```bash
# 1. Codex 版本
codex --version  # 必须 ≥ 0.128.0

# 2. feature flag
grep "goals = true" ~/.codex/config.toml || cat >> ~/.codex/config.toml <<'EOF'
[features]
goals = true
EOF

# 3. 工作区干净
git status --short  # 必须为空

# 4. 项目有 acceptance commands
ls package.json Cargo.toml go.mod 2>/dev/null

# 5. 当前分支不是 main/master/dev
git branch --show-current

# 6. 运行模式探测
RUN_MODE=$(bash references/run-mode.sh detect)
# 输出: CLI-YOLO | TMUX-YOLO | CLI-EXEC | SUBAGENT
echo "$RUN_MODE" > .agent/tasks/$TASK_ID/RUN_MODE
```

任一失败 → 整个 skill 退出并报告原因。

#### Step 0.1：AC + Mode + Budget + Custom Rubric 确认

orchestrator agent 在 GOAL.md 落盘之前，向人类**一次性批量**提案以下 4 项（Question Budget = 3 + 1 项可选维度，超出走推断默认）：

1. **Acceptance Criteria 量化**
   - 列出推断的 AC（从 prompt + Context Harvest 提炼）
   - 每条必须能由 EVAL.md 中某条命令 / 截图断言
   - 模糊 AC（"更好用"、"更快"）必须改写成数字

2. **Goal-Attainment Mode**

   | 模式 | 何时停 | 适用场景 |
   |---|---|---|
   | `threshold` | 综合分数 ≥ 阈值（默认 4.0/5.0） | 追求达到某质量水平 |
   | `no-improvement-N` | 连续 N 轮（默认 3）分数不再上升 | 优化类（性能/体积/a11y）|
   | `regression-prevention` | 任一维度 < baseline 立即停 | 重构类（功能不变结构变好）|
   | `hybrid` | threshold + no-improvement-N 都满足 | 既要达标又要稳定 |

   推断默认值：
   - 重构 / migration → `regression-prevention`
   - 性能 / 体积优化 → `no-improvement-N`
   - 新功能 / 修复 → `threshold`
   - UI 循环改造 → `no-improvement-N` + 同分硬规则选优（详见 `references/ui-review-checklist.md`）

3. **Budget 上限**：默认 files ≤ 50 / tokens ≤ 500K / wall_clock ≤ 4h / verification_failures ≤ 3

4. **自定义评分维度（可选）**
   - orchestrator 探测任务类型（UI / API / 性能 / 重构）后**主动建议**扩展维度
   - 例：UI 任务建议加 `Layout Stability` / `Small Popup Density` / `Interaction Priority`（来自 `references/score-rubric-extensions.md`）
   - 人类可追加自定义维度（"成功反馈不能影响布局" → `Layout Stability`）
   - 所有维度（基础 4 + 扩展）必须在 EVAL.md 显式列出，reviewer 才会评

5. **Reviewer 阵容 + 各自检查维度（必须用户确认）**

   分两步：先按任务信号**路由**出 reviewer 阵容，再生成 **Reviewer Plan 确认表**让用户确认每个 reviewer 查什么。

   **5a. 路由 reviewer 阵容**（2026-05 升级 4 角色路由）

   orchestrator 根据任务特征**主动建议**额外 reviewer。详细路由规则见
   `references/role-router.md`（任务信号 → 角色映射 + 探测命令 + 反例）。快速路由表：

   | 任务信号 | 推荐 extra reviewer |
   |---|---|
   | `is_ui_task: true` / 含截图证据 | **director-design**(视觉)+ **director-frontend**(代码 double check)|
   | git diff 含 `*.tsx/jsx/vue/svelte/css` 但无截图 | **director-frontend**(代码气味 / 边界 / AI slop) |
   | prompt 含 "宣传 / 发推 / release notes / post to ..." | **director-promote**(9 维材料 audit) |
   | prompt 含 "装 / 卸 / setup / install / uninstall" | **director-ops**(7 维流程 audit) |
   | 项目规则 / tech stack / 架构 / API schema / migration / 跨服务 | **director-architect** ✅(7 维 quality audit) |
   | 高风险 auth / 支付 / 加密 | (未来 director-security) |

   **5b. 生成 Reviewer Plan 确认表（必须用户确认）**

   - orchestrator 把路由出的阵容整理成一张 **reviewer × 检查维度映射表**（格式见下方"Reviewer Plan 确认表"），
     **每个 reviewer 标注它负责检查哪几个维度**：
     - 内置 Reviewer Codex（**必跑**）：默认负责 `Correctness / Maintainability / Risk` + 非 UI 的扩展维度
     - `director-design` → UI 视觉维度（`UX` + Layout Stability 等）
     - `director-frontend` → JSX 代码维度（Correctness / Maintainability 等）
     - `director-promote` / `director-ops` / `director-architect` → 各自领域维度
   - **整张表给用户逐项确认**——不是只确认"加不加 reviewer"，而是确认"每个 reviewer 各查什么"
   - 用户可：增删 reviewer、把某维度从 A reviewer 挪到 B reviewer、追加维度
   - 用户回复 "yes / 默认 / 按你的来" → 按建议表写入；显式说 "不要 X" → 移除；沉默 / 模糊 → 取建议默认
   - 确认后写入 GOAL.md `extra_reviewers:` 段（每个 reviewer 带 `checks:` 列出其维度，schema 见 `references/goal-template.md`）
   - 仲裁规则默认 **AND-pass**（所有 reviewer 都通过才整体 pass）+ 不加权，详见 `references/reviewer-arbitration.md`
   - 不加 extra reviewer = 只跑内置 Reviewer Codex（它仍要在确认表里声明检查维度），向下兼容 v3 行为

**禁止**：未确认就启动 Goal Codex。AC 模糊 / reviewer 检查范围未确认 → goal 跑飞或漏审，攻击面在 Phase 0 这里堵住。

##### Reviewer Plan 确认表（Step 0.1 第 5 项的产物，必须呈给用户）

orchestrator 生成下表，作为 APPROVAL 契约的一部分（IM 会话时随 Step 0.4 发回，见下文）：

```md
## Reviewer Plan — <TASK_ID>

| Reviewer | 类型 | 负责检查的维度 | 仲裁权重 |
|---|---|---|---|
| Reviewer Codex | 内置·必跑 | Correctness / Maintainability / Risk / <非 UI 扩展维度> | 1.0 |
| director-design | extra | UX / Layout Stability / Small Popup Density | 1.0 |
| <其他 extra> | extra | <维度列表> | <weight> |

仲裁规则: AND-pass（所有 reviewer 都 pass 才整体 pass）

> 请确认：reviewer 阵容是否合适？每个 reviewer 的检查维度是否要增删 / 调整归属？
```

**覆盖性自检**：表生成后，orchestrator 必须核对 EVAL.md 里**每个评分维度都至少被一个 reviewer 认领**。
有维度无人认领 → 补 reviewer 或把该维度并入某 reviewer，**不允许出现"无人检查的维度"**。

#### Step 0.2：创建任务目录 + 隔离 worktree + 模板落盘

```bash
TASK_ID="$(date +%Y%m%d-%H%M%S)-$(echo $TASK_NAME | tr ' ' '-')"

# 隔离 worktree（**禁止**在主 worktree 跑 codex --yolo）
WORKTREE="../$(basename $PWD)-goal-$TASK_ID"
git worktree add "$WORKTREE" -b "goal/$TASK_ID"
cd "$WORKTREE"

# **必须在 cd 进 worktree 之后**创建任务目录（否则路径写到主 worktree）
mkdir -p ".agent/tasks/$TASK_ID"/{logs,review-input/screenshots,reviews,review-audit,snapshots,scores}

# 记录原始 remote（boundary-watch 用作基线，不允许中途改）
git remote get-url origin > ".agent/tasks/$TASK_ID/.original-remote" 2>/dev/null || true
```

按模板创建（含 Step 0.1 确认的所有字段）：
- `GOAL.md` — 用 `references/goal-template.md`（含 `is_ui_task` / `risk_class` / `run_mode` / 扩展维度段 / `extra_reviewers` 含 `checks`）
- `PLAN.md` — 用 `references/plan-template.md`
- `EVAL.md` — 用 `references/eval-template.md`（含基础 4 维 + 扩展维度）
- `STOP-CONDITIONS.md` — 用 `references/stop-conditions.md` 模板（独立成文件，方便 reviewer/orchestrator/watcher 共用）
- `REVIEWER-PLAN.md` — Step 0.1 第 5 项生成的 reviewer × 检查维度映射表（Step 0.4 发给用户确认 / IM 会话发回来源通道）
- `STATUS.md` — 初始化为 `Phase: 0 / Step: 0 / Last verification: never / Next action: read GOAL.md`

`.gitignore` 必须加：
```
.agent/tasks/*/logs/
.agent/tasks/*/review-input/
.agent/tasks/*/reviews/
.agent/tasks/*/scores/
```

#### Step 0.3：基线评分（**必须独立 Reviewer Codex 跑，禁止 orchestrator 自己当代理**）

```bash
cd "$WORKTREE"
TASK_DIR=".agent/tasks/$TASK_ID"

# 1. 准备 baseline 用的 review-input
mkdir -p "$TASK_DIR/baseline/screenshots"
bash references/runtime-evidence.sh "$TASK_ID" baseline

# 2. 启动独立 Reviewer Codex 给 baseline 打分
#    必须是新进程，且 launch cmd 写入 BASELINE.md 留证据
BASELINE_PID=$(codex exec --skip-git-repo-check < references/baseline-prompt.md & echo $!)
wait $BASELINE_PID
# 输出 .agent/tasks/$TASK_ID/BASELINE.md，含 reviewer_pid + reviewer_thread_id 字段
```

**硬验证**：BASELINE.md 必须含 `reviewer_pid` 字段，且 `reviewer_pid != orchestrator_pid`。orchestrator 自己当 reviewer 直接拒绝（脚本校验）。

**禁止**：跳过 baseline 直接启 Goal——会失去退化检测信号；orchestrator 充当 baseline reviewer 会让后续 mini-review 评分基准漂移。

#### Step 0.4：APPROVAL.md 人类签字

orchestrator agent 把 Phase 0 产出物发给人类签字。产出物**必须包含**：
- GOAL.md / EVAL.md / STOP-CONDITIONS.md / BASELINE 全文 + 关键截图
- **Reviewer Plan 确认表**（Step 0.1 第 5 项生成的 reviewer × 检查维度映射表）

人类**必须**回复或在 worktree 内创建：

```bash
# .agent/tasks/$TASK_ID/APPROVAL.md
APPROVED by <human-id> @ <ISO-8601 ts>
Reviewed: GOAL.md / EVAL.md / STOP-CONDITIONS.md / BASELINE.md / Reviewer Plan
Notes: <optional>
```

**当 `run_mode = TMUX-YOLO` 时必须额外包含**（5 项代价显式接受，缺一不允许进 Phase 1）：

```bash
# .agent/tasks/$TASK_ID/APPROVAL.md（TMUX-YOLO 增量段）
## TMUX-YOLO Acceptance
ACCEPTED 5 tmux-yolo costs by <human-id> @ <ISO-8601 ts>:
- [x] orphan tmux session cleanup 责任在 orchestrator + watcher
- [x] capture-pane buffer ANSI 转义由下游 strip
- [x] phase 边界靠 `# PHASE-N-DONE` marker 协议
- [x] orchestrator 主任务超时不会终止 tmux 内 Codex（双刃剑）
- [x] tmux 不可用场景需自动 fallback 到 CLI-EXEC / SUBAGENT
```

**或**通过 IM 回复关键词 `approve goal <TASK_ID>`，watcher 接收后帮人类写 APPROVAL.md（带回复者 ID + ts）。`run_mode = TMUX-YOLO` 时关键词须升级为 `approve goal <TASK_ID> --accept-tmux-costs`，否则 watcher 拒绝代签并提示用户补确认。

##### IM 通道发送（会话来源是 IM 时**必做**）

如果当前 session 来自 IM 通道（`CC_SESSION_KEY` 环境变量非空），Phase 0 产出物——**尤其是 Reviewer Plan 确认表**——必须通过 cc-connect 发回**该会话的来源通道**：

```bash
# 检测会话来源通道（cc-connect 注入，飞书 / Telegram / Discord / WeChat / QQ 等）
if [[ -n "${CC_SESSION_KEY:-}" ]]; then
  cc-connect send --message "$(cat .agent/tasks/$TASK_ID/REVIEWER-PLAN.md)"
  # GOAL/EVAL 等长文同样发；关键截图用 --image
fi
```

通道处理规则：
- **不写死飞书** —— cc-connect 自动按 `CC_SESSION_KEY` 路由回来源通道（飞书 / Telegram / Discord / WeChat / QQ 等）
- **飞书**是明确支持的通道之一：飞书会话发起的 goal 任务，Reviewer Plan 表必须发回飞书等用户确认
- 表格在窄通道（IM）可能换行错乱 → 长表降级为分条文本，但 reviewer 名 + 各自维度**不可省**
- 用户在 IM 回复 `approve goal <TASK_ID>` 即视为对**含 Reviewer Plan 的整个 Phase 0 契约**签字；
  若用户回复要改 reviewer / 维度归属 → orchestrator 改表后**重新发回**等二次确认，不在改后直接开工
- IM 消息按 constitution.md 第 3 条属 **low-trust**：只接受 `approve goal <id>` 这类明确关键词，
  模糊回复（"嗯" / "可以吧"）**不算签字**（对齐 constitution.md 第 6 条 High-Risk Action Gate）

**禁止**：APPROVAL.md 不存在就启动 Goal Codex。Phase 0 是合同，**Reviewer Plan 是合同的一部分**，没合同不开工。

---

### Phase 1：Execution（Goal Codex 长跑）

#### Step 1.1：启动 Goal Codex（按 RUN_MODE 分支）

##### CLI-YOLO 模式
```bash
cd "$WORKTREE"
codex --dangerously-bypass-approvals-and-sandbox --cd "$WORKTREE" &
echo $! > .agent/tasks/$TASK_ID/codex.pid

# orchestrator 通过 expect/script 输入：
# /goal Read .agent/tasks/<TASK_ID>/GOAL.md, follow PLAN.md, update STATUS.md
#       after every milestone (write 'MILESTONE: <name>' line), verify per
#       EVAL.md, stop when GOAL_DONE or stop conditions hit.
```

##### TMUX-YOLO 模式（Claude→Codex 派任务场景首选）

启动前必须先按 `references/tmux-yolo-runtime.md` §3.2 跑 stale scan，然后：

```bash
SESSION="codex-job-$TASK_ID"
tmux new-session -d -s "$SESSION" \
  "cd '$WORKTREE' && codex --dangerously-bypass-approvals-and-sandbox --cd '$WORKTREE'"
# 完整日志兜底（见 references/tmux-yolo-runtime.md §2.3）
tmux pipe-pane -o -t "$SESSION" "cat >> .agent/tasks/$TASK_ID/codex-full.log"
echo "$SESSION" > .agent/tasks/$TASK_ID/tmux.session
# 注：tmux session 在系统层持久存在，跨 Bash 工具调用不死

# 投喂初始 /goal 指令：marker 协议条款见 references/tmux-yolo-runtime.md §1.1
tmux send-keys -t "$SESSION" "/goal Read .agent/tasks/$TASK_ID/GOAL.md, follow PLAN.md, update STATUS.md after every milestone. Emit '# PHASE-<N>-DONE @ <ISO-UTC>' on its own line at the end of each phase (NOT inside code blocks); emit '# PHASE-<N>-ABORTED @ <ts> reason: <stop-id>' instead if a stop condition fires. Verify per EVAL.md, stop when GOAL_DONE or stop conditions hit." Enter

# orchestrator / watcher 之后通过 capture-pane 抓 buffer 判断进度（完整协议见 references/tmux-yolo-runtime.md §1.2 / §2.2）：
#   pane=$(tmux capture-pane -t "$SESSION" -J -p -S -2000 | strip_tmux_artifacts)
#   echo "$pane" | grep -E '^# PHASE-[0-9]+-(DONE|ABORTED) @ '
# 抓到 DONE marker 触发 snapshot + reviewer + review-audit；
# 抓到 ABORTED 写 STATUS.md STOPPED 并退出 watcher。
```

完整 3 项协议（marker / ANSI strip / cleanup）落地见 **`references/tmux-yolo-runtime.md`**。

##### CLI-EXEC 模式（每个 Phase 单次启动）
```bash
codex exec --skip-git-repo-check --cd "$WORKTREE" < references/goal-prompt.md
# 默认共用 goal-prompt.md;若需按 Phase 拆分,自行创建 phase-specific prompt 文件
# 跑完即退；watcher 检测 STATUS.md MILESTONE 后再派下一 Phase
```

##### SUBAGENT 模式（orchestrator 派子代理）
```python
# orchestrator 用 Agent(subagent_type=codex-rescue, prompt=...) 派一次一 Phase
# 不需要 codex.pid（orchestrator 持引用）
```

**关键约束**：
- **必须** `--dangerously-bypass-approvals-and-sandbox`（用户明确要求 codex 跑真实 host 环境，否则 pnpm install / keychain / dev server 都不可用）
- **必须** `--cd "$WORKTREE"`（隔离边界由 worktree 提供，不依赖 sandbox）
- 同时启动 `boundary-watch.sh`（见 Step 1.2）防止 codex 越界改主 worktree

完整 Goal prompt 见 `references/goal-prompt.md`。

#### Step 1.2：启动 watcher（健康 + 边界 + IM inbox poll）

```bash
nohup bash references/watcher.sh "$TASK_ID" \
  > .agent/tasks/$TASK_ID/logs/watcher.log 2>&1 &
echo $! > .agent/tasks/$TASK_ID/watcher.pid

# watcher 主循环按时间戳节流串行跑 3 个守卫（不是并发，避免 race）：
#   1. boundary-watch.sh（每 30 秒，检测 codex 是否动了 worktree 外文件 / 主分支 / git remote）
#   2. cc-connect inbox poll（每 60 秒，把人类 IM 回复落到 STATUS.md Human Feedback 段）
#   3. health-check.sh（每 INTERVAL 默认 5 分钟，检测 running/milestone/done/stalled/failed/stopped）
# 如果某次 health-check 卡 30s+，boundary 检查会被推迟到下个 sleep 后；属于已知妥协。
# 真正需要并发，可在 watcher.sh 内 fork 子 shell（当前不做，避免日志交错）。
```

watcher 是 **orchestrator idle 期间的唯一活跃进程**。它接管：
- 健康判定（running / milestone / done / stalled / failed / stopped）
- 边界守卫（详见 `references/boundary-watch.sh`）
- IM inbox poll（**人类 pause/abort/adjust 由 watcher 落盘，不再要 orchestrator poll**）
- mini-review 触发 + score-diff + snapshot
- UI 截图即时通过 cc-connect 推送

#### Step 1.3：watcher milestone 循环（含 UI 截图 + audit + snapshot）

每当 watcher 检测到 `milestone` 状态：

```bash
# 1. runtime-evidence.sh 收集证据（含 UI 任务的状态走查截图）
bash references/runtime-evidence.sh "$TASK_ID" "scores/$milestone"

# 2. 启动 mini-review codex（独立新进程，超时 10 分钟）
timeout 600 codex exec --skip-git-repo-check < references/milestone-review-prompt.md
# 输出 .agent/tasks/$TASK_ID/scores/$milestone.json
# prompt 里**反复强调** "score on 1-5 scale, do NOT rescale to 1-10"

# 3. score-diff.py vs baseline，按 GOAL.md mode 判定
MODE=$(grep -A1 "^mode:" $TASK_DIR/GOAL.md | head -1 | awk '{print $2}')
python3 references/score-diff.py \
  --baseline $TASK_DIR/BASELINE.md \
  --current  $TASK_DIR/scores/$milestone.json \
  --mode     "$MODE" \
  --no-improvement-history $TASK_DIR/scores/aggregate-trend.json

# 4. snapshot：分数创新高 → 立刻 git tag
CURRENT_AGG=$(jq -r .aggregate $TASK_DIR/scores/$milestone.json)
HIGHEST=$(cat $TASK_DIR/snapshots/HIGHEST_SCORE 2>/dev/null || echo 0)
if (( $(echo "$CURRENT_AGG > $HIGHEST" | bc -l) )); then
  git tag "snapshot-$milestone-${CURRENT_AGG}"
  echo "$CURRENT_AGG" > $TASK_DIR/snapshots/HIGHEST_SCORE
  echo "snapshot-$milestone-${CURRENT_AGG}" > $TASK_DIR/snapshots/HIGHEST_TAG
fi

# 5. 写 review-audit/round-N.jsonl（详见 references/review-audit-schema.md）
bash references/write-audit.sh "$TASK_ID" "$milestone" mini-review

# 6. UI 截图即时推 IM（如果 is_ui_task=true 且 CC_SESSION_KEY 非空）
if [[ -n "${CC_SESSION_KEY:-}" ]] && grep -q "is_ui_task: true" $TASK_DIR/GOAL.md; then
  IMGS=$(find $TASK_DIR/scores/$milestone/screenshots -name "*.png" | head -8)
  IMG_ARGS=""; for f in $IMGS; do IMG_ARGS="$IMG_ARGS --image $f"; done
  cc-connect send --message "[$TASK_ID] $milestone score=$CURRENT_AGG (Δ vs baseline)" $IMG_ARGS
  # 同时写入 pending-review-images.txt 让 orchestrator 后补校验
  echo "$milestone $IMGS" >> $TASK_DIR/pending-review-images.txt
fi
```

**UI 截图协议**（`is_ui_task: true` 时强制）：
- ✅ **即时发送**（不批发）
- ✅ **状态矩阵覆盖**（normal / duplicate / 边缘视口 / 滚动到底等，详见 `references/ui-review-checklist.md`）
- ✅ orchestrator 下次被人 ping 时**批量补校验**（view_image 看 pending-review-images.txt 中所有图，发现错位发"勘误"消息）
- ✅ 收尾发"历史最高分轮次"截图（不是最后一轮），明确说明"这是最终采用版本"

#### Step 1.4：orchestrator idle 模型

orchestrator 启动 watcher 后**进入 idle**。只有以下事件唤醒：

| 唤醒源 | 触发条件 | orchestrator 动作 |
|---|---|---|
| **人类 ping** | "现在咋样" / "我加个规则" / "暂停下" | 读 STATUS.md / scores/aggregate-trend.json / latest REVIEW.md，总结回复 |
| **final review 完成** | watcher touch `.agent/tasks/<id>/.review-pending` | 读 REVIEW.md，做仲裁判断（详见 Step 2.4），决定 commit / 退回 Goal / 终止 |
| **stop signal** | watcher touch `.agent/tasks/<id>/.stop-signal` | 读 STOPPED 原因，决定 abort 或 rescope |
| **human approve/reject IM** | 关键词触发 | 落 APPROVAL.md / 终止 |

**禁止**：
- orchestrator 周期 poll IM（这是 watcher 的活）
- orchestrator 自跑 mini-review（这是 watcher 的活）
- orchestrator 周期检查 git diff（这是 boundary-watch 的活）
- orchestrator idle 期间不允许并发跑其他任务（idle 不等于离线，得能秒响应人类）

---

### Phase 2：Final Review（独立 Reviewer Codex + 硬隔离）

#### Step 2.1：Goal 完成 → 生成 review-input

watcher 检测到 `done` 后：

```bash
cd "$WORKTREE"
TASK_DIR=".agent/tasks/$TASK_ID"
REVIEW_INPUT="$TASK_DIR/review-input"
mkdir -p "$REVIEW_INPUT/screenshots"

# 1. 静态证据
git diff main > "$REVIEW_INPUT/diff.patch"
git diff --stat main > "$REVIEW_INPUT/diff-stat.txt"
git status --short > "$REVIEW_INPUT/status.txt"

# 2. EVAL 命令输出
bash references/runtime-evidence.sh "$TASK_ID" review-input
```

#### Step 2.2：创建 review-readonly worktree（**两 Codex 硬隔离的核心**）

```bash
ROUND=$(($(ls $TASK_DIR/reviews/ 2>/dev/null | wc -l) + 1))
REVIEW_WORKTREE="../$(basename $PWD)-review-readonly-r$ROUND"

# 拉同一个 commit 到独立 worktree（reviewer 在这里跑，写入不污染 Goal worktree）
git worktree add "$REVIEW_WORKTREE" HEAD

# 物理屏蔽 implementer 自述
rm -f "$REVIEW_WORKTREE/$TASK_DIR/STATUS.md" \
      "$REVIEW_WORKTREE/$TASK_DIR/ISSUES.md"
rm -rf "$REVIEW_WORKTREE/$TASK_DIR/logs/"
# 也屏蔽历史 REVIEW（防止后续 round 锚定）
rm -rf "$REVIEW_WORKTREE/$TASK_DIR/reviews/"

# 把 review-input copy 进 readonly worktree
cp -r "$TASK_DIR/review-input" "$REVIEW_WORKTREE/$TASK_DIR/"
cp "$TASK_DIR/BASELINE.md" "$REVIEW_WORKTREE/$TASK_DIR/"
cp "$TASK_DIR/GOAL.md" "$REVIEW_WORKTREE/$TASK_DIR/"
cp "$TASK_DIR/EVAL.md" "$REVIEW_WORKTREE/$TASK_DIR/"
```

#### Step 2.3：启动 Reviewer Codex（**内置 + extra_reviewers 注册机制**）

**Reviewer 形态**：
- **内置 Reviewer Codex**（必跑）：现有的 codex exec + readonly worktree + env -i 硬隔离，做"代码 / 测试 / 合规 / 4 维 rubric"审计
- **Extra Reviewers**（可选注册）：通过 GOAL.md `extra_reviewers` 字段声明，与内置 Reviewer **并列启动**，做专项审计（如 `director-design` UI 视觉审）

详见 `references/reviewer-arbitration.md` 的注册机制 + 仲裁规则。

##### Step 2.3.1：启动内置 Reviewer Codex（与 v3 一致）



```bash
# 网络/凭据隔离：env -i 清空敏感变量
env -i \
  PATH="/usr/local/bin:/usr/bin:/bin" \
  HOME="$HOME" \
  NODE_ENV="test" \
  TASK_ID="$TASK_ID" \
  codex exec --skip-git-repo-check --cd "$REVIEW_WORKTREE" < references/review-prompt.md \
  > "$TASK_DIR/reviews/round-$ROUND/codex.log" 2>&1 &

REVIEWER_PID=$!
echo $REVIEWER_PID > "$TASK_DIR/reviews/round-$ROUND/reviewer.pid"

# **进程隔离硬验证**
GOAL_PID=$(cat "$TASK_DIR/codex.pid" 2>/dev/null || echo 0)
[[ "$REVIEWER_PID" != "$GOAL_PID" ]] || { echo "ABORT: reviewer pid == goal pid"; exit 1; }
ORCHESTRATOR_PID="${PPID}"
[[ "$REVIEWER_PID" != "$ORCHESTRATOR_PID" ]] || { echo "ABORT: reviewer pid == orchestrator pid"; exit 1; }

wait $REVIEWER_PID

# Reviewer 输出 REVIEW.md 到 readonly worktree，watcher copy 回 Goal worktree
cp "$REVIEW_WORKTREE/$TASK_DIR/review-output/REVIEW.md" \
   "$TASK_DIR/reviews/round-$ROUND/REVIEW.md"

# 销毁 review-readonly worktree（防止下次 round 看到上次结果）
git worktree remove --force "$REVIEW_WORKTREE"
```

**硬隔离三重**：
1. **进程隔离**：reviewer pid ≠ goal pid ≠ orchestrator pid（启动后立刻校验 + 写 audit）
2. **会话隔离**：必须 `codex exec`，**禁止** `codex resume` / 传 thread_id；跑完销毁 codex session 缓存
3. **文件系统隔离**：reviewer 工作在独立 readonly worktree，物理上不包含 STATUS.md / ISSUES.md / logs/ / 历史 reviews/
4. **网络/凭据隔离**：`env -i` 清空 keychain / CF_API_TOKEN / GITHUB_TOKEN 等敏感变量

##### Step 2.3.2：并列启动 Extra Reviewers（如果 GOAL.md 有声明）

watcher 解析 GOAL.md `extra_reviewers` 段，对每个声明的 reviewer **并列派 subagent**：

```bash
# 伪代码：launch_extra_reviewers
for reviewer_name in $(yq '.extra_reviewers[]' "$TASK_DIR/GOAL.md"); do
  # 派 subagent 显式调用 director-* skill
  bash "$SCRIPT_DIR/launch-extra-reviewer.sh" "$TASK_ID" "$ROUND" "$reviewer_name" &
  EXTRA_PIDS+=($!)
done

# 等所有 extra reviewer 返回（collect-all，单路失败不阻塞）
wait "${EXTRA_PIDS[@]}"
```

每个 extra reviewer 输出独立报告：
- `reviews/round-$ROUND/REVIEW.md`（内置 Reviewer Codex）
- `reviews/round-$ROUND/extras/<reviewer-name>.md`（如 `extras/director-design.md`）

**派工 prompt 模板**（每个 extra reviewer，遵循 `references/parallelization-template.md` 显式调用 skill 硬规则）：

```
Slot: extra-reviewer-<name>
Task: 作为 <reviewer-name> 对当前 Goal 完成状态做专项审计

必须显式调用的 skill:
  - <reviewer-name>（如 director-design，subagent 默认不会主动用）

输入（只读）:
  - GOAL.md / EVAL.md / BASELINE.md / review-input/
  - 当前 round: <N>
  - **本 reviewer 负责的检查维度**: <从 GOAL.md extra_reviewers[name].checks 注入>
    —— 只在这些维度上打分，不评其他维度（其他维度由别的 reviewer 负责）

输出: 写到 .agent/tasks/<TASK_ID>/reviews/round-<N>/extras/<reviewer-name>.md
返回 JSON: {reviewer_name, verdict, aggregate, checked_dimensions, must_fix, should_fix, errors}

约束:
  - 只审被认领的 checks 维度，不越界评别人的维度
  - 不读 STATUS.md / ISSUES.md / logs/（与内置 Reviewer Codex 相同隔离原则）
  - 不修改任何代码
  - 必须按自己 skill 的 Output Contract 出报告
```

watcher 派工时把该 reviewer 在 GOAL.md `extra_reviewers[].checks` 里声明的维度注入 prompt 的
"负责的检查维度"段。内置 Reviewer Codex 同理——按 `REVIEWER-PLAN.md` 里它的 checks 行注入 review-prompt。

详细注册 schema + 派工脚本见 `references/reviewer-arbitration.md`。

#### Step 2.4：处理 verdict + 多 reviewer 仲裁 + snapshot + 最高分回退

watcher touch `.review-pending` → orchestrator 唤醒，读 REVIEW.md：

```python
# 伪代码：orchestrator 仲裁逻辑
review = read("reviews/round-N/REVIEW.md")
goal = read("GOAL.md")

if review.verdict == "fail":
    arbitration = []
    for must_fix in review.must_fix:
        # 关键仲裁规则：黑名单优先级 > reviewer Must Fix
        if must_fix.file in goal.non_goals:
            arbitration.append({
                "must_fix_idx": must_fix.idx,
                "decision": "overridden",
                "reason": f"file in GOAL.md Non-goals: {must_fix.file}"
            })
        else:
            arbitration.append({"must_fix_idx": must_fix.idx, "decision": "accepted"})

    # 写 review-audit/round-N.jsonl 含完整仲裁记录
    write_audit(round=N, review=review, arbitration=arbitration)

    if all(a.decision == "overridden" for a in arbitration):
        # reviewer 提的 Must Fix 全在黑名单 → 视同 pass，进 Phase 3
        proceed_to_phase_3()
    else:
        # 把 accepted Must Fix 写回 STATUS.md "Next Action"
        # 退回 Goal Codex 修，回 Step 1.1
        retry()

elif review.verdict == "pass":
    # snapshot：分数创新高才打 tag
    if review.aggregate > read_highest_score():
        git_tag(f"snapshot-final-r{N}-{review.aggregate}")
    write_audit(round=N, review=review, arbitration=[])
    proceed_to_phase_3()

# 连续 N 轮（默认 3）不涨分 → 强制回退到最高分 snapshot
if no_improvement_count() >= 3:
    highest_tag = read_highest_tag()
    notify_human(f"3 轮不涨分，最高分在 {highest_tag}，回退？")
    if human_approves():
        git_checkout(highest_tag)
        proceed_to_phase_3()
```

**关键规则**：
- **黑名单优先 reviewer Must Fix**：reviewer 要拆 `Non-goals` 文件 → orchestrator 拒，写 audit
- **3 轮 review fail 上限**：超出 → 强制终止 Goal Codex + alert
- **3 轮不涨分**：回到历史最高分 snapshot tag（不是最后一轮）
- **PASS 但低于最高分**：不自动回滚，但保留快照让人类选
- **多 reviewer 仲裁**：默认 **AND-pass**（所有 reviewer 都 pass 才整体 pass），详见 `references/reviewer-arbitration.md`

**多 reviewer 仲裁伪代码**（替代上面的单 reviewer 逻辑）：

```python
codex_review = read("reviews/round-N/REVIEW.md")
extra_reviews = [read(f"reviews/round-N/extras/{r}.md")
                 for r in read_extra_reviewers_from_goal()]
all_reviews = [codex_review] + extra_reviews

# 1. 仲裁规则（默认 AND-pass）
arbitration_rule = read_goal_field("arbitration_rule") or "AND-pass"

# 2. 黑名单仲裁（与现有一致，对每个 reviewer 的 must_fix 都过滤）
for review in all_reviews:
    for must_fix in review.must_fix:
        if must_fix.file in goal.non_goals:
            mark_overridden(review, must_fix, reason="non-goals")

# 3. 合并 verdict
overall_verdict = apply_arbitration(all_reviews, rule=arbitration_rule)
# AND-pass: 所有 reviewer 都 pass（含 override 后视同 pass）→ pass
# 任一 fail → retry（把所有 reviewer 的 must_fix 合并写回 STATUS.md）

# 4. snapshot 用几何平均（强调"两边都好"，避免一边极高一边极低也通过）
overall_aggregate = geometric_mean([r.aggregate for r in all_reviews if r.aggregate])

# 5. 写 audit 含所有 reviewer
write_audit(round=N, all_reviews=all_reviews, arbitration=...)
```

---

### Phase 3：Delivery

#### Step 3.1：风险分层验证（**按 risk_class 分级，不再硬性强制 orchestrator 自跑**）

| risk_class | orchestrator 必须自跑验证？ | 说明 |
|---|---|---|
| `low`（纯重构 / typo / 文档）| ❌ 信 reviewer | 节省时间 |
| `medium`（业务逻辑 / 新功能） | ✅ 跑 EVAL.md 部分关键命令 | 抽查 |
| `high`（auth / 支付 / 加密 / 生产部署） | ✅ 全套 EVAL + 真实环境复验 | 必复验 |

risk_class 在 Step 0.1 Step 4 由 orchestrator 推断 + 人类确认，写入 GOAL.md。

#### Step 3.2：人类签字

通过 cc-connect 发送：
- REVIEW.md 全文（最后一轮 + 最高分轮的对比）
- diff-stat
- baseline → 最高分 snapshot 的评分对比表
- **最高分轮次的关键截图**（明确"这是最终采用版本"）
- 询问："commit & push <最高分 snapshot>? hold? rollback?"

人类回复 `commit` 才进 Step 3.3。

#### Step 3.3：commit + push（基于最高分 snapshot 不是 HEAD）

```bash
HIGHEST_TAG=$(cat "$TASK_DIR/snapshots/HIGHEST_TAG")
git checkout "$HIGHEST_TAG"

# 调用 clean-commit
# message 模板：feat(X): <objective> (Codex Goal: <N> rounds, <M> review failures, score Δ +<X>, snapshot=$HIGHEST_TAG)
```

如果是 IM 会话，clean-commit 自动 push（CC_SESSION_KEY 非空）。

#### Step 3.4：清理

- 关闭 watcher 进程
- 关闭 Codex 进程
- 销毁所有 review-readonly worktree（如果还有遗留）
- 可选：清理 snapshot-* tag（保留最高分 tag 一周后清理）
- worktree 保留（人类决定 merge/rebase/cleanup）
- 输出最终报告（Output Contract）

---

## Two-Codex Hard Isolation（两 Codex 硬隔离 — 重点）

本 skill 的**生命线**。Goal Codex（实施者）和 Reviewer Codex（裁判）必须满足以下**全部**约束，少一项就退化为"自我评估"：

### 进程隔离
- Reviewer 启动后立刻校验：`reviewer_pid != goal_pid && reviewer_pid != orchestrator_pid`
- 校验失败 → 立刻 abort，写 alert 到 STATUS.md
- pid 写入 `reviews/round-N/reviewer.pid` 留证据

### 会话隔离
- ✅ 必须 `codex exec` 单次任务调用
- ❌ **禁止** `codex resume`
- ❌ **禁止**传 `--thread-id` / `--session-id` 复用 Goal 的 session
- 跑完销毁 reviewer codex session 缓存（`~/.codex/sessions/<thread>` 关联文件）

### 文件系统隔离
- Reviewer 工作在**独立 readonly worktree**（`git worktree add HEAD`，每轮独立创建）
- readonly worktree **物理不包含**：`STATUS.md` / `ISSUES.md` / `logs/` / 历史 `reviews/round-*/`
- Reviewer 输出到 readonly worktree 的 `review-output/REVIEW.md`，watcher 才 copy 回 Goal worktree
- 跑完立刻销毁 readonly worktree

### 网络/凭据隔离
- 启动 reviewer 必须 `env -i`，只保留：`PATH` / `HOME` / `NODE_ENV` / `TASK_ID`
- **不传** `KEYCHAIN_*` / `CF_API_TOKEN` / `GITHUB_TOKEN` / `OPENAI_API_KEY`（reviewer 用 codex 内置 auth）
- Reviewer 不应 push / deploy / 调用外部 API（这些是 orchestrator 的事）

### 信息隔离强化
review-prompt.md 已写禁读名单。**额外强化**：
- 不读 STATUS.md / ISSUES.md / logs/（物理屏蔽 + prompt 强调）
- 不读历史 REVIEW.md（防止后续轮锚定）
- 不读 `Next Action` 段（这是 Goal 修复指引，不是给 reviewer 看的）
- 不接受 "implementer says" / "as discussed" / "the agent did X" 等污染语
- mini-review prompt 反复强调 "score on 1-5 scale, do NOT rescale to 1-10"

### 审计留证
每次 review 启动 + 完成都写 `review-audit/round-N.jsonl`：
```json
{
  "round": N, "ts": "...",
  "reviewer_pid": 12345, "reviewer_thread_id": "...",
  "reviewer_launch_cmd": "codex exec --cd /path/review-readonly-rN",
  "reviewer_worktree_sha": "<commit>",
  "goal_md_sha": "<file content sha>",
  "verdict": "fail|pass",
  "scores": {...},
  "must_fix": [...], "should_fix": [...],
  "new_rules_proposed": [...],
  "orchestrator_arbitration": {
    "must_fix_accepted": [0, 2],
    "must_fix_overridden": [1],
    "override_reasons": ["sanitize.ts in GOAL.md Non-goals"]
  }
}
```

---

## Orchestrator Idle Model（orchestrator 空闲模型 — 重点）

**核心原则**：orchestrator 是人类的副驾，不是流水线执行者。Phase 1/2 期间应该 95% 时间 idle，watcher 接管所有自动化。

### orchestrator 只在 4 个时刻被唤醒

1. **Phase 0 契约门**（一次性）
2. **人类主动 ping**（IM "现在咋样" / "加规则" / "暂停"）
3. **watcher 信号**（`.review-pending` / `.stop-signal` / `.boundary-violation`）
4. **stop condition 触发**（自检 STATUS.md 含 STOPPED）

### orchestrator 被唤醒时的标准动作

| 唤醒事件 | 标准动作 |
|---|---|
| 人类 ping "现在咋样" | 读 STATUS.md / scores/aggregate-trend.json / 最近 milestone score → 一句话总结 |
| 人类 ping "加规则 X" | 把 X 抽象成评分维度，追加到 EVAL.md `Reviewer Rubric` 段，写入 `.agent/tasks/<id>/Human Feedback`，让 Goal 下个 milestone 读到 |
| 人类 ping "暂停" | 写 `STOPPED: human-paused` 到 STATUS.md（watcher 下个循环看到自停） |
| `.review-pending` | 读 REVIEW.md → 仲裁（黑名单优先 / Must Fix 拆解 / snapshot 检查）→ 决定 commit / 退回 / 终止 |
| `.stop-signal` | 读 STOPPED 原因 → 决定 abort 或 rescope |
| `.boundary-violation` | 立刻 hard kill codex + alert 人类 |

### orchestrator **禁止**

- 周期 poll IM（这是 watcher 的活，详见 watcher.sh inbox-poll 段）
- 周期跑 mini-review（这是 watcher 的活）
- 周期跑 git diff（这是 boundary-watch 的活）
- idle 期间并发跑其他任务（必须能秒响应人类 ping）

### "watcher 不可用" 的兜底（SUBAGENT 模式）

SUBAGENT 模式下 orchestrator 无法持有后台 watcher 进程。此时 orchestrator **被迫兼任 watcher**：
- 派完一个 Phase 的 codex-rescue 后立刻 git diff --stat 自检
- 区分 "subagent 真完成" vs "agent 转发后台但实际 idle 退出"（Claude 经验文档第 1 条教训）
- 必须主动跑 mini-review codex-rescue（不能省）
- 必须主动写 review-audit / snapshot
- IM 推送由 orchestrator 自己发

但**仍然不破坏**两 Codex 硬隔离原则——subagent 也是新进程，启动方式仍走 `codex exec` + readonly worktree。

---

## Decision Rules（硬写死）

### Pre-flight Failure Modes

| 检查失败 | 退出动作 |
|---|---|
| Codex 版本 < 0.128.0 | 提示升级，退回 flow-dev-task |
| feature flag 没开 | 自动写入 config.toml 然后继续 |
| git status 不干净 | 让用户先 commit 或 stash |
| 当前在 main/master/dev | 强制创建 worktree |
| 无 acceptance commands | 警告 + 让用户写 EVAL.md 时手填 |
| run_mode 探测失败 | 退回 flow-dev-task |

### Stop Conditions（硬约束）

任一命中立即停 Goal Codex 并 notify 人类：

- 连续 3 次 verification fail
- Review 连续 2 次 fail
- 文件改动数 > GOAL.md `Budget` 上限
- token 估算超 GOAL.md `Budget` 上限
- 健康检查 stalled 状态连续 3 次
- 需要破坏性 git 操作
- **boundary-watch 检测到 worktree 外文件被改 / 主分支被切 / git remote 被改**（hard kill）
- 需要修改 auth / 支付 / 加密代码
- 任一 milestone 评分 < baseline（regression-prevention 模式）
- 连续 N 个 milestone 评分不上升（no-improvement-N 模式）
- 人类 IM 回复 `pause` 或 `abort`
- **APPROVAL.md 被人类删除**（人类反悔）

### Snapshot + 最高分回退规则

- 每轮 review PASS 且分数创新高 → watcher 自动 `git tag snapshot-<round>-<aggregate>`
- 写 `snapshots/HIGHEST_SCORE` + `HIGHEST_TAG` 跟踪
- PASS 但低于历史最高分 → 不自动回滚，仅累计 no-improvement 计数
- 连续 3 轮不涨分 → orchestrator 提示人类回退到 HIGHEST_TAG
- 最终 commit 默认走 HIGHEST_TAG 不是 HEAD

### 同分硬规则裁决（来自 Codex UI 经验文档）

同分时按 GOAL.md `STOP-CONDITIONS.md` 中"硬规则风险"段判定：
- 有遮挡控件 / 数量承诺不一致 / 状态混淆等硬规则风险的版本，即使分数相同也不优先采用
- 如果同分版本因更符合规则被选为新基准，no-improvement 从该基准重新计算

### 风险分层验证

详见 Step 3.1 表。

---

## Output Contract

完成后必须输出：

```md
## Codex Goal Task Report

### Task
- ID:
- Objective:
- Worktree path:
- Run Mode: CLI-YOLO | TMUX-YOLO | CLI-EXEC | SUBAGENT
- Risk Class: low | medium | high
- Goal-Attainment Mode: threshold | no-improvement-N | regression-prevention | hybrid
- Custom Score Dimensions: <list>

### Phase 0 Contract
- APPROVAL.md timestamp:
- Approver:
- BASELINE.md reviewer pid: <verified ≠ orchestrator>

### Baseline (pre-task scoring)
- Correctness: N/5  Maintainability: N/5  UX: N/5 (or n/a)  Risk: N/5
- Custom dimensions: <list of N/5>
- Aggregate: X.X

### Execution
- Goal Codex started: <ts>  completed: <ts>  duration:
- Milestones completed: <n>
- Snapshots created: <n>  HIGHEST_TAG: snapshot-X-Y.Y
- Token budget used: <est>
- Health stalls / failures: <n> / <n>
- Boundary violations: <n>
- IM milestone reports pushed: <n>
- Human interrupts received: <n> (continue/pause/abort/adjust)

### Score Trajectory
- baseline → milestone-1 → ... → final
- HIGHEST: round X, aggregate Y.Y
- 每个 milestone 4 维度 + 扩展维度评分

### Review
- Reviewer rounds: <n>  Final verdict (combined): pass | fail | aborted
- Arbitration rule: AND-pass | OR-pass | weighted-avg | hard-rule-override
- **Reviewer roster**:
  - codex-reviewer (内置): <verdict / aggregate>
  - <extra-reviewer-1> (如 director-design): <verdict / aggregate> | not invoked
  - <extra-reviewer-2>: ... | not invoked
- Overall aggregate (geometric mean): <X.X>
- Two-Codex Isolation verified: yes (process/session/fs/net all 4 layers)
- Review audit log: review-audit/round-*.jsonl (N rounds, M overrides)
- Must Fix accepted / overridden (按 reviewer 区分): <a> / <b>
- Should Fix recorded: <c>
- Runtime evidence verified: <list of user-journeys passed>

### UI Screenshots (only if is_ui_task=true)
- IM messages pushed: <n>  pending review-image audits: <n>  errata sent: <n>
- HIGHEST_TAG screenshots: <list of paths>

### Delivery
- Risk-tiered orchestrator self-verification: skipped (low) | partial (medium) | full (high)
- Commit SHA: (based on HIGHEST_TAG <tag>)
- Push status: pushed | committed | skipped | n/a
- Worktree fate: kept | merged | rebased | cleaned

### Risks / 技术债
- <项>: <说明>

### 结论
- 可交付: yes | no
- 需要人类后续: <list>
```

---

## Red Flags — STOP

任一命中必须停下：

- 在主分支裸跑 `/goal` 没开 worktree
- **APPROVAL.md 不存在**就启动 Goal Codex（Phase 0 没签字）
- **BASELINE.md 由 orchestrator 自己当 reviewer**（reviewer_pid == orchestrator_pid）
- **Reviewer Codex 复用 Goal Codex 的 session/thread**（reviewer_pid == goal_pid）
- **Reviewer 工作在 Goal worktree**（不是独立 readonly worktree）
- **Reviewer 能读到 STATUS.md / 历史 REVIEW.md**（隔离失效）
- **Reviewer 启动时未 `env -i`**（凭据泄漏到 reviewer）
- Reviewer prompt 含实施者解释 / 历史评分 / 上一轮失败原因
- Goal Codex 报"完成"但 STATUS.md 没写 `GOAL_DONE`
- watcher 没启动就让 Goal 跑（CLI-YOLO / TMUX-YOLO / CLI-EXEC 模式）
- review verdict pass 但 risk_class=high 时 orchestrator 没自跑验证
- 修改文件超 GOAL.md Budget 但继续推进
- token 用量接近 budget 但不停
- Goal Codex 修改了 SPEC 范围外文件 / boundary-watch 命中
- 把 Codex 修改全部 `git add .` 而不是选择性 staging
- 跳过 Step 0.1（未确认 AC / mode / budget / 自定义维度 / **Reviewer Plan**）就启动 Goal
- **Reviewer Plan 未经用户确认就启动 Goal**（reviewer 阵容 + 各自检查维度是 Phase 0 合同的一部分）
- **EVAL.md 有维度无任何 reviewer 的 `checks` 认领**（漏审维度，必须补 reviewer 或重分配）
- **IM 会话下 Reviewer Plan 没发回来源通道**（飞书等发起的 goal，确认表必须发回该通道）
- 跳过 Step 0.3 baseline scoring 就启动 Goal
- 跳过运行时证据收集就裁决 verdict
- IM 会话下跳过 milestone 推送 / UI 任务不发截图
- 检测到分数低于 baseline 但继续推进（regression-prevention 模式下）
- **3 轮不涨分但 commit 最后一轮**（必须回到 HIGHEST_TAG）
- **mini-review 把 1-5 改成 1-10**（脚本拒绝接受这种 score）
- **截图文件名 ≠ 内容**但 orchestrator 没 view_image 校验就发出去（UI 任务下）
- **同分时选了有硬规则风险的版本**（必须按 STOP-CONDITIONS.md 硬规则段裁决）

---

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "Goal 跑得挺顺，跳过 review 直接 commit 吧" | review 是本 skill 的 50% 价值，跳了就退化成裸 /goal |
| "Reviewer 也是 Codex，让它复用 thread 省 token" | 复用 = 污染独立性 = review 失效 |
| "Reviewer 跟 Goal 在同一 worktree 也能跑" | 文件系统不隔离 = reviewer 能瞥见 STATUS / logs，自我评估又回来了 |
| "watcher 太啰嗦，先不跑了" | 没 watcher = goal silent pause + 烧 quota + 错过人类反馈 |
| "Goal 说完成了，STATUS.md 应该也写了吧" | 必须 grep `GOAL_DONE` 确认 |
| "改的就是 main 分支文件，不开 worktree 也行" | --yolo + main + 长跑 = 灾难 |
| "Verdict pass 应该没问题，不用再跑测试" | 高风险任务必须自跑，低风险才能信 reviewer |
| "Stalled 3 次了，再等等可能就好了" | 硬阈值，必须 notify 人类 |
| "AC 已经在 prompt 里了，不用再确认了" | 用户口语化 AC 多半模糊，必须 Phase 0 量化 + APPROVAL 签字 |
| "Baseline scoring 太花时间，我自己当代理打个分吧" | 你当 reviewer = 后续 mini-review 评分基准漂移 = 退化检测失效 |
| "Reviewer 看 diff 就够了，不用真跑" | 编译过 ≠ 跑得起来 ≠ 用户旅程能走通 |
| "milestone 推送太烦人，等 Goal 完成再发结果就行" | 人类校准窗口在中间，结尾发就晚了 |
| "分数稍微低于 baseline 没关系，整体在涨" | regression-prevention 模式下任一维度低就停 |
| "最后一轮没创新高，但是 reviewer pass 了，commit 最后一轮吧" | 必须回到 HIGHEST_TAG，最终交付的是历史最高分 |
| "reviewer 要拆 sanitize.ts，那就拆吧" | 黑名单优先 reviewer Must Fix，必须仲裁拒绝 |
| "UI 截图 Goal Codex 截过了，reviewer 不用再截" | reviewer 必须自己截，可能 Goal 截的是好看但不工作的状态 |
| "subagent 跑过测试就够了，我不用复验" | risk_class=high 必须复验；risk_class=low 才允许跳 |

---

## Codex Delegation Hook

本 skill **本身就是 Codex 派工的特例**——把整个长任务派给 Codex Goal。

ROI 判断：

| 场景 | ROI |
|---|---|
| 任务 ≥ 2 小时 + 清晰验收 | 🟢 高 |
| 任务 < 2 小时 | 🔴 低（启动 worktree + watcher 开销 > 节省）|
| 任务无清晰验收 | 🔴 负（goal 跑飞烧 quota）|
| 任务高风险（auth/支付）| 🔴 负 |
| UI 循环改造（迭代式）| 🟢 高（snapshot + 同分硬规则正是为此设计）|

派工细则细节以本 skill 为准，不引用 `flow-dev-task` 的 Codex Delegation Hook。

---

## Relationship to Other Skills

### Upstream Handoff Payload（来自 flow-dev-task）

**字段规范遵循 `references/handoff-payload-template.md`**（所有 flow-* skill 共享同一套字段集）。

`flow-dev-task` Stage 5 判定"任务过长"切到本 skill 时，**必须**透传以下字段：

| 字段 | 必填 | 说明 |
|---|---|---|
| `objective` | ✅ | 一句话任务目标 |
| `suggested_scope` | ✅ | 已识别的 scope 白名单 |
| `suggested_non_goals` | 推荐 | 明确不动的范围（黑名单） |
| `acceptance_hints` | 推荐 | 用户口语化 AC，Step 0.1 量化时用 |
| `time_budget_hours` | 推荐 | 用户暗示的时间预算 |
| `risk_class` | ✅ | low / medium / high（high 直接拒绝接手）|
| `is_ui_task` | ✅ | bool；true 时激活 UI 截图协议 + 状态走查 + 同分硬规则 |
| `attainment_mode_hint` | 可选 | 已推断的 mode |
| `prior_context` | 可选 | git/branch/diff 状态 |

如果上游已传 `attainment_mode_hint` + `acceptance_hints` + `time_budget_hours` + `is_ui_task`，Step 0.1 直接使用，不再问人类（除非 hints 含模糊量词）。

### 上下游列表

- **上游**: 用户直接触发 / `flow-dev-task` Stage 5 判定"任务过长"时 handoff
- **下游（调用）**:
  - `clean-commit`（Step 3.3 commit，基于 HIGHEST_TAG）
  - chrome MCP / `playwright` / `agent-browser`（runtime-evidence.sh / mini-review / final review 截图）
  - cc-connect（IM milestone push + 人类裁决 + UI 截图发送 + inbox poll）
- **不下游**:
  - `superpowers:test-driven-development`（Codex 内部按 EVAL.md 走）
  - `superpowers:verification-before-completion`（替换为本 skill 的 baseline + milestone + final review pipeline）

---

## Reuse

测试用例保留在 `tests/cases.md`。
所有模板和脚本在 `references/`，可被任何 orchestrator agent + Goal Codex + Reviewer Codex 直接读取使用。

`references/` 目录结构：
- `run-mode.sh` / `run-mode.md` — 三种运行模式探测脚本 + 说明
- `codex-goal-setup.md` — pre-flight 脚本
- `goal-template.md` — GOAL.md 模板（含 is_ui_task / risk_class / 扩展维度段）
- `plan-template.md` — PLAN.md 模板
- `eval-template.md` — EVAL.md 模板（含基础 4 维 + 扩展维度）
- `stop-conditions.md` — 停止条件清单（独立成文件）
- `goal-prompt.md` — Goal Codex 启动 prompt
- `baseline-prompt.md` — Baseline 评分 Reviewer prompt
- `milestone-review-prompt.md` — Milestone 轻量评分 Reviewer prompt
- `review-prompt.md` — Final Reviewer prompt（含运行时验证 + 硬隔离要求）
- `runtime-evidence.sh` — 启动项目 + 跑用户旅程 + 截图
- `score-diff.py` — baseline vs current 评分对比 + 退化判定
- `health-check.sh` — 6 维度健康检查（已修 SIGPIPE bug）
- `boundary-watch.sh` — worktree 边界守卫
- `snapshot.sh` — 分数创新高时打 snapshot tag
- `write-audit.sh` — 写 review-audit/round-N.jsonl
- `watcher.sh` — 看门狗主进程（health + boundary + inbox-poll + milestone 触发）
- `review-audit-schema.md` — 审计日志 JSONL schema
- `ui-review-checklist.md` — UI 任务的状态走查 / 截图三件套 / 同分硬规则
- `score-rubric-extensions.md` — 扩展评分维度库（Layout Stability / Small Popup Density 等）
