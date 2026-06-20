# director-* 角色型 skill 元规范

> 本文件定义 **director-*** 命名空间下所有角色 skill 的**标准结构**。
> 新建角色 / 改造现有角色都必须对齐本规范。当前 6 个 director-* 都遵循此模板(部分有合理例外,见 §2 子类)。

## 1. 命名空间含义

`director-*` 是**角色型 agent**(role-based agent),区别于 `flow-*` 编排型流水线(workflow orchestrator)。

| 类型 | 命名 | 本质 | 例子 |
|---|---|---|---|
| **角色型** | `director-<role>` | 一个虚拟专家:**专业判断 + 自己干活 + 调度同领域工具** | director-design / director-promote / director-frontend / director-ops / director-architect / director-pm |
| **编排型** | `flow-<workflow>` | 一条流水线:**串联多个 skill,推任务从起点到终点** | flow-dev-task / flow-project-finish / flow-codex-goal |
| **工具型** | `<tool>` | 单一能力,被 director-* 或 flow-* 调用 | web-image / clean-commit / delivery-gate |

## 2. 5 个核心角色(2026-06 现状)+ 子类型

### 标准 director-*(5 个)— 单角色 + 同领域工具调度

| Skill | 角色 | N modes 摘要 |
|---|---|---|
| `director-design` | 设计师 | audit / direction / variants / mockup / handoff(5 modes) |
| `director-frontend` | 前端工程师 | audit / boundaries / implement / extract / handoff(5 modes) |
| `director-promote` | 宣发者 | audit / draft / variants / dispatch / recap(5 modes) |
| `director-ops` | 运维 | install / uninstall(2 modes,装卸主干) |
| `director-pm` | 产品经理 | clarify / prd / prioritize / critique(4 modes) |

### 角色型 + 内部 mini-pipeline(1 个)— architect 子类

| Skill | 角色 | 内部 pipeline 性质 |
|---|---|---|
| `director-architect` | 架构师 | 含"盘点 → 评估 → 设计 → 暂停求批 → 执行"内部小流水线,跟标准 director-* 不同(标准是 mode 切换,不是 stage 串联) |

**子类规则**:角色型 + 内部 pipeline 是合理的(架构 / project-prep 这类工作天然带流水线)。这种 skill **可**:
- 用"输入识别表"代替标准 Mode Selection 表(因为不是 mode 切换是 stage 走通)
- Mode 数量不必 5(architect 实际是单"流水线 mode")
- 9 维 audit 可扩展到 10 维(加上"规则路由"等架构特有维度)

但**仍必须**:
- 对齐 Q gate / Output Contract / audit-rubric / constitution 引用
- 包含 Executor Selection / Red Flags + Rationalizations / Relationship 等 14-16 段
- 明示**为什么**是子类(在 SKILL.md "关于命名"段说清楚)

未来候选:`director-pm` / `director-qa` / `director-security`。

## 3. 必备 16 段结构(SKILL.md)

每个 director-* 的 `SKILL.md` 必须含以下段(顺序 + 命名严格一致):

```
1. Frontmatter (name + description)
2. 关于命名 (引本元规范)
3. Overview (角色定位 + 它不是 / 它是 / 核心信念)
4. 角色信条 (2026-05 新增 — 第一人称立场 + 心理测试题 + 失败模式)
5. When to Use / When NOT to Use
6. Mode Selection 表 (mode / 用户意图 / 主要产出 / 默认调度工具)
7. Required Workflow
   ├── Step 0 Question Gate(开干前澄清,≤ 3 问题,模糊回复取默认)
   ├── Step 1 通用前置(探测/收集证据)
   ├── Step 2..N mode-specific 流程
   └── 每个 mode 含 Deep 段(thinking guide,一句话指引)
8. N 维 Audit Checklist + Aggregate → Verdict 映射表
9. Output Contract (强制全字段 + 佐证字段必填)
10. Red Flags — STOP
11. Rationalizations to Reject
12. Parallelization Plan
13. Subagent 派工模板(调其他 director-* / 工具时必须显式指挥)
14. Executor Selection
15. Relationship to Other Skills (4 director-* 互引 + Handoff 出口 + Upstream Payload)
16. Reuse (tests/cases.md + references 索引)
```

### 角色信条段写作要求(段 4)

**位置**:Overview 之后,When to Use 之前。

**结构**:
1. **第一人称宣言**:`我是 X,不是 Y;我...,不是...`(立调性 + 划边界)
2. **心理测试题**:`我做 X 时心里只问一个问题:"<具体测试问题>?"`(给评判一个具体锚点)
3. **核心立场段**:1-2 段散文式立场(可带情绪,可带审美焦虑)
4. **失败模式清单(5-6 条)**:每条带"为什么这是和稀泥/AI slop/制造噪音"的二阶解释
5. **统一收尾**:`越界 = 假装什么都懂 = 让每个领域都做半吊子`

**调性参考**:director-design / director-frontend / flow-codex-goal 的角色信条段。

**禁止**:
- 写成抽象口号("追求卓越")—— 必须具体到这个角色独有的失败模式
- 缺心理测试题 —— 没测试题的信条等于装饰
- 失败模式 ≥ 7 条 —— 超过 6 条说明颗粒度不对,合并或下沉到 Red Flags

## 4. references/ 必备文件

```
references/
├── <role>-principles.md       # N 维 rubric + 1/3/5 锚点(audit 用)
├── evidence-discovery.md      # 证据查找规则(来自 _shared/,sync-shared.sh 同步)
├── parallelization-template.md # 并行编排(来自 _shared/,sync-shared.sh 同步)
├── handoff-payload-template.md # handoff schema(来自 _shared/,sync-shared.sh 同步)
└── <domain>-*.md              # 各角色特有(如 director-design 的 design-principles.md /
                               #  director-frontend 的 boundary-discovery.md)
```

