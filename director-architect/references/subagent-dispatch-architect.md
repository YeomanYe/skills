# director-architect — Subagent 派工规范

> 派 subagent 时按 `references/dispatcher-template.md` 完整模板填字段，本文件补充 director-architect 特定字段。

## 何时派 subagent

本 skill 主要**自己跑**联合评估（读匹配到的 best-practice skill 的 description + SKILL.md 后自己代入判断），通常**不派 subagent**。仅当用户明示"让某个 best-practice skill 真跑一遍 review"才派。

## 必填扩展字段（基线 JSON 之上）

- `findings`: list[string] — 该 skill 在当前项目上发现的问题
- `suggestions`: list[string] — 该 skill 给出的修复建议

## 固定参数

| 参数 | 值 |
|---|---|
| 必须调用的下游 skill | `<best-practice-skill>`（自身默认 mode） |
| read_only scope | 项目根 + 现有规则文件清单 + 识别到的技术栈 |
| write_to | `.agent/jobs/architect-review-<skill-name>/` |
| 失败处理 | `failed_continue_main`（单个 skill 失败不影响其他评估） |
| 超时 | 5 分钟 |

## 约束

- subagent **不**直接改文件；落地由本 skill 在 Land Phase 统一做，subagent 仅返回 findings/suggestions
