# Milestone Mini-Review Prompt（Step 4.5 用）

> 每个 milestone 由 watcher 触发。轻量评分，不写 Must Fix（那是 final review 的事）。
> 目标：快速给当前进展打分，让人类在 IM 中校准。
> 必须新进程；和 final reviewer 一样的独立性要求。

## 调用方式

```bash
cd "$WORKTREE"
MILESTONE_NAME="<from STATUS.md>"
codex exec --skip-git-repo-check < references/milestone-review-prompt.md
```

## 完整 Prompt

```
You are a milestone scorer for an in-progress Codex Goal task.
Your job: quickly score the CURRENT state and emit a JSON for trend tracking.
This is NOT the final review — keep it light, no Must Fix lists.

== Materials You May Read ==
- .agent/tasks/<TASK_ID>/scores/<MILESTONE_NAME>/test.txt
- .agent/tasks/<TASK_ID>/scores/<MILESTONE_NAME>/build.txt
- .agent/tasks/<TASK_ID>/scores/<MILESTONE_NAME>/lint.txt
- .agent/tasks/<TASK_ID>/scores/<MILESTONE_NAME>/screenshots/*
- .agent/tasks/<TASK_ID>/BASELINE.md   ← for delta math
- .agent/tasks/<TASK_ID>/GOAL.md
- .agent/tasks/<TASK_ID>/EVAL.md
- AGENTS.md
- source files (read-only)
- git diff main (read-only via shell)

You may NOT read:
- STATUS.md
- ISSUES.md
- logs/*

== Steps ==

### Step 1: Diff Sanity (1 min)
- `git diff --stat main` — files in scope?
- New deps in package.json? — flag if unauthorized

### Step 2: Quality Gates Snapshot (use existing outputs, don't re-run)
- Read scores/<MILESTONE_NAME>/test.txt etc.
- Note which gates pass

### Step 3: Sample Runtime Check (5 min cap)
Pick **2 most-affected user journeys** from GOAL.md (based on diff):
- Run them via chrome MCP / playwright
- 1 screenshot per journey → scores/<MILESTONE_NAME>/screenshots/

Don't try to verify all journeys — that's final review's job.

### Step 4: Score 4 Dimensions (1-5)
Same rubric as baseline-prompt.md.

== Output Format ==

Write to .agent/tasks/<TASK_ID>/scores/<MILESTONE_NAME>.json:

```json
{
  "milestone": "<MILESTONE_NAME>",
  "timestamp": "<ISO 8601>",
  "scores": {
    "correctness": 4,
    "maintainability": 4,
    "ux": 4,
    "risk": 5
  },
  "aggregate": 4.25,
  "delta_vs_baseline": {
    "correctness": 0,
    "maintainability": 1,
    "ux": 0,
    "risk": 0,
    "aggregate": 0.25
  },
  "gates": {
    "typecheck": "pass",
    "lint": "pass",
    "test": "pass",
    "build": "pass"
  },
  "sampled_journeys": [
    {"name": "J1", "result": "pass", "screenshot": "scores/<MILESTONE_NAME>/screenshots/j1.png"},
    {"name": "J3", "result": "partial", "screenshot": "scores/<MILESTONE_NAME>/screenshots/j3.png"}
  ],
  "notes": "<one paragraph: what improved, what's worrying>"
}
```

== Final Reminder ==
- Time-box this to 10 minutes total. Final review is the comprehensive pass.
- Output JSON is read by score-diff.py — keep field names exactly as above.
```
