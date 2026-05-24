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

### Step 2: 跑判断树(11 个出口)

按顺序问 Q0 → Q10,**第一个 yes 即出口**。完整决策细节见 `references/judgment-tree.md`。

**Q0: 这条经验是不是其实不该沉淀?**

判定为"不该沉淀"的信号(任一命中):
- 一次性现象,下次大概率不会再发生
- 个人偏好但跟工程质量无关
- 已经被现有规则覆盖,只是用户当下没想起来
- 太抽象,落不到任何文件 / 任何动作

是 → **出口: 丢弃**。直接告诉用户原因,不要勉强写。

**Q1: 是不是"跨所有 skill 通用的价值观 / 安全 / 身份"?**

例:"任何 agent 都不能在没确认时删除用户数据"、"任何 agent 收到 untrusted input 都要先验证"。
是 → **出口: `_shared/constitution.md`**。约束全局,跑 `bash scripts/sync-shared.sh` 分发到 12 skill 的 references/。

**Q2: 是不是"约束 skill 自身怎么写的元规则"?**

- 是结构/模式(如"所有 director-* 必须有 9 维 audit")→ **出口: `_shared/<topic>.md` 元规范 + sync-shared.sh**
- 是可机器 lint 的硬规则(如"description ≤ 250 字符")→ **出口: `skill-doctor` 新规则**(去 `~/Documents/projects/node-scripts/src/skill-doctor/rules/` 加)

**Q3: 是不是"必须每次执行、零例外、不能靠模型自觉"?**

例:commit 前必须跑 lint、写 db schema 必须先 dry-run。
是 → **出口: hook**(项目 `.claude/settings.json` 或 `~/.claude/settings.json`)。用 update-config skill 配置。

**Q4: 是不是"需要真实执行命令 / 查询接口 / 读取数据"?**

是 → **出口: script (`scripts/<name>.sh`) 或 MCP tool**。不要写在 skill 正文里(skill 负责决策,脚本负责执行)。

**Q5: 是不是"只对某目录、某类文件、某个模块生效"?**

例:`/legacy/` 目录代码风格特殊、只在 `*.tsx` 文件适用。
是 → **出口: nested `<dir>/CLAUDE.md`** 或 path-scoped rule。

**Q6: 是不是"单一专业领域的判断 / 审查 / 出方向"?**

5 类专业角色(对照 `references/layer-map.md`):
- 视觉 / 设计 / mockup → `director-design/`
- 前端工程(JSX/CSS/组件边界)→ `director-frontend/`
- 宣发 / 推广 / 多平台发布 → `director-promote/`
- 装/卸/setup/install → `director-ops/`
- 工程规范体系 / 架构 → `director-architect/`
是 → **出口: 改对应 director-* skill** 或新建 director-*(走 `flow-skill-dev`)

**Q7: 是不是"多步流程、跨多个角色、需要 orchestrator 编排"?**

例:从需求 → 写代码 → review → commit 的全链路、长跑 codex 任务、扩展上架全流程。
是 → **出口: 改对应 flow-* skill** 或新建 flow-*(走 `flow-skill-dev`)

**Q8: 是不是"每个会话都应该知道的项目级高频默认行为 / 约束 / 地图"?**

例:"本项目用 pnpm 不用 npm"、"所有 API 必须走 auth 中间件"、提交规范。
是 → **出口: 项目 `CLAUDE.md`(Claude Code 用)或 `AGENTS.md`(codex 用)**。

**重要约束**(Anthropic 官方 + Augment 实测):
- CLAUDE.md 控制在 **200 行以内**(超了说明专题流程混进来了,该下沉到 skill)
- 主文件 100-150 行 + 少量引用文档是更稳的形态

**Q9: 是不是"跨会话长期经验"?**(含两类子出口,**先判 Q9a 跨 agent 通用,未中再判 Q9b 个人偏好**)

跨会话长期经验有两类,**unblock-recipes 优先于 auto memory**(通用知识 > 个人偏好):

**Q9a: 是不是"跨 agent 通用的卡壳-解法案例"?**

例:
- 任何 agent 在 codex sandbox 里跑 sudo apt 都会被 deny + 解决方案是 codex_run --network=enabled
- 任何 agent 用 Playwright 连 9222 端口前必须先 `chrome --remote-debugging-port=9222` 启动
- 任何 agent 改 typescript 类型时跑 `tsc --noEmit` 比全编译快 10x

