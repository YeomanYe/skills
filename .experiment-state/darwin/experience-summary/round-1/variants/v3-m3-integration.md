---
name: experience-summary
description: Use after finishing a real task to triage the lesson/pattern/gotcha into the right architectural layer — picks among constitution / shared metaspec / skill-doctor rule / director-* / flow-* / CLAUDE.md / nested CLAUDE.md / hook / script / MCP / auto memory / discard. Triggers on phrases like "这次学到的 xxx 该写到哪", "经验该沉淀到哪一层", "踩了个坑想沉淀", "复盘", "lesson learned", "where should this go", "post-task triage", "exp-sum", "es 这条经验", "经验分诊". 不替代 retro 会议、不替代 flow-skill-dev 写新 skill、不替代 brainstorming。
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)
> **Constitution fallback(全局优先级)**: 本 skill 任何条款若与 `_shared/constitution.md` 冲突,**constitution > exp-sum**。
> 解读: exp-sum 只是把经验路由到正确层,自己不是价值观源头。任何 5 段输出 / handoff JSON / 信号发射,
> 若实际违反 constitution(例如越权改 source、越权 commit、伪造证据),立刻让步,本 skill 优先回滚。

# Experience Summary —— 经验分诊

## Overview

每完成一次真实任务后,把"学到的东西 / 踩的坑 / 新约束 / 新流程"分诊到 agent 架构的正确层级。

核心信念:**skill / CLAUDE.md / hook / constitution 不是同一种东西,选错层 = 经验白攒**。
- 放在常驻层(CLAUDE.md)的应该是高频、高广适、低歧义的;专题流程进常驻 = 每次会话烧 token 还不被认真看
- 放在按需层(skill)的应该是多步流程 / 专题判断;通用价值观进 skill = 散落各处、不互相覆盖
- 放在强制层(hook / constitution)的应该是"零例外、不靠模型自觉"的;只是建议进强制 = 误伤

本 skill 不修代码,只输出**分诊结论 + 推荐位置 + 写作草稿 + 上移提醒**。

## When to Use

- 用户刚完成一个真实任务,问"这次学到的 X 应该放哪"
- 用户说"踩了个坑想沉淀" / "想把这个流程固定下来" / "复盘"
- 用户在 CLAUDE.md / skill / hook 几个选项之间纠结
- 用户发现某个 skill 反复触发同一个规则,问"是不是该上移成通用约束"

## When NOT to Use

- 用户在**做任务中**(用 `flow-dev-task` / `flow-codex-goal`)
- 用户要**创建/改写 skill**(用 `flow-skill-dev`)
- 用户要**头脑风暴**新方向(用 `superpowers:brainstorming`)
- 用户要**写完整 retro / post-mortem 报告**(更重,本 skill 只做单条分诊)
- 用户想**批量整理**历史经验(本 skill 单次只分诊一条)

## Workflow

### Step 1: 锁定要分诊的经验

请用户用**一句话**描述这次想沉淀的内容。模糊就追问(最多 2 个问题):

- 这条经验是"每次都要做"还是"特定情况下要做"?
- 它只对当前项目有用,还是跨项目通用?
- 它需要执行真实动作,还是只是约束模型行为?
- 触发场景是什么?(写代码时 / commit 前 / 部署时 / review 时 ...)

如果用户给的是"我觉得 agent 应该更聪明点"这种空话,直接告诉用户**这条不该沉淀**,跳到 Step 5。

### Step 2: 跑判断树(12 个出口)

按顺序问 Q0 → Q10,**第一个 yes 即出口**。每个 Q 的判定信号 / 反例 / 边界规则 / 决策流程图见
`references/judgment-tree.md`(完整版)。下面只列入口提问 + 命中出口:

