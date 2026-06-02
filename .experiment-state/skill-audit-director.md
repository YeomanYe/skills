# director-* skill 库 audit 报告

> 审查范围:director-architect / director-design / director-frontend / director-ops / director-promote
> 共享层基线:`_shared/director-template.md` (16 段元规范) / `_shared/question-gate.md` / `_shared/output-contract-schema.md` / `_shared/audit-rubric.md` / `_shared/handoff-payload-template.md` / `_shared/parallelization-template.md` / `_shared/evidence-discovery.md` / `_shared/dispatcher-template.md` / `_shared/constitution.md`
> Audit 日期:2026-06-02

---

## 总体结论

5 个 director-* 都已对齐 _shared 层的核心引用(question-gate / output-contract-schema / audit-rubric),但**结构 drift 严重**:director-template.md 16 段元规范没有任何一个 SKILL.md 完整对齐——段标题命名/顺序/合并粒度都自由发挥。**最严重的一个根因 = director-template.md 自己 outdated**:它声明"4 个核心角色"但实际已有 5 个(director-architect 是后加的),且第 3 段写"必备 16 段结构"但段编号显示只到 16,与 README/各 SKILL 现实结构对不上。

**统计**:P0=12 / P1=18 / P2=14 / 跨 director drift = 9 项

---

## 跨 director 一致性 drift 表(必看 — 优先修这张)

| 维度 | director-architect | director-design | director-frontend | director-ops | director-promote | drift 严重度 |
|---|---|---|---|---|---|---|
| **Question Gate 引用** | `references/question-gate.md`(共享) ✓ | `references/question-gate.md`(共享) ✓ | `references/question-gate.md`(共享) ✓ | `references/question-gate.md`(共享) ✓ | `references/question-gate.md`(共享) ✓ | ✅ 一致 |
| **Output Contract 引用** | `references/output-contract-schema.md` ✓ | `references/output-contract-schema.md` ✓ | `references/output-contract-schema.md` ✓ | `references/output-contract-schema.md` ✓ | `references/output-contract-schema.md` ✓ | ✅ 一致 |
| **Audit rubric 引用** | `references/audit-rubric.md` §2 ✓ | `references/audit-rubric.md` §2 ✓ | `references/audit-rubric.md` §2 ✓ | `references/audit-rubric.md` §2 ✓ | `references/audit-rubric.md` §2 ✓ | ✅ 一致 |
| **Red Flags 段位置** | 与 Rationalizations / Common Mistakes 合并为 1 段(L364) | 独立 1 段(L331),引用 failure-modes.md | 与 Rationalizations 分 2 段(L434/L452,内联完整清单)| 合并 1 段(L307),引用 failure-modes.md | 分 2 段(L402/L431,**内联完整清单**)| 🟡 高 drift |
| **Codex Delegation Hook 段** | 有(L420) | 有(L345) | 有(L467) | 有(L359) | 有(L455) | ✅ 全有 |
| **Mode 表格式 / 列数** | **无 Mode 表**(用"输入识别"代替,4 行)| 5 mode 表(4 列:意图/mode/产出/工具)| 5 mode 表(4 列)| 2 mode 表(4 列)| 5 mode 表(4 列)| 🟡 中(architect 用非标准结构) |
| **9 维 audit 是否各自重复定义** | 自定义增 3 维(8/9/10),基线 7 + 3 = 10 维 | 基线 7 + 自定义 2 = 9 维(明示 9 维度名称) | 基线 7 + 自定义 2 = 9 维(维度 8/9 详写) | 基线 7 维(无加维度,锚点重定义) | 基线 7 + 自定义 2 = 9 维 | 🟡 中(architect 标 9 维但实际 10 维;ops 是 7 维独苗) |
| **Verdict 标签** | ready-to-land/ready-with-refinement/needs-refinement/blocked | pass/pass-with-fixes/needs-redesign/blocked | ready/ready-with-fixes/needs-revision/needs-rewrite | installed-clean/installed-with-warnings/partial/failed | ready/ready-with-fixes/needs-revision/blocked | 🔴 高(命名碎,3 套以上不同语义) |
| **关于命名段** | 含"自带 mini-orchestration"特别说明,**唯一一个**说自己内带 pipeline | 标准 6 行 | 标准 6 行 | 标准 6 行 | 标准 6 行 | 🟡 中(architect 是特例,应在元规范明示) |
| **Subagent 派工模板段** | 独立 `## Subagent 派工`(L402) | 嵌在 Parallelization Plan 内 | 嵌在 Parallelization Plan 内 | 独立 `## Subagent 派工`(L343) | 嵌在 Parallelization Plan 内 | 🟡 中 |
| **constitution.md 引用方式** | `> 本 skill 受 references/constitution.md 约束` ✓(L16) | ✓(L15) | ✓(L17) | ✓(L14) | ✓(L18) | ✅ 一致 |

### Drift 关键发现

