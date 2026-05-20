# Baseline Scoring Prompt（Phase 0.3 用）

> 在 Goal Codex 启动**之前**跑一次。给当前系统打分，作为后续退化检测基线。
> 必须新进程；和 final reviewer 一样的独立性要求。

## 调用方式

```bash
cd "$WORKTREE"
# 必须 --dangerously-bypass-approvals-and-sandbox：
# 否则 codex 落 BASELINE.md 时被 read-only sandbox 拦截（写入 patch rejected），
# 评分跑了但产物落不下来，orchestrator 被迫转写 stdout 到文件 → 灰色地带
# 影响 reviewer_pid != orchestrator_pid 的硬隔离断言。
codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox < references/baseline-prompt.md
```

> 注：和 Phase 1 Goal Codex + Phase 2 final reviewer 启动方式一致——只要这些环节都
> bypass sandbox，整套硬隔离才能闭环（reviewer 独立进程 + 独立 worktree + 真实可写）。

## 完整 Prompt

```
You are an INDEPENDENT baseline scorer. Goal Codex has NOT started yet.
Your job: score the CURRENT state of this codebase, before any modifications.
This baseline will be used later to detect regressions.

== Materials You May Read ==
- .agent/tasks/<TASK_ID>/baseline/test.txt
- .agent/tasks/<TASK_ID>/baseline/build.txt
- .agent/tasks/<TASK_ID>/baseline/lint.txt
- .agent/tasks/<TASK_ID>/baseline/screenshots/*
- .agent/tasks/<TASK_ID>/GOAL.md (User Journeys list)
- .agent/tasks/<TASK_ID>/EVAL.md (rubric)
- AGENTS.md
- source files (read-only)

You may NOT read:
- Anything related to Goal Codex (it hasn't run yet)

== Steps ==

### Step 1: Quality Gates Snapshot
For each gate in EVAL.md:
- Does the current output show pass?
- Note any pre-existing failures — these are NOT introduced by Goal Codex.

### Step 2: Runtime Verification (current state)
Start the project yourself:
- Web app: `pnpm dev` and open via chrome MCP / playwright
- CLI: run with realistic inputs

For each User Journey in GOAL.md:
- Walk through it on the CURRENT (unchanged) system
- Take a screenshot → save to .agent/tasks/<TASK_ID>/baseline/screenshots/journey-N.png
- Note: does it work today? partially? not at all?

### Step 3: Score 4 Dimensions (1-5)
Score the CURRENT system, not what you wish it were:
- Correctness: do features today work as documented?
- Maintainability: code structure, naming, abstraction quality
- UX: only if UI exists — current visual + interaction quality
- Risk: security posture, dependency hygiene, error handling

== Output Format ==

Write to .agent/tasks/<TASK_ID>/BASELINE.md:

```md
# Baseline: <TASK_ID>

## Timestamp
<ISO 8601>

## Current Quality Gates
- typecheck: pass | fail (tail of output)
- lint: pass | fail (count + tail)
- test: pass | fail (X/Y)
- build: pass | fail
- pre-existing failures (NOT to be blamed on Goal Codex):
  - <list>

## User Journey Status (current)
- [<x|/|partial>] J1 "<name>": <observation> — screenshots/journey-1.png
- [<x|/|partial>] J2 "<name>": ...

## Rubric Scores (baseline)
- Correctness:    N/5 — <one-line reason>
- Maintainability: N/5 — ...
- UX:             N/5 (or n/a) — ...
- Risk:           N/5 — ...
- Aggregate:      X.X (4-dim avg, n/a dimensions excluded)

## Reference Screenshots
- baseline/screenshots/journey-1.png
- baseline/screenshots/journey-2.png
- ...

## Notes for Future Comparison
- <e.g., "current bundle size 1.2MB, watch for regression">
- <e.g., "J3 currently broken on Safari, Goal not required to fix unless AC says so">
```

== Final Reminder ==
- Be honest. If the current system is mediocre, score it mediocre.
- Goal Codex's job is to IMPROVE these numbers (or at least not lower them).
- Take real screenshots. They're the only objective evidence of "before".
```