- **Q0**: 这条经验是不是其实**不该沉淀**? → 出口: **L0 丢弃**
- **Q1**: 是不是"跨所有 skill 通用的**价值观 / 安全 / 身份**"? → 出口: **L1 `_shared/constitution.md`**
- **Q2a**: 是不是"约束 skill 自身怎么写的**元规范**(结构/模式)"? → 出口: **L2a `_shared/<topic>.md`**
- **Q2b**: 是不是"可机器 **lint 的硬规则**"? → 出口: **L2b skill-doctor 新规则**
- **Q3**: 是不是"**必须每次执行、零例外**、不能靠模型自觉"? → 出口: **L3 hook**
- **Q4**: 是不是"需要**真实执行命令 / 查询接口 / 读取数据**"? → 出口: **L4 script / MCP**
- **Q5**: 是不是"**只对某目录、某类文件、某个模块**生效"? → 出口: **L5 nested CLAUDE.md**
- **Q6**: 是不是"**单一专业领域**的判断 / 审查 / 出方向"? → 出口: **L6 改对应 director-***
- **Q7**: 是不是"**多步流程、跨多个角色**、需要 orchestrator 编排"? → 出口: **L7 改对应 flow-***
- **Q8**: 是不是"每个会话都应该知道的**项目级高频默认行为**"? → 出口: **L8 `CLAUDE.md` / `AGENTS.md`**
  - **硬约束**: CLAUDE.md 控制在 **200 行以内**(Anthropic 官方);超了说明专题流程混进来了,该下沉到 skill
- **Q9a**(优先于 Q9b): 是不是"**跨 agent 通用的卡壳-解法**案例"? → 出口: **L9a `unblock-recipes/recipes/<slug>.md`**
- **Q9b**(Q9a 未中再判): 是不是"**per-user 个人偏好 / 反复被纠正**的经验"? → 出口: **L9b auto memory**
- **Q10**(兜底): 都不命中? → 出口: **L10 不沉淀**

**Q9a vs Q9b 优先级**: 通用知识 > 个人偏好。任何"卡壳-解法"先尝试 9a;只有"换 agent / 换用户不适用"才落 9b。

### Step 3: 输出可直接执行的写作草稿

按 Q0-Q10 的命中出口,给一份**可直接 copy-paste 写入对应文件**的草稿。
草稿要求 + 各层模板见 `references/templates.md`(L9a 模板单独成文,见 `references/l9a-recipe-template.md`)。

**Prior-art 检查(出口是 director-* / flow-* 时必做)**:

在给"新建 skill"草稿之前,**必须先列已有同类 skill** 让用户选:

- 出口 = director-* → 列已实现 5 个: director-design / director-frontend / director-promote / director-ops / director-architect。问"改哪个的哪段?"还是"真的需要新建第 6 个角色?"
- 出口 = flow-* → 列已实现 7 个: flow-codex-goal / flow-dev-task / flow-ext-publish / flow-project-bootstrap / flow-project-finish / flow-skill-dev / flow-skill-research。问"改哪个的哪个 step?"还是"新建?"

**默认推荐**: 改现有 > 新建。只有当 ≥ 3 个现有 skill 都"沾边但都不准确"时才考虑新建。
新建草稿前提示:"新建一个 director-* / flow-* 是大投入(走 flow-skill-dev 完整 8 步),确认要新建吗?"

### Step 4: 上移提醒

上移信号 / 上移路径表 / 上移检查清单见 `references/failure-modes.md` 末段。
3 个信号任一命中(用户口头明示 / 本对话计数 ≥ 2 / 跨 director 信号)→ 本 skill 必须输出上移检查清单。

### Step 5: 输出契约

固定 **5 段顺序**(顺序不可变):

```
【一句话沉淀】把<X>变成了<Y>,沉淀到了<Z>。
【分诊结论】<出口名称>(Q<N> 命中)
【推荐位置】<具体文件绝对路径或相对路径>
【写作模板】<可复制的 Markdown / YAML / 代码草稿>

【后续提醒】<上移路径 / flow-skill-dev / sync 分发 / CLAUDE.md 行数超限 ...>
```

完整 5 段格式说明 + 各段写作要求 + handoff 边界见 `references/output-contract-template.md`。

**基线 JSON / markdown 分流** 见 `../_shared/output-contract-schema.md`(跨 skill 通用)。
本 skill 扩展:
- 5 段 markdown = **human-facing 主产物**(给 user 看的对话响应)
- handoff payload = **机器读 JSON 含 3 段技术契约**(分诊结论 + 推荐位置 + 写作模板)落盘 `.agent/jobs/<task-slug>/triage.json`
- 【一句话沉淀】+ 【后续提醒】**不进 handoff JSON**(纯 human-facing,见下方"handoff 边界"段)

**【一句话沉淀】格式硬约束**(主体保留,不可下沉):

