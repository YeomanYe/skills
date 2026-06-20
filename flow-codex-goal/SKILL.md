---
name: flow-codex-goal
description: >
  [explicit-only · 显式点名才触发,无自动路由] 无人值守长跑 Codex:契约门(人类签字)+ 硬隔离 Reviewer Codex + 每轮 snapshot + 最高分回退 + UI 证据推 IM + idle orchestrator(人类随时打断)。
  本 skill 是完整工作流入口,但**不自动触发**——只在用户显式点名("用 codex-goal"/"用 flow-codex-goal"/"无人值守长跑")时进入。**不要根据场景关键词自动触发。**
type: workflow
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)
> 本 skill 对齐 `../_shared/flow-template.md`(flow-* 元规范)。**Executor Selection 例外**:本 skill 是 Codex 重委派的承载者/元方法,不适用通用执行者选择判断(`references/executor-selection-template.md` § 5 "例外 skill:flow-codex-goal" 明示)。

# flow-codex-goal

## TL;DR for Orchestrators（30 秒上手）

> 第一次读本 skill？先读这段，再按需 deep-dive 后面 1000+ 行的细则。

**做什么**：把一个长任务派给 Codex `/goal` 跑，加一套"硬隔离 reviewer + snapshot 回滚
+ 人类校准窗口"挡住它跑飞。

**5 个必读 phase**（按顺序）：

| # | 段 | 一句话 |
|---|---|---|
| 1 | **Phase 0 契约门** | APPROVAL.md 不签字不开跑，**80% 价值的来源** |
| 2 | **Run Mode 探测** | CLI-YOLO / TMUX-YOLO / CLI-EXEC / SUBAGENT 四选一，Phase 0 必须先定 |
| 3 | **Phase 1 执行 + watcher** | watcher 周期 poll，你 idle 等唤醒 |
| 4 | **Phase 2 final review** | 独立 Reviewer Codex 必须硬隔离（不复用 Goal session / worktree / 凭据）|
| 5 | **Phase 3 delivery** | 最高分 snapshot 回退 + commit |

**3 个最常翻的车**（详见 Red Flags）：

- Phase 0 跳了 → 跑完用户不认账
- Reviewer 跟 Goal 同 worktree / 同 session → review 失效，等于裸 `/goal`
- 3 轮不涨分但 commit 最后一轮 → 必须回 `HIGHEST_TAG`

**3 件 orchestrator 不该做的事**（详见执行原则）：

- 替 Goal 想问题 / 替 Reviewer 解释 / 觉得自己比 watcher 准

**调用方不一定是 Claude**：本 skill 支持 Claude / Codex / Gemini / 任何能调用 Bash 的
orchestrator agent。Claude 专属机制（cc-connect IM 推送、Agent SUBAGENT 模式）会自动
降级为"orchestrator 主动 poll"，详见 `references/run-mode.md`。

**References 路由表**（按需深读）：

| 想知道什么 | 读 |
|---|---|
| 这次跑哪种 mode | `references/run-mode.md` + `run-mode.sh` |
| watcher 怎么工作的 | `references/watcher.sh` + 本文 Watcher Exit Code 段 |
| Reviewer 怎么独立隔离 | 本文 Two-Codex Hard Isolation 段 + `references/reviewer-arbitration.md` |
| Phase 0 契约长什么样 | `references/goal-template.md` + `references/eval-template.md` |
| Reviewer prompt | `references/baseline-prompt.md` / `milestone-review-prompt.md` / `review-prompt.md` |
| 历史踩坑案例 | `references/incident-log.md` |
| UI 任务专属规则 | `references/ui-review-checklist.md` + `score-rubric-extensions.md` |
| 出问题手动 rerun | `references/manual-rerun-prompts.md` |

---

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

### 执行原则

**orchestrator 是流水线的看门人，不是执行者；不得代替 Goal Codex 处理问题，不得代替 Reviewer 评分，不得代替用户决定 verdict。**

