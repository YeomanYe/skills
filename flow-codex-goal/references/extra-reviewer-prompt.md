# Extra Reviewer 派工 Prompt 模板

SKILL.md Step 2.3.2 引用本文件。watcher.sh 调用
`launch-extra-reviewer.sh` 时按本模板组装 subagent prompt。

**通用字段集 + subagent 行为约束遵循 `dispatcher-template.md`**。
**并行 ROI / reduce 方式遵循 `parallelization-template.md`**。
本文件只列 flow-codex-goal 特定字段。

---

## Prompt 模板

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

---

## flow-codex-goal 特定字段

| 字段 | 来源 | 注入方式 |
|---|---|---|
| `<reviewer-name>` | GOAL.md `extra_reviewers[].name` | 模板占位 |
| `<N>` | 当前 round 序号 | watcher 计数 |
| `本 reviewer 负责的检查维度` | GOAL.md `extra_reviewers[].checks`（Step 0.1 第 5 项确认） | yq 读后注入 |
| 输出 JSON schema | 见上方"返回 JSON" 行 | 与 `output-contract-schema.md` 基线字段叠加 reviewer 专属字段 |

---

## 内置 Reviewer Codex 同源

`review-prompt.md` 同样注入 `REVIEWER-PLAN.md` 里它的 `checks` 行——内置
reviewer 也只审被认领的维度，不再越界。

派工脚本：
- 内置：Step 2.3.1 中 `codex exec ... < review-prompt.md`
- Extra：`launch-extra-reviewer.sh "$TASK_ID" "$ROUND" "$reviewer_name"`

两个路径都遵循 Two-Codex Hard Isolation（pid / session / fs / env 四隔离）。
