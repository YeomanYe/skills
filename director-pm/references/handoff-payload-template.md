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
| `tech_stack` | flow-project-bootstrap / director-architect | 项目主要技术栈（用于规则集选择）|
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
- `flow-project-bootstrap`（下游：project-prep / director-architect / frontend-design / director-design）
- `flow-project-finish`（下游：clean-commit / delivery-gate / director-design）
- `flow-ext-publish`（下游：ext-preflight / web-image）
- `flow-skill-dev`（下游：skill-creator / writing-skills / skill-behavior-test / sync-skills）
- `flow-skill-research`（下游：find-skills）

### director-* 角色型 agent
- `director-design`（上游：flow-project-finish / flow-project-bootstrap / director-frontend / delivery-gate，下游：huashu-design / web-image / ui-ux-pro-max；handoff 出口：director-frontend / web-design-guidelines / delivery-gate）
- `director-architect`（上游：flow-project-bootstrap / 用户直接触发，下游：动态匹配的 best-practice skill（无固定清单）/ clean-commit；handoff 出口：flow-project-finish / flow-ext-publish / director-design；替代：原 project-rules-design + flow-project-rules）
- `director-frontend`（上游：flow-dev-task / flow-project-finish / 用户直接触发；调用：director-design / web-image；handoff 出口：frontend-design plugin / delivery-gate）
- `director-promote`（上游：flow-project-finish / 用户直接触发；调用：director-design / web-image；内置 5 平台子模块 twitter/v2ex/appinn/sspai/producthunt；handoff 出口：flow-ext-publish）
- `director-ops`（上游：flow-dev-task / 用户直接触发；不调用其他 director-*；不可越界）

---

## Path-Based Payload Convention(2026-05 强制约束)

**问题**: 直接把 spec / diff / evidence / 大段文本内联进 payload → 上游主上下文污染 + 下游 prompt 体积爆炸。

**规则**: 所有"大内容"字段(估算 > 200 字符 / > 5 行)必须改用 path 引用,不内联。

### 字段命名约定

| 内联字段(❌) | path 替代(✅) | 说明 |
|---|---|---|
| `spec` | `spec_path` | spec 内容文件路径 |
| `diff` | `diff_path` | git diff 文件路径(`git diff > .agent/jobs/<job>/diffs.patch`) |
| `evidence` | `evidence_paths: []` | 截图/录屏/log 路径数组 |
| `goal` | `goal_path` | 目标说明文件 |
| `plan` | `plan_path` | 实现计划文件 |
| `code` | `code_paths: []` | 相关源码文件路径数组 |
| `logs` | `log_path` | 执行日志路径 |
| `report` | `report_path` 或 `artifact_path` | 完整 markdown 报告路径(对齐 output-contract-schema.md) |

### 例外(可保持内联)

以下小字段可继续内联,无需 path:
- `task_id` / `objective`(短句目标)
- `risk_class`(enum)
- 数字 / boolean / 短 enum
- `must_fix: []` / `should_fix: []` 数组(每项 < 100 字)
- 任何明显短小且 inline 更易读的字段

判定标准:**字段值如果 > 200 字符或 > 5 行 → 强制 path-based**;否则按可读性自由。

### path 文件存放规范

约定:
- 临时 handoff 文件落到 `.agent/jobs/<job-slug>/` 目录
- spec 文件落到 `.agent/specs/<slug>.md`(若是 todo-flow 等带 slug 的)
- 长期保存的 evidence 落到 `.agent/evidence/<date>/`
- `.agent/` 应已加入项目 `.gitignore`(若否,提醒调用方加)

### 上下游协议

- **上游写入**:把大内容写到约定 path,handoff payload 只填 `<name>_path` 字段
- **下游读取**:按 path 字段 `Read` 文件;只在真正需要时 read,不要 prefetch
- **subagent 派工**:遵循上述约定,prompt 里只放 path,subagent 自己 read

### 反例

```yaml
# ❌ 错: 内联 spec 全文
handoff:
  task_id: abc123
  spec: |
    # Implementation Spec
    
    ## Goal
    Implement feature X with the following requirements:
    1. Step one with detailed description
    2. Step two ...
    (continues for 200 lines)
  evidence:
    screenshot_data: <base64 1MB blob>
    diff: |
      diff --git a/foo.ts ...
      (300 lines of diff)
```

```yaml
# ✅ 对: path-based
handoff:
  task_id: abc123
  spec_path: .agent/specs/abc123.md
  evidence_paths:
    - .agent/evidence/2026-05-28/screenshot.png
  diff_path: .agent/jobs/abc123/diffs.patch
```

### 与 dispatcher-template.md / output-contract-schema.md 的关系

- 本 addendum 规定 **handoff payload** 字段层(上下游 skill 之间)
- `dispatcher-template.md`(若存在)规定 **subagent 派工 prompt** 层(prompt 字段名 + invoke directive)
- `output-contract-schema.md`(若存在)规定 **回流** 层(JSON 结果 + artifact_path)

三者协同:**path-based 是统一精神**——任何大内容都不应在 token 流(prompt / payload / output)里内联。