**长任务最容易死在"orchestrator 自己也开始动手"**——一旦 orchestrator 替 Goal 想问题 /
替 Reviewer 评分 / 替用户决定 verdict，**硬隔离机制立刻坍缩**。orchestrator 多醒 1 次 =
长任务多 1 个污染点。

执行前必须问一个问题：**"如果 orchestrator 现在 sleep 8 小时回来，pipeline 能不能自己跑完、
自己停在该停的地方、自己 ping 回来？"** 不能 = pipeline 设计有误，应先修复再启动。**idle 是美德**。

非 Claude orchestrator（Codex / Gemini / 任何能调用 Bash 的 agent）调用时，
IM 推送 / Agent 工具等 Claude 专属机制自动降级为"orchestrator 主动 poll"，
仍然 idle 优先。降级映射见 `references/run-mode.md`。

最容易翻的 5 个车（"看起来在帮忙，实际在破坏隔离"）：

- **替 Goal Codex 想问题** → 上下文偷喂 = baseline 之后评分不可比。让 watcher 处理。
- **替 Reviewer 解释 Goal 的意图** → 隔离失效。reviewer 评错就重派，不要"帮它理解"。
- **跳 Phase 0 直接启动** → 没 APPROVAL.md = 3 小时后用户问跑的什么答不上。
- **觉得自己比 watcher 准** → boundary 误报就修 watcher，不要在 orchestrator 加豁免。
- **越界做高风险代码** → auth / 支付 / 加密必须由 orchestrator agent 自写，不得派 Codex。
  constitution 级硬约束，与"用户明确指定"无关。

### Codex `/goal` 的硬限制 + 本 skill 的兜底

Codex `/goal` 是 Codex CLI 0.128.0+ 的实验功能（feature flag `goals = true`），让一个 Codex 围绕目标持续执行，但有 5 个硬限制必须靠本 skill 兜底：

| Codex 自身限制 | 本 skill 的兜底 |
|---|---|
| 没有自动循环 | watcher.sh 周期 poll + 触发 continuation |
| 没有花销上限 | GOAL.md Budget + score-diff 退化检测 + watcher 强停 |
| 完成检测不可靠 | health-check.sh 6 维度判定 + STATUS.md `GOAL_DONE` 信号 |
| 没有评分基线 | Step 0.3 强制独立 baseline scoring |
| 自报常失真（"完成"实际未跑、文件数虚报、截图错位）| watcher 跨证据交叉校验 + reviewer 独立运行时验证 |

## 用户判断权优先（任务大小的最终决定权在用户）

**"任务该不该用 codex-goal 跑"是"该不该做"层面的决定，属于用户**——本 skill 的
"≥ 2 小时"门槛只是 **agent 自动路由时的建议信号**，不是准入门禁。对齐
`constitution.md` 第 1 条：agent 只判断"怎么做"，不替用户判断"该不该"。

两种入口区别对待：

| 入口 | 任务大小的处理 |
|---|---|
| **agent 自动路由**（agent 自己判断该不该用本 skill） | "≥ 2 小时"作为建议信号——短任务时 agent **倾向建议** `flow-dev-task` |
| **用户明确指定**（原话含"用 codex-goal"/"用 goal 模式跑"/"让 codex 后台跑"等） | **用户判断权优先**。agent 可以**一次性诚实告知**代价，但**告知后不得再阻止**，按用户意愿进入流程 |

**用户明确指定短任务时的一次性告知 gate**（必做一次，且仅一次）：
- 启动 worktree + watcher + baseline/final reviewer 的固定开销，对 < 2h 的任务可能 > 节省
- 若任务是**图片 / 视觉 / 文案等主观评分类**：Codex 的评分能力不比 Claude 强，"刷到高分"
  不代表真达标——主观分由 reviewer 给，不是客观验证
