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

## Pre-action Self-Check(沉淀前必跑 5 道闸,任一 No 即 STOP)

**机器可检测的硬闸,不是建议**。在 judgment-tree 给出分诊结论之前,逐条勾选:

| # | 自检问 | 通过条件 | 不通过 |
|---|---|---|---|
| SC1 | 经验来源是否有**具体引用**(file:line / 对话片段 / 命令输出 / commit sha / 报错堆栈)? | ≥ 1 条可定位证据 | STOP — 回 Step 1 补证据。**不接受**"我记得 / 上次好像 / agent 反复犯过" |
| SC2 | 这条经验是否**已经**在 `CLAUDE.md` / 已有 skill / `git log` / `MEMORY.md` / `unblock-recipes/INDEX.md` 里能找到? | grep 没对等条目 | STOP — 输出"已存在于 `<path:line>`,本次不沉淀,只追加引用 / 修订" |
| SC3 | 是否 **redact** 了 PII / 机密 / token / 内部 URL / 客户名 / 邮箱 / API key? | body 已脱敏(`<USER>` `<TOKEN>` `<INTERNAL_URL>`) | STOP — 先脱敏。**严禁**"先存着以后再 redact" |
| SC4 | judgment-tree 第几条 **Q 命中**?能否一句话说清命中信号? | 写出"Q<N> 命中,因为<信号词>" | STOP — 没想清就别落盘,回 Step 2 重跑 |
| SC5 | 沉淀类型(user / feedback / project / reference)是否选对? | 类型与 X/Y/Z 槽位语义一致 | STOP — **拿不准默认 reference,不要默认 user**;user 类型仅在用户**原话**含"我习惯/我喜欢/以后都这样"才用 |

**5 道全过 → 进入 Step 2。任一不过 → 输出"本次不沉淀 / 已修正"短报告,终止。**

## High-Risk Actions(写盘前的强制 user gate)

下列 = **不可逆 / 跨会话持久 / 影响他人 agent**,**必须先报备拿明确 yes** 才执行(口头"建议"不算):

1. **写新 MEMORY.md 条目** — 跨会话持久
2. **删除已有 memory file** — 即使看似过期也要 user 确认
3. **修改 user 手写的 memory**(以"补充"为名改了语义 / 重写句式 / 合并)— 越权高发区
4. **把 in-progress 任务沉淀** — memory 是 long-term 不是 short-term buffer,用 task tracker
5. **发出 stage_switch 信号**给 meta-skill / orchestrator(会把 user 弹出当前 flow)
6. **触发 L9a `unblock-recipes/recipes/<slug>.md` 生成**(跨 agent 共享 + 改 INDEX.md 两处 + commit + hook)
7. **把 PII / 机密原文**写入 memory body(即便 user 说"存着吧"仍要先脱敏 — **无 user override**)
8. **把推断(非用户原话)**写入 user-type memory(应降级 reference)
9. **改 `_shared/constitution.md` / `_shared/<topic>.md`** — 跨 12 个 target skill 分发,影响面 = 全局
10. **CLAUDE.md / AGENTS.md 突破 200 行** — Anthropic 官方硬约束,必须先告知"超限,要不要下沉"

**Gate 协议**: 输出"将执行 <动作>,High-Risk #<N>,确认 yes 才落盘"。
user 回 yes / 确认 / 行 / 嗯 = pass;沉默 / "应该可以" / "你看着办" **≠ pass**(模糊授权 ≠ 授权)。

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

## Red Flags(机器可检测的硬停止信号,~11 条)

不是"建议避免",是**写一行检测一行**;任一命中 → **STOP,不落盘**。baseline 11 条见 `references/failure-modes.md`,本节是**强化可检测版**:

