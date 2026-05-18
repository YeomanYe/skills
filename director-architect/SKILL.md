---
name: director-architect
description: >
  Use when 用户需要"架构师视角"——评估、设计、重构、对齐项目的工程规范体系
  (CONTRIBUTING.md / docs/<domain>/ / AGENTS.md / RULE.md / 技术栈约束 / 规则分域 /
  规则路由)。本 skill 扮演架构师角色：盘点现状 + 联合多个 best-practice skill 评估 +
  设计目标结构 + 暂停求批 + 落地执行。触发短语包括："审一下规范"、"梳理一下规范"、
  "整理项目规则"、"规范应该怎么分"、"对齐 X 项目的规则结构"、"按 X 项目做规范"、
  "engineering rules review"、"audit project rules"、"design rules structure"、
  "align project conventions"。
  Do NOT use for: 单文件规则的措辞修订(→ 直接 Edit)/ README / CHANGELOG / 上架文案
  (→ flow-project-finish / flow-ext-publish)/ 视觉规则的具体 token 取值
  (→ director-design)/ 单个 skill 自己的写法(→ writing-skills)。
---

# director-architect — 虚拟架构师

## 关于命名

`director-*` 是 **角色型 agent** 命名空间（区别于 `flow-*` 编排型流水线）。
每个 director-* 都是一个"虚拟专家角色"：专业判断 + 调度自己领域的工具，
但**不越界到其他角色的领地**。详见顶层 [README.md](../README.md) 的 director-* 段
与元规范 [`references/director-template.md`](references/director-template.md)。

**特别说明**：本 director 是 director-* 家族里**自带 mini-orchestration** 的角色——
内部含「调研（联合评估）→ 审批 gate → 落地」三相流水线。这与 director-design 那种
"纯产出型 director"略不同。取舍来源：架构工作天然带流水线属性（评估必先于设计，
设计必先于落地，落地必先于批准），强行拆成多个 skill 反而割裂职责，且会丢"决策连贯性"。
因此采用 director-* 的统一文档骨架，但承认内部有流水线。

对用户**单一暴露面**：用户不需要挑 mode，本 skill 根据输入信号自决走哪条内部路径
（见下方"输入识别"段）。

## Overview

`director-architect` 是"架构师"角色——给定一个项目，**先判断真实诉求**（审一下 / 梳理 /
对齐参考 / 已定好让我写），再走内部 pipeline：

1. **Research Phase**：盘点现状 + 识别技术栈 + 动态匹配 best-practice skill + 联合评估 +
   设计目标结构 + 合成改进方案（含**决策记录**：哪些是 best-practice 间冲突的自决，
   选了什么，为什么）
2. **Approval Gate**：把方案 + 文件级 diff 预览交给用户，**显式等用户 yes**
3. **Land Phase**：仅在批准后写文件

它不是：
- ❌ 单文件规则编辑器（用户只想改一句话 → 直接 Edit）
- ❌ 单个 best-practice skill 的替代品（它**调度**它们，而不是吞并）
- ❌ 收尾文档处理器（README / CHANGELOG / 上架文案 → `flow-project-finish`）
- ❌ 设计师 / 前端工程师 / 运维（→ director-design / director-frontend / director-ops）

它是：
- ✅ **架构判断 + 跨 skill 联合评估 + 落地编排者**
- ✅ 自己跑规则盘点、结构设计、迁移路径合成
- ✅ 调度（**强制环节**）：项目实际栈对应的 best-practice skill 一起 review
- ✅ 最终交付**自决但留痕**：冲突的决策必须在 Output Contract 显式记录

核心原则：**没看到当前项目证据 + 没跑联合评估，就不出结构方案**。

## When to Use

- 用户想新建一个工程规范体系（greenfield 项目，规则从 0 起步）
- 用户想整理已有的项目规范、规则文档或 AI 协作规则
- 用户要审查规则现状（"审一下"、"看看"、"诊断"）
- 用户要按参考项目镜像规则结构（"按 X 项目做"、"对齐 Y"）
- 用户已经定好结构，只想落地（"已经定好了，帮我写"）
- 用户讨论 `CONTRIBUTING.md`、`docs/<domain>/index.md`、规则入口、规则路由、规范分层

## When NOT to Use

