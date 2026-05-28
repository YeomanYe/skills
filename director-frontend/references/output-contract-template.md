# Output Contract Template — director-frontend

> 本文件是 `director-frontend` 完整 markdown 报告模板。
> 主体 SKILL.md `## Output Contract` 段只声明 JSON 基线 + 扩展字段(见 `output-contract-schema.md`),
> subagent 把以下完整 markdown 落盘到 `artifact_path`(默认 `.agent/jobs/director-frontend-<task-slug>/output.md`)。
> 主流程要展示给用户 / 移交下游(`delivery-gate` / `director-design` 视觉复审 / `frontend-design` plugin)时再 `Read artifact_path`。

## 完整报告模板(强制全字段)

```md
## Director-Frontend Report

### 任务理解
- 用户原话:
- mode 判定: audit | boundaries | implement | extract | handoff
- 目标文件 / 范围: <path 或 component 名>
- 框架: React | Preact | Fresh | Solid | other

### 项目规范探测
- 项目规范强度: strong | medium | weak
- 现有相似实现: <path 或 none>
- 状态管理: <useState / Context / store>
- 样式工具: <cn / cva / clsx / 原生>
- 已用 UI 库: <antd / shadcn / radix / headless-ui / 无>
- design tokens 源: <path 或 none>

### Question Gate
- 问题数: 0 | 1 | 2 | 3
- 问题清单:
  - Q1: ...(默认值: ...)
  - Q2: ...
- 用户回复: <quote 或 "用默认值">
- 影响的执行决策: <list>

### 证据采集(对照 references/evidence-discovery.md)
- 探测命令: <list 用了哪些 rg / find / ls>
- 命中: <list 找到的文件/相似实现>
- 缺失: <list 没找到的证据 + 影响>
- 适用性判断: <list 现有相似实现是否真的适用本次任务>
- 降级: <若有,明示降级原因>

### 委派情况(哪些 skill 被调度)
- director-design: <为何调 / 拿到了什么> | not invoked
- web-image: <为何调 / 拿到了什么> | not invoked
- delivery-gate: <handoff 路径> | not invoked
- 自做(不派工): <自跑了哪些步骤>

### 遵循的 9 维 audit(**每维必须含 `[文件:行号 + 引用]` 佐证**)
- [✓] 组件边界清晰度 — N/5 — `[文件:行号]` <具体观察 + 对照锚点>
- [✓] 组件层级归属 — N/5 — `[文件路径 / 层级判定信号]`
- [✓] 本地规范遵循度 — N/5 — `[对比 <项目内文件:行号>]`
- [✓] API 命名一致性 — N/5 — `[对比 <项目内同类组件 props>]`
- [✓] 状态管理合理性 — N/5 — `[文件:行号 + 状态边界证据]`
- [✓] 样式组织 — N/5 — `[文件:行号 + cn/cva 用法]`
- [✓] props 设计 — N/5 — `[props 清单 + 是否含业务语义]`
- [✓] 复用证据 — N/5 — `[≥ 2 处使用路径 或 仅 1 处 → 不该 shared]`
- [✓] AI slop — N/5 — `[具体 slop 信号:仅 null / Fragment-only / 冗余前缀 + 文件:行号]`
- **aggregate**: X.X / 5

> 禁止用 "<证据 / 结论>" 等空泛占位符。详见 references/evidence-discovery.md 第 5 段佐证格式。

### 前端判断
- verdict: ready | ready-with-fixes | needs-revision | needs-rewrite
- diagnosis: <最大问题 1-2 句>
- findings:
  - [must-fix] <位置>: <问题>。影响: <为什么重要>。建议: <怎么改>
  - [should-fix] ...

### 实际修改(implement / extract mode)
- 修改文件清单: <list>
- 新增组件: <list 含层级归属>
- 移动组件: <from → to>
- 删除组件: <list>
- 自跑复查 audit 结果: pass / 仍有 N must-fix

### Boundary 候选(boundaries / extract mode)
- 候选组件: <list>
- 4 层归类: primitive=N / shared=N / business=N / page-local=N
- 不进 shared 的候选 + 理由: <list>

### 产出物
- 报告 / handoff spec / 实际代码 diff 路径:

### Next Step
- 继续 implement / 用户决定是否抽 X / handoff 给 director-design 视觉复审
- 推荐下一个 mode 和理由

### 明确不在职责内(告知 orchestrator)
- 视觉设计判断 → director-design
- 文案/宣传发布 → director-promote
- a11y/WCAG → web-design-guidelines
- 固定尺寸出图 → web-image
- 后端/API → 非前端范畴
```

## 字段完整性要求

- **不可省略** 任何一段(无相关内容写 `n/a` + 一句话理由)
- **不可使用空泛占位符**(`<证据>` / `<结论>` / `TBD`)
- **9 维 audit 每维必须 `[✓]` 或 `[n/a]`**,跳过等于盲区
- **委派情况段不可写"无"** — 必须真实记录"自跑了哪些步骤"或"调了哪些下游 skill"

## 与 Output Contract Schema 的关系

主体 SKILL.md `## Output Contract` 段只声明 JSON(参见 `references/output-contract-schema.md` §7):

```json
{
  "verdict": "ready | ready-with-fixes | needs-revision | needs-rewrite",
  "aggregate": 0.0,
  "must_fix": [],
  "should_fix": [],
  "evidence_paths": [],
  "artifact_path": ".agent/jobs/director-frontend-<task-slug>/output.md",
  "files_touched": [],
  "boundaries_extracted": [],
  "handoff_spec_path": "<path 或 null>",
  "mode": "audit | boundaries | implement | extract | handoff"
}
```

JSON 字段语义按 `output-contract-schema.md` 基线 + 上方扩展字段:
- `files_touched`: implement / extract mode 真实改的文件清单
- `boundaries_extracted`: boundaries / extract mode 抽出的组件名清单
- `handoff_spec_path`: handoff mode 写盘的 spec 绝对路径
- `mode`: 本次执行的 mode(audit / boundaries / implement / extract / handoff)