- 必须有 3 个槽位: **X(做了什么经验)** / **Y(变成了什么载体)** / **Z(沉淀到了哪个概念位置)**
- **不带技术细节** —— 完整禁用词清单(出口编号 / 判断树编号 / 技术形态 / 文件名 / 工具命令 / skill 名)见 `references/output-contract-template.md`
- 用**用户口语**描述(项目脚本 / 全局宪法 / 领域专家 / 启动手册 / 长期记忆 ...)
- 每个出口的 Y/Z 模板见 `references/layer-map.md` 各层"叙事模板"段
- 例子:"把**重复的浏览器操作过程**变成了**代码**,沉淀到了**项目脚本**"

**handoff 边界**: 【一句话沉淀】是 **human-facing only**,**不进 handoff payload**。
下游 skill(flow-skill-dev / update-config / sync-skills)消费的是
【分诊结论 / 推荐位置 / 写作模板】3 段技术契约。

## Layer Map(12 个出口速查)

| # | 经验类型 | 出口 | 触发问题 |
|---|---|---|---|
| 0 | 不该沉淀 | 丢弃 | Q0 |
| 1 | 跨 skill 价值观/安全 | `_shared/constitution.md` | Q1 |
| 2a | skill 元规范 | `_shared/<topic>.md` + sync | Q2 |
| 2b | skill 可 lint 硬规则 | `skill-doctor` 新规则 | Q2 |
| 3 | 必须每次强制 | hook | Q3 |
| 4 | 真实执行 | script / MCP | Q4 |
| 5 | 模块级约束 | nested CLAUDE.md | Q5 |
| 6 | 单一专业判断 | `director-*/` | Q6 |
| 7 | 跨角色编排 | `flow-*/` | Q7 |
| 8 | 项目级常驻 | `CLAUDE.md` / `AGENTS.md` | Q8 |
| **9a** | **跨 agent 卡壳-解法** | **`unblock-recipes/recipes/<slug>.md`** | **Q9a(优先于 9b)** |
| 9b | per-user 个人偏好 | auto memory | Q9b |
| 10 | 兜底丢弃 | 不沉淀 | Q10 |

**关键变化**: 第 9 层拆分为 9a / 9b,**9a 优先**。原"长期个人偏好 → auto memory"现属 9b;
新增 9a"跨 agent 卡壳-解法 → unblock-recipes"是 2026-05-25 增加的目标层。

完整层级说明见 `references/layer-map.md`。每层写作草稿见 `references/templates.md`。

## Red Flags & Rationalizations

完整 Red Flags 清单(11 条停止信号)+ Rationalizations 拒答表(10 条常见自我开脱)
见 `references/failure-modes.md`。命中任一 Red Flag **停止并修正**;不要拿
Rationalizations 给自己台阶。

## Self-Reference(自指)

本 skill 自己也遵循它推荐的层级原则,实际归属:

- **本 skill 本身 = 独立 skill**(同 clean-commit / skill-doctor 同类,无前缀)
  - 不是 director-*: 它不审单一专业领域,而是路由所有领域
  - 不是 flow-*: 它不强制多 step orchestration,单次调用就出结论
  - 不是 _shared/: 它有完整 SKILL.md 流程,是被触发的 skill 不是被引用的 metaspec
- **12 层架构图(layer-map.md)** = 跨 skill 通用认知模型 → 未来如果 ≥ 2 个 skill 需要引用 → 上移到 `_shared/layer-map.md`,目前还是本 skill 独享
- **用户反复推同一经验** → 触发 Step 4 上移机制,本 skill 自己也会被自己的规则约束

## Relationship to Other Skills