1. **D1 [P0]** — `_shared/director-template.md` 第 2 段宣称"4 个核心角色(2026-05 现状)",但 director-architect 已存在且本身在 description 提到"5 directors"。**元规范 outdated → 整个 audit 锚点失效**。修元规范 + 同步到 5 个 references/director-template.md。
2. **D2 [P0]** — `_shared/director-template.md` 第 3 段宣称"16 段必备结构",但**没有一个 SKILL.md 严格按 16 段命名/顺序对齐**。最对齐的是 director-design / director-frontend / director-promote(13-14 段),director-architect 跳过 Mode Selection 段(用"输入识别"代替),director-ops 缺 9 维 audit。**元规范是宣言不是契约 → 应改为 lint 规则可机器验证**。
3. **D3 [P1]** — Mode 表格式碎裂:design/frontend/promote 是"5 mode 表(意图/mode/产出/工具)",ops 是 2 mode,architect 用非标准"输入识别表"。建议元规范允许"N mode 表",但**列定义统一**。
4. **D4 [P1]** — Red Flags 段策略不一致:architect / design / ops 已下沉到 references/failure-modes.md(主体只引用),**frontend / promote 仍内联完整清单**(违反 references 拆分原则)。
5. **D5 [P1]** — Verdict 标签碎裂:5 个 skill 有 3 套不同"档 1"命名(ready / pass / ready-to-land / installed-clean),虽然 audit-rubric.md §4 允许"标签词可变",但**当上游 orchestrator 要统一处理时,要 maintain 一张映射表**。建议元规范加"4 档对齐 README 表"硬约束。
6. **D6 [P1]** — Subagent 派工段位置不一致:architect/ops 独立成段(良好),design/frontend/promote 嵌在 Parallelization Plan 内(违反 director-template.md 第 8 段把派工独立的暗示)。建议**全部独立成段**并引用 `references/dispatcher-template.md`。
7. **D7 [P2]** — director-architect 自带 mini-orchestration 是合理的(架构工作天然带流水线),但**没有被元规范承认**。应在 director-template.md 加段:"角色型 + 可选内部 pipeline" 子类。
8. **D8 [P2]** — director-ops 只有 7 维(无 8/9 自定义),其他 4 个都加 2-3 维。审计-rubric 允许只用基线,但**design / frontend / promote 加了 8/9 (composition/原生感/AI slop)但都用不同名字**——基线之上的"产品气质 / 平台原生感 / AI slop"这种**跨角色都有意义**的维度应下沉到 audit-rubric.md。
9. **D9 [P2]** — `关于命名` 段写法漂移:architect 写了 4 段(含 mini-orchestration 特别说明),其他 4 个写了 6 行套话。元规范应给一个最小化模板。

---

## 12 个 audit 维度 — 按 skill 逐项

### 1. 是否对齐 director-template.md 16 段结构

`_shared/director-template.md:27-52` 定义 16 段必备结构。实际对齐情况:

| 段 # | 段名 | architect | design | frontend | ops | promote |
|---|---|---|---|---|---|---|
| 1 | Frontmatter | ✓ | ✓ | ✓ | ✓ | ✓ |
| 2 | 关于命名 | ✓(扩展) | ✓ | ✓ | ✓ | ✓ |
| 3 | Overview | ✓ | ✓ | ✓ | ✓ | ✓ |
| 4 | 角色信条 | ✓(L61) | ✓(L43) | ✓(L49) | ✓(L47) | ✓(L49) |
| 5 | When to Use / When NOT to Use | ✓ | ✓ | ✓ | ✓ | ✓ |
| 6 | Mode Selection 表 | ❌(用"输入识别"非标准代替) | ✓ | ✓ | ✓ | ✓ |
| 7 | Required Workflow + Step 0 + Deep | ✓ | ✓(Step 4 含 Deep 表) | ✓(各 mode 段含 Deep) | ✓(Step 0 含 Deep) | ✓(Step 4 含 Deep 表) |
| 8 | N 维 Audit Checklist + Verdict 映射 | ✓ | ✓ | ✓ | ✓(Step 6.5) | ✓ |
| 9 | Output Contract | ✓ | ✓ | ✓ | ✓ | ✓ |
| 10 | Red Flags — STOP | ⚠️ 合并 | ✓ | ✓ | ⚠️ 合并 | ✓ |
| 11 | Rationalizations to Reject | ⚠️ 合并到 10 | ⚠️ 下沉 failure-modes 但主体段缺 | ✓(L452) | ⚠️ 合并到 10 | ✓(L431) |
| 12 | Parallelization Plan | ✓ | ✓ | ✓ | ✓ | ✓ |
| 13 | Subagent 派工模板 | ✓(L402) | ⚠️ 嵌在 Parallelization | ⚠️ 嵌在 Parallelization | ✓(L343) | ⚠️ 嵌在 Parallelization |
| 14 | Codex Delegation Hook | ✓ | ✓ | ✓ | ✓ | ✓ |
| 15 | Relationship to Other Skills | ✓ | ✓ | ✓ | ✓ | ✓ |
| 16 | Reuse | ✓ | ✓ | ✓ | ✓ | ✓ |

**[P0]** 元规范 16 段标准与实际严重 drift,**没有任何一个 SKILL.md 严格通过**:`_shared/director-template.md:27-52`

