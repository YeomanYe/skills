# director-frontend Test Cases

> 用于 `skill-behavior-test` 和 `skill-integration-test`。

## 1. 触发场景(正例)

### case-trigger-01: 加新组件
**Prompt**: "在 features/checkout/ 加个 PriceSummary 组件"
**Expected**: 触发 director-frontend。mode=implement。
Step 1 探测项目规范 → audit 前置判定 → 写代码 → audit 复查。

### case-trigger-02: 重构臃肿页面
**Prompt**: "这个 AI 生成的 landing page 太长了,拆成组件"
**Expected**: 触发 director-frontend。mode=extract(默认走 boundaries 出候选)。
焦点向外发现法 + 4 层归类。

### case-trigger-03: 审 JSX
**Prompt**: "看下我这段 React 写得怎么样"
**Expected**: 触发 director-frontend。mode=audit。
9 维评分 + verdict + findings(must-fix / should-fix)。

### case-trigger-04: 拆组件边界
**Prompt**: "这块 UI 应该拆成哪几个组件?"
**Expected**: 触发 director-frontend。mode=boundaries。
出候选清单 + 4 层归类 + 不动代码。

### case-trigger-05: 给后端 spec
**Prompt**: "出个 PricingCard 的组件 API spec 给后端看"
**Expected**: 触发 director-frontend。mode=handoff。
写盘 `.agent/frontend-handoff/<task-id>/spec.md`。

---

## 2. 反例触发(不该触发)

### case-non-trigger-01: 视觉判断
**Prompt**: "看下这个设计怎么样" / "出个 mockup"
**Expected**: **不**触发 director-frontend。应该触发 `director-design`。

### case-non-trigger-02: 写文案 / 发宣传
**Prompt**: "发到 v2ex" / "写个推广文案"
**Expected**: **不**触发 director-frontend。应该触发 `director-promote`。

### case-non-trigger-03: a11y 合规
**Prompt**: "这个表单的 a11y 检查一下符合 WCAG 吗"
**Expected**: **不**触发 director-frontend。应该触发 `web-design-guidelines`。

### case-non-trigger-04: 后端 / API
**Prompt**: "写个 user API 端点" / "调下这个 SQL"
**Expected**: **不**触发 director-frontend。后端不在范畴。

### case-non-trigger-05: 商店上架
**Prompt**: "上架到 Chrome Store"
**Expected**: **不**触发 director-frontend。应该触发 `flow-ext-publish`。

### case-non-trigger-06: 出图
**Prompt**: "出个 1280×800 的 hero 图"
**Expected**: **不**触发 director-frontend。应该触发 `web-image`(若是固定尺寸出图)
或 `director-design`(若是 mockup)。

---

## 3. 主流程成功场景

### case-success-audit-01: 完整 9 维 audit
**Input**: 用户提供 React 组件文件
**Expected output**(关键字段):
- mode: audit
- Step 1 探测项目规范完成(强度判定 / 现有相似实现 / 状态管理 / 样式工具)
- 9 维全部 [✓] 或 [n/a] 评分(每维 1-5)
- aggregate: X.X / 5
- verdict: ready / ready-with-fixes / needs-revision / needs-rewrite
- findings 含 must-fix 和 should-fix 分类
- 不修代码

### case-success-implement-01: 写新组件
**Input**: "加个 EmailInput 组件"
**Expected**:
1. Step 1 探测项目规范(找到现有 `Input` / `TextField` 是否能复用)
2. audit 前置判定(本地规范强弱 / 是否需要外部参考)
3. 写代码(优先复用项目模式;无则按 antd API + shadcn 样式 + radix 交互)
4. audit 自跑复查(9 维评分)
5. 复查通过或回环修
6. Output Contract 含修改文件清单 + 复查结果

