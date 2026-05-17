# Frontend Principles — 9 维 Audit Rubric

> 由 `director-frontend` 的 audit / implement / extract mode 自跑。每维 1-5 分,
> **所有维度必须 [✓] 或 [n/a]**,跳过任何维度等于盲区。<4 分必出修正建议。

## 锚点说明

每维列 1 / 3 / 5 三个锚点。实际打分时落在最接近的锚点上。2 / 4 为中间值。

---

## 1. 组件边界清晰度 (Boundary Clarity)

> 最小抽取单元是否成立。有无视觉/交互/状态/语义完整边界。

**1 分**(边界混乱):
- 单个组件混了多个独立焦点区(form + dialog + table 一锅端)
- 边界由 `<div>` 包到组件外,没有视觉/交互边界
- 抽出后调用方更难读

**3 分**(边界基本但不极致):
- 边界存在但是包了 1-2 个额外可选项(可独立但没必要分)
- 命名能解释边界,但需要补一句话才能说清职责

**5 分**(清晰可命名):
- 视觉 + 交互 + 状态 + 语义边界齐全
- 一个清晰名称能表达意图(`TextField` / `SearchBox` / `PricingCard`)
- 抽出后调用方更易读

---

## 2. 组件层级归属 (Layer Placement)

> primitive / shared / business / page-local 4 层归属是否正确。

**1 分**(归错层):
- 业务组件塞进 `components/ui/`(`PricingCard` 在 `ui/` 下)
- 页面专属组件抽进 `shared/`(`FinalCTASection` 在 `shared/`)
- 命名含业务名词却放 primitive 层

**3 分**(部分对):
- 大体正确但有 1-2 处边界模糊(如 `Card` 在 ui 但内部固定了业务色)
- 抽 shared 但只在 1 个页面用,未来复用证据不强

**5 分**(正确):
- 每个组件层级有明确判定信号支撑
- 业务组件在 `features/<domain>/`
- shared 组件有 ≥ 2 个页面真实复用证据
- page-local 保留在页面文件夹

---

## 3. 本地规范遵循度 (Local Convention Fit)

> 命名 / API / 样式 / 目录是否沿用项目模式。

**1 分**(完全偏离):
- 项目用 `cn` + `cva`,新组件写 inline style
- 项目用 PascalCase 文件,新组件用 kebab-case
- 项目状态命名 `isOpen`,新组件用 `visible`

**3 分**(部分对齐):
- 命名/目录跟项目,但样式工具偏离
- 用项目 hooks 但 props API 偏离已有组件

**5 分**(完全对齐):
- 项目规范扫描后,每一条都遵循
- 跟项目同类组件 API 命名一致
- 用项目已有样式工具 + design tokens

---

## 4. API 命名一致性 (API Consistency)

> props 命名 / 事件命名 / 受控边界跟项目其他组件一致。

**1 分**(分裂):
- 同一项目内并存 `value` / `val` / `current` 表示同一概念
- 事件 `onClick` / `clickHandler` / `handleClick` 混用
- 受控 / 非受控边界含糊(`defaultValue` 和 `value` 同时支持但无规则)

**3 分**(主要一致):
- 命名跟项目主流模式一致,但 1-2 个新 props 命名拍脑袋

**5 分**(全一致):
- 跟项目所有同类组件 API 一致
- 受控边界清晰(`value + onChange` / `defaultValue` 二选一)
- 事件命名遵循 React 惯例 + 项目额外约定

---

## 5. 状态管理合理性 (State Design)

> hooks 滥用 / 状态提升 / Context 滥用 / 全局 store 边界。

**1 分**(乱):
- 一个组件 8 个 `useState`,本可合并为 1 个 reducer
- 状态应在父组件却在子组件(导致兄弟通信走 props drilling)
- 业务状态塞进 Context 导致渲染爆炸

**3 分**(可工作但欠优):
- 2-3 个 useState 本可合并
- 偶有不必要的 useEffect

**5 分**(合理):
- 状态范围跟数据生命周期匹配
- 衍生状态用 `useMemo` 不用 `useState`
- Context 只放跨组件树共享的稳定数据
- 全局 store 只放跨页面持久数据