- **上游**: 用户在完成任务后直接触发
- **下游(handoff)**:
  - 出口是 skill / director-* / flow-* → `flow-skill-dev` 完整流程
  - 出口是 hook → `update-config` 配置 settings.json
  - 出口是 constitution / _shared/ → **完整 4 步链**:
    1. `bash scripts/sync-shared.sh`(分发到 12 个 target skill 的 references/)
    2. `git add -A && git commit && git push origin main`(推到 GitHub 单一事实源)
    3. `cd ~/.config/skillshare/skills && git pull origin main`(skillshare clone 拉更新)
    4. `skillshare sync --force`(分发到 `~/.claude/skills/` 等 agent 目标)
  - 出口是 skill-doctor 规则 → 切到 `~/Documents/projects/node-scripts/` 项目走 `flow-dev-task`
  - 出口是单个 skill 同步 → `sync-skills`(把单个 skill 目录同步到中心,**不是**用于 _shared 分发)
  - **出口是 unblock-recipes(L9a)**:
    1. 本 skill 按 `references/l9a-recipe-template.md` 输出完整骨架
    2. 用户/agent 把模板落盘到 `~/Documents/projects/skills/unblock-recipes/recipes/<slug>.md`
    3. **必须同步更新** `unblock-recipes/INDEX.md` 两处(按 tag 分类 + 按 symptom 关键词反查)
    4. commit 到中心 — pre-commit hook 跑 skill-doctor 自动检查 frontmatter 完整性

**不替代**:
- `flow-skill-dev`(那是写 skill 本身)
- `superpowers:brainstorming`(那是发散探索)
- retro / post-mortem 会议(那是更重的复盘)

### 跟其他 meta 类 skill 的优先级(避免抢同一回合)

| 主体场景 | hat 的位置 | meta-skill 的位置 | unblock-recipes 的位置 |
|---|---|---|---|
| **本 skill 显式触发**("经验该写哪") | hat 让位,只在最终对话响应末尾追加告知行;**不**写入 exp-sum 5 段产物 | 不触发(meta-skill 是项目级配置,不是经验沉淀) | Q9a 路径下被本 skill 调度 — 由本 skill 输出 L9a 模板后,user/agent 落盘到 unblock-recipes/recipes/ |
| meta-skill 主体跑时 | hat 让位(同上) | 主体 | 卡壳分支兜底 |
| user 直接写经验到 unblock-recipes/recipes/(绕过本 skill)| 被 unblock-recipes 拒绝(它唯一入口是本 skill Q9a) | n/a | 拒绝,告知 user 走 exp-sum |

**关键 invariant**:
- 任何主体 skill 跑时,hat 不挡 / 不替 / 不进产物 — 见 `hat/SKILL.md` 同名段
- 本 skill 的 L9a 产物 = unblock-recipes/recipes/<slug>.md 的**唯一合法生成路径**(unblock-recipes 拒接直接写入)— 见 `references/l9a-recipe-template.md`

---

## Integration Contracts(跨 skill 边界 / handoff schema / precedence rules)

> 本段定义 exp-sum 跟其他 skill 的硬契约 — 用 JSON schema + 文件路径 + 优先级表锁死边界,避免下游误消费或重复沉淀。

### A. Contract with meta-skill — stage switch signal

**触发条件**: exp-sum 在 Step 1/2 过程中,从用户描述里检测到"项目 stage 切换"信号
(例如从 `bootstrap` 切到 `dev`,从 `dev` 切到 `finish`,或反向回退)。
检测信号 = 用户口语命中关键词("项目启动好了 / 现在进开发期 / 准备收尾 / 暂停开发,回到 bootstrap"),
或经验本身就是"stage-X 默认行为 / stage-X 退场条件"。

**信号文件位置**(单一事实源):
```
~/.claude/projects/<project-slug>/.signals/stage-switch.json
```
- `<project-slug>` = 当前项目目录 basename(同 meta-skill 约定)
- 父目录不存在时 exp-sum 必须先 `mkdir -p`,不允许静默丢失
- 单文件,新信号**覆盖**旧文件(最新 stage 切换为准);历史归档由 meta-skill 自己负责

**JSON schema(exp-sum 发出方)**:
```json
{
  "schema_version": "1.0",
  "emitted_by": "experience-summary",
  "emitted_at": "<ISO-8601 timestamp>",
  "project": "<project-slug>",
  "from_stage": "bootstrap | dev | finish | paused | unknown",
  "to_stage": "bootstrap | dev | finish | paused",
  "evidence": [
    "<用户原话引用 1>",
    "<exp-sum 判断树命中的具体 Q 出口或经验类型>"
  ],
  "suggested_skills": [
    "flow-project-bootstrap",
    "flow-dev-task",
    "flow-project-finish"
  ],
  "confidence": "high | medium | low",
  "ttl_minutes": 60
}
```

