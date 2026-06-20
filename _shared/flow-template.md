# flow-* 编排型 skill 元规范

> 本文件定义 **flow-\*** 命名空间下所有编排型 skill 的**标准结构**。
> 跟 `director-template.md` 平行(那是角色型 skill 元规范,本文件是编排型流水线元规范)。
> 新建 flow-* / 改造现有 flow-* 都必须对齐本规范。当前 7 个 flow-* 应逐步对齐本模板。

## 1. 命名空间含义

`flow-*` 是**编排型 skill**(workflow orchestrator),区别于 `director-*` 角色型 skill。

| 类型 | 命名 | 本质 | 例子 |
|---|---|---|---|
| **编排型** | `flow-<workflow>` | 一条流水线:**串联多个 skill,推任务从起点到终点** | flow-dev-task / flow-project-finish / flow-codex-goal |
| **角色型** | `director-<role>` | 一个虚拟专家:**专业判断 + 自己干活 + 调度同领域工具** | director-design / director-frontend / director-promote / director-ops / director-architect |
| **工具型** | `<tool>` | 单一能力,被 director-* 或 flow-* 调用 | clean-commit / web-image / delivery-gate |

## 2. 当前 7 个 flow-* 现状(2026-06 快照)

| Skill | 主任务 | 主体 stage | 典型上下游 |
|---|---|---|---|
| `flow-dev-task` | 单 dev 任务 e2e(intake → plan → code → test → commit) | dev | 上游:user / flow-project-bootstrap;下游:flow-codex-goal(长任务切走) |
| `flow-codex-goal` | 无人值守长跑 Codex(双 reviewer + snapshot + budget) | dev | 上游:flow-dev-task Stage 5 切;下游:clean-commit |
| `flow-project-bootstrap` | 项目启动多 stage 链(MVP + 规范 + 设计候选) | bootstrap | 上游:user;下游:flow-dev-task / director-architect / director-design |
| `flow-project-finish` | 项目收尾(doc sync / README / landing / delivery-gate / commit) | finish | 上游:user;下游:director-* / delivery-gate / clean-commit |
| `flow-ext-publish` | 浏览器扩展上架 e2e | finish | 上游:user / ext-preflight;下游:director-promote(素材)/ store-upload |
| `flow-skill-dev` | 新建 / 改 skill 完整链 | meta | 上游:user / experience-summary L6/L7;下游:writing-skills / skill-behavior-test / skill-integration-test / sync-skills |
| `flow-skill-research` | 调研现有 skill 域(搜索 → 筛选 → 推荐 → 装) | meta | 上游:user / experience-summary L?;下游:find-skills / 浏览器 / 安装 |

未来候选:`flow-incident-response` / `flow-onboarding` / `flow-migration`。

## 3. 必备 14 段结构(SKILL.md)

每个 flow-* 的 `SKILL.md` **应**含以下段(顺序 + 命名严格一致)。新建必须全有;现存 skill 逐步对齐。

| 序 | 段 | 必填 | 内容 |
|---|---|---|---|
| 1 | frontmatter `description` | ✅ | 触发短语(中英文)+ 反例(Do NOT use)+ 上游/下游 hint |
| 2 | constitution 引用(顶部一句话) | ✅ | `> 本 skill 受 _shared/constitution.md 约束` |
| 3 | `# <Skill 名>` + `## Overview` | ✅ | 核心信念 + 跟其他 skill 边界 |
| 4 | `## 角色信条`(5 翻车清单) | ✅ | 5 个最容易翻车的场景 + 对应防护(可加心理测试,如 dev-task 风格) |
| 5 | `## When to Use` / `## When NOT to Use` | ✅ | 触发 / 不触发场景明确 |
| 6 | `## Required Workflow`(numbered phases) | ✅ | 编号 stage / phase / step + 每步**有 actionable gate**(怎么判定该步完成) |
| 7 | `## Question Gate(Step 0)` | 推荐 | 引用 `_shared/question-gate.md` 通用规范(不再各自内联 "Q budget = 3" 等约定)|
| 8 | `## Output Contract` | ✅ | **必须引 `_shared/output-contract-schema.md`** 基线 JSON + markdown 落盘约定;只写本 skill 扩展字段 |
| 9 | `## Handoff Payload`(上游 / 下游字段) | ✅ | 引用 `_shared/handoff-payload-template.md`;明示本 skill 接收什么 / 输出什么字段(给下游 skill 用) |
| 10 | `## Parallelization Plan`(如派 subagent)| 条件 | 引用 `_shared/parallelization-template.md`;描述 slot / 派工 prompt / 输出聚合 |
| 11 | `## Dispatcher Plan`(如调下游 skill)| 条件 | 引用 `_shared/dispatcher-template.md`;描述决策表 / 调用契约 / 失败兜底 |
| 12 | `## Evidence Discovery`(如出报告 / 决策证据)| 推荐 | 引用 `_shared/evidence-discovery.md`;明示证据采集步骤 |
| 13 | `## Executor Selection` | ✅ | 引用 `_shared/executor-selection-template.md`(2026-06 改版:默认自写 / 大体量样板派便宜档 subagent / Codex 重委派降级为可选;各 flow-* 不再自定义 ROI 表)|
| 14 | `## Red Flags + Rationalizations` | ✅ | 段名严格一致 ;详细清单下沉 `references/failure-modes.md` |
| 15 | `## Relationship to Other Skills` | ✅ | Upstream / Downstream / 并列 skill / 跟 meta 类 skill (hat / exp-sum / unblock-recipes / meta-skill) 优先级 |
| 16 | `## Reuse` | ✅ | references/ + tests/ + agents/(如有) 列表 |

