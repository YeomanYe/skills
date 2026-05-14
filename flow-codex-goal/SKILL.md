---
name: flow-codex-goal
description: >
  Use when running long-horizon tasks via Codex `/goal` mode with an independent
  fresh-process Codex review pass for verification. Trigger on phrases like
  "用 codex goal 跑这个长任务", "让 codex 后台跑", "无人值守长跑", "use codex goal mode",
  "long-horizon agent task", "background codex execution", "ralph loop", "let codex
  run for hours". Do NOT use for short tasks (use `flow-dev-task` instead),
  exploratory work without acceptance criteria (use brainstorming), or tasks where
  Claude itself should be the executor (use `flow-dev-task` with Codex Delegation
  Rules at Stage 5).
type: workflow
---

# flow-codex-goal

## Overview

编排「Codex Goal 长跑 + 独立 Codex Review + 健康检查 + 人类裁决」一条流水线。

核心信念（来自原始协议文档）：

> 长任务不要依赖对话上下文记忆，要依赖**磁盘状态文件**、**明确验收标准**、**独立 worktree**、**验证命令**和**独立 review**。

Codex `/goal` 是 Codex CLI 0.128.0+ 的实验功能（feature flag `goals = true`），让一个 Codex 围绕目标持续执行，但有三个硬限制必须靠本 skill 兜底：

1. **没有自动循环**：`/goal` 只在外部触发时 continuation 一次，不会真"自跑"
2. **没有花销上限**：goal 跑飞会烧光 token quota 没止损
3. **完成检测不可靠**：goal 可能 silent pause 但 Claude 不知道

本 skill 通过**健康检查脚本 + 看门狗 + 状态文件协议**解决这三件事。

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
- 高风险代码（auth/支付/加密）→ Claude 自写，不派 Codex
- Codex CLI 未装或版本 < 0.128.0 → 退回 flow-dev-task 走 Claude 自写

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

### Step 3：启动 Goal Codex

调用方式（按可用性选）：

#### 优先：交互模式 + GOAL.md 引用
```bash
# 在 worktree 内开新终端
codex --yolo &
echo $! > .agent/tasks/$TASK_ID/codex.pid

# Claude 通过 expect/script 输入：
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

watcher 每 5 分钟跑一次 `health-check.sh`，输出 4 种状态：

| 状态 | 触发条件 | watcher 动作 |
|---|---|---|
| `running` | 进程活 + 文件有改动 + STATUS.md 有更新 | 继续等 |
| `done` | STATUS.md 含 `GOAL_DONE` | → 进 Step 5 review |
| `stalled` | 进程活但 ≥ 15 分钟无文件改动 + 无日志增长 + STATUS.md 没更 | 累计 stall 计数；连续 3 次 → notify 人类 |
| `failed` | 进程死了但 STATUS.md 没 GOAL_DONE | → 收集诊断 + notify 人类 |

健康检查的 6 维度：进程存活 / worktree 文件 mtime / 日志增长 / STATUS.md mtime / GOAL_DONE 信号 / token budget 估算。详见 `references/health-check.sh`。

### Step 5：Goal 完成 → 生成 review-input

watcher 检测到 `done` 后自动执行：

```bash
cd "$WORKTREE"
TASK_DIR=".agent/tasks/$TASK_ID"
mkdir -p "$TASK_DIR/review-input"

git diff main > "$TASK_DIR/review-input/diff.patch"
git diff --stat main > "$TASK_DIR/review-input/diff-stat.txt"
git status --short > "$TASK_DIR/review-input/status.txt"

# 按 EVAL.md 跑验证命令（自动检测包管理器）
[[ -f package.json ]] && {
  npx --no-install eslint . > "$TASK_DIR/review-input/lint.txt" 2>&1 || true
  pnpm test > "$TASK_DIR/review-input/test.txt" 2>&1 || true
  pnpm build > "$TASK_DIR/review-input/build.txt" 2>&1 || true
}