## 5. Output Contract 强制佐证字段(ACBDQC Blueprint)

借鉴谷歌经理 ACBDQC 方法论 + director-ops 的 knowledge-and-citation 实践:
**每个评分项 / 每个 finding 必须含可核对的佐证**。

通用佐证字段规范:

| 角色 | 评分时佐证格式 | findings 时佐证格式 |
|---|---|---|
| director-design | `[截图路径:视口尺寸 / 项目 design tokens 路径 / 对照锚点编号]` | `[截图:坐标 / 元素 selector]` |
| director-frontend | `[文件:行号 / 项目内相似实现路径 / 对照锚点编号]` | `[文件:行号 + 代码片段引用]` |
| director-promote | `[平台 URL / 字符数 / 配图路径 / 平台调性 reference]` | `[平台:位置 / 文案原文引用]` |
| director-ops | `[command 输出摘要 / 知识库路径 / 检索命令]` | `[command:行号 / 错误日志引用]` |

**禁止**写"<证据>"或"<结论>"等空泛占位符。必须落到具体引用源。

## 6. Question Gate(Step 0)规范

借鉴 ACBDQC Q + flow-dev-task Question Budget:

```
Step 0 — Question Gate(开干前澄清)

在 mode 判定 + Step 1 探测完成后,进入执行前必须做一次 Q gate:
1. 如果当前任务/材料有关键歧义(无法从上下文推断的决策点)
   → 一次性列出 ≤ 3 个问题(每个带建议默认值)
2. 如果无歧义 → 直接进入执行,**不要**为了"确认一下"而问
3. 用户回模糊("随便/按你的来/直接做") → 取默认,不再问
4. 用户回明确指令 → 按指令执行

**硬约束**:Q gate 只一轮。第二轮追问 = Red Flag。
```

## 7. Deep 段(thinking guide)规范

每个 mode 必须含一句 thinking 指引(借鉴 ACBDQC D),让 AI 进入"角色视角"而非泛泛输出。

参考写法:

| 角色 / mode | Deep 指引示例 |
|---|---|
| director-design audit | "请模拟首次访问用户 3 秒判断,从信息密度 + 视觉舒适度 + 时间感 + 价值感评判" |
| director-frontend implement | "请模拟一年后接手维护者读这段代码,问'5 分钟内能否理解 + 修改'" |
| director-promote audit | "请模拟目标平台资深用户的视角,问'第一眼会不会觉得这是 AI 写的'" |
| director-ops uninstall | "请模拟一个月后用户发现某 LaunchAgent 被误删导致崩溃的场景,反推现在该做什么备份" |

## 8. Subagent 派工模板规范

任何 director-* 调其他 skill 必须用**显式指挥模板**(subagent 默认不会主动 invoke skill)。

通用模板:

```
Task: <一句话任务>

必须调用的 skill:
  - **<skill-name>**(mode=<mode>)
    subagent 默认不会主动 use skill,本指令明确要求你 invoke <skill-name>

输入(只读):
  - <字段 1>: <value>
  - <字段 2>: <value>
  ...

输出目录: .agent/jobs/<task-id>/
返回 JSON: {<schema>}

约束:
  - <硬约束 1>
  - <硬约束 2>
```

## 9. Verdict 映射规范

每个 director-* 的 N 维 audit 必须有 4 档 verdict 映射(名称按角色调整,语义对应):

| Aggregate | Verdict 通用语义 | 角色名称示例 |
|---|---|---|
| ≥ 4.5 | 可交付,无修 | `ready` / `pass` / `installed-clean` |
| 4.0-4.4 | 可交付,可选修 | `ready-with-fixes` / `pass-with-fixes` / `installed-with-warnings` |
| 3.0-3.9 | 必修后可交付 | `needs-revision` / `needs-fix` |
| < 3.0 | 整体不达标,回前置 mode | `needs-rewrite` / `needs-redesign` / `blocked` / `failed` |

特殊触发(任一维度严重失分):直接降级为最差档,跳过 aggregate 计算。

## 10. Parallelization Plan 规范

每个 director-* 必须明确并行集合 / 串行集合,即使"通常不并行"也要写明理由。

参考:`director-design` variants 模式 3 路并行 / `director-promote` dispatch 多平台串行 /
`director-frontend` extract 通常串行 / `director-ops` 装多工具可并行(无依赖)。

## 11. Executor Selection 规范

每个 director-* 必须有 `## Executor Selection` 段,引 `../_shared/executor-selection-template.md`,**不内联 ROI 表**。

通用准则(细则全在 _shared 模板,各 director-* 不重复):
- **决策 / 判断 / 评分类** → 当前 agent 自写(judgment-heavy,不外派)
- **大体量纯样板(脚手架 / 测试夹具 / 批量同结构)** → 派便宜档 subagent(haiku/sonnet)/ fast
- **Codex 重委派** → 默认不走,仅 ≥2h 长跑 + 清晰验收 + 可并行/批量时考虑

## 12. Relationship 段规范

必须含 4 段:

1. **Upstream Orchestrator** — 谁会触发本 skill(列已实际对接的;未对接的标"潜在,需手工接入")
2. **调度的工具** — self orchestrates 哪些 skill / tool
3. **Handoff 出口** — 不调用,只移交 spec 给谁
4. **Upstream Handoff Payload** — 上游传什么字段,有 → 不重复探测;无 → 自己探测;**禁止冗余追问**

必须明示其他 3 个平行 director-* 角色(列名 + 一句话职责)。

## 13. README 同步规范

中心仓 README.md 的 "director-* 角色" 段必须列全 4 个角色 + 元规范链接到本文件。
新加角色时同步更新 README。
