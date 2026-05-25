# Codex Goal Task Report — Output Contract Template

> 本文件是 `SKILL.md` 的 Output Contract 完整 schema。Phase 3 delivery 完成后
> orchestrator **必须**按本模板输出 task report。
>
> 调用方式:`SKILL.md` Output Contract 段引用本文件即可,模板字段不在 SKILL.md
> 主干重复(避免双源维护漂移)。

## Schema

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

## 字段必填规则

| 段 | 必填 | 触发条件 |
|---|---|---|
| Task / Phase 0 Contract / Baseline / Execution / Review / Delivery / 结论 | ✅ 任何任务 | 全部 |
| UI Screenshots | 仅 `is_ui_task=true` | GOAL.md 字段触发 |
| Custom Score Dimensions / 扩展维度评分 | 仅 GOAL.md 声明了扩展维度 | EVAL.md 含 extras |
| Reviewer roster 含 `not invoked` | 当 extra reviewer 在 Reviewer Plan 里但实际未跑(timeout / 不适用) | 必须显式标注,不允许省略 |

## 输出位置

- 落盘:`.agent/tasks/$TASK_ID/TASK-REPORT.md`
- 同时:orchestrator 在对话里完整复述(或 IM 推送),不允许只写盘不口播——
  人类裁决依赖 inline report,不会主动 cat 文件