# UI 改动 → Playwright 截图
git diff --name-only main | grep -qE '\.(tsx?|vue|svelte|css)$' && {
  # 跑 agent-browser 或 playwright 截图到 review-input/screenshots/
  echo "ui_changed=true" >> "$TASK_DIR/review-input/manifest.txt"
}
```

### Step 6：启动独立 Reviewer Codex

**必须**满足：
- 全新进程（不能复用 Goal 的 thread）
- 不读 Goal Codex 的对话历史
- 不读实施者解释
- 只基于 review-input/ 客观材料判断

```bash
cd "$WORKTREE"
codex exec --skip-git-repo-check < references/review-prompt.md
```

`references/review-prompt.md` 已写好严格的 reviewer 指令，会输出 `.agent/tasks/$TASK_ID/REVIEW.md`。

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
- 关键截图（如有）
- 询问："commit & push? hold? rollback?"

人类回复后才 commit。

### Step 9：commit + push

调用 `clean-commit` skill，把 Codex 信息显式传入 commit message：
```
feat(X): <goal objective> (Codex Goal: 1 round, 0 review failures)
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

### Reviewer Independence Gates

- Reviewer Codex **必须**新进程（pid 与 Goal 不同）
- Reviewer prompt **不得**包含 "the implementer says"、"as discussed" 等污染语
- Reviewer 输出 `Verdict: pass` 时，**Claude 必须**自跑一遍验证命令对照（不信任 reviewer 自报）

## Output Contract

完成后必须输出：

```md
## Codex Goal Task Report

### Task
- ID:
- Objective:
- Worktree path:

### Execution
- Goal Codex started: <ts>
- Goal Codex completed: <ts>
- Total duration:
- Milestones completed: <n>
- Token budget used: <est>
- Health check stalls triggered: <n>
- Verification failures: <n>

### Review
- Reviewer rounds: <n>
- Final verdict: pass | fail | aborted
- Must Fix resolved: <n>
- Should Fix recorded: <n>

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
- review verdict pass 但 Claude 没亲自跑验证命令
- 修改文件超 GOAL.md Budget 但继续推进
- token 用量接近 budget 但不停
- Goal Codex 修改了 SPEC 范围外的文件
- 把 Codex 修改全部 `git add .` 而不是选择性 staging

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "Goal 跑得挺顺，跳过 review 直接 commit 吧" | review 是本 skill 的 50% 价值，跳了就退化成裸 /goal |
| "Reviewer 也是 Codex，让它复用 thread 省 token" | 复用 = 污染独立性 = review 失效 |
| "watcher 太啰嗦，先不跑了" | 没 watcher = goal 可能 silent pause + 烧 quota |
| "Goal 说完成了，STATUS.md 应该也写了吧" | 必须 grep `GOAL_DONE` 确认，不能信"应该"|
| "改的就是 main 分支文件，不开 worktree 也行" | --yolo + main + 长跑 = 灾难 |
| "Verdict pass 应该没问题，不用我再跑测试" | reviewer 也可能瞎判，Claude 必须亲跑兜底 |
| "Stalled 3 次了，再等等可能就好了" | 硬阈值，必须 notify 人类 |

## Codex Delegation Hook

本 skill **本身就是 Codex 派工的特例**——把整个长任务派给 Codex Goal。

ROI 判断：

| 场景 | ROI |
|---|---|
| 任务 ≥ 2 小时 + 清晰验收 | 🟢 高（这正是 /goal 设计场景）|
| 任务 < 2 小时 | 🔴 低（启动 worktree + watcher 开销 > 节省）|
| 任务无清晰验收 | 🔴 负（goal 会跑飞烧 quota）|
| 任务高风险（auth/支付）| 🔴 负（Codex 不应碰这类代码）|

派工细则细节以本 skill 的 SKILL.md 为准，不引用 `flow-dev-task` 的 Codex Delegation Rules（那是 Claude 主线 + Codex 子任务模式，本 skill 是反过来）。

## Relationship to Other Skills

- **上游**: 用户直接触发 / `flow-dev-task` Stage 5 判定"任务过长"时 handoff 给本 skill
- **下游（调用）**:
  - `clean-commit`（Step 9 commit）
  - `agent-browser` 或 `playwright`（Step 5 截图）
  - cc-connect（Step 8 人类沟通，可选）
- **不下游**:
  - `superpowers:test-driven-development`（Codex 内部按 EVAL.md 走，不调外部 TDD skill）
  - `superpowers:verification-before-completion`（替换为本 skill 的 review pipeline）

## Reuse

测试用例保留在 `tests/cases.md`。
所有模板和脚本在 `references/`，可被 GOAL Codex 直接读取使用。