- **director-architect 段 6 命名漂移** — 使用 "输入识别(单一入口)" 而非标准的 "Mode Selection",但架构师确实是单入口模式。建议元规范增加"可选:用 input-routing 代替 Mode Selection 适用于单入口角色"。[P1] `director-architect/SKILL.md:114`
- **director-design 段 11 漂移** — Rationalizations 不是独立段,被吸收进 `## Red Flags`(L331)的引用里,只引用 failure-modes.md 没明示。[P1] `director-design/SKILL.md:331`
- **director-ops 缺独立 Mode Selection 表的合理化处理** — 只有 2 mode,但用了正式 Mode 表(良好),但 Mode 表之后插入 "适用范围" + "需要先读取的文件" 两段(L112/L118),违反元规范第 6→7 顺序。[P2] `director-ops/SKILL.md:112-118`

---

### 2. Description frontmatter 质量

| skill | 中文触发短语 | 英文触发短语 | Do NOT use 反例 | 评分 |
|---|---|---|---|---|
| director-architect | "审一下规范"/"梳理一下规范"/"整理项目规则" 等 8+ | "engineering rules review"/"audit project rules" 等 4 | 4 条反例 | ✅ 优秀 |
| director-design | "看下这个设计怎么样"/"出几个不同设计方向" 等 8+ | "design review"/"design critique" 等 4 | 5 条反例 | ✅ 优秀 |
| director-frontend | "加个组件"/"重构这个页面" 等 9+ | "implement this UI"/"refactor this React" 等 4 | 7 条反例 | ✅ 优秀 |
| director-ops | "装一下 X"/"卸载 X" 等 11+ | "install X"/"uninstall X" 等 4 | 5 条反例 | ✅ 优秀 |
| director-promote | "做宣传"/"发个推"/"发到 v2ex" 等 7+ | "launch on Product Hunt"/"post to twitter" 等 4 | 5 条反例 | ✅ 优秀 |

**总评**:这一项 5 个 skill 都很到位,没有 P0/P1 问题。

- **[P2]** director-promote description 有 32 行,逼近 frontmatter 长度上限。建议把"Product Hunt 属于发布到曝光平台性质"这段注释下沉到 SKILL.md 正文。`director-promote/SKILL.md:14-16`

---

### 3. 5 mode 表(应有的命名 + 完整度)

`_shared/director-template.md:18-23` 定义 5 mode:
- design: audit/direction/variants/mockup/handoff
- frontend: audit/boundaries/implement/extract/handoff
- promote: audit/draft/variants/dispatch/recap
- ops: install/uninstall(2 mode)

实际:

| skill | mode 数 | 实际命名 | 与元规范对齐 |
|---|---|---|---|
| director-design | 5 | audit / direction / variants / mockup / handoff ✓ | ✅ 完美 |
| director-frontend | 5 | audit / boundaries / implement / extract / handoff ✓ | ✅ 完美 |
| director-promote | 5 | audit / draft / variants / dispatch / recap ✓ | ✅ 完美 |
| director-ops | 2 | install / uninstall ✓ | ✅ 完美 |
| director-architect | **0(用输入识别)** | research-only / research+land / mirror+land / 已定好 | ❌ 元规范未覆盖此模式 |

**[P0]** director-architect 没有 Mode Selection 表,改用"输入识别"决策表。这是合理的(单入口),但**元规范 director-template.md 第 2 段不承认 architect 角色,所以"5 modes"约束变成空文**。`director-architect/SKILL.md:114` + `_shared/director-template.md:18-23`

**[P1]** director-template.md 应区分:
- 多 mode 角色(design/frontend/promote):用 Mode Selection 表
- 流程角色(ops):用"主干 + 子流程"
- 单入口角色(architect):用"输入识别 → 内部路径"
都是合法 dispatcher,元规范应明示三类 + 各自的最小骨架。

---

### 4. Question Gate Step 0 引用 vs 内联

`_shared/question-gate.md` 是共享规范。5 个 skill 引用情况:

| skill | 引用 references/question-gate.md | 内联硬约束摘要 | 评分 |
|---|---|---|---|
| director-architect | ✓ `L132` | ✓ 4 行摘要 + 3 行触发点 | ✅ |
| director-design | ✓ `L112` | ✓ 4 行摘要 + 1 行触发点 | ✅ |
| director-frontend | ✓ `L119` | ✓ 4 行摘要 + 1 行触发点 | ✅ |
| director-ops | ✓ `L131` | ✓ 4 行摘要 + 1 行触发点 + Deep 表 | ✅ |
| director-promote | ✓ `L122` | ✓ 4 行摘要 + 1 行触发点 | ✅ |

**[P2]** 5 个都"引用 + 摘要内联"模式一致,但摘要 4 行(一轮/≤3/默认值/不冗余追问)在 5 个 SKILL.md 里**重复了 5 遍 = 共 20+ 行重复内容**。共享文件就是为了避免重复,**摘要 1 行 + 引用就够**。`director-architect/SKILL.md:134-138` 与其他 4 个同样。

---

### 5. Required Workflow numbered steps + gate