### case-success-extract-01: 抽取臃肿页面
**Input**: 200 行 landing page,含 5 个 section
**Expected**:
1. boundaries 出候选(HeroSection / FeatureGrid / PricingSection / TestimonialsSection / FinalCTASection)
2. 4 层归类(全 page-local;FeatureGrid 视情况 shared)
3. 用户确认 → 真实迁移文件
4. 验证:导入边界无循环 / 交互状态完整
5. 自跑 audit 复查

### case-success-boundaries-01: 出候选清单
**Input**: 一段复杂的 JSX
**Expected**:
- 候选清单 + 焦点来源 + 边界 + 4 层归类
- **不动代码**
- 输出 props API 建议 + 文件位置建议

### case-success-handoff-01: 给后端 spec
**Input**: "给 PricingCard 出 spec"
**Expected**:
- 写盘 `.agent/frontend-handoff/<task-id>/spec.md`
- 含组件目标 / 层级 / 文件位置 / props API / 状态边界 / 样式约定 / 依赖 /
  交互状态 / 验收点 / 不要做什么
- 不写代码

---

## 4. Red Flag 反例(必须拦截)

### case-redflag-01: 跳过 Step 1 直接写
**Input**: implement 任务,agent 没探测项目规范就写 inline style
**Expected**: 拒绝。Step 1 项目规范探测是 implement 前置必经。

### case-redflag-02: 跳过 audit 直接 implement
**Input**: 用户没说"按 X 风格直接写",直接写
**Expected**: 拒绝。implement 必须先 audit 前置判定 + 写后复查。

### case-redflag-03: 9 维有维度不标 n/a
**Input**: audit 时维度 6(样式组织)无证据应该 [n/a]
**Expected**: Output Contract 明确写 `[n/a] 维度 6 — 无样式改动,跳过`,
**不**省略也**不**填 0 分。

### case-redflag-04: 业务组件塞 components/ui/
**Input**: 把 `PricingCard` 抽到 `components/ui/pricing-card.tsx`
**Expected**: 触发 Red Flag(维度 2 = 1 分 + 特殊触发 → needs-rewrite)。
建议改到 `features/pricing/components/pricing-card.tsx`。

### case-redflag-05: 抽 shared 没复用证据
**Input**: 抽 `SectionHeader` 到 shared/,但只在 1 个页面用
**Expected**: 拒绝。抽 shared 必须 ≥ 2 个页面真实复用证据。
保留 page-local 直到第 2 处真实复用出现。

### case-redflag-06: 写完不复查
**Input**: implement 完成后直接宣称完成
**Expected**: 拒绝。implement 必须自跑 audit 复查 → 复查不通过回环修。

### case-redflag-07: 命名加冗余前缀
**Input**: 项目只有单层封装却命名 `BaseInput` / `CustomModal`
**Expected**: 触发组件写法红线。改为 `Input` / `Modal`。

### case-redflag-08: 越界出图
**Input**: implement 时 agent 自己画 hero 图
**Expected**: 越界 Red Flag。应 handoff 给 `director-design` 或调 `web-image`。

### case-redflag-09: 照搬外部库
**Input**: 项目用 CSS Modules,agent 按 shadcn(Tailwind)写
**Expected**: 违反优先级铁律。本地规范优先。
改为按项目 CSS Modules 模式 + 参考 shadcn 的组件拆分思路(不照抄实现)。

### case-redflag-10: 写仅返回 null 的组件
**Input**: agent 写 `function X(){ useEffect(...); return null }`
**Expected**: 违反组件写法红线。改写为自定义 hook 或工具函数。

---

## 5. 边界场景

### case-edge-01: 项目规范 weak
**Input**: 新项目无明确约定
**Expected**: Step 1 探测后标 `weak`,Step 5 允许走外部参考(优先级第 4 层)。
明示用户当前依据是外部模式不是本地。

### case-edge-02: 框架不在主流清单
**Input**: 用户用 SolidJS / Qwik 等冷门 JSX 框架
**Expected**: 调整状态管理 / hooks 命名以匹配框架习惯(SolidJS 用 signal 不用 useState)。
但 9 维 audit 通用,只是 1-2 维度的实现细节随框架调整。

