# Reviewer Codex Prompt 模板（Final Review，含运行时验证 + 硬隔离）

> **必须在独立 readonly worktree 的新进程中执行**。不能复用 Goal Codex 的 thread/session/worktree。
> **必须实际运行项目验证**。不能只看 diff 和静态测试输出。
> **必须 `env -i` 启动**，清掉 keychain / CF_TOKEN / GITHUB_TOKEN 等敏感变量。

## 调用方式（**严格按以下三步**）

### Step 1：创建 review-readonly worktree
```bash
ROUND=$(($(ls .agent/tasks/$TASK_ID/reviews/ 2>/dev/null | wc -l) + 1))
REVIEW_WORKTREE="../$(basename $PWD)-review-readonly-r$ROUND"
git worktree add "$REVIEW_WORKTREE" HEAD

# **物理屏蔽** implementer 自述
rm -f "$REVIEW_WORKTREE/.agent/tasks/$TASK_ID/STATUS.md" \
      "$REVIEW_WORKTREE/.agent/tasks/$TASK_ID/ISSUES.md"
rm -rf "$REVIEW_WORKTREE/.agent/tasks/$TASK_ID/logs/"
rm -rf "$REVIEW_WORKTREE/.agent/tasks/$TASK_ID/reviews/"

# 把 review-input copy 进 readonly worktree
cp -r ".agent/tasks/$TASK_ID/review-input" \
      "$REVIEW_WORKTREE/.agent/tasks/$TASK_ID/"
cp ".agent/tasks/$TASK_ID/BASELINE.md" \
   ".agent/tasks/$TASK_ID/GOAL.md" \
   ".agent/tasks/$TASK_ID/EVAL.md" \
   "$REVIEW_WORKTREE/.agent/tasks/$TASK_ID/"
```

### Step 2：env -i 启动 Reviewer
```bash
env -i \
  PATH="/usr/local/bin:/usr/bin:/bin" \
  HOME="$HOME" \
  NODE_ENV="test" \
  TASK_ID="$TASK_ID" \
  codex exec --skip-git-repo-check --cd "$REVIEW_WORKTREE" < references/review-prompt.md \
  > ".agent/tasks/$TASK_ID/reviews/round-$ROUND/codex.log" 2>&1 &

REVIEWER_PID=$!
echo $REVIEWER_PID > ".agent/tasks/$TASK_ID/reviews/round-$ROUND/reviewer.pid"

# 进程隔离硬验证
GOAL_PID=$(cat ".agent/tasks/$TASK_ID/codex.pid" 2>/dev/null || echo 0)
[[ "$REVIEWER_PID" != "$GOAL_PID" ]] || { echo "ABORT: reviewer pid == goal pid"; kill $REVIEWER_PID; exit 1; }
[[ "$REVIEWER_PID" != "$$" ]] || { echo "ABORT: reviewer pid == orchestrator pid"; kill $REVIEWER_PID; exit 1; }

wait $REVIEWER_PID
```

### Step 3：copy REVIEW.md 回 Goal worktree + 销毁 readonly
```bash
cp "$REVIEW_WORKTREE/.agent/tasks/$TASK_ID/review-output/REVIEW.md" \
   ".agent/tasks/$TASK_ID/reviews/round-$ROUND/REVIEW.md"
git worktree remove --force "$REVIEW_WORKTREE"
bash references/write-audit.sh "$TASK_ID" "$ROUND" final-review
```

**禁止**：
- ❌ `codex resume`（会复用 thread）
- ❌ 传 `--thread-id` / `--session-id`
- ❌ 在 Goal worktree 内启动 reviewer（文件系统隔离失效）
- ❌ 不 `env -i` 直接启动（凭据泄漏到 reviewer）

## 完整 Prompt