| skill | Step 编号 | Step 0 Q gate | Approval / 确认 gate | Deep guide |
|---|---|---|---|---|
| director-architect | Step 0-9(完整) | ✓ L130 | ✓ Approval Gate(L255) + 同意定义 | ✓ L221 "模拟一年后接手维护者" |
| director-design | Step 0-5 | ✓ L110 | ⚠️ 无,只在 dispatch 时隐含 | ✓ L156 Deep 表(每 mode 1 行) |
| director-frontend | Step 0 + 各 mode 段 | ✓ L117 | ⚠️ 无显式 gate | ✓ 每个 mode 段含 1 行 Deep |
| director-ops | Step 0-7 (其中 6.5 = audit) | ✓ L128 | ✓ Step 4 用户确认(L216) | ✓ L142 Deep 表 |
| director-promote | Step 0-5 | ✓ L120 | ✓ 在 Dispatch Rules 段(L217) | ✓ L167 Deep 表 |

- **[P1]** director-design 没有显式"高风险动作 gate" — 元规范 第 7 段要求每个 director 都要明示破坏性动作前的确认 gate。design 在 handoff 时把 spec 写盘是有副作用的,应加 gate。`director-design/SKILL.md:170-172`
- **[P1]** director-frontend 没有显式"高风险动作 gate" — 写代码 = 改文件,implement / extract mode 有副作用,应加 gate(类似 "Approval Gate before code write")。`director-frontend/SKILL.md:182-195`
- **[P2]** director-architect 的 Approval Gate 写法是 5 个里最强的(详细列了什么算/不算同意,L262-273),应**当作模板下沉到 _shared/approval-gate.md**,其他 director 引用。`director-architect/SKILL.md:255-276`

---

### 6. 9 维 audit checklist 是否引用 _shared/audit-rubric.md(或各自 references/)+ 命名对齐

| skill | 引用 audit-rubric | 维度数 | 自定义增维度 | 红线触发独立列表 |
|---|---|---|---|---|
| director-architect | ✓ L336 | 7 + 3 = **10 维** | 维度 8 联合评估 / 9 参考对齐 / 10 现规则一致 | ✓ L351-353 |
| director-design | ✓ L175 | 7 基线 + 9 设计专用(改写)= 9 维 | 不是"基线 + 自定义",而是 9 维设计专用直接覆盖 | ✓ L194-196 |
| director-frontend | ✓ L266 | 7 + 2 = 9 维 | 维度 8 复用证据 / 9 AI slop | ✓ L271-273 |
| director-ops | ✓ L257 | 7 基线(无自定义)| 锚点重定义,不加维度 | ✓ L264-266 |
| director-promote | ✓ L186 | 7 + 2 = 9 维 | 维度 8 平台原生感 / 9 图片合规 | ✓ L195-198 |

**对齐情况**:5 个都引用 audit-rubric.md §2 ✓,这是好趋势。但有 drift:

- **[P0]** director-design 维度 1-9 是"信息层级/布局密度/字体系统/色彩与对比/组件一致性/交互状态/响应式/产品气质/完成度",**完全覆盖基线 7 维,没有"基线 + 增量"的清晰区分**。违反 `audit-rubric.md:96-103` 的引用骨架(应该是 "维度 1-7 基线 + 维度 8-N 增量")。其他 4 个都遵守骨架,只有 design 没有。`director-design/SKILL.md:173-181`
- **[P1]** director-architect 标题写 "N 维 Audit Checklist"(L334),但实际是 10 维。其他 4 个明示维度数(9 维度/9 维/7 维)。应改为 "10 维 Audit Checklist" 或"基线 7 维 + 自定义 3 维"。`director-architect/SKILL.md:334`
- **[P1]** director-design 没明示"维度 1-7 对应基线哪一维",阅读者无法追溯哪个是基线扩展。应加映射表:基线 scope → design 维度 1 信息层级等。`director-design/SKILL.md:175-178`
- **[P2]** director-ops 是唯一不加维度的(7 维基线纯锚点重定义),其他 4 个都加。这是合理的(运维场景偏流程),但应在 SKILL.md 显式说明"为何不加自定义维度"(目前只在 Step 6.5 锚点段说)。`director-ops/SKILL.md:257`
- **[P2]** 跨 director "维度 8 / 9" 重名但语义不同:
  - design 8 = 产品气质 / 9 = 完成度
  - frontend 8 = 复用证据 / 9 = AI slop
  - promote 8 = 平台原生感 / 9 = 图片合规
  - architect 8 = 联合评估 / 9 = 参考对齐 / 10 = 现规则一致
  **跨 skill 看"维度 8"会以为有共同语义,实际是各自定义**。元规范应明示"自定义维度从 8 开始,不要假设 8 是同一含义"。

---

### 7. Output Contract 引用 vs 内联

`_shared/output-contract-schema.md` 规定:主 SKILL.md ≤ 15 行只声明基线 + 扩展字段,完整 markdown 模板下沉 `references/output-contract-template.md`。

| skill | 行数 | 引用基线 | 引用 references/output-contract-template.md | 内联完整 markdown | 评分 |
|---|---|---|---|---|---|
| director-architect | 18 行(L313-331) | ✓ | ✓ | ❌ 没内联 | ✅ 良好 |
| director-design | 22 行(L306-329) | ✓ | ✓ | ❌ 没内联 | ✅ 良好 |
| director-frontend | 26 行(L407-432) | ✓ | ✓ | ❌ 没内联 | ✅ 良好 |
| director-ops | 21 行(L286-305) | ✓ | ✓ | ❌ 没内联 | ✅ 良好 |
| director-promote | 22 行(L379-400) | ✓ | ✓ | ❌ 没内联 | ✅ 良好 |