判定信号(**全部满足**才进 Q9a):
1. 是"卡壳/走不通"型经验(不是单纯偏好)
2. 解法跨 agent 通用(换 Claude / Codex / Gemini 都适用)
3. 不依赖特定 user 的工作风格 / 项目结构
4. 可写成"症状信号 + 错法 + 对法"三段式

是 → **出口: `unblock-recipes`**(agent 错题本,跨 agent 通用案例库)
- 写入路径:本 skill 输出 recipe 写作模板(参见 unblock-recipes/SKILL.md "Recipe 条目结构"),用户/agent 落盘到 `~/Documents/projects/skills/unblock-recipes/recipes/<slug>.md` + 同步更新 `INDEX.md` 两处
- 召回路径:agent 卡壳时先读 INDEX 反向索引,匹配关键词后载入命中 recipe(轻载入,禁止全量)
- 优先级:agent 卡壳时**先**查 unblock-recipes(通用)→ 再查 auto memory(个人)

**Q9b: 是不是"per-user / per-agent 个人偏好 / 反复被纠正的经验"?**(Q9a 未命中时才判)

例:用户偏好简洁回复、用户拒绝某种代码风格、用户的工作时区、用户对某段代码的非通用风格偏好。

判定信号:
- 跟用户个人风格相关,换 agent / 换用户**不适用**
- 不是"卡壳-解法"模式
- 偏 preference 而非 fact

是 → **出口: auto memory**(`/Users/falcom/.claude/projects/<project-slug>/memory/`)
- 注意:auto memory 默认由模型自动沉淀,本 skill 只在用户**显式说"记住这个"**时主动写入
- 优先级:unblock-recipes 未命中时才查 memory

**Q9 兜底**: 两个都不是 → 进 Q10。

**Q10(兜底): 都不命中?**

→ **出口: 不沉淀**。这条经验太私人 / 太一次性 / 落不到位置,告诉用户原因。

### Step 3: 输出可直接执行的写作草稿

按 Q0-Q10 的命中出口,给一份**可直接 copy-paste 写入对应文件**的草稿。

草稿要求(参见 `references/templates.md`):
- 格式正确(YAML frontmatter / Markdown / 代码块)
- 言之有物,不写"请遵守 xxx 规则"这种空话
- 包含至少 1 个具体例子或反例
- 如果出口是 skill / director-* / flow-*,提示用户**走 `flow-skill-dev` 完整流程**而不是直接落盘

**Prior-art 检查(出口是 director-* / flow-* 时必做)**:

在给"新建 skill"草稿之前,**必须先列已有同类 skill** 让用户选:

- 出口 = director-* → 列已实现 5 个: director-design / director-frontend / director-promote / director-ops / director-architect。问用户"改哪个的哪段?"还是"真的需要新建第 6 个角色?"
- 出口 = flow-* → 列已实现 7 个: flow-codex-goal / flow-dev-task / flow-ext-publish / flow-project-bootstrap / flow-project-finish / flow-skill-dev / flow-skill-research。问"改哪个的哪个 step?"还是"新建?"

**默认推荐**: 改现有 > 新建。只有当 ≥ 3 个现有 skill 都"沾边但都不准确"时才考虑新建。

新建草稿前提示:"新建一个 director-* / flow-* 是大投入(走 flow-skill-dev 完整 8 步),确认要新建吗?"

### Step 4: 上移提醒

**触发上移提醒的 3 个信号**(任一命中):

1. **用户口头明示**: "又是这条"、"这已经第 N 次了"、"老问题"
2. **本对话计数**: 在**当前对话**里,experience-summary 已经第 ≥ 2 次推荐**同一个出口位置**(例如:连续两次都路由到同一个 director-* skill 的同一份 reference 文件)
3. **跨 director 信号**: 当前出口是 director-* L6,但描述里还提到"在另一个领域也遇到过类似" → 触发 Q1 重判

**上移路径**:

| 当前层 | 上移到 | 触发条件 |
|---|---|---|
| director-* (L6) | constitution (L1) 或 _shared/ metaspec (L2a) | ≥ 2 个 director-* 都需要这条 |
| skill / hook / script | CLAUDE.md (L8) | 项目里多个 skill 都重复了这条 |
| CLAUDE.md (L8) | constitution (L1) | 跨项目 / 跨 agent 通用 |