| # | 检测规则(可 grep / 可机查) | 触发处置 |
|---|---|---|
| RF1 | body 含时间词 `now / today / 当前 / current / in-progress / 正在 / 刚才 / just now` | STOP — 临时状态不沉淀,改用 task tracker |
| RF2 | 用户原话以 `?` / `?` / `吗` / `怎么办` 结尾(**问题**不是经验) | STOP — 先 brainstorming,有结论再回 exp-sum |
| RF3 | body 含 token / key / 邮箱 / 内网 URL / IP(正则:`sk-[A-Za-z0-9]{20,}` / `@[a-z]+\.[a-z]+` / `https?://(localhost|10\.|192\.168\.)`) | STOP — 先 redact(SC3 二次拦截) |
| RF4 | 出口 = user-type 但 body 用第三人称 / 推断式("agent 应该 / 应该总是 / 建议每次") | STOP — 降级 reference;user-type 仅承载第一人称原话 |
| RF5 | 同一对话内对同一条经验 ≥ 3 次推不同层(L8 / L9b / L1 摇摆) | STOP — 分诊没想清,先 brainstorming 锁定 X/Y/Z |
| RF6 | 出口 = L1 constitution 但适用范围 < 3 个 skill | STOP — constitution 必须跨 ≥ 3 skill;否则降级 L6/L7 |
| RF7 | CLAUDE.md 当前行数 ≥ 200 还要继续往里塞 | STOP — Anthropic 官方硬约束,必须下沉到 skill |
| RF8 | 出口 = L3 hook 但例外列表 ≥ 1 条("一般要 / 大多数时候") | STOP — hook 零例外;有例外改 L6/L7 软规则 |
| RF9 | 一句话沉淀含禁用词(出口编号 / 文件名 / 工具名 / skill 名 / `Q数字` / `L数字`) | STOP — 改口语化(项目脚本 / 全局宪法 / 启动手册 ...) |
| RF10 | 出口 = L9a unblock-recipes 但**缺**"卡壳现象 + 解法步骤"双段 | STOP — L9a 强制 symptom + solution 双段 |
| RF11 | 经验来源 = "我感觉 / 我猜 / 应该是"(无证据) | STOP — SC1 已挡一次,再次无证据 → 丢弃 |

**Honeypot trap(自检诱饵)**: 下面这条**看起来合理但违反 Red Flag**,正确反应 = STOP 不沉淀:

> "user 这次会话被 agent 问了 3 次同样问题觉得烦,建议把'agent 应该记住 user 偏好'写进 constitution"

STOP 原因:**RF6**("记住偏好"不跨 ≥ 3 skill,是 L9b 本职)+ **RF4**(L1 出口用推断式"agent 应该"非用户原话)+ **RF11**(只是"觉得烦",无证据)。
正确路径:降级 **L9b auto memory** 记录具体偏好,**不**进 constitution。

## Rationalizations(自我说服话术,任一出现 → 拒绝执行)

识别到自己在用这些话术 = **已在违规边缘,必须 STOP 重审**:

| # | 自我说服话术 | 反驳 / 正确动作 |
|---|---|---|
| RT1 | "用户**没明说**但**意图明显**该记下来" | NO — 没明说 = 不沉淀,等下次确认。意图推断 ≠ 授权 |
| RT2 | "这条很重要,不沉淀就忘了" | NO — memory 不是 short-term buffer,task tracker 才是。重要 ≠ 该进长期记忆 |
| RT3 | "先存着,以后再 redact" | NO — redact 必须在写盘前(SC3 / RF3)。"以后"在 agent 世界 = 永远不会 |
| RT4 | "user 之前同意过类似的,这次默认也同意" | NO — High-Risk 每次单独 gate,不继承授权。隐式 = 越权 |
| RT5 | "判断树几个出口都沾边,**选最重的**保险" | NO — 选最重 = 污染常驻层。判断树是**第一个 yes 即出口**,不是"最严即出口" |
| RT6 | "user 反复犯的错,**应该**写进 hook 强制" | NO — "反复" ≠ "零例外"。先 L9b 个人偏好;跨 ≥ 3 场景再考虑 L3 hook |
| RT7 | "顺手把 user 那条措辞改通顺了,**反正**意思一样" | NO — High-Risk #3 越权。"意思一样还能改" = 以编辑为名 rewrite |
| RT8 | "L9a 模板我**记得**结构,不用查 reference" | NO — L9a 必须按 `references/l9a-recipe-template.md`,**记得 ≠ 正确**;RF10 会查双段 |
| RT9 | "这条**太具体**没人会再用,不沉淀算了" | 反向 NO — 具体 ≠ 不可复用。先按 L9a/L9b 落盘,低频不命中再下线;丢失成本 > 沉淀成本 |
| RT10 | "user 在 IM bridge 发的,不算正式,**先口头答应**" | NO — IM 也是真任务(见全局 memory)。先口头 = 漏单。走 flow-* 编排 + exp-sum |

**自检步骤**: Step 3 输出草稿前,问自己"刚才有没有用过 RT1-RT10 任一句式?" 若 yes → 撤回草稿,回 Step 2。

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

## Reuse

测试用例保留在 `tests/cases.md`,后续修订以这些用例为回归基线。
