---
name: experience-summary
description: Use after finishing a real task to triage the lesson/pattern/gotcha into the right architectural layer — picks among constitution / shared metaspec / skill-doctor rule / director-* / flow-* / CLAUDE.md / nested CLAUDE.md / hook / script / MCP / auto memory / discard. Triggers on phrases like "这次学到的 xxx 该写到哪", "经验该沉淀到哪一层", "踩了个坑想沉淀", "复盘", "lesson learned", "where should this go", "post-task triage", "exp-sum", "es 这条经验", "经验分诊". 不替代 retro 会议、不替代 flow-skill-dev 写新 skill、不替代 brainstorming。
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)

# Experience Summary —— 经验分诊

## Overview

任务结束后,把"学到的 / 踩的坑 / 新约束 / 新流程"分诊到正确的架构层。**选错层 = 经验白攒**。

| 层 | 应放什么 | 错放后果 |
|---|---|---|
| 常驻(CLAUDE.md) | 高频、广适、低歧义 | 专题流程烧 token 还不被看 |
| 按需(skill) | 多步流程 / 专题判断 | 通用价值观散落不互覆盖 |
| 强制(hook/constitution) | 零例外、不靠自觉 | 只是建议进强制 = 误伤 |

本 skill **不修代码**,只输出: 分诊结论 + 推荐位置 + 写作草稿 + 上移提醒。

## When to Use

- 用户刚完成任务,问"这次学到的 X 应该放哪"
- 用户说"踩了个坑想沉淀" / "把这流程固定下来" / "复盘"
- 用户在 CLAUDE.md / skill / hook 之间纠结
- 某 skill 反复触发同一规则,问"该上移成通用约束吗"

## When NOT to Use

- 用户**做任务中** → `flow-dev-task` / `flow-codex-goal`
- 用户**创建/改 skill** → `flow-skill-dev`
- 用户**头脑风暴**新方向 → `superpowers:brainstorming`
- 用户**写完整 retro / post-mortem** → 本 skill 只做单条分诊
- 用户**批量整理**历史经验 → 本 skill 单次只一条

## Workflow

### Step 1: 锁定经验

请用户**一句话**描述。模糊时追问(≤2 问):

- 每次都做 vs 特定情况?
- 当前项目专用 vs 跨项目通用?
- 执行真实动作 vs 约束模型行为?
- 触发场景? (写代码 / commit / 部署 / review ...)

**"我觉得 agent 应该更聪明点"这种空话 → 直接告诉用户不该沉淀,跳 Step 5。**

### Step 2: 判断树(12 出口,首中即出)

按顺序问 Q0 → Q10,**第一个 yes 即出口**。完整判定信号 / 反例 / 边界见 `references/judgment-tree.md`。

| Q | 提问 | 出口 |
|---|---|---|
| Q0 | 不该沉淀? | **L0 丢弃** |
| Q1 | 跨 skill 通用**价值观/安全/身份**? | **L1 `_shared/constitution.md`** |
| Q2a | 约束 skill **怎么写**的元规范(结构/模式)? | **L2a `_shared/<topic>.md`** |
| Q2b | 可机器 **lint 的硬规则**? | **L2b skill-doctor 新规则** |
| Q3 | **每次必执行、零例外**、不靠自觉? | **L3 hook** |
| Q4 | 需要**真实执行命令/查接口/读数据**? | **L4 script / MCP** |
| Q5 | **只对某目录/某类文件/某模块**生效? | **L5 nested CLAUDE.md** |
| Q6 | **单一专业领域**判断/审查/出方向? | **L6 改 director-*** |
| Q7 | **多步流程、跨多角色**、需 orchestrator? | **L7 改 flow-*** |
| Q8 | 每会话该知的**项目级高频默认**? | **L8 `CLAUDE.md` / `AGENTS.md`** |
| Q9a | **跨 agent 通用卡壳-解法**案例?(优先 9b) | **L9a `unblock-recipes/recipes/<slug>.md`** |
| Q9b | **per-user 偏好 / 反复被纠正**? | **L9b auto memory** |
| Q10 | 都不命中 | **L10 不沉淀** |