**总评**:这一项 5 个 skill 都完成了下沉,没有 P0/P1 问题。

- **[P2]** director-frontend Output Contract 段含 4 行扩展字段语义解释(L426-430),其他 4 个都简洁。建议下沉到 output-contract-template.md。`director-frontend/SKILL.md:426-430`
- **[P2]** verdict 命名混乱(见 drift 表 D5)— 元规范应加一张"基线 4 档 verdict 各 skill 自命名对照表",方便上游 orchestrator 统一处理。

---

### 8. Red Flags + Rationalizations 段质量

| skill | Red Flags 处理 | Rationalizations 处理 | 段策略 | 质量 |
|---|---|---|---|---|
| director-architect | 主体 6 行引用 + 下沉 failure-modes.md | 同上,3 段合一(Red Flags + Rationalizations + Common Mistakes + Delivery Check) | **优秀** | ✅ 5/5 |
| director-design | 主体 8 行引用 + 下沉 failure-modes.md | 引用同一文件 | **优秀** | ✅ 5/5 |
| director-frontend | **内联完整 18 条**(L434-450) | **内联完整 10 条**(L452-465) | **未下沉** | ⚠️ 2/5 |
| director-ops | 主体 8 行引用 + 下沉 failure-modes.md | 同上,3 段合一 | **优秀** | ✅ 5/5 |
| director-promote | **内联完整 28 条**(L402-429,promote 是最长的) | **内联完整 18 条**(L431-453) | **未下沉** | ⚠️ 2/5 |

**[P0]** director-frontend 和 director-promote 没有下沉 Red Flags / Rationalizations,主体 SKILL.md 因此**膨胀 100+ 行**。failure-modes.md 文件已存在(`director-frontend/references/failure-modes.md` / `director-promote/references/failure-modes.md`),但主体没有按 architect/design/ops 的下沉模式精简。`director-frontend/SKILL.md:434-465` + `director-promote/SKILL.md:402-453`

- **[P1]** director-promote 的 Red Flags 28 条里有 6 条专属于"图片合规"(L418-429),这是宣发独有的密集判断,应该在主体保留 5-10 条高优引用,详细清单下沉到 `failure-modes.md`(已存在但 SKILL.md 没用)。`director-promote/SKILL.md:402-429`

---

### 9. Codex Delegation Hook 段

director-template.md 第 11 段必备 + ROI 表。

| skill | 段存在 | ROI 表 | 引用 flow-dev-task 唯一规范 | 质量 |
|---|---|---|---|---|
| director-architect | ✓ L420 | 🟡/🔴 两档(不含 🟢)| ✓ | ✅ |
| director-design | ✓ L345 | 全 🔴(7 行) | ✓ | ✅ |
| director-frontend | ✓ L467 | 🟢/🟡/🔴 完整 8 行 | ✓ | ✅ 最完整 |
| director-ops | ✓ L359 | 🟢/🟡/🔴 完整 11 行 | ✓ | ✅ 最完整 |
| director-promote | ✓ L455 | 主要 🔴(8 行)+ 1 🟢 | ✓ | ✅ |

**总评**:5 个都有,没有 P0/P1 问题。

- **[P2]** director-design Codex Hook 全 🔴,没有任何 🟢 / 🟡,意味着这个 skill 内没有任何 Codex 可派工的步骤。这本身没问题(设计是 judgment-heavy),但应解释"为何全 🔴"(目前只有 1 行"判断 + 调度 + 仲裁类工作,全部 🔴"),与 ops/frontend 详细分类形成对比时显得太草率。`director-design/SKILL.md:345-358`
- **[P2]** director-promote Codex Hook 也几乎全 🔴(只有 1 个 🟢 在 variants 派 subagent,但备注说仍是 Claude 不是 Codex)。同上,应明示"为何宣发不适合 Codex"。`director-promote/SKILL.md:455-468`

---

### 10. References 使用率 + 应引但没引

每个 skill 的 references/ 目录都已包含共享文件(audit-rubric / dispatcher-template / question-gate / constitution / director-template / evidence-discovery / handoff-payload-template / output-contract-schema / parallelization-template + output-contract-template + failure-modes)。