**meta-skill 收到后的响应契约**:
1. 读 `stage-switch.json` → 校验 `schema_version` / `ttl_minutes` 未过期 / `project` 匹配当前 cwd
2. 校验通过 → 更新 meta-skill 自己的 stage 状态(同 meta-skill 内部存储约定),并在下次会话默认 hint `suggested_skills[0]`
3. 校验失败(schema 不兼容 / 过期 / 项目不匹配)→ **静默忽略**,不报错,不删文件 — exp-sum 不为下游异常负责
4. meta-skill **不允许**反向写回该文件(单向 exp-sum → meta-skill);需要回写状态走 meta-skill 自己的存储

**exp-sum 自检 invariant**:
- 信号文件写入必须是**最后一步**(在 5 段输出已经成型之后),避免半成品信号污染下游
- `confidence: low` 时 exp-sum 仍可发信号,但必须在【后续提醒】里 surface "此为低置信度切换提示,meta-skill 可能忽略"

### B. Contract with unblock-recipes — L9a incident payload

**Invariant 重申**: L9a unblock-recipes/recipes/ 的**唯一合法生成路径** = exp-sum 显式输出。
unblock-recipes 端 pre-commit hook 拒接非 exp-sum 来源的 recipe(通过检查 frontmatter `source: experience-summary` 字段强制)。

**exp-sum 输出格式**(machine-readable,跟 5 段 markdown 并列产出,落盘 `.agent/jobs/<task-slug>/l9a-incident.json`):

```json
{
  "schema_version": "1.0",
  "emitted_by": "experience-summary",
  "source": "experience-summary",
  "recipe_slug": "<kebab-case 短语,< 60 字符>",
  "incident_summary": "<一句话:agent 在什么场景卡壳,卡在哪个具体动作>",
  "reproduce_steps": [
    "<step 1: 触发场景>",
    "<step 2: agent 尝试动作 A>",
    "<step 3: 失败/卡壳的具体现象 — 必须包含可观测信号(error message / 死循环计数 / 超时)>"
  ],
  "blocker_type": "tool-permission | wrong-mental-model | stale-cache | infra-missing | api-contract-mismatch | timing | other",
  "proposed_recipe_skeleton": {
    "symptoms": ["<可被 INDEX.md 反查的关键词,3-7 个>"],
    "tags": ["<分类 tag,1-3 个>"],
    "verified_solution": "<已验证可用的解法,带最小可执行命令/步骤>",
    "anti_patterns": ["<已知无效的尝试,避免后人重蹈>"],
    "applies_to": "<agent 范围:claude-code | codex | cursor | all>"
  },
  "consumer": "unblock-recipes"
}
```

**unblock-recipes 消费方契约**:
1. 读 `l9a-incident.json` → 用 `proposed_recipe_skeleton` 填充 `recipes/<recipe_slug>.md` 模板
2. 必须同步更新 `unblock-recipes/INDEX.md` 两处(按 tag / 按 symptom 反查)— 由 unblock-recipes 自己的写入流程保证
3. 落盘后 pre-commit hook 校验 frontmatter `source: experience-summary` + `incident_ref: <task-slug>` — 缺失则拒绝 commit
4. exp-sum **不直接写 recipes/ 文件** — 它只产出 incident.json,落盘由 user/agent 在 unblock-recipes 流程里完成

**字段 enforcement**:
- `reproduce_steps` 必须 ≥ 3 步且含可观测失败信号 — 否则 exp-sum 拒绝输出 L9a,降级到 L10 丢弃并提示"现象不可复现,无法沉淀为 recipe"
- `blocker_type` 必须命中 enum 之一;`other` 出现频率 ≥ 3 次触发 exp-sum 自身上移(Step 4 上移提醒)
- `verified_solution` 必须是**已验证可用**的解法,未验证的方案走 L0/L10 丢弃,不进 recipes/

### C. Precedence with hat — hat 主-skill > exp-sum

**冲突场景**: exp-sum 沉淀的经验跟 hat 主-skill 当前戴的 hat persona / behavior 冲突
(例如 exp-sum 想沉淀"每次写代码前先 brainstorm",但当前 hat = `快`,主-skill = `flow-dev-task` 已经过 stage 1 brainstorm)。

**优先级硬规则**:
```
hat 主-skill > exp-sum
```