**硬约束**:
- Q8 出口的 `CLAUDE.md` 必须 ≤ **200 行**(Anthropic 官方)。超了 = 专题流程混进来,该下沉到 skill。
- **Q9a > Q9b**:任何"卡壳-解法"先试 9a;只有"换 agent/换 user 不适用"才落 9b。

### Step 3: 输出可执行草稿

按命中出口给**可直接 copy-paste** 的草稿。模板见 `references/templates.md`(L9a 单独见 `references/l9a-recipe-template.md`)。

**Prior-art 检查(出口 = director-* 或 flow-* 必做)**:

新建 skill 前**必须先列已有同类**让用户选:

| 出口 | 现有列表 | 必问 |
|---|---|---|
| director-* | design / frontend / promote / ops / architect (5 个) | "改哪个的哪段?还是真要建第 6 个?" |
| flow-* | codex-goal / dev-task / ext-publish / project-bootstrap / project-finish / skill-dev / skill-research (7 个) | "改哪个的哪 step?还是新建?" |

**默认: 改现有 > 新建**。只有当 ≥ 3 个现有 skill 都"沾边但都不准"时才考虑新建。
新建前提示:"新建 director-* / flow-* 是大投入(走 flow-skill-dev 完整 8 步),确认?"

### Step 4: 上移提醒

完整信号 / 路径表 / 检查清单见 `references/failure-modes.md` 末段。

**3 信号任一命中 → 本 skill 必须输出上移检查清单**:
1. 用户口头明示
2. 本对话计数 ≥ 2
3. 跨 director 信号

### Step 5: 输出契约

**固定 5 段顺序(不可变)**:

```
【一句话沉淀】把<X>变成了<Y>,沉淀到了<Z>。
【分诊结论】<出口名称>(Q<N> 命中)
【推荐位置】<具体文件绝对路径或相对路径>
【写作模板】<可复制的 Markdown / YAML / 代码草稿>

【后续提醒】<上移路径 / flow-skill-dev / sync 分发 / CLAUDE.md 行数超限 ...>
```

完整格式 + 各段写作要求 + handoff 边界见 `references/output-contract-template.md`。
基线 JSON / markdown 分流见 `../_shared/output-contract-schema.md`(跨 skill 通用)。

**本 skill 扩展**:
- 5 段 markdown = **human-facing 主产物**(给 user 看)
- handoff payload = **机器读 JSON,含 3 段技术契约**(分诊结论 + 推荐位置 + 写作模板)→ `.agent/jobs/<task-slug>/triage.json`
- 【一句话沉淀】+【后续提醒】**不进 handoff JSON**(纯 human-facing)

**【一句话沉淀】格式硬约束(主体保留,不可下沉)**:

- 必须 3 槽位: **X(做了什么)** / **Y(变成什么载体)** / **Z(沉淀到哪个概念位置)**
- **禁带技术细节** —— 禁用词清单(出口编号/判断树编号/技术形态/文件名/工具命令/skill 名)见 `references/output-contract-template.md`
- 用**用户口语**(项目脚本 / 全局宪法 / 领域专家 / 启动手册 / 长期记忆 ...)
- 每出口的 Y/Z 模板见 `references/layer-map.md` "叙事模板"段
- 例:"把**重复的浏览器操作过程**变成了**代码**,沉淀到了**项目脚本**"

**handoff 边界**:【一句话沉淀】= **human-facing only**,**不进 handoff payload**。
下游 skill(flow-skill-dev / update-config / sync-skills)消费【分诊结论 / 推荐位置 / 写作模板】3 段技术契约。

## Layer Map(12 出口速查)

| # | 经验类型 | 出口 | Q |
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
| **9a** | **跨 agent 卡壳-解法** | **`unblock-recipes/recipes/<slug>.md`** | **Q9a(优先 9b)** |
| 9b | per-user 个人偏好 | auto memory | Q9b |
| 10 | 兜底丢弃 | 不沉淀 | Q10 |

