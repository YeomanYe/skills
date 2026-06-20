# Audit Rubric — director-* / exp-sum 通用质量评分规范

> 借鉴 ACBDQC Blueprint 强制佐证 + `director-template.md` 第 9 段 verdict 映射规范。
> 本文件定义 **director-*** 与 **exp-sum** 共用的 N 维 audit 基线:维度、锚点、聚合公式、verdict 映射、报告格式。
> 角色特定锚点 / 角色自定义增维度归各 skill 自己的 SKILL.md。

## 1. 用途

每个 director-* / exp-sum 在出 verdict 前都要做"N 维质量自审"。原本各 skill 各定义一遍 7-9 维 + 1/3/5 锚点 + 聚合公式 + verdict 映射,**重复 200+ 行**且 verdict 等级语义会漂移。

本文件统一三件事:
1. **基线维度集**(7 维,跨角色都有意义)
2. **聚合 → verdict 等级映射**(只定 4 档等级 + 行动语义,标签词由各 skill 自命名)
3. **报告格式 + 特殊降级触发模式**

各 skill 需要在基线之上加角色专属维度(详见 §7 引用模板)。**不可减维度**(否则失去对齐意义),只可调锚点描述 + 加自定义维度。

## 2. 通用 7 维基线框架

每维 1-5 分。锚点是**跨角色基线**——各 skill 在 SKILL.md 里按本领域重定义 1/3/5 描述,但维度名称与编号必须保留。

| # | 维度 | 1/3/5 锚点(基线,可按领域调整) |
|---|---|---|
| 1 | **Scope / 探测充分性** | 1=只看 1 处入口 / 3=核心 3-5 处 / 5=全体系扫齐 + 引用 ≥ 10 处定位 |
| 2 | **证据来源可信度** | 1=单一来源 / 3=本地+网络 / 5=本地+用户提供+官方,含适用性判断 |
| 3 | **决策证据强度** | 1=结论无定位引用 / 3=部分有 [file:line]/[command:行] / 5=每条决策都有可核对引用 |
| 4 | **方案 / 计划可执行性** | 1=步骤模糊 / 3=步骤明确 / 5=每步含类型 + 风险 + 来源,可被他人直接重跑 |
| 5 | **执行 / 产出成功率** | 1=失败重试无错排 / 3=有失败但停下报告 / 5=全成功或失败定位精准 |
| 6 | **验证完整性** | 1=只验 1 项 / 3=主路径验证 / 5=主+边界+残留+回归 smoke 全覆盖 |
| 7 | **可追溯 / 沉淀质量** | 1=没记录 / 3=填了模板 / 5=含日期+版本+踩坑+可被未来 agent 反推执行 |

锚点描述用"具体行为"而非"质量形容词"(避免 "中等""不错")。

## 3. 特殊触发降级(任一直接 verdict 降级)

聚合分之外,以下硬故障触发直接降级,**不看 aggregate**:

- **维度 3(决策证据)= 1** 且关键决策无任何定位引用 → 最低档(`blocked` / `failed`),因为无证据 = AI slop
- **维度 4(可执行性)= 1** 且方案含破坏性操作 → 最低档,因为破坏性 + 步骤模糊 = 事故
- **维度 6(验证完整性)= 1** → 次低档(`partial`),因为没验证就宣告完成 = 把锅推给下游
- **角色专属红线**(各 skill 自定义,例如 director-ops 维度 4 用户确认 = 1 → `failed`、director-design 维度 6 交互状态 = 1 + ≥ 2 关键状态缺失 → `blocked`)

各 skill 在 SKILL.md 里**显式枚举**自己的红线触发列表(不能默写"参考通用")。

## 4. Aggregate → Verdict 等级映射

aggregate = N 维**算术平均**(`sum(scores) / N`)。`[n/a]` 维度不计入分母,但 SKILL.md 必须给出跳过理由(否则按 1 分计算)。

| Aggregate score | Verdict 等级语义 | 行动 |
|---|---|---|
| ≥ 4.5 | **clean 档**(无修可交付) | 进入下一阶段 / dispatch / 记录沉淀 |
| 4.0-4.4 | **with-warnings 档**(可选修) | 列 should-fix 清单,用户决定是否修 |
| 3.0-3.9 | **partial 档**(必修后才可交付) | 列 must-fix 清单,修完回审 |
| < 3.0 | **failed 档**(整体不达标,回前置 mode) | 回 direction / draft / research 重出 |

verdict 标签的**具体词**由各 skill 自命名。**等级数(4 档)与语义对应不可变**,标签词可变。

### 4.1 当前 6 个 director-* 的 verdict 映射表(orchestrator 跨 skill 处理时查这张)