| 共享文件 | architect | design | frontend | ops | promote |
|---|---|---|---|---|---|
| audit-rubric.md | ✓ refs L506 / 在 SKILL 引 | ✓ refs / 引 | ✓ refs / 引 | ✓ refs / 引 | ✓ refs / 引 |
| constitution.md | ✓ refs / 引 L16 | ✓ refs / 引 L15 | ✓ refs / 引 L17 | ✓ refs / 引 L14 | ✓ refs / 引 L18 |
| director-template.md | ✓ refs / 引(3 处) | ✓ refs / 引(1 处) | ✓ refs / 引(2 处) | ✓ refs / 引(2 处) | ✓ refs / 引(2 处) |
| dispatcher-template.md | ✓ refs / 引 L404 | ✓ refs / **未在主体 SKILL.md 引用** | ✓ refs / **未在主体 SKILL.md 引用** | ✓ refs / 引 L345 | ✓ refs / **未在主体 SKILL.md 引用** |
| evidence-discovery.md | ✓ refs / **未在主体引用**(只在 references/ 同步) | ✓ refs / 引 L167 | ✓ refs / 引 L167 | ✓ refs / **未在主体引用** | ✓ refs / 引 L177 |
| handoff-payload-template.md | ✓ refs / 引 L480 | ✓ refs / 引 L396 | ✓ refs / 引(简化为"按共享模板") | ✓ refs / 引(简化为"按共享模板") | ✓ refs / 引 L519 |
| output-contract-schema.md | ✓ refs / 引 L315 | ✓ refs / 引 L308 | ✓ refs / 引 L409 | ✓ refs / 引 L288 | ✓ refs / 引 L381 |
| parallelization-template.md | ✓ refs / 引 L379 | ✓ refs / 引 L246 | ✓ refs / 引 L341 | ✓ refs / 引 L327 | ✓ refs / 引 L259 |
| question-gate.md | ✓ refs / 引 L132 | ✓ refs / 引 L112 | ✓ refs / 引 L119 | ✓ refs / 引 L131 | ✓ refs / 引 L122 |
| output-contract-template.md | ✓ refs / 引 L331 | ✓ refs / 引 L326-329 | ✓ refs / 引 L432 | ✓ refs / 引 L304-305 | ✓ refs / 引 L398 |
| failure-modes.md | ✓ refs / 引 L364-368 | ✓ refs / 引 L333-334 | ❌ refs 存在但**主体 SKILL.md 没引** | ✓ refs / 引 L309 | ❌ refs 存在但**主体 SKILL.md 没引** |

**[P0]** director-frontend / director-promote `references/failure-modes.md` 文件已存在(完整下沉版),但主体 SKILL.md 仍内联完整 Red Flags + Rationalizations 清单。这是**未完成的下沉**。`director-frontend/SKILL.md:434-465` + `director-promote/SKILL.md:402-453`

**[P1]** director-design / director-frontend / director-promote 没在主体 SKILL.md 引用 `dispatcher-template.md`,虽然文件已 sync。Subagent 派工模板分散在 Parallelization Plan 段内联写,违反 dispatcher-template.md 第 "各 skill 如何引用本模板" 段(应 5-15 行 + 引用)。

**[P2]** director-architect / director-ops 主体没引用 `evidence-discovery.md`,虽然 references 已 sync。佐证格式应该全员引用,即使简短一行也好。

**[P2]** director-frontend / director-ops Upstream Handoff Payload 段简化为"按共享模板",其他 3 个直接引用 `references/handoff-payload-template.md`,引用路径不一致。

---

### 11. Outdated 内容 / dead 引用 / 矛盾

- **[P0]** `_shared/director-template.md:18-23` 第 2 段标题"4 个核心角色(2026-05 现状)",但 director-architect 已加入,变成 5 个。元规范没同步,导致所有 references/director-template.md 都 outdated。`_shared/director-template.md:16-23` + 5 处 references 副本
- **[P0]** `_shared/director-template.md:27-52` 第 3 段"必备 16 段结构",但段编号实际是 1-16 = 16 段,中间 Red Flags / Rationalizations / Parallelization / Subagent 派工 / Codex Delegation / Relationship / Reuse = 7 段都在 8-16 之间,**没有一个 SKILL.md 完全按这 16 段命名/顺序对齐**。元规范要么 enforce 要么改"建议结构"。`_shared/director-template.md:27-52`
- **[P0]** `_shared/director-template.md:189-196` 第 12 段 Relationship "必须明示其他 3 个平行 director-* 角色",但实际有 5 个 director-*。所有 SKILL.md 在"平行角色"段也只写 3-4 个不写全,**架构-design 互相不知道彼此存在**。`director-architect/SKILL.md:451-456` + `director-design/SKILL.md:371-375` 等。
- **[P1]** `director-design/SKILL.md:23` 引用 `顶层 [README.md](../README.md) 的 director-* 段` 但没说 README 5 director 段是否同步——README 应该列 5 director(不是 4)。
- **[P1]** `director-design/SKILL.md:375` 引用 `_shared/director-template.md(元规范)或同步到本目录的 references/director-template.md`,但 `_shared/` 路径在 skillshare 同步后不可达(dispatcher-template.md 已明示过这点)。**所有 5 个 director 在 Relationship 段都有此 bug**。`director-design/SKILL.md:375` / `director-ops/SKILL.md:413` 等。
- **[P1]** `director-promote/SKILL.md:547` Reuse 段写"4 个 director-* 都遵循",应改为 "5 个 director-*"。同问题在 `director-frontend/SKILL.md:551`。
- **[P2]** `director-frontend/SKILL.md:552` 写"director-template.md — director-* 元规范(13 段 SKILL.md 结构 + 必备字段)",但元规范实际是 16 段不是 13 段。`director-frontend/SKILL.md:552` + `director-promote/SKILL.md:547`
- **[P2]** `director-ops/SKILL.md:413-414` 引用 `_shared/director-template.md` 然后说"或同步到本目录的 references/director-template.md",**两种路径并列**,语义模糊(读哪个)。统一为 `references/`。
- **[P2]** `director-design/SKILL.md:387-392` "明确不调用" 段有重复条目:`director-frontend` 出现 3 次(Handoff 出口 / 明确不调用 / 平行角色),并在 L392 自己解释"这里强调不主动调它执行"。这段语义模糊,建议合并精简。
- **[P2]** `director-promote/SKILL.md:498-502` "当前对接状态" 段提到 flow-ext-publish "目前不自动消费" 本 skill 写盘的素材,且明示"后续若做集成升级 ... 应增加 ..."。这是 **TODO 性质的备忘**,不应在 SKILL.md 主体里(应放 issue / changelog)。