**变化**: 第 9 层拆 9a / 9b,**9a 优先**。原"长期个人偏好 → auto memory"现属 9b;
9a"跨 agent 卡壳-解法 → unblock-recipes"是 2026-05-25 新增。

完整层级见 `references/layer-map.md`;每层草稿见 `references/templates.md`。

## Red Flags & Rationalizations

完整 Red Flags(11 条停止信号)+ Rationalizations 拒答表(10 条自我开脱)见 `references/failure-modes.md`。
**命中任一 Red Flag → 停止并修正**;不要拿 Rationalizations 给自己台阶。

## Self-Reference(自指)

本 skill 自己也遵循它推荐的层级原则:

- **本 skill = 独立 skill**(同 clean-commit / skill-doctor,无前缀)
  - 不是 director-*: 路由所有领域,不审单一专业
  - 不是 flow-*: 单次调用就出结论,不强制多 step
  - 不是 _shared/: 有完整 SKILL.md 流程,是被触发的 skill 不是被引用的 metaspec
- **12 层架构图(layer-map.md)** = 跨 skill 通用认知模型 → 未来 ≥ 2 个 skill 引用时上移到 `_shared/layer-map.md`,目前独享
- **用户反复推同一经验** → 触发 Step 4 上移,本 skill 也被自己规则约束

## Relationship to Other Skills

- **上游**: 用户完成任务后直接触发
- **下游(handoff)**:

| 出口 | 下游链路 |
|---|---|
| skill / director-* / flow-* | `flow-skill-dev` 完整流程 |
| hook | `update-config` 配置 settings.json |
| constitution / _shared/ | **4 步链**: ①`bash scripts/sync-shared.sh` 分发到 12 target skill;②`git add -A && git commit && git push origin main` 推到 GitHub 单一事实源;③`cd ~/.config/skillshare/skills && git pull origin main` 拉更新;④`skillshare sync --force` 分发到 `~/.claude/skills/` 等 agent 目标 |
| skill-doctor 规则 | 切到 `~/Documents/projects/node-scripts/` 走 `flow-dev-task` |
| 单 skill 同步 | `sync-skills`(单 skill 目录到中心,**不是** _shared 分发) |
| unblock-recipes (L9a) | ①本 skill 按 `references/l9a-recipe-template.md` 输出骨架;②user/agent 落盘 `~/Documents/projects/skills/unblock-recipes/recipes/<slug>.md`;③**必须同步更新** `unblock-recipes/INDEX.md` 两处(按 tag 分类 + 按 symptom 反查);④commit — pre-commit hook 跑 skill-doctor 检查 frontmatter |

**不替代**: `flow-skill-dev`(写 skill 本身)/ `superpowers:brainstorming`(发散探索)/ retro / post-mortem(更重)。

### 跟其他 meta 类 skill 的优先级(避免抢回合)

| 主体场景 | hat | meta-skill | unblock-recipes |
|---|---|---|---|
| **本 skill 显式触发**("经验该写哪") | 让位,只末尾追加告知行;**不**写 5 段产物 | 不触发(项目级配置,非经验沉淀) | Q9a 下被本 skill 调度 — 本 skill 输出 L9a 模板后,user/agent 落盘 |
| meta-skill 主体跑时 | 让位(同上) | 主体 | 卡壳分支兜底 |
| user 直接写到 recipes/(绕过本 skill) | 被 unblock-recipes 拒绝(唯一入口是 Q9a) | n/a | 拒绝,告知走 exp-sum |

**关键 invariant**:
- 主体 skill 跑时,hat 不挡 / 不替 / 不进产物 — 见 `hat/SKILL.md` 同名段
- 本 skill 的 L9a 产物 = unblock-recipes/recipes/<slug>.md 的**唯一合法生成路径**(unblock-recipes 拒接直接写入)— 见 `references/l9a-recipe-template.md`

## Reuse

测试用例保留在 `tests/cases.md`,后续修订以这些用例为回归基线。
