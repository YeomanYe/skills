# Failure Modes — director-frontend

> 合并自原 SKILL.md `## Red Flags — STOP` + `## Rationalizations to Reject` + `## 组件写法红线` 段。
> 主体 SKILL.md 只列触发逻辑摘要并引用本文件。

## Red Flags — STOP(任一命中必须停下)

### 流程违规

- **没探测项目规范就开始写代码** — 必须先扫现有约定 + 找相似实现(Step 1)
- **跳过 audit 直接 implement** — 除非用户明示"按 X 风格直接写"
- **9 维有维度未应用但不标 n/a** — 每维必须 [✓] 或 [n/a],跳过等于盲区
- **本地规范明显存在却照搬外部库写法** — 违反优先级铁律
- **写完不自跑 audit 复查** — implement / extract 必须复查
- **复查不通过仍宣称完成** — 必须回环修或明确说明卡点

### 组件结构违规

- **业务组件塞进 `components/ui/`** — 违反层级归属硬规则
- **抽 shared 没有真实复用证据** — 无证据保留 page-local / business
- **写只返回 `null` 或纯 Fragment 包裹的"组件"** — 违反组件写法红线
- **命名加冗余前缀** — `BaseInput` / `CustomModal`,除非多层封装并存

### 越界

- **调用 `director-design` / `director-promote` / `flow-ext-publish`** 做不属于前端的事
- **自己生成 hero 图 / promo tile** — 应 handoff 给 `director-design` 或调 `web-image`

### 报告造假

- **Output Contract 委派情况段写"无"** — 必须真实记录哪些 skill 被调或全自跑

## 组件写法红线(implement / audit mode 都检查)

除 9 维外,以下是对组件代码本身的**硬性约束**:

- **不要写只返回 `null` 的组件** — 改写为工具函数 / 自定义 hook / 内联到调用点
- **避免只用 Fragment 包裹的组件** — 多处复用 / memo / 错误边界才保留;否则并入调用方
- **组件命名优先用最简单的词** — `Input` / `Button` / `Modal`,不要 `BaseInput` / `CommonButton` / `CustomModal`(除非项目里多层封装并存)
- **业务组件不进 `components/ui/`** — `PricingCard` / `SignupForm` 等带业务语义的组件归 `features/<domain>/components/`
- **不为复用创造万能组件** — 配置 props > 5 时停下,可能是抽错了边界
- **不绕过项目现有样式工具** — 项目用 `cn` + `cva`,不要写 inline style 或额外 className 拼接

## Rationalizations to Reject(自我合理化反驳清单)

| 说辞 | 现实 |
|---|---|
| "项目规范我看代码就懂了,不用专门扫" | 必须 Step 1 探测,凭"看着像"会漏目录/命名/状态/样式中至少 1 项 |
| "9 维太多,挑 3 个看就行" | 每维必须 [✓] / [n/a],缺维等于盲区 |
| "shadcn 写法挺好,直接照搬到项目" | 违反优先级铁律:项目规范 > 内现成实现 > 外部参考 |
| "组件不到 100 行,跳过 audit 直接写" | implement 不论行数都必须前置 audit + 写后复查 |
| "抽 shared 反正以后可能用得到" | 无真实复用证据不进 shared,先放 page-local/business |
| "写完测试都过了,不用 audit" | 测试过 ≠ 代码可维护,audit 看的是结构 / 边界 / 规范 |
| "把业务 props 塞进 Button 加个 variant 就好" | 业务 variant 是抽错了边界的信号,该单独写 PricingButton 在 features/ |
| "命名 `BaseInput` 更明确" | 单层封装用 `Input`,加 `Base*` 前缀只在并存多层时区分 |
| "我顺手把 hero 图也画了" | 越界 — 视觉是 director-design 的事;前端 handoff 出去 |
| "委派情况段写'自做'就行,具体步骤太多懒得列" | 必须真实列(自跑了哪些 mode / 哪些 audit 维度) |

## Failure Modes 快速分诊(主体引用入口)

主体 SKILL.md 提到任一以下信号时,定位到本文件对应段:

| 主体信号 | 本文件段落 |
|---|---|
| 跳 audit / 跳 Step 1 / 不自跑复查 | Red Flags — 流程违规 |
| 业务组件塞 `components/ui/` / 抽 shared 无证据 / null + Fragment 组件 | Red Flags — 组件结构违规 + 组件写法红线 |
| 主动调 director-design / 自画 hero | Red Flags — 越界 |
| "9 维太多挑几个" / "shadcn 直接抄" / "测试过了不用 audit" | Rationalizations to Reject |