- 只想改单条规则文字或错别字 → 直接 Edit
- 只想讨论某个 skill 自身的写法 → `skill-creator` / `writing-skills`
- 只想审一次代码实现 → `superpowers:code-reviewer` 或对应技术栈 best-practice skill
- 只想写 README / CHANGELOG / 上架文案 → `flow-project-finish` / `flow-ext-publish`
- 只想讨论视觉设计 token 的具体取值 → `director-design`
- 项目已进入实现中段，只想调整单一规则 → 直接编辑该规则文件
- 完整多阶段项目启动（含 MVP / preview / 设计） → `flow-project-bootstrap`（它内部会调本 skill）

## 输入识别（单一入口，不让用户挑 mode）

director 根据用户输入信号自动选内部路径，**不需要用户先挑 mode**：

| 输入信号                                  | 内部路径                            |
|-------------------------------------------|-------------------------------------|
| "审一下" / "诊断" / "看看" / "评估一下"   | **research only**（不进 land）      |
| "梳理" / "整理" / "改造" / "重构规则"     | research → Approval → land          |
| "按 X 项目" / "对齐 Y" / "参照那个项目"   | research（含镜像兼容检查）→ land    |
| "已经定好了，帮我写" / "按这个方案落地"   | 跳过部分 research，进 land 前先**回放 plan 求批准**（不假设用户口述就是最终方案） |

**禁止**让用户在对话里挑 mode（`audit`/`design`/`land` 之类）。如果输入信号模糊
（例如只说"帮我看下规则吧"），按 Question Gate 默认走完整 research only，再问要不要落地。

## Required Workflow

### Step 0 — Question Gate（开干前澄清，**通用规范**）

详见 [`references/question-gate.md`](references/question-gate.md)（共享）。

硬约束（摘要）：
- **一轮** + **≤ 3 个问题**，每个带建议默认值
- 模糊回复（"随便/按你的来"）→ 取默认，不再问
- 无歧义 → 直接执行，不为"确认一下"而问
- 已在 Upstream Handoff Payload 给的字段 + Step 1 已探测的事实 → **禁止再问**

本 skill 常见 Q gate 触发点（**只在拿不到时问**）：
- 目标项目根路径（默认 `pwd` / `git rev-parse --show-toplevel`）
- 参考项目路径或 URL（"按 X 项目"信号触发时；找不到 X 才问）
- 是否落地（用户说"审一下" → 默认只 research；说"梳理" → 默认 research+land）

---

### Research Phase（**强制完整执行，所有子环节缺一不可**）

#### Step 1 — 盘点项目规则现状

读当前项目已有的规则入口和正文（**带证据**，每条结论附 `[file:line]`）：

- `CONTRIBUTING.md`
- `RULE.md`
- `AGENTS.md`
- `docs/`（递归扫所有 md）
- `ai/`、`.claude/`、`.agents/`（若存在）
- `package.json` / 各栈元信息

盘点要回答：
- 当前有哪些规则文档（**列路径**）
- 哪些是入口，哪些是正文
- 哪些内容重复（**指出具体片段**）
- 哪些内容放错层（**对照分类模型**）
- 哪些领域缺失

#### Step 2 — 识别技术栈（粗粒度）

只读元信息，不深度扫描源码：

- `package.json` → `react`/`next`/`vue`/`nuxt`/`svelte`/`solid`/`preact`/`astro`/`remix`/`vite`/`tailwindcss`/`fresh`
- `deno.json` → `deno`
- `go.mod` → `go`
- `Cargo.toml` → `rust`
- `pyproject.toml` / `requirements.txt` / `uv.lock` → `python`
- `pnpm-workspace.yaml` / `nx.json` / `turbo.json` / `lerna.json` → `monorepo`
- `tsconfig.json` → `typescript`

用户手动指定的栈**优先**。最终产出明确 stack 列表，如 `["fresh", "deno", "preact", "tailwindcss"]`。

#### Step 3 — 动态匹配 best-practice skill（**禁止写死清单**）

在以下本地目录扫描：

- `~/.claude/skills/`
- `~/.agents/skills/`
- `~/.config/skillshare/skills/`
- 当前项目的 `.claude/skills/`、`.agents/skills/`（若存在）

匹配规则详见 [`references/skill-matching-rules.md`](references/skill-matching-rules.md)。
要点：

