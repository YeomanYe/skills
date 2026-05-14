---
name: flow-codex-goal
description: >
  Use when an orchestrator agent (Claude / Codex / any other) needs to run a
  long-horizon task via Codex `/goal` mode with an independent fresh-process Codex
  review pass for verification, baseline scoring to prevent regression, and
  periodic IM-pushed milestone reports for human oversight. Trigger on phrases
  like "用 codex goal 跑这个长任务", "让 codex 后台跑", "无人值守长跑",
  "use codex goal mode", "long-horizon agent task", "background codex execution",
  "ralph loop", "let codex run for hours". Do NOT use for short tasks (use
  `flow-dev-task` instead), exploratory work without acceptance criteria (use
  brainstorming), or tasks where the orchestrator itself should be the executor
  (use `flow-dev-task`).
type: workflow
---

# flow-codex-goal

## Overview

编排「Codex Goal 长跑 + 基线评分 + 独立 Codex Review（含运行时证据）+ 健康检查 + IM 周期推送 + 人类裁决」一条流水线。

**调用方角色**：本 skill 不假设调用方是 Claude——可以是 Claude Code、Codex CLI、或任何其他能调用 Bash 的 agent。下文统一用 **orchestrator agent** 指代调用方。orchestrator agent 是这条流水线的**管理者**：定义目标、启动 Goal Codex、监控、定期把进展推给人类、收尾决策。

核心信念（来自原始协议文档）：

> 长任务不要依赖对话上下文记忆，要依赖**磁盘状态文件**、**明确验收标准**、**独立 worktree**、**验证命令**、**独立 review**和**周期性人类校准**。

Codex `/goal` 是 Codex CLI 0.128.0+ 的实验功能（feature flag `goals = true`），让一个 Codex 围绕目标持续执行，但有四个硬限制必须靠本 skill 兜底：

1. **没有自动循环**：`/goal` 只在外部触发时 continuation 一次，不会真"自跑"
2. **没有花销上限**：goal 跑飞会烧光 token quota 没止损
3. **完成检测不可靠**：goal 可能 silent pause 但 orchestrator 不知道
4. **没有评分基线**：不知道改动是"提升"还是"退化"，可能越修越差

本 skill 通过**健康检查脚本 + 看门狗 + 状态文件协议 + 基线评分 + 周期性 milestone 推送**解决这四件事。

## When to Use

进入本 skill 必须**全部**满足：

- 任务边界清晰，可拆步骤，有可验证的 acceptance criteria
- 预估执行时间 ≥ 2 小时（< 2 小时直接用 flow-dev-task 更省）
- 用户希望"无人值守长跑"或"后台跑"
- Codex CLI ≥ 0.128.0 且已启用 `goals` feature flag（pre-flight 自动检查）
- 项目工作区干净（git status clean）或可创建 worktree

## When NOT to Use

- 短任务（< 2 小时）→ `flow-dev-task`
- 模糊目标（"让 UI 更好看"无量化指标）→ `superpowers:brainstorming`
- 探索性任务，没有 stop condition → `superpowers:brainstorming`
- 高风险代码（auth/支付/加密）→ orchestrator agent 自写，不派 Codex
- Codex CLI 未装或版本 < 0.128.0 → 退回 flow-dev-task 走 orchestrator agent 自写

## Required Workflow

按顺序执行，**不允许跳步**。

### Step 0：Pre-flight 检查

执行以下 5 项，任一失败 → 整个 skill 退出并报告原因：

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
# 至少其中之一必须存在：pnpm test / npm test / yarn test / cargo test / go test
ls package.json Cargo.toml go.mod 2>/dev/null