- 告知后**不再重复劝阻**，不反复要求用户改用 flow-dev-task；用户坚持即进入 Phase 0

**禁止**：用户已明确指定 codex-goal，agent 仍以"任务太短"为由拒绝进入或反复劝退。

## When to Use

**建议条件**（agent 自动路由时参考；用户明确指定时第 2 条不作硬性要求）：

- 任务边界清晰，可拆步骤，有可验证的 acceptance criteria
- 预估执行时间 ≥ 2 小时 —— *建议信号，非准入门禁；用户明确指定时不受此限*
- 用户希望"无人值守长跑"或"后台跑"
- Codex CLI ≥ 0.128.0 且已启用 `goals` feature flag —— *硬性技术前提，不可豁免*
- 项目工作区干净（git status clean）或可创建 worktree —— *硬性前提*

## When NOT to Use

- 短任务（< 2 小时）→ **agent 自动路由时**建议 `flow-dev-task`；**用户明确指定 codex-goal 时**
  尊重用户判断，仅走一次性告知 gate（见上方"用户判断权优先"段），不阻止
- 模糊目标（"让 UI 更好看"无量化指标）→ `superpowers:brainstorming`
- 探索性任务，没有 stop condition → `superpowers:brainstorming`
- 高风险代码（auth/支付/加密）→ orchestrator agent 自写，不派 Codex（**安全约束，不可豁免**）
- Codex CLI 未装或版本 < 0.128.0 → 退回 flow-dev-task（**硬性技术前提，不可豁免**）

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

   **5a. 路由 reviewer 阵容**

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

按 Step 0.0 探测的 `RUN_MODE` 启动 Goal Codex。**4 模式（CLI-YOLO / TMUX-YOLO / CLI-EXEC / SUBAGENT）的完整启动命令** + 投喂方式见 `references/run-mode.md`；TMUX-YOLO 的 stale scan / `# PHASE-N-DONE` marker 协议 / ANSI strip / pipe-pane 日志 / cleanup 见 `references/tmux-yolo-runtime.md`。

**关键约束**：
- **必须** `--dangerously-bypass-approvals-and-sandbox`（用户明确要求 codex 跑真实 host 环境，否则 pnpm install / keychain / dev server 都不可用）
- **必须** `--cd "$WORKTREE"`（隔离边界由 worktree 提供，不依赖 sandbox）
- 同时启动 `boundary-watch.sh`（见 Step 1.2）防止 codex 越界改主 worktree

完整 Goal prompt 见 `references/goal-prompt.md`。

#### Step 1.2：启动 watcher（健康 + 边界 + IM inbox poll）

**两种启动方式**（细节见下方「Orchestrator Wake-up Combo」段 + `references/wake-up-combo.md`）：

| 方式 | 退出通知 | 何时选 |
|---|---|---|
| **A — Bash run_in_background**（**推荐**） | orchestrator 主进程（tool notification） | Claude Code agent + 支持 `Bash(run_in_background=true)` |
| **B — nohup detached**（fallback） | 无；靠 watcher 30 min cc-connect cron 兜底 | 裸 shell / cron / 其他 agent |

```bash
# A（推荐，Claude Code）— BashOutput 自动 surface exit code
bash references/watcher.sh "$TASK_ID"

# B（fallback）— watcher 内部 30 min wake cron 兜底（CC_SESSION_KEY 非空时生效）
nohup bash references/watcher.sh "$TASK_ID" \
  > .agent/tasks/$TASK_ID/logs/watcher.log 2>&1 &
echo $! > .agent/tasks/$TASK_ID/watcher.pid
```

watcher 主循环串行跑 3 个守卫（不并发避免 race）：boundary-watch（30s）/
cc-connect inbox poll（60s）/ health-check（默认 5min）。watcher 是
**orchestrator idle 期间的唯一活跃进程**，接管：健康判定 / 边界守卫 /
IM inbox poll（人类 pause/abort/adjust 由 watcher 落盘）/ mini-review 触发 +
score-diff + snapshot / UI 截图即时 cc-connect 推送 / B 方案 wake cron 自管理
（exit 3 故意保活穿越 retry）。

