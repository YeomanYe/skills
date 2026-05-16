# director-design 行为测试用例

验证设计师角色 skill 的触发 / mode 判定 / 9 维度 audit / 委派 / 边界。

## 正例触发

### T1. audit 触发

Prompt：
> 帮我看下这个 popup 截图设计怎么样？[附截图]

预期：
- 触发本 skill
- evidence: screenshot + viewport
- mode: audit
- 自跑 9 维度 checklist（无需调 huashu-design）
- Output Contract 全字段，含"委派情况: 自做（所有 9 维度）"

### T2. variants 触发

Prompt：
> 这个 dashboard 想换风格，给我 3 个不同设计方向。

预期：
- mode: variants
- 派 3 个 huashu-design subagent 并行（按 references/parallelization-template.md）
- 委派情况列 3 路调用 + 每个方向的产出路径
- 9 维度只评 baseline（当前状态）

### T3. mockup 触发

Prompt：
> 我选第二个方向，帮我出个 mockup。

预期：
- mode: mockup
- 调 huashu-design 出 HTML 原型 / 或调 web-image 出固定尺寸图
- 4 断点截图并行（375 / 768 / 1024 / 1440）
- 委派情况列 huashu-design 或 web-image + 截图 subagent

### T4. handoff 触发

Prompt：
> 这个 mockup 确定了，给前端实现。

预期：
- mode: handoff
- 写设计 spec 到 `.agent/design-handoff/<task-id>/spec.md`
- 输出路径回传给 orchestrator
- **不调用** flow-jsx-ui 或 frontend-design（只交付，不实现）
- "Next Step" 明示 "handoff 给 flow-jsx-ui"

### T5. 触发关键词覆盖

Prompt：
> 从设计师角度看一下 / design critique / 设计走查 / give me design variants

预期：均触发 director-design。

## 反例触发

### N1. a11y / WCAG 不触发

Prompt：
> 帮我审查这个页面的 a11y 是否合规。

预期：**不**触发 director-design，路由给 `web-design-guidelines`。

### N2. 代码约定不触发

Prompt：
> 这个组件命名规范吗 / props 接口设计合理吗。

预期：**不**触发，路由给 `jsx-ui-audit`。

### N3. JSX UI 工程实现不触发

Prompt：
> 帮我实现这个 React 组件。

预期：**不**触发，路由给 `flow-jsx-ui`。

### N4. 纯后端 / API 不触发

Prompt：
> 这个接口报 500 帮我查日志 / 这段 SQL 怎么优化。

预期：**不**触发。

### N5. 用户已明确直接实现

Prompt：
> 直接按这个 mockup 实现，不用设计审查。

预期：**不**触发，进 flow-jsx-ui 或 flow-dev-task。

## 主流程

### M1. audit → variants → mockup → handoff 完整链路

预期阶段顺序：
1. Step 1 evidence: screenshot 探测，记录 viewport
2. Step 2 mode 初判 audit
3. Step 3 项目设计系统探测（tailwind.config.* / theme.* / etc.）
4. Step 4 自跑 9 维度 checklist，对照 references/design-principles.md 锚点评分
5. Step 5 Output Contract 含 verdict + findings + 9 维度评分
6. 用户回 "出 variants" → mode 切换 variants → 派 3 路 huashu-design 并行
7. 用户回 "选第 2 个 → mockup" → mode 切换 mockup → 调 huashu-design + web-image
8. 用户回 "给前端" → mode 切换 handoff → 写 spec 落盘 + 输出路径
9. 全程 Output Contract 真实记录委派情况

## 护栏 / 负例

### G1. 无视觉证据下断言"通过" → STOP

Prompt：
> 只看代码，这个页面设计效果是不是已经很好？

预期：
- evidence: code-only
- 不下"设计通过"结论
- Output Contract verdict: needs-direction（需要补证据）
- Red Flag 命中

### G2. 9 维度有维度跳过但不标 n/a → STOP

预期：每个维度必须 [✓ + 评分] 或 [n/a + 原因]，遗漏 = Red Flag

### G3. 跳过 variants 直接 mockup → STOP

场景：用户没明确方向就说"出个 mockup"。

预期：先反问 "已经有偏好方向了吗？还是先给 variants？"，不直接 mockup。

### G4. handoff 不写 spec 文件 → STOP

场景：handoff mode 完成但只在对话里输出 spec，不落盘。

预期：Red Flag 命中，必须写 `.agent/design-handoff/<task-id>/spec.md`

### G5. 调用 frontend-design 写生产代码 → STOP

场景：handoff 时本 skill 顺手调 frontend-design。

预期：越界，Red Flag 命中。frontend-design 由 flow-jsx-ui 接手或用户直接调。

### G6. 用 ui-ux-pro-max 推荐覆盖项目 tokens → STOP

场景：项目已有 tailwind tokens，本 skill 推荐外部 161 色板覆盖。

预期：项目设计系统优先，外部推荐只在缺失或明显落后时引入，且必须明示理由。

### G7. variants 3 方向只换配色 → STOP

预期：3 方向必须真正差异化（布局 / 信息层级 / 风格至少 1 个维度不同），不能只换主色。

### G8. 委派情况段写"无" / Output Contract 缺字段 → STOP

预期：必须真实记录所有 skill 调用 + 9 维度应用情况；段缺 = AI slop 嫌疑

## 边界 / 回归

### B1. 没有项目设计系统

场景：项目根没 tailwind.config / theme / tokens。

预期：Output Contract "项目设计系统探测" 段如实标 "none"；可调 ui-ux-pro-max 推荐起点。

### B2. 同分 variants 裁决

场景：3 个 variants reviewer 给的分都一样。

预期：按 references/design-principles.md 中"硬规则"类维度优先（信息层级 / 完成度 / 产品气质）裁决。

### B3. 多个 mode 同时被需要

场景：用户说"帮我看下设计 + 给几个改进方向"。

预期：按 audit → direction 最小可逆链路推进；先 audit 给 verdict + findings，再问要不要进 direction。

### B4. project-finish 上游调用本 skill

场景：flow-project-finish Step 3 调本 skill 做落地页设计。

预期：通过 handoff payload 透传 `task_id` / `objective` / `risk_class` / `is_ui_task: true` / `design_tokens_source` 等字段，本 skill 不重复探测。

## 判定通过的核心标准

一次 director-design 调用同时满足以下才算通过：

1. ✅ evidence 字段明确（screenshot/url/code-only/missing + viewport）
2. ✅ mode 5 选 1 明确
3. ✅ 项目设计系统探测段已填
4. ✅ 委派情况段真实记录（不允许"全部 not invoked"+ Output 还有完整 findings）
5. ✅ 9 维度每个都 [✓ + 评分] 或 [n/a + 原因]
6. ✅ aggregate 按 references/design-principles.md 公式计算
7. ✅ verdict 4 选 1（pass / pass-with-fixes / needs-redesign / needs-direction）
8. ✅ findings 含 must-fix / should-fix 区分
9. ✅ Next Step 推荐明确
10. ✅ 不在职责内段明确告知 orchestrator handoff 出口
11. ✅ 无 Red Flag 命中
12. ✅ handoff mode 下 spec 文件落盘且路径回传
13. ✅ variants mode 下 3 方向真正差异化（不只换色）
14. ✅ 派工时引用 references/parallelization-template.md（subagent prompt 含"必须调用 X skill"显式指挥）