可选段(大 skill 加,小 skill 不强求):
- **TL;DR for Orchestrators(30 秒上手)** — SKILL.md > 400 行时**必加**,放在 Overview 之后
- **Run Modes**(如 flow-codex-goal 4 路 — CLI-YOLO / TMUX-YOLO / CLI-EXEC / SUBAGENT)
- **Mode Selection 表**(如本 flow 有多种执行路径)

## 4. references/ 拆分原则

- SKILL.md 主体**目标 < 350 行**;< 200 最佳
- `references/<topic>.md` 收纳大段细节
- `references/failure-modes.md` 收纳 Red Flags + Rationalizations 完整清单(主体只列 Top 5-8 + 引用)
- `references/templates/<artifact>.md` 收纳产物模板
- references 数量 / SKILL 体积比应在 0.02-0.05 之间(过低 = 内联太多;过高 = 主体太空)

## 5. tests/ 拆分原则

- `tests/cases.md` 必有,基础回归用例
- 关键 handoff 边界(给下游传什么字段)应有专门 case
- 关键失败模式(boundary / budget / 高风险 user gate)应有反例 case

## 6. 跟元规范的兼容

- 命名:`flow-<lowercase-with-hyphen>`(不允许大写 / 下划线 / 中文)
- description 长度:中英文混合,< 800 字符(skill-doctor 软警告)
- 受 `constitution.md` 约束 — frontmatter 后第一段必声明
- Output Contract 必引 `_shared/output-contract-schema.md` — 不允许私有 schema
- Executor Selection 必引 `_shared/executor-selection-template.md` — 不允许自定义 ROI 表(若特殊场景不适用,在引用句后注明"豁免理由")

## 7. 新建 / 改造 checklist

新建 flow-* 时:
- [ ] 命名符合 `flow-<workflow>` 规范
- [ ] 14 段必备结构齐全
- [ ] Q gate 引 `_shared/question-gate.md`
- [ ] OC 引 `_shared/output-contract-schema.md`
- [ ] Handoff Payload 引 `_shared/handoff-payload-template.md`
- [ ] Executor Selection 引 `_shared/executor-selection-template.md`
- [ ] failure-modes 下沉 `references/failure-modes.md`
- [ ] tests/cases.md 至少 5 case(触发 / 反例 / 主体 / handoff / 失败)
- [ ] 跑 skill-doctor 0 err

改造现存 flow-* 时:
- [ ] 对照 Master 跨 flow drift 表(见 `.experiment-state/skill-audit-flow.md` 历史快照,若仍在)
- [ ] 优先消 drift,不主动加新段
- [ ] 改完跑 skill-doctor + 至少跑一遍 tests/cases.md 触发用例

## 8. 反例 / Anti-patterns

- ❌ **flow-* 内联私有 Q gate 约定**(各 flow 一套不同的 "Q budget" 数字)
- ❌ **flow-* 内联私有 Executor Selection / Codex ROI 表**(应引 _shared/executor-selection-template.md)
- ❌ **flow-* Output Contract 段缺失**(7/4 已违反)
- ❌ **failure-modes.md 命名不一致**(`failure-modes` / `禁止行为` / `Completion Rules` / `常见错误` 都用过 — 应统一)
- ❌ **flow-* 主体 SKILL.md > 600 行**(应大段下沉 references)
- ❌ **flow-* 不引 constitution.md**(本 skill 是 always-follow)
- ❌ **flow-* 跨阶段 handoff payload 不声明字段**(下游 flow-* 接不到)