#### Step 1.3：watcher milestone 循环（含 UI 截图 + audit + snapshot）

每当 watcher 检测到 `milestone` 状态，按以下 6 步串行执行：

1. **runtime-evidence** — `bash references/runtime-evidence.sh "$TASK_ID" "scores/$milestone"`
   （含 UI 任务的状态走查截图）
2. **mini-review codex**（独立新进程，timeout 600）—
   `codex exec < references/milestone-review-prompt.md` 输出 `scores/$milestone.json`，
   prompt 反复强调 "score on 1-5 scale, do NOT rescale to 1-10"
3. **score-diff** — `python3 references/score-diff.py` 按 GOAL.md `mode` 判退化
4. **snapshot** — 分数创新高 → `git tag "snapshot-$milestone-$CURRENT_AGG"` +
   写 `snapshots/HIGHEST_SCORE` / `HIGHEST_TAG`
5. **audit** — `bash references/write-audit.sh "$TASK_ID" "$milestone" mini-review`
6. **UI 截图即时推 IM**（`is_ui_task=true` + `CC_SESSION_KEY` 非空）—
   `cc-connect send --image` 多图 + 写 `pending-review-images.txt` 让
   orchestrator 后补校验

**UI 截图协议**（`is_ui_task: true` 时强制）：
- ✅ **即时发送**（不批发） + **状态矩阵覆盖**（详见 `references/ui-review-checklist.md`）
- ✅ orchestrator 下次被人 ping 时**批量补校验**（view_image 看
  pending-review-images.txt，发现错位发"勘误"消息）
- ✅ 收尾发"历史最高分轮次"截图（不是最后一轮），明确说明"这是最终采用版本"

#### Step 1.4：orchestrator idle 模型

orchestrator 启动 watcher 后**进入 idle**，只在被唤醒时动手。完整唤醒源 / 标准动作 / 禁止清单 / exit-code 映射见下方 **`## Orchestrator Idle Model`** 段。

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

**派工 prompt 模板**：完整模板 + 字段注入规则见 `references/extra-reviewer-prompt.md`
（遵循 `references/dispatcher-template.md` 通用字段集 + `references/parallelization-template.md` 显式 skill 调用硬规则）。

watcher 派工时把该 reviewer 在 GOAL.md `extra_reviewers[].checks` 里声明的维度注入 prompt 的
"负责的检查维度"段。内置 Reviewer Codex 同理——按 `REVIEWER-PLAN.md` 里它的 checks 行注入 review-prompt。

详细注册 schema + 派工脚本见 `references/reviewer-arbitration.md`。

#### Step 2.4：处理 verdict + 多 reviewer 仲裁 + snapshot + 最高分回退

watcher touch `.review-pending` → orchestrator 唤醒，读 REVIEW.md → 走仲裁逻辑。

**完整伪代码**（单 reviewer 退化路径 + 多 reviewer 主路径）见
`references/orchestrator-arbitration.md`。本段只列硬规则速查：

- **黑名单优先 reviewer Must Fix**：reviewer 要拆 `Non-goals` 文件 → orchestrator 拒，写 audit
- **3 轮 review fail 上限**：超出 → 强制终止 Goal Codex + alert（watcher exit 2）
- **3 轮不涨分**：回到历史最高分 snapshot tag（不是最后一轮）
- **PASS 但低于最高分**：不自动回滚，但保留快照让人类选
- **多 reviewer 仲裁**：默认 **AND-pass**（所有 reviewer 都 pass 才整体 pass）。
  4 种规则（AND-pass / OR-pass / weighted-avg / hard-rule-override）详见
  `references/reviewer-arbitration.md`