1. skill 目录名或 `SKILL.md` 的 `name` 含 stack 关键字
2. `SKILL.md` 的 `description` 含 stack 关键字
3. 用户明确点名的 skill 直接纳入
4. 项目规则架构方法本身——本 skill **自己**承担（不再调 `project-rules-design`，它已被本 skill 吸收）

去重后产出本次评估的 skill 列表，**在 Output Contract 显式列出来源路径**。
某个栈完全找不到对应 skill，**如实标注"未覆盖"**，不要硬套不相关的 skill。

只读本地目录，不访问网络，不调用 `npx skills`。

#### Step 4 — 联合评估（**强制环节，不可跳过**）

让每个匹配到的 skill 在自己的职责范围内审视当前规范：

- **本 skill 自己**负责：入口结构、分域、层级、重复、混层、优先级、领域目录是否同时具备
  `index.md` 和 `rules.md`
- **技术栈 skill** 负责：该栈应该被写入规范的工程约束
- **用户额外指定的 skill**：按其自述职责审视

「某个栈应该进入哪个规则域、覆盖哪些关键点」统一查
[`references/stack-checklist.md`](references/stack-checklist.md)（本 skill 自带，
与原 `flow-project-rules` 引用同一份事实）。

若 `stack-checklist.md` 没覆盖某个栈，按 checklist 末尾"未覆盖栈的处理"规则走：
不硬套最接近条目，在最终报告显式保留缺口。

评估时要明确区分四类问题：**规范缺失** / **规范偏差** / **规范冗余** / **规范放错层**。

**Deep 段（thinking guide）**：模拟一年后接手维护者读这个规则系统，问"5 分钟内能找到任意领域
的入口 + 知道每个领域的总纲在哪 + 知道遇到该栈应该看哪个文件吗？"——找不到就是 finding。

#### Step 5 — 比对参考项目（仅当用户给了参考项目）

按 [`references/mirroring-checklist.md`](references/mirroring-checklist.md) 检查：

- 参考项目的规则结构（目录骨架、分域）
- 与当前项目栈的**兼容性**（不可机械搬运）
- 哪些值得借鉴，哪些不适用，**为什么**

**禁止**："按 X 项目做"就直接 cp，必须先对齐栈兼容性。

#### Step 6 — 结构设计 + 方案合成

目标结构至少说明：
- 总入口文件（默认 `CONTRIBUTING.md`）
- 分几个领域（默认起点：`architecture` / `coding` / `ui` / `ai-guide`）
- 每个领域是否需要 `index.md`（**必须**）和 `rules.md`（**必须**）
- 每个领域下有哪些二级文件
- 各文件之间的优先级与阅读路径

**领域目录的标准文件骨架**（详见 [`references/stack-checklist.md`](references/stack-checklist.md)
末尾的引用指向）：
- `index.md`：导航（不堆正文）
- `rules.md`：总纲（不塞命令、验证步骤、专题细则）

**决策记录**（**强制字段，自决必须留痕**）：
- 列出 best-practice skill 之间结论冲突的点
- 列出本 skill 内部权衡（例如"是否给 `testing` 单独分域 vs 合入 `coding`"）
- 每个冲突点：备选方案 / 选定方案 / 理由

---

### Approval Gate（**唯一的暂停点**）

输出"调研报告 + 改进方案 + 文件级 diff 预览 + 决策记录"后，**显式问用户**：

> 以上方案是否可以落地？要不要调整？

详见 [`references/approval-format.md`](references/approval-format.md)。

**在收到明确同意前，不得进入 Land Phase**。

以下含糊回应**不算**同意：
- 「嗯」「嗯嗯」「哦」
- 「ok 吧」「行吧」「好像可以」
- 「随便」「都行」「你看着办」
- 只复述了部分计划但没有表态

明确同意至少需要类似「可以落地」「就按这个改」「go ahead」「开始吧」这种不含保留的表态，
或逐条勾选哪些可改哪些不改。

**plan 内容变更**（用户提了调整，本 skill 重写了方案）后，旧的 yes **不算批准**，
必须重新征求确认。

---

### Land Phase（仅当方案被批准）

#### Step 7 — 落地前校验

- 运行 `git status` 确认工作区干净；若不干净，提示用户并等待处理
- 若计划包含大量文件迁移，提醒用户当前 commit 可作为回退点

#### Step 8 — 写文件

只执行用户已确认的部分：