# 5. 当前分支不是 main/master/dev（避免裸跑）
git branch --show-current
```

### Step 0.5：确认验收标准 + Goal-Attainment Mode（**必须在启动 Goal Codex 之前完成**）

orchestrator agent **必须**在 GOAL.md 落盘之前，向人类**一次性批量**确认以下 3 项（Question Budget = 3，超出走默认推断）：

1. **Acceptance Criteria 是否量化、可验证**？
   - 列出当前推断的 AC（从用户 prompt + Context Harvest 提炼）
   - 每条必须能由 EVAL.md 中某条命令 / 某张截图断言
   - 模糊的 AC（"更好用"、"更快"）必须改写成数字（"P95 latency < 200ms"、"a11y score ≥ 90"）

2. **Goal-Attainment Mode 选哪种**？

   | 模式 | 何时停 | 适用场景 |
   |---|---|---|
   | `threshold` | 综合分数 ≥ 阈值（默认 4.0/5.0） | 追求达到某个质量水平 |
   | `no-improvement-N` | 连续 N 轮（默认 3）分数不再上升 | 优化类任务（性能、bundle size、a11y）|
   | `regression-prevention` | 任何一项分数 < baseline 立即停 | 重构类任务（功能不变，结构变好）|
   | `hybrid` | threshold AND no-improvement-N 都满足 | 既要达标又要稳定 |

   推断默认值：
   - 重构 / migration → `regression-prevention`
   - 性能 / 体积优化 → `no-improvement-N`
   - 新功能 / 修复 → `threshold`
   - 用户没明确说 → 用推断默认值，并在 GOAL.md 注明

3. **Budget 上限是否合理**？
   - 默认：files ≤ 50 / tokens ≤ 500K / wall_clock ≤ 4h / verification_failures ≤ 3
   - 让人类确认或调整

确认后写入 GOAL.md（见 `references/goal-template.md` 的 Goal-Attainment Mode 段）。

**禁止**：未确认就启动 Goal Codex。AC 模糊会导致 goal 跑飞，攻击面在 Step 0.5 这里堵住。

### Step 1：创建任务目录 + 文件协议

```bash
TASK_ID="$(date +%Y%m%d-%H%M%S)-$(echo $TASK_NAME | tr ' ' '-')"
mkdir -p ".agent/tasks/$TASK_ID"/{logs,review-input/screenshots}
```

按 `references/` 模板创建：
- `GOAL.md` — 用 `references/goal-template.md`
- `PLAN.md` — 用 `references/plan-template.md`
- `EVAL.md` — 用 `references/eval-template.md`
- `STATUS.md` — 初始化为 `Phase: 0 / Step: 0 / Last verification: never / Next action: read GOAL.md`

`.gitignore` 必须加：
```
.agent/tasks/*/logs/
.agent/tasks/*/review-input/
```

### Step 2：创建独立 worktree

```bash
WORKTREE="../$(basename $PWD)-goal-$TASK_ID"
git worktree add "$WORKTREE" -b "goal/$TASK_ID"
cd "$WORKTREE"
```

**禁止**在主 worktree 直接跑 goal——`--yolo` + goal 长跑组合会污染主分支。

### Step 2.5：基线评分（**必须在启动 Goal Codex 之前**）

为防止"越改越退化"，先用 Reviewer Codex 对**当前未改动状态**评分一次，作为 baseline。

```bash
# 在 worktree 内
cd "$WORKTREE"
TASK_DIR=".agent/tasks/$TASK_ID"

# 1. 准备 baseline 用的伪 review-input（只有 EVAL 命令输出 + 截图，无 diff）
mkdir -p "$TASK_DIR/baseline/screenshots"
pnpm test > "$TASK_DIR/baseline/test.txt" 2>&1 || true
pnpm build > "$TASK_DIR/baseline/build.txt" 2>&1 || true
pnpm lint  > "$TASK_DIR/baseline/lint.txt" 2>&1 || true

# 2. 启动项目 + 截关键流程截图（按 GOAL.md 中"用户旅程"列表）
#    用 references/runtime-evidence.sh 自动化（见下方）
bash references/runtime-evidence.sh "$TASK_ID" baseline

