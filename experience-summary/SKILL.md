---
name: experience-summary
description: Use after finishing a real task to triage the lesson/pattern/gotcha into the right architectural layer — picks among constitution / shared metaspec / skill-doctor rule / director-* / flow-* / CLAUDE.md / nested CLAUDE.md / hook / script / MCP / auto memory / discard. Triggers on phrases like "这次学到的 xxx 该写到哪", "经验该沉淀到哪一层", "踩了个坑想沉淀", "复盘", "lesson learned", "where should this go", "post-task triage", "exp-sum", "es 这条经验", "经验分诊". 不替代 retro 会议、不替代 flow-skill-dev 写新 skill、不替代 brainstorming。
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)

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

## Reuse

测试用例保留在 `tests/cases.md`,后续修订以这些用例为回归基线。