- 按计划新增 / 修改 / 迁移 / 合并 / 删除文件
- 迁移内容要真实搬运正文，**不只是重命名**
- 更新活跃引用路径（例如 `AGENTS.md` 指向 `CONTRIBUTING.md`）
- 不允许新旧两套规则入口同时有效

落地后**可建议**（不强制）调用 `clean-commit` 做一次收尾提交。
若用户明确要求"顺便提交"，**不要**自己 `git add` / `git commit`，转交给 `clean-commit`。

#### Step 9 — 最终报告

按 Output Contract 的 "Land 输出" 段格式输出。

---

## 输入识别 → 走到哪一步

| 输入信号 | research 全跑？ | Approval gate？ | Land？ |
|---|---|---|---|
| "审一下" / "诊断" | ✅ | 出 plan 但不强求 yes | ❌ |
| "梳理" / "整理" / "改造" | ✅ | ✅ 必须 yes | ✅ |
| "按 X 项目" / "对齐 Y" | ✅（含 Step 5 镜像） | ✅ | ✅ |
| "已经定好了，帮我写" | 部分跳过（仍跑 Step 1-2 验证） | ✅ **必须回放 plan 求确认** | ✅ |

## Output Contract

### research 输出（**所有 mode 都必须输出，强制全字段**）

```md
## Director-Architect Research Report

### 任务理解
- 用户原话:
- 内部路径判定: research-only | research+approval+land | research+mirror+approval+land | land-only
- 触发信号: "审一下" | "梳理" | "按 X 项目" | "已经定好了" | 其他: <原文>

### 项目规则现状（**带证据 [file:line]**）
- 入口文件: <CONTRIBUTING.md / RULE.md / AGENTS.md / ... 列路径 + 行数>
- docs/ 树: <实际目录结构>
- 重复内容: <具体片段 + 出现位置>
- 放错层内容: <对照分类模型说明>
- 缺失领域: <list>

### 识别到的技术栈
- 自动识别: <stack list + 元信息来源>
- 用户指定: <list 或 "无">
- 最终栈清单: <merged>

### 参与联合评估的 skill 清单
- <skill-name> (<来源路径>) — 结论: <一句话>
- <skill-name> (<来源路径>) — 结论: ...
- **未覆盖的栈**: <list 或 "无">

### 联合评估结果（按四类问题分）
- 规范缺失: <list>
- 规范偏差: <list>
- 规范冗余: <list>
- 规范放错层: <list>

### 参考项目对齐（**仅当 Step 5 跑了**）
- 参考项目路径: <path 或 URL>
- 借鉴的模式: <list>
- 不适用的部分 + 理由: <list>

### 决策记录（**自决必须留痕，缺失 = Red Flag**）
- 冲突点 1: <best-practice skill A 说 X，B 说 Y>
  - 备选方案: <list>
  - 选定方案: <which>
  - 理由: <why>
- 冲突点 2: ...
- 内部权衡 1: <例如 "testing 单独分域 vs 合入 coding">
  - 备选方案 / 选定 / 理由

### 目标结构
- 总入口: <path>
- 分域目录:
  - <domain>/
    - index.md（导航职责: ...）
    - rules.md（总纲职责: ...）
    - <二级文件 1>: <职责>
    - ...
- 阅读优先级 / AI 路由: <说明 AI 先读什么、再读什么>

### 文件级变更清单（diff 预览）
- 新增: <path>
- 修改: <path + 摘要>
- 迁移: <from → to + 是否真搬正文>
- 合并: <多个 → 一个>
- 删除: <path>

### 风险与权衡
- 风险 1: <如 "迁移后大量历史引用需修">
- 权衡 1: <如 "选了 strict mode tsconfig 会增加现存 type errors">

### Next Step
- 若 research-only: 等用户决定是否进入落地
- 若 research+approval+land: **Approval Gate** — 等用户明确 yes
- 若 land-only: 已回放 plan，等用户确认这是最终方案

### 明确不在职责内（告知 orchestrator）
- README / CHANGELOG → flow-project-finish
- 视觉 token 具体取值 → director-design
- 单 skill 自身写法 → skill-creator / writing-skills
- 写生产代码 → director-frontend
```

### land 输出（**仅当 Land Phase 执行后**）