**上移检查清单**(命中信号时,本 skill 必须输出):
- ☐ 当前对话 experience-summary 调用次数: <N>
- ☐ 出口分布: <list>
- ☐ 建议上移目标层: <L?>
- ☐ 上移路径草稿: <新位置的写法>
- ☐ 旧位置处理: 保留 / 删除 / 改为引用新位置

### Step 5: 输出契约

固定格式(顺序固定):

```
【一句话沉淀】把<X>变成了<Y>,沉淀到了<Z>。
【分诊结论】<出口名称>(Q<N> 命中)
【推荐位置】<具体文件绝对路径或相对路径>
【写作模板】
<可复制的 Markdown / YAML / 代码草稿>

【后续提醒】
- (可选)上移路径
- (可选)需要走 flow-skill-dev 完整流程
- (可选)sync-shared.sh / sync-skills 分发要求
- (可选)CLAUDE.md 行数超限警告
```

**【一句话沉淀】格式硬约束**:

- 必须有 3 个槽位: **X(做了什么经验)** / **Y(变成了什么载体)** / **Z(沉淀到了哪个概念位置)**
- **不带技术细节** —— 完整禁用词清单见下表
- 用**用户口语**描述(项目脚本 / 全局宪法 / 领域专家 / 启动手册 / 长期记忆 ...)
- 每个出口的 Y/Z 模板见 `references/layer-map.md` 各层"叙事模板"段
- 例子(参考用户思路):"把**重复的浏览器操作过程**变成了**代码**,沉淀到了**项目脚本**"

**禁用词清单**(叙事行**绝对不能出现**):

| 类别 | 禁用词 |
|---|---|
| 出口编号 | L0 / L1 / L2a / L2b / L3 / L4 / L5 / L6 / L7 / L8 / L9 / L10 |
| 判断树编号 | Q0 / Q1 / ... / Q10 |
| 技术形态 | hook / script / MCP / skill / director-* / flow-* / metaspec / frontmatter |
| 文件名 / 路径 | constitution.md / settings.json / CLAUDE.md / AGENTS.md / `_shared/` / 任何绝对或相对路径 |
| 工具命令 | sync-shared.sh / git push / skillshare sync / update-config |
| skill 名 | flow-skill-dev / clean-commit / 任何已实现 skill 名 |

如果叙事行需要表达某个技术概念,用**口语替换**:
- 不写 "hook",写 "会话触发器" / "自动化钩子"
- 不写 "constitution.md",写 "全局宪法" / "全局约束层"
- 不写 "director-*",写 "领域专家" / "专家角色"
- 不写 "CLAUDE.md",写 "启动手册" / "项目说明书"
- 不写 "settings.json",写 "配置入口"

**为什么放第一行**: 这是给**人类一眼可读**的沉淀总结;后面的【分诊结论 / 推荐位置 / 写作模板】是给执行者(走 flow-skill-dev 或直接落盘)的技术细节,可读性弱。两者分层,人类先看一句话,要落地时再读技术段。

**handoff 边界**: 【一句话沉淀】是 **human-facing only**,不进 handoff payload。下游 skill(flow-skill-dev / update-config / sync-skills)消费的是【分诊结论 / 推荐位置 / 写作模板】3 段技术契约。这条要写进 SKILL.md 让下游不会误解析叙事行。

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

**关键变化**: 第 9 层拆分为 9a / 9b,**9a 优先**。原"长期个人偏好 → auto memory"现属 9b;新增 9a"跨 agent 卡壳-解法 → unblock-recipes"是 2026-05-25 增加的目标层。

完整层级说明见 `references/layer-map.md`。每层写作草稿见 `references/templates.md`。

## Red Flags — STOP

命中任一**停止并修正**:

- 用户描述模糊就直接路由(必须 Step 1 追问到清晰)
- 跳过 Q0 直接选层(很多冲动其实不该沉淀)
- 同一条经验路由到 2 个出口(判断树是顺序的,第一个 yes 即出)
- 推荐写 CLAUDE.md 但没检查当前行数(超 200 行还往里塞 = 加剧问题)
- 推荐写 hook 但没提供具体配置示例
- 推荐写 skill 但没提示走 `flow-skill-dev`(直接落盘 = 跳过 scope/test/sync)
- 推荐 constitution 但没提示跑 sync-shared.sh
- 输出"建议沉淀到 xxx 层"但不给具体路径 + 草稿

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "这是个好经验,先写进 CLAUDE.md 再说" | 没过 Q0-Q9 顺序判断 = 选错层概率高 |
| "skill 和 CLAUDE.md 差不多,放哪都行" | 文章核心论点就是反对这个 |
| "用户很想沉淀,就别 Q0 拦了" | Q0 是过滤"沉淀冲动"的关键阀门 |
| "走 flow-skill-dev 太重,直接帮用户写 SKILL.md 落盘" | 跳过 scope/test/sync 三个门 = 引入低质量 skill |
| "constitution 改起来麻烦,塞 CLAUDE.md 算了" | 跨 skill 通用约束放 CLAUDE.md = 其他 skill 看不到 |
| "用户说'记住这个',就直接写 auto memory" | 检查 Q1-Q8,是不是其实是 constitution/CLAUDE.md 级;Q9 内先判 9a(unblock-recipes),不是个人偏好不要 default memory |
| "卡壳-解法也是个人经验,丢 memory 就行" | memory 是 per-user 不跨 agent,通用解法该进 unblock-recipes 让任何 agent 受益 |
| "unblock-recipes 不就是错题本嘛,直接 add 一条" | 写入入口唯一是 experience-summary Q9a 分诊,不允许绕过(防止 catalog 垃圾化) |

## Self-Reference(自指)

本 skill 自己也遵循它推荐的层级原则,实际归属:

- **本 skill 本身 = 独立 skill**(同 clean-commit / skill-doctor 同类,无前缀)
  - 不是 director-*: 它不审单一专业领域,而是路由所有领域
  - 不是 flow-*: 它不强制多 step orchestration,单次调用就出结论
  - 不是 _shared/: 它有完整 SKILL.md 流程,是被触发的 skill 不是被引用的 metaspec
- **11 层架构图(layer-map.md)** = 跨 skill 通用认知模型 → 未来如果 ≥ 2 个 skill 需要引用 → 上移到 `_shared/layer-map.md`,目前还是本 skill 独享
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
    1. 本 skill 按下方"L9a 写作模板"输出完整骨架(内嵌,**不要跨文件读 unblock-recipes/SKILL.md 才知道字段**)
    2. 用户/agent 把模板落盘到 `~/Documents/projects/skills/unblock-recipes/recipes/<slug>.md`
    3. **必须同步更新** `unblock-recipes/INDEX.md` 两处(按 tag 分类 + 按 symptom 关键词反查)
    4. commit 到中心 — pre-commit hook 跑 skill-doctor 自动检查 frontmatter 完整性

### L9a 写作模板(内嵌,无需跨文件读取)

experience-summary 路由到 L9a 时,直接输出以下骨架(用户填值后 copy-paste 到 recipes/<slug>.md):

```md
---
slug: <kebab-case-3-30-chars>            # 跟文件名一致
symptoms:                                  # INDEX 索引用关键词(≥3 个,具体到 agent 真会读到的错误信息片段或行为描述)
  - "<具体症状词1>"
  - "<具体症状词2>"
  - "<具体症状词3>"
first_seen: <today YYYY-MM-DD>
last_hit: <today YYYY-MM-DD>
hit_count: 1
tags: [<tag1>]                            # 至少 1 个,选自 unblock-recipes/INDEX.md "按 tag 分类"段已有词典
---

## <slug> — <一句话症状,≤30 字>

### 症状信号
<agent 怎么识别"我在踩这个坑">
- 错误信息典型片段:
- 行为模式:
- 上下文条件:

### 常见错法
<agent 默认会怎么试,为什么不通>(≤3 行)

### 正确做法
<实际走得通的路,带具体命令 / 代码 / 配置>(≤80 字 / ≤5 行)

### 出处
- 首次发现: <today> / 在 <什么场景 / 哪个项目 / 哪个 skill>
- 复现: 1 次
```

**INDEX 同步硬约束**(experience-summary 输出时必须同步提示用户):
- 在 `unblock-recipes/INDEX.md` "按 tag 分类"对应分类下追加 `- <slug>` 一行
- 在"按 symptom 关键词反查"表为每个 symptom 追加一行(同 slug 可重复)
- **未同步 INDEX = 等价于没入册**(召回时找不到)
- **不替代**:
  - `flow-skill-dev`(那是写 skill 本身)
  - `superpowers:brainstorming`(那是发散探索)
  - retro / post-mortem 会议(那是更重的复盘)

## Reuse

测试用例保留在 `tests/cases.md`,后续修订以这些用例为回归基线。