- exp-sum 必须**让步**:不输出跟当前 hat 主-skill 行为冲突的写作模板;不发射会改变 hat persona 的信号
- exp-sum 检测到冲突时,在【后续提醒】里 surface:"此经验跟当前 hat=`<X>` 的主-skill 行为冲突,建议先切回中性 hat 再沉淀,或将经验降级到 L9b(per-user 偏好)"
- exp-sum **不允许**为了沉淀经验主动要求用户换 hat — 换 hat 是用户主动行为,exp-sum 只能提示

**为什么 hat 优先**: hat 是会话级 persona,exp-sum 是单点沉淀。hat 出错只影响当前回合,
exp-sum 出错(沉淀到错误层)会污染所有后续会话 — 但 hat 的会话级判断必须保留,否则破坏主-skill 的执行连贯性。
让步策略 = 经验暂存到 `.agent/jobs/<task-slug>/deferred-triage.json`,等 hat 退场后由用户重新触发 exp-sum。

### D. Boundary with flow-* — 谁沉淀什么

避免 flow-dev-task / flow-codex-goal / flow-skill-dev 完成后跟 exp-sum 重复沉淀同一条经验。

| 经验类型 | flow-* 自己沉淀 | exp-sum 沉淀 |
|---|---|---|
| 单次任务的 commit message / PR 描述 | ✅ flow-dev-task Stage 8 | ❌ exp-sum 不碰 |
| 单次任务的 user-facing recap | ✅ flow-dev-task → change-recap | ❌ exp-sum 不碰 |
| 任务过程中踩的**新坑 + 已验证解法**(可复用) | ❌ flow-dev-task 不沉淀 | ✅ exp-sum L9a → unblock-recipes |
| 任务暴露的**项目级高频默认行为缺失** | ❌ flow-dev-task 不沉淀 | ✅ exp-sum L8 → CLAUDE.md |
| 任务暴露的**跨 skill 价值观漏洞** | ❌ flow-dev-task 不沉淀 | ✅ exp-sum L1 → constitution |
| skill 自身行为 bug(skill 触发不准 / 输出格式漏) | ❌ flow-dev-task 不沉淀 | ✅ exp-sum L2b → skill-doctor 规则 |
| 个人偏好被反复纠正 | ❌ flow-dev-task 不沉淀 | ✅ exp-sum L9b → auto memory |

**Invariant**:
- flow-* 的沉淀边界 = **本次任务的产出物**(commit / PR / recap)
- exp-sum 的沉淀边界 = **跨任务可复用的认知 / 流程 / 约束**
- 重叠区(例如"任务里发现的坑")**默认归 exp-sum**,flow-* 只负责本次产出,不替 exp-sum 做长期沉淀

**handoff 时序**:
```
flow-dev-task Stage 8 commit 完成
     ↓ (--auto-recap=true 默认)
change-recap 输出用户视角讲解
     ↓ (用户问"这次学到的 X 该写到哪")
exp-sum 触发 → 跑 12 出口判断树 → 沉淀
```
flow-dev-task **不主动**调 exp-sum,exp-sum 必须由用户显式触发 — 避免每个 task 完成都强制走经验沉淀(用户疲劳)。

### E. ASCII 流程图 — agent session 结束 → exp-sum 触发 → judgment-tree → 沉淀 / 发信号 / no-op