```md
## Director-Architect Land Report

### 批准证据引用
- 用户原话: <quote 不含糊的批准表态>
- 时间戳:

### 改了哪些文件
- 新增: <path>
- 修改: <path>
- 迁移: <from → to>
- 合并: <多个 → 一个>
- 删除: <path>

### 委派情况（哪些子任务调了哪些 skill）
- clean-commit: <invoked / not invoked>
- 其他: <如调了某 best-practice skill 出具体规则文本>
- 自做: <list>

### 遗留
- 待处理的历史引用: <list>
- 未覆盖的栈: <list>

### Delivery Check
- [ ] CONTRIBUTING.md 只做总入口（无正文堆积）
- [ ] 每个领域目录同时存在 index.md + rules.md
- [ ] 无两套同时有效的规则体系
- [ ] 项目实际栈都被某个规则域覆盖（或显式标"未覆盖"）
- [ ] 决策记录已在 research 报告留痕

### 下一步建议
```

## Red Flags — STOP

任一命中必须停下：

- **用户没明确 yes 就 land**（含糊回应、"嗯嗯"、"看着办"都不是 yes）
- **没跑联合评估就给 plan**（Step 4 是强制环节）
- **plan 内容变更后用旧的 yes 当批准**（必须重新征求）
- **把 best-practice skill 列表写死**（必须按当前栈动态匹配，写死 = 漏栈或硬塞）
- **自决冲突时不在 Output Contract 留决策记录**（缺记录 = 黑箱）
- **"按 X 项目"直接 cp 参考项目目录结构**（必须先跑 Step 5 兼容性检查）
- **跳过 Step 1 项目证据采集，凭印象设计结构**
- **机械改文件名而不重写内容边界**
- **保留双轨规则体系**（新旧同时有效）
- **没看到项目证据就断言"规范已完善 / 已对齐"**
- **混入 README / CHANGELOG / 上架文案重写**（越界，归 flow-project-finish / flow-ext-publish）

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "用户输入已经很清楚了，跳过联合评估直接给结构" | 联合评估是 research 的**强制环节**，不是"看情况"；跳过 = 漏栈风险 |
| "这个项目没什么栈相关 skill 可匹配，跳过 evaluate" | 至少要显式说"未匹配到栈相关 skill"+ 自己跑结构评估；不能省略输出 |
| "用户说了'按 X 项目做'，直接镜像就行" | 仍要先对齐当前项目栈是否兼容（Step 5），不然把不适用的规则硬塞过来 |
| "冲突太微小，不用写决策记录" | 自决就必须留痕，**无例外**；微小冲突也要写"自决了 + 理由：不重要" |
| "用户口头 OK 了就开始 land" | "OK" / "嗯" / "看着办" 都不是明确 yes，必须显式问到"可以落地"级别表态 |
| "plan 没大改，沿用上次的 yes" | 内容变更后任何级别都要重新征求；只有完全没改才能沿用 |
| "顺便把 README 也整理了" | 越界。README → flow-project-finish |
| "顺便把 commit 也帮 ta 提交了" | clean-commit 的职责，转交它，不要自己 git add |
| "AI 没读 stack-checklist 也能凭经验给规则" | 必须查清单，避免漂移；项目实际栈未覆盖时必须显式标"未覆盖" |
| "用户已经走过 project-prep 了，跳过 Step 1 盘点" | project-prep 不读项目规则文档；本 skill 的 Step 1 是独立证据源 |

## Common Mistakes

- 把"梳理"信号当成"审一下"（漏了 Land Phase 询问）
- Step 4 联合评估只读 skill 名，不真消费其 description / SKILL.md 中的判断逻辑
- 决策记录只写"选了 A"，不写备选 / 理由（**等于没写**）
- 把 `index.md` 写成总纲（堆正文）或把 `rules.md` 写成导航（只列链接）
- 迁移内容时只 `mv` 文件，不重写内容边界，结果旧分类还残留在文本里
- Approval Gate 后立即开干，不再做最后一次 `git status` 校验
- 把未覆盖的栈静默吞掉，不在报告里显式列出

## Delivery Check

宣称工作完成前，核对：

### research 阶段
- [ ] Step 1 盘点项目规则现状（带 `[file:line]` 证据）
- [ ] Step 2 识别技术栈（自动 + 用户指定）
- [ ] Step 3 动态匹配 best-practice skill（写出来源路径）
- [ ] Step 4 联合评估（每个 skill 出一句话结论）
- [ ] Step 5 仅当用户给参考项目时执行
- [ ] Step 6 结构设计 + **决策记录**完整