- **几何平均**：multi-reviewer 整体 aggregate = `(r1.agg * r2.agg * ... * rN.agg) ** (1/N)`，
  强调"两边都好"，避免一边极高一边极低也通过

retry 时把 accepted must_fix（跨 reviewer 合并去重后）写回 `STATUS.md` 的
`Next Action` 段，watcher 检测新 commit 后触发 round-(N+1)。

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
每次 review（baseline / mini-review / final）启动 + 完成都写一行 JSONL 到 `review-audit/round-N.jsonl`，含独立性证据（`reviewer_pid` / `reviewer_thread_id` / `reviewer_worktree_sha` ≠ goal/orchestrator）+ verdict + scores + `orchestrator_arbitration`。**完整字段 schema 见 `references/review-audit-schema.md`**。

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
- **review verdict=fail 且 consecutive_fails < 3 时问用户"要不要 retry"**（必须自动 retry；只在达到 3 次上限时才上报）

### Watcher Exit Code → Orchestrator 行为映射

watcher 主循环退出时按 verdict 给不同 exit code，orchestrator 必须按 exit code 自动决策，**不允许把"是否 retry"问用户**：

| exit code | watcher 含义 | orchestrator 必做动作 |
|---|---|---|
| **0** | 最终 verdict=pass，task 完成且通过 review | 进 Phase 3（risk-tiered 验证 + 人类签字 commit/push） |
| **2** | 最终 verdict=fail，**已达 review-3-fail 上限** | **必须上报人类**（abort/handoff/rescope 4 选 1），不再 auto-retry |
| **3** | 最终 verdict=fail，**未达 3 次上限**（fails=1 或 2） | **自动 retry**：① 读 reviews/round-N/arbitration.md → ② 黑名单仲裁 Must Fix → ③ 把 accepted Must Fix 派给 Goal Codex 修 → ④ 重启 watcher 进 round-(N+1) → ⑤ **不问用户** |
| **4** | verdict 解析失败（reviewer 全 missing 等） | 上报人类手动检查 `reviews/round-N/` |

**判定 consecutive_fails**：watcher 把当前 fail 计数写到 `.agent/tasks/<id>/.review-fail-count`。pass 时清零；exit 3 时累加。orchestrator 不需要自己维护这个计数。

**为什么不允许问用户**：
- skill `Goal-Attainment Mode` 已经规定了 hybrid=threshold+no-improvement-N 的退出条件
- 每次 fail 都问用户就是把 skill 的自动化承诺打折
- 真要人类干预的场景已经明确（fail 满 3 次 + boundary 违规 + budget 耗尽 + 人类主动 ping），其他情况不许问
- 例外：commit / push / 销毁 worktree 等 destructive ops **必须** user gate（constitution.md 第 6 条 High-Risk Action Gate）

### Orchestrator Wake-up Combo（A + B 兜底）

**根问题**：watcher `cc-connect send` 是 bot → user 单向，不会反弹唤醒 orchestrator
session → 磁盘信号文件没人读，exit 3 auto-retry 失效。

**组合解法**：
- **A 主路** — Claude Code `Bash(run_in_background=true)`，watcher 退出时 tool
  notification 自动唤醒 orchestrator，按 exit code 走映射表（0 token、< 1s 延迟）
- **B 兜底** — watcher 启动时注册 30 min cc-connect cron `wake-orchestrator-${TASK_ID}`，
  非 retry 终止分支退出前 `cleanup_orchestrator_wake`，exit 3 故意保活穿越 retry
  （约 $0.5–1 / 4h 任务，< 30 min 延迟）

两路独立失效不影响另一路。完整启动脚本 / cron 表达式 / token 成本权衡表 /
不可破坏的纪律见 `references/wake-up-combo.md`。

### "watcher 不可用" 的兜底（SUBAGENT 模式）