| 等级 | director-design | director-frontend | director-promote | director-ops | director-architect | director-pm |
|---|---|---|---|---|---|---|
| **clean**(≥ 4.5) | `pass` | `ready` | `ready` | `installed-clean` | `ready-to-land` | `approved` |
| **with-warnings**(4.0-4.4) | `pass-with-fixes` | `ready-with-fixes` | `ready-with-fixes` | `installed-with-warnings` | `ready-with-refinement` | `approved-with-trims` |
| **partial**(3.0-3.9) | `needs-redesign` | `needs-revision` | `needs-revision` | `partial` | `needs-refinement` | `needs-rework` |
| **failed**(< 3.0) | `blocked` | `needs-rewrite` | `blocked` | `failed` | `blocked` | `blocked` |

新建 director-* 时,**在 SKILL.md 引用本表**(`../_shared/audit-rubric.md` §4.1)并加自己的一行,而不是自命名一套不映射的标签。

**禁止**用几何平均 / 加权平均(各角色会借此粉饰短板,违反 ACBDQC 强制佐证)——若某维度严重失分,走 §3 特殊降级,不靠权重稀释。

## 5. 报告格式(强制)

每维必须按以下格式输出(每行一维):

```
[✓] <维度名> — N/5 — [<佐证: command 输出摘要 / 文件:行号 / 截图:坐标视口 / 平台 URL>]
```

或跳过:

```
[n/a] <维度名> — 跳过理由: <具体说明,如"本任务无破坏性操作,无须验证"〉
```

最后两行汇总:

```
- aggregate: X.X / 5
- verdict: <从映射表选出的本 skill 自命名标签>
```

**佐证字段必须能被人工 review 到原文**——禁止"<证据>""<结论>"等空泛占位符(详见 `references/evidence-discovery.md` §6 AI slop 反检测清单)。

## 6. 与 exp-sum 的关系

exp-sum 主线走 judgment-tree 决策树(Q0 → Q10 第一个 yes 即出口),与本 rubric **不冲突也不替代**。可在以下两种场合复用本 rubric:

- **判定经验沉淀质量**:把待沉淀经验过一遍 §2 的 7 维,< 3 档直接打回让用户补证据,不污染长期记忆层
- **元审计**:对已有 director-* 的 audit 结果做"二阶 audit",验证每维评分本身是否符合本 rubric 报告格式

exp-sum 不强制每次都跑 rubric——judgment-tree 是主路径,rubric 是可选复用框架。

## 7. 各 skill 如何引用本规范

各 director-* 在 SKILL.md 的"N 维 Audit Checklist"段只需写以下骨架(取代原 30-60 行表格):

```md
## N 维 Audit Checklist

按 `references/audit-rubric.md` §2 跑 7 维基线评分。本 skill 1/3/5 锚点重定义(基线之外的领域特化):

- 维度 1(基线: scope/探测充分性)→ 本 skill: <领域特化描述,1/3/5 锚点>
- 维度 3(基线: 决策证据强度)→ 本 skill: <领域特化描述>
- 其余维度沿用基线

### 本 skill 自定义增维度(基线 7 维 + 以下):

- 维度 8 — <名称>: 1=... / 3=... / 5=...
- 维度 9 — <名称>: 1=... / 3=... / 5=...

### 本 skill 红线触发(§3 通用之外):

- 维度 X = 1 且 <条件> → <verdict 标签>
- 维度 Y = 1 且 <条件> → <verdict 标签>

### Aggregate → Verdict 映射(本 skill 自命名标签)

| Aggregate | Verdict | 行动 |
|---|---|---|
| ≥ 4.5 | `<clean 档标签>` | <行动> |
| 4.0-4.4 | `<with-warnings 档标签>` | <行动> |
| 3.0-3.9 | `<partial 档标签>` | <行动> |
| < 3.0 | `<failed 档标签>` | <行动> |

详细 1/3/5 锚点 + 各 verdict 的下一步行动见 `references/<role>-principles.md`。
```

各 skill 的 SKILL.md "Audit Checklist" 段因此从 ~30-60 行压缩到 ~15-20 行。详细领域锚点全部下沉到该 skill 的 `references/<role>-principles.md`。

## 8. 反模式(maintainer 红线)

- **改基线维度名 / 编号** → 失去跨 skill 对齐意义,违反者退回
- **删基线维度**(只可加,不可减)→ 同上
- **verdict 档数从 4 改成 3 / 5** → 会破坏 §4 通用语义映射
- **用几何平均 / 加权稀释短板** → 违反 §4 第二段
- **跳过维度但不标 `[n/a]` + 理由** → 按 1 分计入,且触发 §3 维度 6 → `partial` 路径
- **本文件下沉具体某 skill 的实例 1/3/5 锚点** → 锚点归各 skill SKILL.md / references,不污染共用元规范
