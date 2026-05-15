# Review Audit JSONL Schema

每次 review（baseline / mini-review / final-review）都必须写一行 JSONL 到 `.agent/tasks/<id>/review-audit/round-<round>.jsonl`，并更新 `INDEX.md`（人类可读摘要）。

目的：
- **复盘**：reviewer 反复保守 / Must Fix 反复触某条 AC 边界 → 能从 audit log 挖出来
- **改 prompt**：发现某种 false-positive 模式 → 用作 prompt 改进证据
- **改 GOAL**：reviewer 反复触某条 AC 边界 → AC 写得不清楚
- **守独立性证据**：reviewer_pid / reviewer_thread_id 留证据，事后能验证两 Codex 没串扰

## JSONL 字段

每行一个 JSON object：

```json
{
  "round": "milestone-3" | "1" | "2",
  "type": "baseline" | "mini-review" | "final-review",
  "ts": "2026-05-15T10:23:45Z",

  "reviewer_pid": 12345,
  "reviewer_thread_id": "t-abc123",
  "reviewer_launch_cmd": "codex exec --cd /path/review-readonly-r2",
  "reviewer_worktree": "/path/review-readonly-r2",
  "reviewer_worktree_sha": "<git commit sha that reviewer saw>",

  "goal_md_sha": "<sha256 of GOAL.md reviewer read>",
  "eval_md_sha": "<sha256 of EVAL.md reviewer read>",

  "verdict": "pass" | "fail" | "baseline-recorded",
  "scores": {
    "correctness": 4,
    "maintainability": 4,
    "ux": 4,
    "risk": 5,
    "layout_stability": 4,
    "small_popup_density": 5
  },
  "aggregate": 4.33,

  "delta_vs_baseline": {
    "correctness": 0, "maintainability": 1, "ux": 0, "risk": 0,
    "aggregate": 0.25
  },

  "must_fix": [
    {
      "idx": 0,
      "file": "src/components/Foo.tsx",
      "issue": "function exceeds 80 lines",
      "why_blocking": "AC6 violation"
    },
    {
      "idx": 1,
      "file": "src/utils/sanitize.ts",
      "issue": "sanitizeMailHtml exceeds 80 lines",
      "why_blocking": "AC6 violation"
    }
  ],
  "should_fix": [
    {"idx": 0, "file": "...", "issue": "...", "rationale": "..."}
  ],

  "new_rules_proposed": [
    "Layout Stability: success feedback should not displace footer"
  ],

  "orchestrator_arbitration": {
    "must_fix_accepted": [0],
    "must_fix_overridden": [1],
    "override_reasons": [
      "src/utils/sanitize.ts is in GOAL.md Non-goals (security-critical), AC6 yields to blacklist"
    ],
    "should_fix_planned": [0],
    "snapshot_decision": "create-new-tag" | "skip-not-new-high",
    "highest_tag_so_far": "snapshot-milestone-3-4.25"
  },

  "runtime_evidence": {
    "user_journeys_passed": ["J1", "J2"],
    "user_journeys_failed": ["J3"],
    "screenshots_taken": 8,
    "reviewer_fresh_screenshots_match_goal": true
  },

  "source_file": ".agent/tasks/<id>/reviews/round-2/REVIEW.md"
}
```

## 字段语义

- `round` — milestone 名（mini-review）或轮次序号（final-review）
- `type` — baseline / mini-review / final-review，决定如何解析 source_file
- `reviewer_pid / thread_id / worktree` — **独立性证据**。事后能验证 ≠ goal_pid 且 ≠ orchestrator_pid
- `goal_md_sha / eval_md_sha` — 防止 reviewer 看到的是过时版本
- `must_fix.idx` — orchestrator_arbitration 引用用
- `orchestrator_arbitration` — orchestrator 仲裁决定 + 理由（关键字段，复盘用）
- `new_rules_proposed` — reviewer 提出的新评分维度建议（Phase 0 之后通过这条把维度沉淀回 EVAL.md）
- `snapshot_decision` — 是否创建新 snapshot tag

## INDEX.md 摘要

`write-audit.sh` 自动维护一份人类可读 INDEX.md：

```md
# Review Audit Index — <TASK_ID>

| Round | Type | Verdict | Aggregate | Reviewer PID | TS |
|---|---|---|---|---|---|
| baseline | baseline | baseline-recorded | 4.0 | 23456 | 2026-05-14T10:00:00Z |
| milestone-1 | mini-review | n/a | 4.0 | 23457 | 2026-05-14T11:30:00Z |
| milestone-2 | mini-review | n/a | 4.0 | 23458 | 2026-05-14T13:00:00Z |
| milestone-3 | mini-review | n/a | 4.25 | 23459 | 2026-05-14T15:00:00Z (HIGHEST) |
| 1 | final-review | fail | 4.0 | 23460 | 2026-05-14T17:00:00Z |
| 2 | final-review | fail | 4.0 | 23461 | 2026-05-14T19:00:00Z |
| 3 | final-review | pass | 4.25 | 23462 | 2026-05-14T21:00:00Z |

**Highest snapshot**: snapshot-milestone-3-4.25
**Final commit basis**: highest snapshot
**Override count**: 2 (round 2: sanitize.ts, round 3: oauth-flow.ts — both Non-goals)
**New rules proposed**: 1 ("Layout Stability")
```

## 复盘查询范例

```bash
# 列出所有 orchestrator override 的 Must Fix
jq -s '[.[] | select(.orchestrator_arbitration.must_fix_overridden | length > 0)
        | {round, file: .must_fix[.orchestrator_arbitration.must_fix_overridden[0]].file,
           reason: .orchestrator_arbitration.override_reasons[0]}]' \
   review-audit/round-*.jsonl

# 查 reviewer 是否串了 thread
jq -s '[.[] | .reviewer_thread_id] | unique | length' review-audit/round-*.jsonl
# 应该 = round 数；少了说明有 reviewer 复用了 thread → 隔离失效

# 哪些维度评分波动最大
jq -s 'map(.scores) | transpose' review-audit/round-*.jsonl
```