### Approval Gate（若进入 land）
- [ ] 显式向用户提问"是否可以落地"
- [ ] 收到明确同意表态（不是"嗯"或"看着办"）
- [ ] plan 变更后重新征求过

### land 阶段
- [ ] 落地前 `git status` 干净
- [ ] 文件变更与批准的 diff 一致
- [ ] 无双轨规则体系
- [ ] 历史引用已更新或在报告显式列遗留
- [ ] 项目实际栈都有规则覆盖（或显式标"未覆盖"）

## Parallelization Plan

详见 [`references/parallelization-template.md`](references/parallelization-template.md)（共享）。

本 skill 的并行集合：

| Slot | 任务 | 形态 | 串/并 |
|---|---|---|---|
| `stack-detect` | Step 2 读元信息（package.json / Cargo.toml / go.mod 等） | Bash 并行 | 并 |
| `skill-scan` | Step 3 扫 4-5 个本地 skill 目录 | Bash 并行 | 并 |
| `rules-read` | Step 1 读本项目规范 + 可选参考项目规范 | Bash 并行（cat / find 同时跑） | 并 |
| Step 4 联合评估 | 串行（依赖前 3 路全部完成） | — | 串 |
| Step 6 结构设计 | 串行（依赖 Step 4 + 5 输出） | — | 串 |
| Step 7-9 落地 | 串行（顺序写文件） | — | 串 |

**Reduce 策略**：方式 3（内存 JSON 汇总）—— 3 路 Bash 输出由本 skill 解析合并成单一
`evaluation-input.json`，交给 Step 4。

**orchestrator 在 3 路 Bash 派发后短暂 idle**（等待最长一路完成，通常是 clone 参考项目）。
纯 Bash 并行不需要派 subagent。

**收益**：原 ~10min 串行（含 clone 参考项目）→ ~5min。

参考项目 clone 慢（网络）会拖累，可设 30s 超时；超时则降级为"只评估本项目"分支。

## Subagent 派工模板（如调用其他 skill）

本 skill 主要**自己跑**联合评估（读匹配到的 best-practice skill 的 description + SKILL.md 后
自己代入判断），通常**不派 subagent**。

特殊情况（用户要求"让某个 best-practice skill 真跑一遍 review"）派工模板：

```
Task: 让 <best-practice-skill> 在 <当前项目> 上跑一次规则 review

必须调用的 skill:
  - **<best-practice-skill>**(自身默认 mode)
    subagent 默认不会主动 use skill，本指令明确要求你 invoke <best-practice-skill>

输入（只读）:
  - 项目根: <path>
  - 现有规则文件清单: <list>
  - 识别到的技术栈: <stack list>

输出目录: .agent/jobs/architect-review-<skill-name>/
返回 JSON: {skill, status, findings: [...], suggestions: [...], errors}

约束:
  - 只看当前项目实际证据，不发明结论
  - 输出严格按 findings + suggestions 结构
  - **不**直接改文件（落地由本 skill 在 Land Phase 统一做）
```

## Codex Delegation Hook

Codex 是对等 agent，能做本 skill 的所有执行工作。是否派工取决于 **ROI**。

### 🟡 中 ROI 视情况派
- **Step 8 落地修改**（≥ 10 文件迁移 / ≥ 30 处引用更新）：Claude 把每个 mv + 每处引用更新
  写进 SPEC（含 voice 保留约束），Codex 实施，Claude 验收引用是否真解析 + 风格是否漂移
- 派工前提：迁移规模真大（小规模 < 10 文件时 SPEC 撰写成本 ≈ 直接做）

### 🔴 低 / 负 ROI 不建议派
- **Step 1-6 research 全部**：识别栈 / 匹配 skill / 读取规范 / 联合评估 / 决策记录 都是
  judgment-heavy，Codex 起新进程拿不到完整评估框架
- **Approval Gate**：决策类
- **Step 8 小规模迁移**（< 10 文件）：SPEC 撰写成本 > 节省
- **Step 9 最终报告**：依赖整个评估上下文