# 3. 启动 Reviewer Codex 给 baseline 打分（不评判 diff，只评判当前系统质量）
codex exec --skip-git-repo-check < references/baseline-prompt.md
# 输出 .agent/tasks/$TASK_ID/BASELINE.md
```

`BASELINE.md` 必须含：
- 4 维度评分（Correctness / Maintainability / UX / Risk，各 1-5）
- 综合分数（4 项算术平均）
- Quality Gates 当前通过情况
- 关键截图清单
- Timestamp

**这份分数后续每轮 Goal milestone 完成后会被对比**，任一维度低于 baseline 即触发 `regression-prevention` 模式的硬停止。

**禁止**：跳过 baseline 直接启 Goal——会失去"越改越差"的早期信号。

### Step 3：启动 Goal Codex

调用方式（按可用性选）：

#### 优先：交互模式 + GOAL.md 引用
```bash
# 在 worktree 内开新终端
codex --yolo &
echo $! > .agent/tasks/$TASK_ID/codex.pid

# orchestrator agent 通过 expect/script 输入：
# /goal Read .agent/tasks/<TASK_ID>/GOAL.md, follow PLAN.md, update STATUS.md after every milestone, verify per EVAL.md, stop when GOAL_DONE or stop conditions hit.
```

#### 备选：app-server API（程序化）
```bash
codex app-server &
# 通过 thread/goal/set API 设置 goal
```

完整 Goal prompt 见 `references/goal-prompt.md`。

### Step 4：启动看门狗

**这是本 skill 的核心防御机制**。

```bash
nohup bash references/watcher.sh "$TASK_ID" > .agent/tasks/$TASK_ID/logs/watcher.log 2>&1 &
echo $! > .agent/tasks/$TASK_ID/watcher.pid
```

watcher 每 5 分钟跑一次 `health-check.sh`，输出 5 种状态：

| 状态 | 触发条件 | watcher 动作 |
|---|---|---|
| `running` | 进程活 + 文件有改动 + STATUS.md 有更新 | 继续等 |
| `milestone` | STATUS.md 出现新 `MILESTONE: <name>` 行 | → 触发 mini-review + 推送给人类（见 Step 4.5）|
| `done` | STATUS.md 含 `GOAL_DONE` | → 进 Step 5 review |
| `stalled` | 进程活但 ≥ 15 分钟无文件改动 + 无日志增长 + STATUS.md 没更 | 累计 stall 计数；连续 3 次 → notify 人类 |
| `failed` | 进程死了但 STATUS.md 没 GOAL_DONE | → 收集诊断 + notify 人类 |

健康检查的 6 维度：进程存活 / worktree 文件 mtime / 日志增长 / STATUS.md mtime / GOAL_DONE 信号 / token budget 估算。详见 `references/health-check.sh`。

### Step 4.5：周期性 milestone 推送（**IM 会话强制启用**）

每当 watcher 检测到 `milestone` 状态（Goal Codex 完成一个 phase 写入 `MILESTONE:` 行），自动执行：

```bash
# 1. 收集当前 milestone 的运行时证据（截图 + EVAL 输出）
bash references/runtime-evidence.sh "$TASK_ID" "milestone-N"

# 2. 启动 mini-review（轻量，只跑评分，不写 Must Fix）
codex exec --skip-git-repo-check < references/milestone-review-prompt.md
# 输出 .agent/tasks/$TASK_ID/scores/milestone-N.json

# 3. 对比 baseline 检测退化
MODE=$(grep -A1 "^mode:" .agent/tasks/$TASK_ID/GOAL.md | head -1 | awk '{print $2}')
python3 references/score-diff.py \
  --baseline .agent/tasks/$TASK_ID/BASELINE.md \
  --current  .agent/tasks/$TASK_ID/scores/milestone-N.json \
  --mode     "$MODE"

# 4. 如果是 IM 会话（CC_SESSION_KEY 非空），推送给人类
[[ -n "${CC_SESSION_KEY:-}" ]] && cc-connect send \
  --message "[$TASK_ID] Milestone N complete