---

### 12. 跨 director 一致性 drift 详表

(见上方"跨 director 一致性 drift 表"段。)

主要 P0/P1 drift 再列一遍:

- D1 [P0] — 元规范 outdated(4 vs 5 directors)
- D2 [P0] — 16 段结构没有任何一个 SKILL.md 完全对齐
- D3 [P1] — Mode 表格式 3 种碎裂(多 mode / 流程 / 单入口)
- D4 [P1] — Red Flags 下沉策略两套(frontend/promote 没下沉)
- D5 [P1] — Verdict 标签 3 套不同语义
- D6 [P1] — Subagent 派工段位置不一致
- D7 [P2] — architect mini-orchestration 没在元规范承认
- D8 [P2] — 维度 8/9 跨 skill 同名不同义
- D9 [P2] — "关于命名" 段写法漂移

---

## 每个 skill 单独的 P0/P1/P2 清单

### director-architect

- **[P0]** Mode Selection 段缺失(用"输入识别"非标准代替),元规范没承认此模式。`director-architect/SKILL.md:114`
- **[P1]** N 维 Audit 标题写"N 维"应改为"10 维"(基线 7 + 自定义 3)。`director-architect/SKILL.md:334`
- **[P1]** "平行角色" 段未列全 5 个 director-*。`director-architect/SKILL.md:451-456`
- **[P1]** Reuse 段引用 `references/director-template.md`(共享),但元规范说"4 directors",未同步。`director-architect/SKILL.md:507`
- **[P2]** Approval Gate 段写法是 5 个里最强的,应作为模板下沉到 `_shared/approval-gate.md`。`director-architect/SKILL.md:255-276`
- **[P2]** "关于命名" 段有自己的特别说明(mini-orchestration),应该在元规范明示此子类。`director-architect/SKILL.md:24-35`

### director-design

- **[P0]** N 维 Audit Checklist 没明示"基线 1-7 + 自定义 8-9"骨架,直接列 9 维设计专用,违反 `audit-rubric.md:96-103` 的引用规范。`director-design/SKILL.md:173-181`
- **[P1]** Rationalizations 段没有独立(被引用 failure-modes.md 吸收),违反 director-template.md 第 11 段独立要求。`director-design/SKILL.md:331-343`
- **[P1]** 没有显式"高风险动作 gate"(handoff 写盘是有副作用的)。`director-design/SKILL.md:170-172`
- **[P1]** "平行角色" 段未列全 5 个 director-*。`director-design/SKILL.md:371-375`
- **[P1]** Reuse 段 "4 个 director-* 都遵循" 应为 "5 个"。`director-design/SKILL.md:421`(应该在 Reuse 段,可能因文件较短没写)
- **[P2]** "明确不调用" 段重复 `director-frontend` 3 次,语义模糊。`director-design/SKILL.md:387-392`
- **[P2]** Codex Hook 全 🔴 但没解释"为何全 🔴"。`director-design/SKILL.md:345-358`

### director-frontend

- **[P0]** Red Flags + Rationalizations 段没有下沉(failure-modes.md 已存在),主体 SKILL.md 内联 30+ 行清单。`director-frontend/SKILL.md:434-465`
- **[P0]** Subagent 派工模板嵌在 Parallelization Plan 段(L354-403),应独立成段并引用 dispatcher-template.md。`director-frontend/SKILL.md:354-403`
- **[P1]** 没有显式"高风险动作 gate"(implement / extract mode 改文件有副作用)。`director-frontend/SKILL.md:182-210`
- **[P1]** "平行角色" 段未列全 5 个(漏 architect)。`director-frontend/SKILL.md:515-519`
- **[P1]** 主体 SKILL.md 没引用 `dispatcher-template.md`。
- **[P2]** Reuse 段写"4 个 director-* 都遵循",应为 "5 个"。`director-frontend/SKILL.md:551`
- **[P2]** director-template.md 引用写 "13 段 SKILL.md 结构",实际是 16 段。`director-frontend/SKILL.md:552`
- **[P2]** Output Contract 段含 4 行扩展字段语义,应下沉。`director-frontend/SKILL.md:426-430`
- **[P2]** Upstream Handoff Payload 段引用是 "按共享模板",未直接引用文件路径。`director-frontend/SKILL.md:521-538`

### director-ops