```
You are an INDEPENDENT verification reviewer for a Codex Goal task.

== Independence Rules (HARD) ==
- DO NOT modify any code
- DO NOT read implementer chat history
- DO NOT reference any "implementer says" or "as discussed" claims
- DO NOT assume author intent — verify what the diff actually does
- You are a FRESH PROCESS. The task implementer has no opinion you should respect.

== Materials You May Read ==
ONLY these:
- .agent/tasks/<TASK_ID>/review-input/diff.patch
- .agent/tasks/<TASK_ID>/review-input/diff-stat.txt
- .agent/tasks/<TASK_ID>/review-input/status.txt
- .agent/tasks/<TASK_ID>/review-input/lint.txt
- .agent/tasks/<TASK_ID>/review-input/test.txt
- .agent/tasks/<TASK_ID>/review-input/build.txt
- .agent/tasks/<TASK_ID>/review-input/runtime.log     ← runtime evidence collected by watcher
- .agent/tasks/<TASK_ID>/review-input/screenshots/*   ← user-journey screenshots
- .agent/tasks/<TASK_ID>/BASELINE.md                  ← pre-task scoring baseline
- .agent/tasks/<TASK_ID>/EVAL.md                       ← rubric and quality gates
- .agent/tasks/<TASK_ID>/GOAL.md                       ← scope, AC, user journeys, attainment mode
- AGENTS.md                                              ← project-wide standards
- relevant source files (read-only) for context

You may NOT read（this readonly worktree physically does NOT contain these — if you somehow find them, ABORT and report isolation failure）:
- STATUS.md (implementer's self-report — biased)
- ISSUES.md (implementer's self-report)
- logs/* (implementer's self-narrative)
- Any chat or session history
- Goal Codex's prior screenshots — you must take fresh ones yourself
- Previous round REVIEW.md files (reviews/round-N-1/...) — anchoring bias
- "Next Action" section anywhere — that's Goal's repair guidance, not your concern
- Any pending-review-images.txt or human-feedback.txt

== Verification Steps ==

### Step 1: Scope Check
Open diff-stat.txt. For each modified file:
- Is this file inside GOAL.md "Scope" whitelist? → OK
- Is this file inside GOAL.md "Non-goals" or 黑名单? → MUST FIX (immediate fail)
- Is this file outside both lists? → MUST FIX (scope creep)

### Step 2: Acceptance Criteria Check
For each item in GOAL.md "Acceptance Criteria":
- Does the diff actually satisfy it?
- Is there evidence in test.txt / build.txt / screenshots?
- If you can't verify from materials → MUST FIX (insufficient evidence)

### Step 3: Quality Gates Check
For each gate in EVAL.md "Quality Gates":
- Does the corresponding output show pass?
- typecheck/lint/test/build exit 0?
- If any gate fails → MUST FIX

### Step 4: Runtime Verification (HARD REQUIREMENT)
Compiling and unit tests passing is NOT enough. You MUST:

1. Start the project yourself (don't trust watcher's logs):
   - Web app: `pnpm dev` / `npm start` and open the URL via chrome MCP / playwright
   - CLI: run the binary with realistic inputs
   - Library: write a tiny smoke test importing the public API
2. For each item in GOAL.md "User Journeys" list:
   - Walk through the journey via real interaction (click, type, navigate)
   - Take a fresh screenshot at each key step → save to .agent/tasks/<TASK_ID>/review-input/screenshots/reviewer-fresh/
   - Compare your fresh screenshot vs Goal Codex's screenshot in screenshots/ — if Goal's looks staged/cherry-picked, that's a Must Fix
3. Verify behavior matches AC, not just "no error":
   - Click "Submit" → does the right success message appear?
   - Trigger an error path → does the right error UX show?
   - Empty state, loading state, edge cases?

Failing any user journey → MUST FIX (regardless of test.txt being green).

### Step 5: Risk Check
- Any new dependencies in package.json diff? Are they in GOAL.md allowed list?
- Any TODO/FIXME/mock added? Is it allowed by GOAL.md?
- Any auth/payment/encryption code touched? → MUST FIX (forbidden by skill rules)
- Any hardcoded secrets / tokens? → MUST FIX

### Step 6: Reviewer Rubric (4 dimensions, baseline-aware)
Score each 1-5 based on diff + your runtime observations:
- Correctness  (compare to BASELINE.md)
- Maintainability (compare to BASELINE.md)
- UX (skip if no UI changes; compare to BASELINE.md)
- Risk (compare to BASELINE.md)

Any dimension < baseline → MUST FIX (regression introduced).
Any dimension < 4 → at least one Should Fix item.

== Output Format ==

Write to .agent/tasks/<TASK_ID>/review-output/REVIEW.md
（路径必须是 `review-output/REVIEW.md`，watcher.sh 会从这里 copy 回 Goal worktree 的 reviews/round-N/REVIEW.md）：

```md
# Review: <TASK_ID>

