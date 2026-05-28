# Downstream Skill Triggers — director-frontend

> 本文件列**何时**派 subagent 调下游 skill / 派工 prompt 字段如何替换。
> prompt 字段集 + subagent 行为约束的**通用模板**已下沉到 `references/dispatcher-template.md`,
> 本文件只写差异部分 + 派工触发逻辑。

## 触发逻辑表

| 信号 / 场景 | 下游 skill | mode | 说明 |
|---|---|---|---|
| implement 阶段需要 hero 图 / mockup / promo banner | `director-design` | `mockup` | 不要自己瞎画,handoff 设计师角色出方向 |
| implement 阶段需要固定尺寸图(banner / OG / poster / 商店素材) | `web-image` | 默认 | 固定尺寸 + HTML/CSS 生成,跨角色通用工具 |
| handoff mode 写完 spec 后 | `delivery-gate` | 默认 | 交付前总审查,写盘路径回传 |
| implement / extract 写完后视觉是否合规 | `director-design` | `audit` | 写完后视觉复审(可选,主体非必跑) |
| 用户明确要让 plugin 写而非本 skill 自写 | `frontend-design`(plugin) | 默认 | handoff 出口,本 skill 不直接 invoke |

**不调的下游**(主动调属越界):
- `director-promote` — 宣发不在前端范畴
- `flow-ext-publish` — 商店上架不在前端范畴
- `web-design-guidelines` — a11y 合规属于 design / 合规域

## 通用 dispatch prompt 模板

派 subagent 时按 `references/dispatcher-template.md` 完整模板填字段,包括:
- Task(1 行)
- Skill invocation directive(硬规则,subagent 默认不会主动 use skill)
- Handoff payload(path-based,不要内联大块内容)
- Input scope(read_only / write_to / forbidden / no_git_ops)
- Output contract(JSON to stdout + 完整 markdown 写到 `artifact_path`)
- Constraints(failure_mode / timeout / heartbeat / max_parallel)

## 本 skill 的差异(下游 skill 特定字段)

### director-design(mode=mockup)

本 skill 特定:
- 必须调用的下游 skill: `director-design`(mode=`mockup`)
- 必填扩展字段:
  - `product_type`: extension popup / SaaS dashboard / landing page / mobile app
  - `design_tokens_source`: 路径(若无 → "default")
  - `viewport_target`: 目标视口尺寸(若有)
- 必填路径字段(path-based):
  - `evidence_paths`: 已有截图 / 参考图(无则让 subagent 用 playwright 自截)
- write_to: `.agent/jobs/frontend-design-<task-id>/`
- 返回 JSON 扩展:`{ mockup_path, viewport, style_decisions }`
- failure_mode: `failed_continue_main`(视觉缺失主流程可降级继续)
- 约束:严守项目 design tokens 为基准;不得输出含敏感信息的截图

### web-image(默认 mode)

本 skill 特定:
- 必须调用的下游 skill: `web-image`(默认 mode)
- 必填扩展字段:
  - `output_size`: `<W>×<H>` (必须精确)
  - `theme_copy_elements`: 主题 / 文案 / 关键元素描述
  - `design_tokens_source`: 路径 或 "default"
- write_to: `.agent/jobs/web-image-<task-id>/`
- 返回 JSON 扩展:`{ image_path, actual_dimensions }`
- failure_mode: `failed_continue_main`
- 约束:尺寸必须精确(超 1px 即失败);必须由 web-image 用 HTML/CSS 生成,不要其他工具

### delivery-gate(默认 mode)

本 skill 特定:
- 必须调用的下游 skill: `delivery-gate`(默认 mode)
- 必填扩展字段:
  - `handoff_spec_path`: handoff mode 写盘路径
  - `evidence_paths`: 截图 / 代码 diff 路径
- 触发时机: handoff mode 完成 + risk_class=high 时建议跑
- failure_mode: `failed_stop`(交付审查失败必须停)

## orchestrator 行为

派 subagent 后 orchestrator **进入 idle**,subagent 返回 JSON 后:
- 把 `mockup_path` / `image_path` 塞回组件代码或设计 spec
- 视觉资产用完即弃,**不要**把 markdown 全文回流主上下文
- 多路并行时按 `parallelization-template.md` 的 reduce 策略汇总

## 并行场景(罕见,通常不并行)

本 skill 默认串行(理由见主体 `## Parallelization Plan`)。

只有大规模重构(同时拆 10+ 组件)才考虑分 N 路 subagent:
- 必须显式声明每路 subagent 的"必须调用 director-frontend skill"
- 每路独立 `.agent/jobs/extract-N/` 目录
- collect-all 后由 orchestrator 汇总
- 并行规范遵循 `references/parallelization-template.md`