Score: <综合分数> (Δ vs baseline: <差值>)
Correctness: N/5  Maintainability: N/5  UX: N/5  Risk: N/5
Screenshots: <count> attached" \
  --image .agent/tasks/$TASK_ID/scores/milestone-N/screenshots/*.png
```

人类**随时可以回复**：
- `continue` — 我看了，继续
- `pause` — 暂停 Goal Codex 等我看完
- `abort` — 直接终止
- `adjust: <text>` — 我想调整 GOAL.md 某项，把 `<text>` 当反馈写入 STATUS.md `## Human Feedback` 段，Goal Codex 下个 milestone 会读到

**IM inbound 落地责任**：watcher 是单向 push（cc-connect send），不监听 inbound。**orchestrator agent** 负责在每次 watcher push 后**主动 poll** cc-connect inbox（IM 通道支持的话），拿到人类回复后：
- `continue` → 不动作
- `pause` → 写 `STOPPED: human-paused` 到 STATUS.md（watcher 下个循环看到自停）
- `abort` → kill Goal Codex + watcher，标记 worktree 为 abandoned
- `adjust: <text>` → 在 STATUS.md 末尾追加：
  ```md
  ## Human Feedback (<ISO ts>)
  <text>
  ```
  Goal Codex 下个 milestone 开始前会读到（goal-template.md Workflow Rule 5）。

如果 orchestrator agent 是后台 cron 跑的、无法实时 poll → 至少在每次重新进入 skill 时 catch-up 一次，把累计回复合并写入 STATUS.md。

如果 `score-diff.py` 检测到退化（按 GOAL.md `Goal-Attainment Mode` 判定），watcher 会**主动停止 Goal Codex**而不是等人类回复。

**禁止**：
- 在 IM 会话中只发"完成"消息，不发中间 milestone——人类失去校准能力
- orchestrator agent 不 poll IM inbound——人类的 `pause` / `adjust` 永远到不了 Goal Codex

### Step 5：Goal 完成 → 生成 review-input（含运行时证据）

watcher 检测到 `done` 后自动执行：

```bash
cd "$WORKTREE"
TASK_DIR=".agent/tasks/$TASK_ID"
mkdir -p "$TASK_DIR/review-input/screenshots"

# 1. 静态证据
git diff main > "$TASK_DIR/review-input/diff.patch"
git diff --stat main > "$TASK_DIR/review-input/diff-stat.txt"
git status --short > "$TASK_DIR/review-input/status.txt"

# 2. EVAL 命令输出
[[ -f package.json ]] && {
  npx --no-install eslint . > "$TASK_DIR/review-input/lint.txt" 2>&1 || true
  pnpm test > "$TASK_DIR/review-input/test.txt" 2>&1 || true
  pnpm build > "$TASK_DIR/review-input/build.txt" 2>&1 || true
}

# 3. 运行时证据（**最终 review 必须有，不只看 diff**）
bash references/runtime-evidence.sh "$TASK_ID" final
# 该脚本会：
#   - 启动项目（dev / prod build / cargo run）
#   - 按 GOAL.md「用户旅程」列表用浏览器/CLI 跑关键流程
#   - 每步截图到 review-input/screenshots/
#   - 收集运行时日志到 review-input/runtime.log
#   - 关闭服务
```

### Step 6：启动独立 Reviewer Codex（**强制运行时验证**）

**必须**满足：
- 全新进程（不能复用 Goal 的 thread）
- 不读 Goal Codex 的对话历史
- 不读实施者解释
- 只基于 review-input/ 客观材料判断
- **必须实际运行项目并验证用户旅程**（不只看 diff 和 test 输出）

```bash
cd "$WORKTREE"
codex exec --skip-git-repo-check < references/review-prompt.md
```

