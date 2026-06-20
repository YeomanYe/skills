# director-architect — Upstream Handoff Payload

> 通用字段见 `references/handoff-payload-template.md`（共享）。
> 本文件记录上游 orchestrator 调 director-architect 时必须/推荐/可选传的专属字段。

## 字段表

| 字段 | 必填 | 说明 |
|---|---|---|
| `task_id` | ✅ | 任务唯一标识 |
| `objective` | ✅ | 一句话目标（"梳理规则" / "审规则" / "按 X 项目对齐"） |
| `risk_class` | ✅ | low / medium / high（high = 涉及主入口 CONTRIBUTING / 跨多个 domain 重构） |
| `tech_stack` | 推荐 | 项目已识别的技术栈（避免本 skill 重复探测）；**greenfield 且上游未传 → 本 skill 在 Step 2 自做粗粒度主栈选型** |
| `project_root` | 推荐 | 项目根路径 |
| `reference_project` | 可选 | 用户指定的参考项目路径或 URL |
| `prior_context` | 可选 | 上游 Context Harvest 的 git/branch/diff 状态 |
| `approval_inherited_from_orchestrator` | 可选（bootstrap 专用） | `true` 表示上游编排器（如 `flow-project-bootstrap` Stage 1）已让用户批过总设计，本 skill 在 Approval Gate 处可**自动 yes** 直接进入 Land Phase。**缺失或为 false** → 仍走完整 Approval Gate。**唯一允许跳过 Approval Gate 的开关**。 |

## 使用规则

- **如果上游已传**：本 skill 不重复探测，直接用。
- **如果上游未传**：本 skill 自己探测（Step 1 + 2）。
- 已传字段 + Step 1 探测到的事实 → **禁止在 Question Gate 再问**。