SUBAGENT 模式下 orchestrator **被迫兼任 watcher**：自跑 mini-review / write-audit /
snapshot / IM 推送，但仍严守两 Codex 硬隔离（subagent 是新进程，仍走
`codex exec` + readonly worktree）。详见 `references/wake-up-combo.md` 末段。

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
| 任务预估 < 2 小时（用户明确指定 codex-goal） | **不是 failure**——走一次性告知 gate 后继续 Phase 0（见"用户判断权优先"段） |

### Stop Conditions（硬约束）

任一命中立即停 Goal Codex 并 notify 人类：

- 连续 3 次 verification fail
- Review 连续 **3 轮** fail（统一为 3，旧版有处写 2 是文档矛盾——以本条为准；watcher.sh 实现也是 3 次）
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

**基线 JSON / markdown 分流** 见 `references/output-contract-schema.md`(sync from `_shared/output-contract-schema.md`,跨 skill 通用)。本 skill 扩展 = 9 段 Phase 3 task report。

Phase 3 delivery 完成后,orchestrator **必须**按 `references/task-report-template.md`
模板输出 task report——含 Task / Phase 0 Contract / Baseline / Execution /
Score Trajectory / Review / UI Screenshots(条件) / Delivery / Risks / 结论 9 段。

**双通道**:
- 落盘 `.agent/tasks/$TASK_ID/TASK-REPORT.md`
- 同时在对话里**完整复述**(IM session 也 push)——只写盘不口播 = 人类裁决无入口

字段必填规则 / 触发条件 / `not invoked` 标注规则全部在 template 里,本 SKILL.md
不重复维护以避免双源漂移。

---

## Red Flags + Rationalizations

完整 Red Flags 清单（按 Phase 0 / 隔离 / Execution / Score / Delivery 分组，约 30 条）
+ Rationalizations to Reject 对照表（17 条说辞 → 现实）见
**`references/failure-modes.md`**。

主体 SKILL.md 不再展开，新增 / 订正条目在该 reference 内维护。Top 3 翻车点速查
（与 TL;DR 同源）：

1. **Phase 0 跳了** → 跑完用户不认账（APPROVAL.md / Reviewer Plan 未签字）
2. **Reviewer 跟 Goal 同 worktree / 同 session** → review 失效，等于裸 `/goal`
3. **3 轮不涨分但 commit 最后一轮** → 必须回 `HIGHEST_TAG`

---

## Executor Selection

> **特殊例外**:本 skill 是 Codex 重委派的**元方法**(把整个长任务派给 Codex Goal),
> 不适用 `references/executor-selection-template.md` 的"默认不派 / 怎么选执行者"通用判断。
> 该文件 § 5 "例外 skill:flow-codex-goal" 也明示这条豁免。

本 skill 的"什么时候用 codex-goal"路由建议(不是 ROI 判定):

| 场景 | 建议 |
|---|---|
| 任务 ≥ 2 小时 + 清晰验收 | 🟢 推荐 |
| 任务 < 2 小时 | 🔴 不推荐(启动 worktree + watcher 开销 > 节省)— *但用户明确指定 codex-goal 时仍执行,见"用户判断权优先"段* |
| 任务无清晰验收 | 🔴 强烈不推荐(goal 跑飞烧 quota) |
| 任务高风险(auth/支付) | 🔴 强烈不推荐 |
| UI 循环改造(迭代式) | 🟢 推荐(snapshot + 同分硬规则正是为此设计) |

派工细则细节(SPEC 模板 / prompt 模板 / review 检查表)以本 skill 为准,本 skill **不引用** `flow-dev-task` 的细则(本 skill 的派工模型是 long-running Goal,不是 single-shot exec)。

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

测试用例保留在 `tests/cases.md`。所有模板和脚本在 `references/`，可被任何
orchestrator agent + Goal Codex + Reviewer Codex 直接读取使用。

按需查找 reference：参见上方 TL;DR 的 "References 路由表" + `references/` 自身
目录结构（`ls references/`），不在主体重复维护清单以避免与新增 reference 失同步。
