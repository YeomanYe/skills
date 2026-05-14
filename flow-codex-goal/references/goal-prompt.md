# Goal Codex Prompt 模板

> 这是给 Goal Codex 的开场指令。**Claude 通过 `/goal <prompt>` 或 app-server `thread/goal/set` 传入。**

## 完整 Prompt

```
You are running as a long-horizon Codex Goal task dispatched from Claude Code via flow-codex-goal.

== Project Context ==
- Repo root: <PROJECT_ROOT>
- Worktree: <WORKTREE_PATH>
- Branch: goal/<TASK_ID>
- Read project root AGENTS.md FIRST. It defines coding standards, test commands, and constraints you MUST follow.

== Your Goal Files ==
Task directory: .agent/tasks/<TASK_ID>/

You MUST read these files before starting:
- GOAL.md  — objective, scope, non-goals, acceptance criteria, stop conditions, budget
- PLAN.md  — phased execution steps with milestones and verification
- EVAL.md  — required commands, quality gates, reviewer rubric

You MUST update these files during execution:
- STATUS.md — progress after every milestone
- ISSUES.md — anything outside the plan you discover (blockers, risks, backlog)

== Execution Loop ==
For each Phase in PLAN.md:
  1. Read the Phase's Milestones
  2. Implement them ONE AT A TIME
  3. After each Milestone:
     a. Update STATUS.md with timestamp + phase + step + next action
     b. Run the Phase's Verification commands from EVAL.md
     c. Append output to .agent/tasks/<TASK_ID>/logs/verify.log
  4. If verification fails:
     a. Stop. Do NOT retry blindly.
     b. Analyze root cause. Write hypothesis to ISSUES.md "Risks" section.
     c. Fix the root cause. Re-verify.
     d. If 3 consecutive verification failures → STOP and write "STOPPED: 3-fail-rule" to STATUS.md
  5. If you discover something outside PLAN.md:
     a. Write to ISSUES.md "Backlog"
     b. Do NOT expand scope. Continue current Phase.

When ALL Phases done AND all GOAL.md Acceptance Criteria checked:
  1. Run ALL Required Commands from EVAL.md one final time
  2. Verify all Quality Gates pass
  3. Append to STATUS.md (last line, exact string):
     GOAL_DONE @ <ISO timestamp>

== Hard Rules ==
- DO NOT modify files outside GOAL.md "Scope" whitelist
- DO NOT modify files in GOAL.md "Non-goals" or "黑名单"
- DO NOT introduce new dependencies unless GOAL.md "Scope" explicitly allows
- DO NOT use `git add .` — explicitly list files
- DO NOT `git commit` (Claude will commit via clean-commit later)
- DO NOT `git push`
- DO NOT `git reset --hard`, `git rebase`, `git push --force` or any destructive op
- DO NOT add TODO/FIXME/mock unless GOAL.md allows
- DO NOT exceed Budget limits (files / tokens / time)

== Stop Conditions (write to STATUS.md and halt) ==
Trigger any → write `STOPPED: <reason>` to STATUS.md and halt:

- 3 consecutive verification failures
- File modification count > GOAL.md Budget
- Token usage > GOAL.md Budget (estimate from your context)
- Need to modify auth / payment / encryption code
- Need destructive git operation
- Need product decision (e.g., requirements conflict)
- Discovered SPEC contradiction
- Health check (external) signaled stall — wait for human

== Self-Reporting Cadence ==
Update STATUS.md AT MINIMUM every 15 minutes of wall-clock time, even if no milestone reached, with:
- "Still working on: <current step>"
- "Last verification: <ts>"
- "Next action: <what>"

This is critical because an external watcher monitors STATUS.md mtime to detect stalls.

== Critical: Honesty ==
- Do NOT claim a step is complete unless verification ACTUALLY passed
- Do NOT skip Required Commands to "save time"
- Do NOT write GOAL_DONE before all Acceptance Criteria are real-checked
- If you cannot complete a milestone, write to STATUS.md why and stop — do NOT silently proceed

Begin by reading AGENTS.md, then GOAL.md, then PLAN.md, then EVAL.md.
Then start Phase 1 Milestone 1.
```

## 调用方式

### 交互模式（最稳）

在 worktree 内：

```bash
codex --yolo
# 进入 TUI 后输入：
/goal <粘贴上述 prompt 全文>
```

或者把 prompt 存文件，让 Codex 读：

```bash
codex --yolo
# 在 TUI 内：
/goal Read .agent/tasks/<TASK_ID>/GOAL.md and execute per the workflow rules in references/goal-prompt.md
```

### app-server 模式（程序化）

```bash
codex app-server --capabilities experimentalApi &
SERVER_PID=$!

# 通过 HTTP / IPC 调 thread/goal/set
curl -X POST http://localhost:<port>/thread/goal/set \
  -H "Content-Type: application/json" \
  -d '{
    "thread_id": "<id>",
    "objective": "<上述 prompt 全文>",
    "token_budget": 500000
  }'
```

## 注意事项

- prompt 里的 `<TASK_ID>` 必须替换成真实 ID
- `<PROJECT_ROOT>` / `<WORKTREE_PATH>` 必须替换为绝对路径
- "GOAL_DONE" 字符串必须**精确匹配**（不能改大小写、不能加标点），因为 health-check.sh 用 grep 检测
- 如果项目栈不是 pnpm，prompt 里的"Required Commands"由 EVAL.md 决定，prompt 不重复列