```
                    agent session 结束
                          │
                          ▼
              ┌───────────────────────┐
              │ 用户显式触发 exp-sum? │
              │ (口语 / "经验该写哪") │
              └───────────┬───────────┘
                          │
              ┌───────────┴───────────┐
              │ no                    │ yes
              ▼                       ▼
        ┌──────────┐         ┌──────────────────┐
        │  no-op   │         │ Step 1: 锁定经验 │
        │ (不触发) │         │   (1 句话 + ≤ 2 │
        └──────────┘         │    追问)         │
                             └────────┬─────────┘
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │ Step 2: judgment-tree  │
                         │   Q0 → Q10 顺序判断    │
                         │   第一个 yes 即出口    │
                         └────────────┬───────────┘
                                      │
            ┌─────────────────────────┼─────────────────────────┐
            │                         │                         │
            ▼                         ▼                         ▼
      ┌──────────┐              ┌──────────┐              ┌──────────┐
      │ L0 / L10 │              │ L1 ~ L8  │              │ L9a / 9b │
      │  丢弃    │              │ 主流出口 │              │  增量层  │
      └────┬─────┘              └────┬─────┘              └────┬─────┘
           │                         │                         │
           │              ┌──────────┴──────────┐               │
           │              │                     │               │
           ▼              ▼                     ▼               ▼
     ┌──────────┐   ┌──────────┐         ┌──────────┐   ┌──────────────┐
     │ no-op    │   │ Step 3:  │         │ Step 4:  │   │ Step 3 写    │
     │ 5 段输出 │   │ 写作草稿 │         │ 上移检查 │   │ L9a incident │
     │ + 解释   │   │ + handoff│         │ (信号 ≥ 1│   │ JSON +       │
     │ 为何丢弃 │   │  JSON    │         │   命中)  │   │ recipe 骨架  │
     └──────────┘   └────┬─────┘         └────┬─────┘   └──────┬───────┘
                         │                    │                 │
                         ▼                    ▼                 ▼
                   ┌──────────────────────────────────────────────┐
                   │ Step 5: 5 段 markdown 输出 → user            │
                   │                                              │
                   │ 同时:                                        │
                   │  ├─ handoff JSON → .agent/jobs/<slug>/       │
                   │  ├─ (若检测 stage switch) stage-switch.json  │
                   │  │   → ~/.claude/projects/<proj>/.signals/   │
                   │  ├─ (若 L9a) l9a-incident.json               │
                   │  │   → unblock-recipes 流程消费              │
                   │  └─ (若 hat 冲突) deferred-triage.json       │
                   │      → 等 hat 退场后重触发                   │
                   └──────────────────────────────────────────────┘
                                       │
                                       ▼
                              ┌──────────────────┐
                              │  exp-sum 退出    │
                              │  下游 skill 按   │
                              │  契约消费产物    │
                              └──────────────────┘
```

### F. Precedence 总表(冲突时谁优先)

| 冲突对 | 谁优先 | 理由 |
|---|---|---|
| `_shared/constitution.md` ↔ exp-sum 任何条款 | **constitution** | 价值观源头,跨 skill 不可违背 |
| hat 主-skill 当前 persona ↔ exp-sum 沉淀建议 | **hat 主-skill** | 会话级连贯性 > 单点沉淀 |
| meta-skill 项目 stage 状态 ↔ exp-sum 信号 | **信号是建议,meta-skill 自决** | 单向信号,meta-skill 有权忽略 |
| flow-* 本次任务产出 ↔ exp-sum 跨任务沉淀 | **各管各的**(见 D 表) | 边界清晰,重叠区归 exp-sum |
| unblock-recipes 写入入口 ↔ user 直接写 recipes/ | **exp-sum 唯一入口** | L9a invariant,unblock-recipes 拒非 exp-sum 来源 |
| skill-doctor 硬规则 ↔ exp-sum 软建议 | **skill-doctor** | 可 lint 的硬规则 > 经验软建议 |

### G. handoff 产物落盘约定(单一事实源)

| 产物 | 路径 | 写入方 | 消费方 |
|---|---|---|---|
| 5 段 markdown | 对话响应(stdout) | exp-sum | user |
| 3 段技术契约 JSON | `.agent/jobs/<task-slug>/triage.json` | exp-sum | flow-skill-dev / update-config / sync-skills |
| stage 切换信号 | `~/.claude/projects/<proj>/.signals/stage-switch.json` | exp-sum | meta-skill |
| L9a incident payload | `.agent/jobs/<task-slug>/l9a-incident.json` | exp-sum | unblock-recipes 流程 |
| hat 冲突暂存 | `.agent/jobs/<task-slug>/deferred-triage.json` | exp-sum | exp-sum 自己(重触发时读回) |

**路径硬约束**:
- `<task-slug>` = 当前任务的 kebab-case 短名(由用户/上游 flow-* 提供,exp-sum 不自生成)
- `<proj>` = 项目目录 basename
- 所有 `.agent/jobs/` 路径相对当前 cwd;`~/.claude/projects/` 是绝对路径(跨项目共享)
- exp-sum 写入前必须 `mkdir -p` 父目录,失败立刻 surface 给 user,不静默继续

---

## Reuse

测试用例保留在 `tests/cases.md`,后续修订以这些用例为回归基线。
Integration 契约的回归用例(stage-switch / L9a incident / hat 冲突 / flow-* 边界)
单独保留在 `tests/integration-cases.md`,跟 5 段输出测试解耦。