### case-edge-03: 用户拒绝 audit 复查
**Input**: implement 完用户说"不用复查直接 commit"
**Expected**: 仍跑 audit 复查(后台快速),把 findings 放 Output Contract 让用户决定是否听。
不强制阻断用户 commit,但必须告知。

### case-edge-04: handoff 给已废弃 frontend-design plugin
**Input**: handoff mode 用户说"交给 frontend-design plugin 写"
**Expected**: 若 plugin 可用 → 写 spec 文件交付路径。
若 plugin 不可用 → 提示用户直接让 director-frontend 自己 implement(A 选项默认)。

### case-edge-05: 同时审 + 实现
**Input**: "审下这个组件,有问题就帮我改"
**Expected**: mode 链:audit → 出 verdict → 若 needs-revision/needs-rewrite,
征得用户同意后进 implement → 再 audit 复查。
不要单次跑混 mode。

---

## 6. 集成测试场景(skill-integration-test 用)

### case-integration-01: 上游 director-design handoff
**Input**: director-design `handoff` mode 写 `.agent/design-handoff/<task-id>/spec.md`,
用户接着说"按这个 spec 实现"
**Expected**:
- director-frontend 不重复探测 product_type / design tokens(已在 handoff 里)
- 读 design-handoff/<task-id>/spec.md
- implement mode 自跑代码 + audit 复查
- Output Contract 记录"上游 handoff 来源 = director-design / design-handoff path"

### case-integration-02: 下游 director-design 视觉复审
**Input**: implement 完成后,用户说"让设计师再看看"
**Expected**:
- handoff 给 director-design (mode=audit)
- 派 subagent 显式调 `director-design`
- 收 verdict 后塞回本 skill Output Contract

### case-integration-03: 下游 web-image 调用
**Input**: implement 需要一个 promo banner 图片(不是 hero / mockup)
**Expected**:
- 派 subagent 显式调 `web-image`(prompt: "必须调用 web-image skill")
- 收图片路径塞回组件代码

### case-integration-04: handoff 出口给 delivery-gate
**Input**: 真实交付前用户说"准备 PR"
**Expected**:
- Output Contract 给出 handoff path 提示 delivery-gate 接手
- 不主动调 delivery-gate(由 flow-dev-task / 用户决定)

---

## 7. 物理合并验证

### case-merge-01: 原 3 个 skill 已删除
**Expected**: `~/Documents/projects/skills/{flow-jsx-ui,jsx-ui-audit,ui-extract}/`
三个目录全部不存在。

### case-merge-02: 原 skill 触发短语应触发本 skill
**Input**: "审一下 JSX" / "抽组件" / "重构这个 React 页面" / "拆下边界" / "extract components"
**Expected**: 全部触发 `director-frontend`(对应原 3 个 skill 描述里的触发短语)。

### case-merge-03: 边界发现法可查
**Input**: extract / boundaries mode 中,焦点向外扩张的具体规则
**Expected**: 应能在 `references/boundary-discovery.md` 找到"焦点向外发现法" + "停止扩张条件"
+ "组件层级 4 层归类"完整规则(从原 ui-extract 迁入)。

### case-merge-04: 外部参考 fallback 可查
**Input**: 项目规范弱,需要查 antd / shadcn / radix 模式
**Expected**: 应能在 `references/{api-design-fallbacks,style-fallbacks,project-convention-checklist}.md`
找到原 jsx-ui-audit 完整内容。

### case-merge-05: flow-jsx-ui 8 步编排逻辑保留
**Input**: implement mode 跑完整流程
**Expected**: 走原 flow-jsx-ui 的 Step 1-8 等价路径:
项目规范探测 → 边界判断(boundaries 复用) → audit 前置判定 →
best-practice 选择 → 写代码 → audit 复查 → 回环修 → 完成。
