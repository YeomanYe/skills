# Output Contract Template — director-design 完整 markdown 报告模板

> 本文件是 `director-design` 的"人类读"完整 markdown 报告模板。
> 主体 SKILL.md `## Output Contract` 段只保留 JSON 基线字段引用 + 扩展字段声明,
> 完整 markdown 报告由 subagent 落盘到 `.agent/jobs/director-design-<task-slug>/output.md`,
> 主流程要展示给用户 / 移交下游 skill 时再 `Read artifact_path`。
> 通用 JSON 基线字段见 `references/output-contract-schema.md`。

## 完整 markdown 报告模板(强制全字段)

```md
## Director-Design Report

### 任务理解
- 用户原话:
- mode 判定: audit | direction | variants | mockup | handoff
- evidence: <screenshot path / url / code-only / missing + viewport>
- product type: extension popup | SaaS dashboard | landing page | mobile app | other

### 项目设计系统探测
- design tokens 源: <path | none>
- UI 框架: <stack | none>
- 已有 Storybook: yes | no

### Question Gate
- 问题数: 0 | 1 | 2 | 3
- 问题清单:
  - Q1: ...(默认值: ...)
- 用户回复: <quote 或 "用默认值">
- 影响的执行决策: <list>

### 证据采集(对照 references/evidence-discovery.md)
- 探测命令: <list 用了哪些 ls / Playwright 截图 / find>
- 命中: <list 截图路径 + 视口尺寸>
- 缺失: <list 没找到的证据 + 影响>
- 适用性判断: <list 截图是否最新版 / 视口是否覆盖目标设备>
- 降级: <若 evidence: missing,明示降级原因 + 不下视觉结论>

### 委派情况(哪些 skill 被调度)
- huashu-design: <做了什么 / 产出路径 / 调用 ts> | not invoked
- web-image: <做了什么 / 输出图> | not invoked
- ui-ux-pro-max: <咨询了什么> | not invoked
- 自做(不派工): <自己跑了哪些步骤>

### 遵循的设计原则(9 维度)(**每维必须含 `[截图:坐标 + 视口]` 佐证**)
- [✓] 信息层级 — N/5 — `[hero.png:中央偏左,1440×900]` <具体观察 + 对照锚点>
- [✓] 布局密度 — N/5 — `[文件 + 坐标 + 密度数据]`
- [n/a] 字体系统 — 无证据,跳过(说明原因,不省略)
- [✓] 色彩对比 — N/5 — `[截图 + WCAG 对比度计算]`
- [✓] 组件一致性 — N/5 — `[对比 <项目内同类组件截图>]`
- [✓] 交互状态 — N/5 — `[hover/focus/disabled 截图 ≥ 3 张]`
- [✓] 响应式 — N/5 — `[3-4 视口截图齐]`
- [✓] 产品气质 — N/5 — `[对照 <产品类型典型案例>]`
- [✓] 完成度 — N/5 — `[demo 信号清单 + 截图位置]`
- **aggregate**: X.X / 5

> 禁止用 "<证据 / 结论>" 等空泛占位符。详见 references/evidence-discovery.md 第 5 段。

### 设计判断
- verdict: pass | pass-with-fixes | needs-redesign | blocked
- diagnosis: <最大问题 1-2 句>
- findings:
  - [must-fix] <位置/元素>: <问题>。影响: <为什么重要>。建议: <怎么改>
  - [should-fix] ...

### 产出物
- 报告 / mockup / variants / handoff spec 路径:
- 关键截图:

### Next Step
- 继续 audit / 出 variants / 做 mockup / handoff 给 director-frontend
- 推荐下一个 mode 和理由

### 明确不在职责内(告知 orchestrator)
- 工程实现 → director-frontend
- a11y/WCAG 合规 → web-design-guidelines
- 代码约定 → director-frontend
- 写生产代码 → frontend-design
```

## 字段补充说明

- **委派情况**段:禁止全部写 `not invoked`——若全自跑也要写"自做:所有 9 维度 audit 由自己跑"
- **遵循的设计原则**段:每维必须 `[✓]` 或 `[n/a]`,跳过维度等于盲区
- **n/a 必须说明原因**:如"无视觉证据" / "纯静态截图无交互证据"
- **findings**:`[must-fix]` 阻塞交付,`[should-fix]` 不阻塞但建议修
- **artifact_path**:写到 `.agent/jobs/director-design-<task-slug>/output.md`,
  task-slug 必须可追溯(如 `audit-popup-20260528` / `variants-landing-hero`)

## handoff mode 额外产物

`handoff` mode 除上方报告外,还需写设计 spec 到 `.agent/design-handoff/<task-id>/spec.md`,
spec 模板见主体 SKILL.md "Handoff Rules" 段。