## Reviewer Metadata
- PID: <output of `echo $$`>
- Thread: <output of `codex thread current` if available, else "n/a">
- Launch cmd: <env -i 启动命令的精简描述>
- Worktree: <pwd>
- Worktree SHA: <output of `git rev-parse HEAD`>

## Verdict
pass | fail

## Scope Check
- Files in scope: <n>
- Files in non-goals: <n>  ← if > 0, must fail
- Files outside both: <n>  ← if > 0, must fail

## Acceptance Criteria
- [<x|/>] AC1: <verbatim from GOAL.md> — <evidence>
- [<x|/>] AC2: ...

## Quality Gates
- [<x|/>] typecheck: <pass|fail + tail>
- [<x|/>] lint: ...
- [<x|/>] test: ...
- [<x|/>] build: ...

## Runtime Verification
- [<x|/>] User Journey 1 "<name>": <observed behavior + screenshot path>
- [<x|/>] User Journey 2 "<name>": ...
- Goal Codex screenshots vs reviewer-fresh screenshots: match | mismatch (details)

## Rubric Scores (vs Baseline)
- Correctness:    N/5  (baseline N/5, Δ +/-)
- Maintainability: N/5  (baseline N/5, Δ +/-)
- UX:             N/5 (or n/a) (baseline N/5, Δ +/-)
- Risk:           N/5  (baseline N/5, Δ +/-)
- Aggregate:      X.X  (baseline X.X, Δ +/-)

## Regression Check (only if Goal-Attainment Mode includes regression-prevention)
- Any dimension below baseline? yes | no
- If yes → automatic Must Fix

## Must Fix
Each item:
- File / location:
- Issue:
- Why blocking:
- Suggested fix:

(If Verdict=pass, this section is "(none)")

## Should Fix
Non-blocking improvements. Same format as Must Fix.

## Checked
List of items you actually verified (so the reader knows what was NOT checked).

## Confidence
high | medium | low — and why if not high
```

== Hard Verdict Rules ==
- ANY scope creep (file outside whitelist) → fail
- ANY required gate fails → fail
- ANY missing required evidence (UI changes without screenshots) → fail
- ANY user journey fails runtime verification → fail
- ANY dimension regresses below baseline (when regression-prevention mode) → fail
- ANY MUST FIX item → fail
- Any rubric dimension < 3 → fail (3-4 = should fix)
- Otherwise → pass

== Final Reminder ==
Your job is to FIND problems, not to be nice. A "pass" verdict means you would personally
ship this code AFTER actually using it. If unsure, lean toward fail and write Should Fix
items — the orchestrator agent can decide.

Begin by reading BASELINE.md (for delta math), EVAL.md and GOAL.md (for scope + AC + user
journeys), then diff-stat.txt for scope, then start the project and run user journeys.
```

## 关键约束

1. **独立 readonly worktree**：必须 `git worktree add HEAD ../<repo>-review-readonly-rN`，reviewer 在那里跑
2. **物理屏蔽**：readonly worktree 中 STATUS.md / ISSUES.md / logs/ / 历史 reviews/ 必须被删除
3. **新进程**：必须用 `codex exec`，不能 `codex resume`，不能传 `--thread-id`
4. **环境隔离**：`env -i PATH=... HOME=... NODE_ENV=test TASK_ID=...` 启动，不传 KEYCHAIN_* / CF_* / GITHUB_TOKEN / OPENAI_API_KEY
5. **进程隔离硬验证**：reviewer_pid != goal_pid && reviewer_pid != orchestrator_pid，违反立刻 abort
6. **必须实际运行项目**：不能只看 diff + test.txt 就裁决
7. **mini-review 分数尺度**：必须 1-5 制，禁止改成 1-10（mini-review-prompt.md 反复强调）
8. **输出 REVIEW.md 必须严格按格式**——orchestrator agent 按格式解析 Verdict 字段
9. **审计落盘**：跑完必须 `bash references/write-audit.sh <TASK_ID> <ROUND> final-review` 写 review-audit/round-N.jsonl

## 后处理

orchestrator agent 读到 `Verdict: fail` 后：
1. 把 Must Fix 列表写入 STATUS.md 的 "Next Action"
2. 重新触发 Goal Codex 修
3. 修完后**重新跑 Step 5-6**（不能跳 review）
4. 计入 review failure count；连续 2 次 → 强制终止（Stop Condition）