---

## 6. 样式组织 (Style Organization)

> className 组织 / variant 设计 / 不绕过项目工具。

**1 分**(不绕过项目工具):
- 项目用 Tailwind 却写 CSS Modules
- 项目用 `cva` 却用 `clsx` 拼条件
- 同一组件混用 inline style + className

**3 分**(基本规整):
- 用项目工具但 variant 设计粗糙(变量名重复 / 重叠)

**5 分**(整洁):
- 用项目主流工具(cn / cva / tv / clsx)
- variant 设计清晰(size / variant / state 正交)
- 不重复 Tailwind class(用 `@apply` 或 cva 抽出)
- 跟 design tokens 对齐(不写硬编码颜色)

---

## 7. props 设计 (Props Design)

> props 爆炸 / 万能配置器 / 业务逻辑误塞 primitive。

**1 分**(爆炸):
- props > 8 个 + 5 个布尔开关
- 同一 prop 多种类型(`size?: 'sm' | 'md' | 'lg' | number | { width: number, height: number }`)
- primitive 组件含业务 props(`Button` 含 `analyticsEvent` / `permissionKey`)

**3 分**(可控但臃肿):
- props 5-7 个,有 1-2 个可合并或下沉

**5 分**(克制):
- props 表达组件能力,不暴露所有样式细节
- 业务 props 在 wrapper 组件,不下沉 primitive
- 受控/非受控两套清晰,不混用

---

## 8. 复用证据 (Reuse Evidence)

> 抽 shared 前必须有真实跨页面复用证据。

**1 分**(空想复用):
- 抽 shared 但只在 1 个页面用
- "以后可能会用"作为唯一理由
- 没找过项目内现有相似实现就新抽

**3 分**(弱证据):
- 项目内有 1 个相似实现但没整合
- 1 个页面用 + 1 个 future plan

**5 分**(强证据):
- ≥ 2 个页面真实使用
- 抽出前找过项目内相似实现并整合
- props API 兼容已有用法

**无证据 → 保留 `page-local` 或 `business`,不进 `shared`**。

---

## 9. AI slop (AI Slop)

> 避免 AI 生成代码的典型反模式。

**1 分**(典型 AI slop):
- 纯 Fragment 包裹的"组件"(`<>{children}</>`)
- 仅返回 `null` 的"组件"(纯逻辑应是 hook 或工具函数)
- 命名加冗余前缀(`BaseInput` / `CustomModal` / `EnhancedButton`)
- 过度抽象("万能 Section" / `FlexibleContainer`)
- 同一文件多个组件却没分文件
- 注释解释了 obvious 代码("// 设置 state")
- 滥用 `as` 类型断言绕过 TS

**3 分**(轻微):
- 偶有命名冗余 1-2 处
- 偶有可去掉的注释

**5 分**(干净):
- 命名简洁(`Input` / `Button` / `Modal`)
- 抽象有真实需要支撑
- TS 类型严格,不 `any` 不 `as`
- 注释只解释 WHY 不解释 WHAT

---

## Aggregate 评分

加权:9 维等权,算数平均。

| Aggregate | Verdict | 行动 |
|---|---|---|
| ≥ 4.5 | `ready` | 代码可交付,无须重写 |
| 4.0-4.4 | `ready-with-fixes` | should-fix 列清单,可选修 |
| 3.0-3.9 | `needs-revision` | must-fix 列清单,必须修后才可交付 |
| < 3.0 | `needs-rewrite` | 整体不达标,回 implement / extract 重写 |

特殊触发(任一直接降级为 `needs-rewrite`):
- 维度 2(层级归属)= 1 分 **且** 业务组件被塞进 `components/ui/`
- 维度 9(AI slop)= 1 分 **且** 含 ≥ 3 项 AI slop 信号

## 优先级铁律(再次强调)

写代码 / audit 时**永远**按以下优先级:

1. 项目现有规范
2. 项目内现成实现
3. 团队当前技术栈约定
4. 外部优秀参考项目(antd / shadcn / radix)
5. 通用最佳实践

**不要跳过前 3 层直接照搬外部参考**。