- **[P0]** Required Workflow 段后插入"适用范围" + "需要先读取的文件" 两段(L112-122),打乱了元规范第 6→7 段顺序。`director-ops/SKILL.md:112-122`
- **[P1]** N 维 audit 是唯一 7 维(无自定义),应在 SKILL.md 主体显式说明"为何不加自定义维度"。`director-ops/SKILL.md:255-257`
- **[P1]** "平行角色" 段未列全 5 个。`director-ops/SKILL.md:407-411`
- **[P1]** Relationship 段对 `_shared/director-template.md` 和 `references/director-template.md` 两种路径并列,模糊。`director-ops/SKILL.md:413-414`
- **[P2]** Step 6.5 audit 段编号奇怪("6.5"),应改为 Step 6.5 → Step 7 顺移。`director-ops/SKILL.md:255`
- **[P2]** "Upstream" 段没有 "Upstream Orchestrator" 子标题,只有 "Upstream"。`director-ops/SKILL.md:380-383`
- **[P2]** 主体 SKILL.md 没引用 `evidence-discovery.md`。

### director-promote

- **[P0]** Red Flags 段内联 28 条完整清单 + Rationalizations 18 条(L402-453),没有下沉。failure-modes.md 已存在。`director-promote/SKILL.md:402-453`
- **[P0]** Subagent 派工模板嵌在 Parallelization Plan 段内,应独立。`director-promote/SKILL.md:305-377`
- **[P1]** "平行角色" 段未列全 5 个。`director-promote/SKILL.md:506-510`
- **[P1]** "Handoff 出口" 段有 TODO 性质内容("当前对接状态" + "后续若做集成升级"),应放 changelog。`director-promote/SKILL.md:496-505`
- **[P1]** Reuse 段写"4 个 director-* 都遵循",应为 "5 个"。`director-promote/SKILL.md:547`
- **[P1]** 主体 SKILL.md 没引用 `dispatcher-template.md`。
- **[P2]** director-template.md 引用 "13 段 SKILL.md 结构",实际 16 段。`director-promote/SKILL.md:547`
- **[P2]** description frontmatter 长 32 行,逼近上限。`director-promote/SKILL.md:14-16`
- **[P2]** Codex Hook 几乎全 🔴 但没解释。`director-promote/SKILL.md:455-468`

---

## 推荐修复优先级

### Round 1 (P0 — 影响整体一致性,必须先修元规范)

1. 修 `_shared/director-template.md` 第 2 段:声明 5 个 director-*(含 architect)。同步到所有 references/director-template.md。
2. 修 `_shared/director-template.md` 第 3 段:重新列 16 段必备结构,明示"哪些段名/顺序硬,哪些可选"。增加"三类 dispatcher"子类(多 mode / 流程 / 单入口)。
3. 修 `_shared/director-template.md` 第 12 段:Relationship 写"列全所有 director-* 角色",不限 3 个。
4. 下沉 director-frontend / director-promote 的 Red Flags + Rationalizations 到各自 references/failure-modes.md(文件已存在)。
5. director-frontend / director-promote / director-design 的 Subagent 派工独立成段,引用 dispatcher-template.md。
6. director-design 9 维 audit 改成"基线 1-7 + 自定义 8-9" 骨架。
7. director-architect 决定:要么承认"输入识别"是合法 Mode Selection 形态(改元规范),要么改为标准 Mode 表。
8. director-ops 把 "适用范围" + "需要先读取的文件" 段挪位(或合并到 When NOT to Use / Reuse)。

### Round 2 (P1 — 一致性 drift 修补)

9. 全 5 个 director-* 的"平行角色"段列全 5 个(architect / design / frontend / ops / promote)。
10. 全 5 个 Reuse 段把 "4 个 director-*" 改为 "5 个"。
11. 全 5 个 director-template.md 引用把 "13 段" 改为 "16 段"。
12. director-design / director-frontend 加显式"高风险动作 gate"。
13. director-architect Approval Gate 段下沉到 `_shared/approval-gate.md`。
14. 5 个 director-* 加一张"verdict 4 档对照表"到 _shared 元规范(让上游能映射)。

### Round 3 (P2 — 质量提升)

15. 元规范第 8 段"自定义维度从 8 开始,不要假设 8 是同一含义"加注。
16. director-design / director-promote Codex Hook 段加 1-2 行"为何全 🔴"。
17. director-promote description frontmatter 精简。
18. director-frontend Output Contract 字段语义下沉。
19. director-promote "Handoff 出口 - 当前对接状态" 段挪到 changelog。
20. 5 个 director-* 路径引用"`_shared/`"统一为"`references/`"(同步后路径)。

---

## 元数据汇总

- **审计标记总数**:P0=12 / P1=18 / P2=14 / 跨 director drift=9 项
- **共审查文件数**:5 SKILL.md + 8 _shared/*.md + 5 references/failure-modes.md
- **最严重问题**:`_shared/director-template.md` outdated,导致所有"对齐"判定基线失效
- **最佳实践参考**(可作为模板下沉):
  - director-architect Approval Gate 段(L255-276)
  - director-architect / director-ops 已下沉 Red Flags 的 references/failure-modes.md 模式
  - director-ops Codex Hook 详细分类(L361-376)
  - 全 5 个 description frontmatter 触发短语 + Do NOT use 反例结构