`references/review-prompt.md` 要求 Reviewer Codex 自己也跑一遍项目（不能只信 watcher 收集的截图——可能是 Goal Codex 作弊截的好看但不工作的状态），通过 chrome MCP / playwright 实际点击关键按钮、观察响应、对比 GOAL.md「用户旅程」预期。

输出 `.agent/tasks/$TASK_ID/REVIEW.md`，含：
- Verdict: `pass | fail`
- 4 维度评分（与 baseline 对比）
- 运行时证据 checklist（哪些用户旅程跑通了 / 哪些没有）
- Must Fix / Should Fix
- Confidence

### Step 7：处理 review verdict

读 `REVIEW.md` 的 `Verdict`：

#### `pass`
→ 进 Step 8

#### `fail` + `Must Fix` 列表
- 第 1-2 次 fail：把 Must Fix 写回 `STATUS.md`，重新触发 Goal Codex 修
- 连续 3 次 fail → 强制终止 Codex，notify 人类
- 修完后**重新跑 Step 5-6**（不能跳 review）

### Step 8：人类裁决

通过 cc-connect（如果 `CC_SESSION_KEY` 非空）发送：
- REVIEW.md 全文
- diff-stat
- baseline → final 评分对比表
- 关键截图（before/after 对比）
- 询问："commit & push? hold? rollback?"

人类回复后才 commit。

**Reviewer 自报 pass 不等于可以 commit**——orchestrator agent 必须再亲自跑一次 EVAL.md 命令对照（reviewer 也可能瞎判）。

### Step 9：commit + push

调用 `clean-commit` skill，把 Codex 信息显式传入 commit message：
```
feat(X): <goal objective> (Codex Goal: 1 round, 0 review failures, score Δ +0.5)
```

如果是 IM 会话，clean-commit 自动 push。

### Step 10：清理

- 关闭 watcher 进程
- 关闭 Codex 进程
- worktree 保留（不自动删，留给人类决定 merge/rebase/cleanup）
- 输出最终报告

## Decision Rules（硬写死）

### Pre-flight Failure Modes

| 检查失败 | 退出动作 |
|---|---|
| Codex 版本 < 0.128.0 | 提示升级，退回 flow-dev-task |
| feature flag 没开 | 自动写入 config.toml 然后继续 |
| git status 不干净 | 让用户先 commit 或 stash |
| 当前在 main/master/dev | 强制创建 worktree（不允许在主分支跑）|
| 无 acceptance commands | 警告 + 让用户写 EVAL.md 时手填 |

### Stop Conditions（硬约束）

任一命中立即停 Goal Codex 并 notify 人类：

- 连续 3 次 verification fail
- Review 连续 2 次 fail
- 文件改动数 > GOAL.md `Budget` 上限
- token 估算超 GOAL.md `Budget` 上限
- 健康检查 stalled 状态连续 3 次（约 15 分钟）
- 需要破坏性 git 操作
- 检测到 SPEC 范围外文件被修改
- 需要修改 auth / 支付 / 加密代码
- **任一 milestone 评分 < baseline**（Goal-Attainment Mode = `regression-prevention` 时）
- **连续 N 个 milestone 评分不上升**（Goal-Attainment Mode = `no-improvement-N` 时，N 默认 3）
- **人类在 IM 中回复 `pause` 或 `abort`**

### Reviewer Independence Gates

- Reviewer Codex **必须**新进程（pid 与 Goal 不同）
- Reviewer prompt **不得**包含 "the implementer says"、"as discussed" 等污染语
- Reviewer 输出 `Verdict: pass` 时，**orchestrator agent 必须**自跑一遍验证命令对照（不信任 reviewer 自报）
- Reviewer **必须**实际运行项目跑一遍用户旅程，不能只看 diff + 静态测试输出

## Output Contract

完成后必须输出：