### 派 Codex 时必须传入 SPEC 的硬约束
- 每个文件迁移的 from→to（精确路径）
- 每处引用更新的 from-pattern → to-pattern（含上下文行号或前后文）
- voice 保留要求："保留原句式 / 原术语 / 原作者风格"
- 验收命令：`grep -r "<old-path>" .`（应无结果）+ 抽样人工 review

派工细则全部以 `flow-dev-task` 的 Codex Delegation Hook 为唯一规范，本 skill 不重复。

## Relationship to Other Skills

### Upstream Orchestrator
本 skill 可由以下编排器调用：
- `flow-project-bootstrap` Stage 2.1 规则脚手架阶段（**替代原 flow-project-rules**）
- 也可被用户直接触发

### 平行角色（director-*）
- `director-design` — 设计师（视觉判断 + 设计工具调度）
- `director-frontend` — 前端工程师（JSX UI 实现 / audit / 抽组件）
- `director-promote` — 宣发者（多平台发布 + 文案审材料）
- `director-ops` — 运维（软件装/卸）
- 详见 [`references/director-template.md`](references/director-template.md)（元规范）

### 调度的工具（self orchestrates，动态匹配）
- 由 Step 3 动态决定，**无固定清单**
- 常见栈对应：`vercel-react-best-practices` / `developing-preact` / `deno-expert` /
  `deno-frontend` 等
- `clean-commit` — Land Phase 后用户要求"顺便提交"时转交

### Handoff 出口（不调用，只移交）
- `flow-project-finish` — README / CHANGELOG / 收尾文档
- `flow-ext-publish` — 上架文案 / 营销材料
- `director-design` — 视觉 token 具体取值

### 替代关系（**本 skill 创建后这两个会删除**）
- `project-rules-design` — 已被本 skill 吸收（规则结构设计 + stack-checklist）
- `flow-project-rules` — 已被本 skill 吸收（联合评估 + 审批 + 落地编排）

### 明确不调用（**主动调用属越界**）
- `frontend-design` — 写生产代码，越界
- `huashu-design` — 视觉原型，越界
- `web-image` — 固定尺寸图，越界

### Upstream Handoff Payload（**本 skill 从上游接收的字段**）

按 [`references/handoff-payload-template.md`](references/handoff-payload-template.md)，
上游 orchestrator 调本 skill 时**必须传**：

| 字段 | 必填 | 说明 |
|---|---|---|
| `task_id` | ✅ | 任务唯一标识 |
| `objective` | ✅ | 一句话目标（"梳理规则" / "审规则" / "按 X 项目对齐"） |
| `risk_class` | ✅ | low / medium / high（high = 涉及主入口 CONTRIBUTING / 跨多个 domain 重构） |
| `tech_stack` | 推荐 | 项目已识别的技术栈（避免本 skill 重复探测） |
| `project_root` | 推荐 | 项目根路径 |
| `reference_project` | 可选 | 用户指定的参考项目路径或 URL |
| `prior_context` | 可选 | 上游 Context Harvest 的 git/branch/diff 状态 |
| `approval_inherited_from_orchestrator` | 可选（bootstrap 专用） | `true` 表示上游编排器（如 `flow-project-bootstrap` Stage 1）已让用户批过总设计，本 skill 在 Approval Gate 处可**自动 yes** 直接进入 Land Phase。**缺失或为 false** → 仍走完整 Approval Gate。**唯一允许跳过 Approval Gate 的开关**。 |

**如果上游已传**：本 skill 不重复探测，直接用。
**如果上游未传**：本 skill 自己探测（Step 1 + 2）。

## Reuse

测试用例在 [`tests/cases.md`](tests/cases.md)。
栈 → 规则域对照清单在 [`references/stack-checklist.md`](references/stack-checklist.md)。
skill 匹配规则在 [`references/skill-matching-rules.md`](references/skill-matching-rules.md)。
Approval Gate 格式在 [`references/approval-format.md`](references/approval-format.md)。
参考项目镜像检查清单在 [`references/mirroring-checklist.md`](references/mirroring-checklist.md)。
并行编排规范在 [`references/parallelization-template.md`](references/parallelization-template.md)（共享）。
handoff payload schema 在 [`references/handoff-payload-template.md`](references/handoff-payload-template.md)（共享）。
Question Gate 规范在 [`references/question-gate.md`](references/question-gate.md)（共享）。
director-* 元规范在 [`references/director-template.md`](references/director-template.md)（共享）。
