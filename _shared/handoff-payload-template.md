# Handoff Payload Template（flow-* skill 共享）

所有 flow-* 编排 skill 之间的 handoff 应该遵循同一套字段集，避免下游 skill 重复追问已知信息。

## 通用字段

### 必填

| 字段 | 类型 | 说明 |
|---|---|---|
| `task_id` | string | 任务唯一标识（推荐 `<date>-<slug>`）|
| `objective` | string | 一句话目标 |
| `risk_class` | enum | `low` / `medium` / `high`（high 触发额外验证步骤）|

### 推荐

| 字段 | 类型 | 说明 |
|---|---|---|
| `suggested_scope` | list[path] | 推断的 scope 白名单（候选 Scope）|
| `suggested_non_goals` | list[path] | 黑名单（明确不动的范围）|
| `acceptance_hints` | list[string] | 用户口语化 AC，下游量化时用 |
| `time_budget_hours` | number | 用户暗示的时间预算 |
| `verification_commands` | list[string] | 已知的验证命令（test / lint / build） |
| `context_files` | list[path] | 上下游交接的关键文件路径 |
| `prior_context` | object | 上游 Context Harvest 收集到的 git/branch/diff 状态 |

### 任务类型相关（按需）

| 字段 | 用在 | 说明 |
|---|---|---|
| `is_ui_task` | flow-codex-goal / director-frontend | bool；true 时激活 UI 截图协议 + 状态走查 |
| `attainment_mode_hint` | flow-codex-goal | 已推断的 mode (`threshold` / `no-improvement-N` / `regression-prevention` / `hybrid`) |
| `run_mode` | flow-codex-goal | `CLI-YOLO` / `CLI-EXEC` / `SUBAGENT` |
| `tech_stack` | flow-project-bootstrap / flow-project-rules | 项目主要技术栈（用于规则集选择）|
| `platform` | flow-ext-publish | `chrome` / `firefox` / `edge`（决定提交渠道）|

## 使用规则

1. **上游必须传** 必填字段 + 推荐字段中有信息的部分
2. **下游必须先读** handoff payload，再决定是否问用户（已传的字段不再问）
3. **不允许下游重复追问** 已传字段（除非字段值含模糊量词，需澄清）
4. **未列在模板里的字段** 算扩展字段，下游可以忽略

## 引用方式

各 flow-* skill 在 `## Relationship to Other Skills` 段加：

```md
### Upstream Handoff Payload
从上游 skill 接收的 handoff 字段统一遵循 `_shared/handoff-payload-template.md`。
本 skill 必须读取以下字段：<列出依赖的字段>。
```

## 已使用本模板的 skill

### flow-* 编排器
- `flow-codex-goal`（上游：flow-dev-task）
- `flow-dev-task`（上游：用户 / flow-project-bootstrap，下游：flow-codex-goal / clean-commit）
- `flow-project-bootstrap`（下游：project-prep / flow-project-rules / frontend-design / director-design）
- `flow-project-finish`（下游：clean-commit / delivery-gate / director-design）
- `flow-project-rules`（上游：flow-project-bootstrap，下游：project-rules-design）
- `flow-ext-publish`（下游：ext-preflight / web-image）
- `flow-skill-dev`（下游：skill-creator / writing-skills / skill-behavior-test / sync-skills）
- `flow-skill-research`（下游：find-skills）

### director-* 角色型 agent
- `director-design`（上游：flow-project-finish / flow-project-bootstrap / director-frontend / delivery-gate，下游：huashu-design / web-image / ui-ux-pro-max；handoff 出口：director-frontend / web-design-guidelines / delivery-gate）
- `director-frontend`（上游：flow-dev-task / flow-project-finish / 用户直接触发；调用：director-design / web-image；handoff 出口：frontend-design plugin / delivery-gate）
- `director-promote`（上游：flow-project-finish / 用户直接触发；调用：director-design / web-image；内置 5 平台子模块 twitter/v2ex/appinn/sspai/producthunt；handoff 出口：flow-ext-publish）
- `director-ops`（上游：flow-dev-task / 用户直接触发；不调用其他 director-*；不可越界）