```md
## Codex Goal Task Report

### Task
- ID:
- Objective:
- Worktree path:
- Goal-Attainment Mode: threshold | no-improvement-N | regression-prevention | hybrid

### Baseline (pre-task scoring)
- Correctness: N/5
- Maintainability: N/5
- UX: N/5  (or n/a)
- Risk: N/5
- Aggregate: X.X

### Execution
- Goal Codex started: <ts>
- Goal Codex completed: <ts>
- Total duration:
- Milestones completed: <n>
- Token budget used: <est>
- Health check stalls triggered: <n>
- Verification failures: <n>
- IM milestone reports pushed: <n> (skipped <m>)
- Human interrupts received: <n> (continue/pause/abort/adjust)

### Score Trajectory
- baseline → milestone-1 → ... → final
- 每个 milestone 4 维度评分 + 综合分数
- Δ(final - baseline): correctness Δ / maintainability Δ / ux Δ / risk Δ / aggregate Δ

### Review
- Reviewer rounds: <n>
- Final verdict: pass | fail | aborted
- Must Fix resolved: <n>
- Should Fix recorded: <n>
- Runtime evidence verified: <list of user-journeys passed>

### Delivery
- Commit SHA:
- Push status: pushed | committed | skipped | n/a
- Worktree fate: kept | merged | rebased | cleaned

### Risks / 技术债
- <项>: <说明>

### 结论
- 可交付: yes | no
- 需要人类后续: <list>
```

## Red Flags — STOP

任一命中必须停下：

- 在主分支裸跑 `/goal` 没开 worktree
- Reviewer Codex 复用 Goal Codex 的 session/thread
- Reviewer prompt 含实施者解释
- Goal Codex 报"完成"但 STATUS.md 没写 `GOAL_DONE`
- watcher 没启动就让 Goal 跑
- review verdict pass 但 orchestrator agent 没亲自跑验证命令
- 修改文件超 GOAL.md Budget 但继续推进
- token 用量接近 budget 但不停
- Goal Codex 修改了 SPEC 范围外的文件
- 把 Codex 修改全部 `git add .` 而不是选择性 staging
- **跳过 Step 0.5**（未与人类确认 AC / goal-attainment mode）就启动 Goal Codex
- **跳过 Step 2.5 baseline scoring** 就启动 Goal Codex
- **跳过运行时证据收集**（只看 diff 和 unit test 输出就裁决 verdict）
- IM 会话下**跳过 milestone 推送**（人类失去校准窗口）
- 检测到分数低于 baseline 但继续推进（regression-prevention 模式下）

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "Goal 跑得挺顺，跳过 review 直接 commit 吧" | review 是本 skill 的 50% 价值，跳了就退化成裸 /goal |
| "Reviewer 也是 Codex，让它复用 thread 省 token" | 复用 = 污染独立性 = review 失效 |
| "watcher 太啰嗦，先不跑了" | 没 watcher = goal 可能 silent pause + 烧 quota |
| "Goal 说完成了，STATUS.md 应该也写了吧" | 必须 grep `GOAL_DONE` 确认，不能信"应该"|
| "改的就是 main 分支文件，不开 worktree 也行" | --yolo + main + 长跑 = 灾难 |
| "Verdict pass 应该没问题，不用再跑测试" | reviewer 也可能瞎判，orchestrator agent 必须亲跑兜底 |
| "Stalled 3 次了，再等等可能就好了" | 硬阈值，必须 notify 人类 |
| "AC 已经在 prompt 里了，不用再确认了" | 用户口语化 AC 多半模糊，必须 Step 0.5 量化 |
| "Baseline scoring 太花时间，直接开 Goal 吧" | 没 baseline 就没退化检测，越改越差也不知道 |
| "Reviewer 看 diff 就够了，不用真跑" | 编译过 ≠ 跑得起来 ≠ 用户旅程能走通，必须运行时验证 |
| "milestone 推送太烦人，等 Goal 完成再发结果就行" | 人类校准窗口在中间，结尾发就晚了——已经烧了几小时 |
| "分数稍微低于 baseline 没关系，整体在涨" | regression-prevention 模式下任一维度低就停，不算总账 |

## Codex Delegation Hook

本 skill **本身就是 Codex 派工的特例**——把整个长任务派给 Codex Goal。

ROI 判断：

| 场景 | ROI |
|---|---|
| 任务 ≥ 2 小时 + 清晰验收 | 🟢 高（这正是 /goal 设计场景）|
| 任务 < 2 小时 | 🔴 低（启动 worktree + watcher 开销 > 节省）|
| 任务无清晰验收 | 🔴 负（goal 会跑飞烧 quota）|
| 任务高风险（auth/支付）| 🔴 负（Codex 不应碰这类代码）|

派工细则细节以本 skill 的 SKILL.md 为准，不引用 `flow-dev-task` 的 Codex Delegation Rules（那是 orchestrator agent 主线 + Codex 子任务模式，本 skill 是反过来——整个长任务交给 Goal Codex，orchestrator agent 退到管理者位）。

## Relationship to Other Skills

### Upstream Handoff Payload（来自 flow-dev-task）

`flow-dev-task` Stage 5 判定"任务过长"切到本 skill 时，**必须**透传以下字段（避免 Step 0.5 重复追问已知信息）：

| 字段 | 必填 | 说明 |
|---|---|---|
| `objective` | ✅ | 一句话任务目标 |
| `suggested_scope` | ✅ | 已识别的 scope 白名单（候选 GOAL.md Scope）|
| `suggested_non_goals` | 推荐 | 明确不动的范围 |
| `acceptance_hints` | 推荐 | 用户口语化 AC，Step 0.5 量化时用 |
| `time_budget_hours` | 推荐 | 用户暗示的时间预算 |
| `risk_class` | ✅ | low / medium / high（high 直接拒绝接手）|
| `attainment_mode_hint` | 可选 | 已推断的 mode（让 Step 0.5 用作默认值）|
| `prior_context` | 可选 | flow-dev-task Context Harvest 收集到的 git/branch/diff 状态 |

如果上游已传 `attainment_mode_hint` + `acceptance_hints` + `time_budget_hours`，Step 0.5 应**直接使用**这些值在 GOAL.md 落盘，不再问人类（除非 hints 内含模糊量词）。

### 上下游列表

- **上游**: 用户直接触发 / `flow-dev-task` Stage 5 判定"任务过长"时 handoff 给本 skill
- **下游（调用）**:
  - `clean-commit`（Step 9 commit）
  - chrome MCP / `playwright` / `agent-browser`（Step 2.5 baseline / Step 4.5 milestone / Step 5 final 截图）
  - cc-connect（Step 4.5 milestone 推送 + Step 8 人类裁决，IM 会话下强制）
- **不下游**:
  - `superpowers:test-driven-development`（Codex 内部按 EVAL.md 走，不调外部 TDD skill）
  - `superpowers:verification-before-completion`（替换为本 skill 的 baseline + milestone + final review pipeline）

## Reuse

测试用例保留在 `tests/cases.md`。
所有模板和脚本在 `references/`，可被任何 orchestrator agent + Goal Codex + Reviewer Codex 直接读取使用。

`references/` 目录结构：
- `codex-goal-setup.md` — pre-flight 脚本
- `goal-template.md` — GOAL.md 模板（含 Goal-Attainment Mode 段）
- `plan-template.md` — PLAN.md 模板
- `eval-template.md` — EVAL.md 模板
- `goal-prompt.md` — Goal Codex 启动 prompt
- `baseline-prompt.md` — Baseline 评分 Reviewer prompt
- `milestone-review-prompt.md` — Milestone 轻量评分 Reviewer prompt
- `review-prompt.md` — Final Reviewer prompt（含运行时验证要求）
- `runtime-evidence.sh` — 启动项目 + 跑用户旅程 + 截图
- `score-diff.py` — baseline vs current 评分对比 + 退化判定
- `health-check.sh` — 6 维度健康检查
- `watcher.sh` — 看门狗（含 milestone 推送）
- `stop-conditions.md` — 停止条件清单
