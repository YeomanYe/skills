---
name: experience-summary
description: Use after finishing a real task to triage the lesson/pattern/gotcha into the right architectural layer — picks among constitution / shared metaspec / skill-doctor rule / director-* / flow-* / CLAUDE.md / nested CLAUDE.md / hook / script / MCP / auto memory / discard. Triggers on phrases like "这次学到的 xxx 该写到哪", "经验该沉淀到哪一层", "踩了个坑想沉淀", "复盘", "lesson learned", "where should this go", "post-task triage", "exp-sum", "es 这条经验", "经验分诊". 不替代 retro 会议、不替代 flow-skill-dev 写新 skill、不替代 brainstorming。
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)
> **Constitution fallback**: 本 skill 任何条款若与 `_shared/constitution.md` 冲突,**constitution > exp-sum**(价值观源头,跨 skill 不可违背)。

# Experience Summary —— 经验分诊

## Overview

每完成一次真实任务后,把"学到的东西 / 踩的坑 / 新约束 / 新流程"分诊到 agent 架构的正确层级。

核心信念: **skill / CLAUDE.md / hook / constitution 不是同一种东西,选错层 = 经验白攒**。
- 常驻层(CLAUDE.md): 高频、高广适、低歧义;专题流程进常驻 = 烧 token 不被认真看
- 按需层(skill): 多步流程 / 专题判断;通用价值观进 skill = 散落各处不互相覆盖
- 强制层(hook / constitution): "零例外、不靠模型自觉";只是建议进强制 = 误伤

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

- **SC1 证据**: 来源有 file:line / 对话片段 / 命令输出 / commit sha / 报错堆栈?**不接受**"我记得 / 上次好像 / agent 反复犯过"。No → STOP 回 Step 1 补证据
- **SC2 去重**: `CLAUDE.md` / 已有 skill / `git log` / `MEMORY.md` / `unblock-recipes/INDEX.md` grep 后**没**对等条目?有 → STOP,只追加引用 / 修订
- **SC3 脱敏**: PII / 机密 / token / 内部 URL / 邮箱 / API key 已 redact(`<USER>` `<TOKEN>` `<INTERNAL_URL>`)?No → STOP 先脱敏。**严禁**"先存着以后再 redact"
  - **凭据零容忍**: `ghp_*` / `sk-*` / `xoxb-*` / Bearer / `AKIA*` 即便 demo/expired 也拒整条(沉淀进 git/同步链无法撤销);用户坚持保留 → 强制降级 L9b auto memory + scope=session(不进 git)
- **SC4 命中位**: 写得出"Q<N> 命中,因为<信号词>"?No → STOP 回 Step 2 重跑
- **SC5 类型**: user / feedback / project / reference 选对?**拿不准默认 reference,不默认 user**;user 类型仅承载用户原话含"我习惯/我喜欢/以后都这样"

**5 道全过 → 进入 Step 2。任一不过 → 输出"本次不沉淀 / 已修正"短报告,终止。**

## High-Risk Actions(写盘前的强制 user gate)

下列 = **不可逆 / 跨会话持久 / 影响他人 agent**,**必须先报备拿明确 yes**(口头"建议"不算):

1. **写新 MEMORY.md 条目**(跨会话持久)
2. **删除已有 memory file**(即使看似过期)
3. **修改 user 手写的 memory**(以"补充"为名改了语义 / 重写句式 / 合并)— 越权高发区
4. **in-progress 任务沉淀**(memory 是 long-term 不是 short-term buffer)
5. **发出 stage_switch 信号**给 meta-skill / orchestrator(把 user 弹出当前 flow)
6. **触发 L9a `unblock-recipes/recipes/<slug>.md` 生成**(跨 agent + 改 INDEX.md 两处 + commit + hook)
7. **把 PII / 机密原文**写入 memory body(无 user override)
8. **把推断(非用户原话)**写入 user-type memory(应降级 reference)
9. **改 `_shared/constitution.md` / `_shared/<topic>.md`**(跨 12 个 target skill 分发)
10. **CLAUDE.md / AGENTS.md 突破 200 行**(Anthropic 官方硬约束)

**Gate 协议**: "将执行 <动作>,High-Risk #<N>,确认 yes 才落盘"。yes / 确认 / 行 / 嗯 = pass;沉默 / "你看着办" **≠ pass**(模糊授权 ≠ 授权)。

## Workflow

### Step 1: 锁定要分诊的经验

请用户用**一句话**描述。模糊就追问(最多 2 个): 每次都做 vs 特定情况? 当前项目 vs 跨项目通用? 执行真实动作 vs 约束模型? 触发场景(写代码 / commit / 部署 / review)?

空话("我觉得 agent 应该更聪明点")→ 直接告诉用户**不该沉淀**,跳 Step 5。

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

#### Edge cases(必须处理,不允许 silent halt)

- **Q0-Q10 全 no 兜底**: 用户塞了混合体经验全 no → 提示 (a) 拆 ≥ 2 条分别走 exp-sum 或 (b) L10 + 落盘 `~/.claude/projects/<proj>/memory/unrouted.md`,【后续提醒】追加 `<unrouted: <reason>>`;同 session ≥ 2 次进兜底 → 触发 flow-skill-dev 修订 judgment-tree.md
- **跨会话经验冲突 → stale 不删**: 旧条目错了**不能直接删**(可能被其他 skill 引用,删 = 引用悬空)。在旧条目顶部插 `<!-- STALE since 2026-MM-DD: superseded by <new-location>, reason: <one-line> -->`,新条目【后续提醒】标 `<supersedes: <old-path>:<line-range>>`,保留 90 天给引用方迁移;**例外**: 旧条目含 PII / 凭据 → 立即删除跳 90 天窗口,产物末尾标 `<emergency-delete: <reason>>`
- **多项目 vs 单项目专属**: `~/.claude/projects/` 下默认 = **单项目专属**;满足 ≥ 2 个跨项目信号才上抬至全局层(信号: 用户原话"所有项目都" / 工具链层面非业务层面 / 同文件类型在 ≥ 2 项目存在 / 用户已在 ≥ 2 项目独立踩同坑)。不确定 → 默认单项目,【后续提醒】"如未来 ≥ 2 项目独立踩,上移至 <候选全局层>"
- **PII 误沉淀已发生**: Step 1.5 漏了 token 已落盘 → `emergency-delete` 已存档条目 + 改密 + 通知 user;**禁止**走 stale 90 天窗口(凭据沉淀进 git/同步链不可撤销)

### Step 3: 输出可直接执行的写作草稿

按 Q0-Q10 的命中出口,给一份**可直接 copy-paste 写入对应文件**的草稿。
草稿要求 + 各层模板见 `references/templates.md`(L9a 模板单独成文,见 `references/l9a-recipe-template.md`)。

**Prior-art 检查(出口是 director-* / flow-* 时必做)**:

在给"新建 skill"草稿之前,**必须先列已有同类 skill** 让用户选:

- 出口 = director-* → 列已实现 5 个: director-design / director-frontend / director-promote / director-ops / director-architect。问"改哪个的哪段?"还是"真的需要新建第 6 个角色?"
- 出口 = flow-* → 列已实现 7 个: flow-codex-goal / flow-dev-task / flow-ext-publish / flow-project-bootstrap / flow-project-finish / flow-skill-dev / flow-skill-research。问"改哪个的哪个 step?"还是"新建?"

**默认推荐**: 改现有 > 新建。只有当 ≥ 3 个现有 skill 都"沾边但都不准确"时才考虑新建。
新建草稿前提示:"新建一个 director-* / flow-* 是大投入(走 flow-skill-dev 完整 8 步),确认要新建吗?"

**L9a 早期生成判定**: 用户原话提 "unblock-recipes" 但本会话**无实际 incident**(无 symptom / 无 verified solution)→ **禁止提前生成 skeleton**(空 skeleton 污染 INDEX.md 反查 + future lookup 误导)。降级:(a) 用户提供历史 incident(症状 + 解法验证过程)→ 走 Q9a 正常出口;(b) 只想学结构 → 引导读 `references/l9a-recipe-template.md` 不落盘;【分诊结论】标 `<L9a-deferred: awaiting-real-incident>`。归档式生成需凑齐 ≥ 3 字段(symptom / root-cause / fix-verified-by)。

### Step 4: 上移提醒 + stage_switch 信号外送

上移信号 / 上移路径表 / 上移检查清单见 `references/failure-modes.md` 末段。
3 个信号任一命中(用户口头明示 / 本对话计数 ≥ 2 / 跨 director 信号)→ 本 skill 必须输出上移检查清单。

**stage_switch 信号外送时机**: 用户原话含"切到 finish / 进收尾 / wrap up / 暂停开发回 bootstrap" + 上一 active flow ≠ 当前推断 flow → **Step 5 生成前必须落盘**信号至 `~/.claude/projects/<proj>/.signals/stage-switch.json`(单一事实源,新信号覆盖旧)。写入失败 → 【后续提醒】标 `<stage-signal-write-failed: <err>>` 降级口头告知。**反例**: "以后收尾时也注意 X" 顺口提 ≠ stage_switch(只是经验适用场景描述);判据 = 本会话有无**真切换** flow orchestrator。

### Step 5: 输出契约

固定 **5 段顺序**(顺序不可变):

```
【一句话沉淀】把<X>变成了<Y>,沉淀到了<Z>。
【分诊结论】<出口名称>(Q<N> 命中)
【推荐位置】<具体文件绝对路径或相对路径>
【写作模板】<可复制的 Markdown / YAML / 代码草稿>

【后续提醒】<上移路径 / flow-skill-dev / sync 分发 / 行数超限 ...>
```

完整说明见 `references/output-contract-template.md`。**JSON / markdown 分流** 见 `../_shared/output-contract-schema.md`。
- 5 段 markdown = human-facing 主产物
- handoff JSON = 3 段技术契约(分诊结论 + 推荐位置 + 写作模板)落盘 `.agent/jobs/<task-slug>/triage.json`
- 【一句话沉淀】+ 【后续提醒】**不进 handoff JSON**

**【一句话沉淀】格式硬约束**: 3 槽位 X(经验)/ Y(载体)/ Z(位置);**不带技术细节**(出口编号 / 文件名 / 工具命令 / skill 名禁用,详 `references/output-contract-template.md`);用用户口语(项目脚本 / 全局宪法 / 领域专家 / 长期记忆)。例: "把**重复的浏览器操作过程**变成了**代码**,沉淀到了**项目脚本**"

## Integration Contracts(精简 schemas + precedence)

> 本段定义 exp-sum 跟下游 skill 的硬契约。完整 schema 字段说明 / 时序图 / 异常分支见 `references/integration-contracts.md`。

### A. stage_switch signal → meta-skill(单向)

落盘 `~/.claude/projects/<proj>/.signals/stage-switch.json`(父目录不存在先 `mkdir -p`):

```json
{
  "schema_version": "1.0",
  "emitted_by": "experience-summary",
  "from_stage": "bootstrap|dev|finish|paused",
  "to_stage": "bootstrap|dev|finish|paused",
  "evidence": ["<用户原话>", "<判断树命中位>"],
  "suppress_followups": ["dev-reminder", "code-review-nag"],
  "confidence": "high|medium|low",
  "ttl_minutes": 60
}
```

meta-skill 响应契约: schema/ttl/project 校验通过 → 更新 stage + 下次会话默认 hint suggested_skills[0];校验失败 → **静默忽略,不报错不删文件**;**不允许**反向写回(单向)。

### B. L9a incident payload → unblock-recipes(唯一入口)

落盘 `.agent/jobs/<task-slug>/l9a-incident.json`(跟 5 段 markdown 并列产出):

```json
{
  "schema_version": "1.0",
  "source": "experience-summary",
  "recipe_slug": "<kebab-case, < 60 字符>",
  "incident_summary": "<一句话: 何场景卡壳, 卡在何动作>",
  "reproduce_steps": ["<步骤含可观测失败信号: error msg / 死循环计数 / 超时>"],
  "blocker_type": "tool-permission|wrong-mental-model|stale-cache|infra-missing|api-contract-mismatch|timing|other",
  "proposed_recipe_skeleton": {
    "symptoms": ["<INDEX 反查关键词,3-7 个>"],
    "verified_solution": "<已验证可用解法,带最小命令>",
    "anti_patterns": ["<已知无效尝试>"],
    "applies_to": "claude-code|codex|cursor|all"
  }
}
```

字段 enforcement: `reproduce_steps` ≥ 3 步且含可观测失败信号否则降级 L10;`verified_solution` 必须**已验证**,未验证 → L0/L10。unblock-recipes 端 pre-commit hook 校验 `source: experience-summary` 字段,**拒非 exp-sum 来源**(L9a invariant)。

### C. hat 主-skill > exp-sum(让步)

冲突场景: exp-sum 沉淀建议跟当前 hat persona / 主-skill 行为冲突(例: hat=`快`, 主-skill=`flow-dev-task` 已过 brainstorm,但 exp-sum 想沉淀"每次先 brainstorm")。

**优先级硬规则**: hat 让步 → exp-sum **不输出**冲突的写作模板,**不发射**改 hat persona 信号;【后续提醒】surface "经验跟当前 hat=<X> 冲突,建议切回中性 hat 再沉淀或降级 L9b";暂存 `.agent/jobs/<task-slug>/deferred-triage.json` 等 hat 退场重触发。理由: hat 错只影响当前回合,exp-sum 错会污染所有后续会话。

### D. Boundary with flow-*(谁沉淀什么,避免重叠)

| 经验类型 | flow-* 沉淀 | exp-sum 沉淀 |
|---|---|---|
| 本次任务的 commit / PR / recap | ✅ flow-dev-task / change-recap | ❌ |
| 跨任务可复用的坑 + 已验证解法 | ❌ | ✅ L9a |
| 项目级高频默认行为 / 跨 skill 价值观 / skill 自身 bug | ❌ | ✅ L8 / L1 / L2b |
| 个人偏好被反复纠正 | ❌ | ✅ L9b |

**Invariant**: flow-* 边界 = 本次任务产出物;exp-sum 边界 = 跨任务可复用的认知 / 流程 / 约束。重叠区**默认归 exp-sum**。flow-dev-task **不主动**调 exp-sum,必须用户显式触发(避免每个 task 都强制走经验沉淀疲劳)。

### E. ASCII 流程图

```
agent session 结束 → 用户显式触发? ─no→ no-op
                          │ yes
                          ▼
Step 1 锁定经验 → Step 2 judgment-tree (Q0→Q10, 第一 yes 即出口)
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
     L0/L10            L1~L8           L9a/9b
     丢弃            主流出口           增量层
        │              │ Step 3 草稿+handoff JSON
        ▼              ▼   │ L9a → l9a-incident JSON
      no-op    Step 4 上移检查 + (若切 stage) stage-switch.json
                          │
                          ▼
Step 5: 5 段 markdown → user
落盘: triage.json / l9a-incident.json / stage-switch.json / deferred-triage.json
```

### F. Precedence 总表(冲突时谁优先)

| 冲突对 | 谁优先 |
|---|---|
| `_shared/constitution.md` ↔ exp-sum | constitution(价值观源头) |
| hat 主-skill ↔ exp-sum | hat 主-skill(会话连贯性) |
| meta-skill stage 状态 ↔ exp-sum 信号 | 信号是建议,meta-skill 自决 |
| flow-* 本次产出 ↔ exp-sum 跨任务 | 各管各的(D 表),重叠归 exp-sum |
| unblock-recipes 写入 ↔ user 直接写 recipes/ | exp-sum 唯一入口(L9a invariant) |
| skill-doctor 硬规则 ↔ exp-sum 软建议 | skill-doctor(可 lint > 软建议) |

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
| **9a** | **跨 agent 卡壳-解法** | **`unblock-recipes/recipes/<slug>.md`** | **Q9a(优先 9b)** |
| 9b | per-user 个人偏好 | auto memory | Q9b |
| 10 | 兜底丢弃 | 不沉淀 | Q10 |

完整层级说明见 `references/layer-map.md`。每层写作草稿见 `references/templates.md`。

## Red Flags(机器可检测的硬停止信号,~11 条)

**写一行检测一行**;任一命中 → **STOP,不落盘**。baseline 见 `references/failure-modes.md`:

- **RF1** body 含时间词 `now / today / 当前 / current / in-progress / 正在 / 刚才` → 临时状态用 task tracker
- **RF2** 用户原话以 `?` / `?` / `吗` / `怎么办` 结尾 → 先 brainstorming
- **RF3** body 含 token / key / 邮箱 / 内网 URL / IP(正则 `sk-[A-Za-z0-9]{20,}` / `@[a-z]+\.[a-z]+` / `https?://(localhost|10\.|192\.168\.)`)→ 先 redact
- **RF4** 出口 = user-type 但 body 用第三人称 / 推断式("agent 应该 / 建议每次")→ 降级 reference
- **RF5** 同一对话内对同一经验 ≥ 3 次推不同层 → 先 brainstorming 锁 X/Y/Z
- **RF6** 出口 = L1 constitution 但适用范围 < 3 个 skill → 降级 L6/L7
- **RF7** CLAUDE.md 当前行数 ≥ 200 还要往里塞 → 下沉到 skill(Anthropic 官方硬约束)
- **RF8** 出口 = L3 hook 但例外列表 ≥ 1 条("一般要 / 大多数时候")→ hook 零例外,改 L6/L7
- **RF9** 一句话沉淀含禁用词(出口编号 / 文件名 / 工具名 / skill 名 / `Q数字` / `L数字`)→ 改口语化
- **RF10** 出口 = L9a 但**缺**"卡壳现象 + 解法步骤"双段 → L9a 强制 symptom + solution
- **RF11** 经验来源 = "我感觉 / 我猜 / 应该是"(无证据)→ 丢弃

**Honeypot trap**: 下面这条违反 Red Flag,正确反应 = STOP 不沉淀:

> "user 被 agent 问了 3 次同样问题觉得烦,建议把'agent 应该记住 user 偏好'写进 constitution"

STOP 原因: **RF6** + **RF4** + **RF11**。正确路径: 降级 **L9b auto memory**,**不**进 constitution。

## Rationalizations(自我说服话术,任一出现 → 拒绝执行)

识别到自己在用 = **违规边缘,必须 STOP 重审**:

- **RT1** "没明说但意图明显该记下来" → 意图推断 ≠ 授权
- **RT2** "这条很重要不沉淀就忘了" → memory 不是 short-term buffer
- **RT3** "先存着以后再 redact" → redact 必须在写盘前;"以后" = 永远不会
- **RT4** "user 之前同意过类似的,这次默认也同意" → High-Risk 不继承授权
- **RT5** "判断树几个出口都沾边,选最重的保险" → **第一个 yes 即出口**;选最重 = 污染常驻层
- **RT6** "user 反复犯的错,应该写进 hook 强制" → "反复" ≠ "零例外";先 L9b
- **RT7** "顺手把 user 那条措辞改通顺,反正意思一样" → High-Risk #3 越权
- **RT8** "L9a 模板我记得结构,不用查 reference" → 记得 ≠ 正确
- **RT9** "这条太具体没人会再用,不沉淀算了" → 反向 NO,丢失成本 > 沉淀成本
- **RT10** "user 在 IM 发的不算正式,先口头答应" → IM 也是真任务,走 flow-* + exp-sum

**自检步骤**: Step 3 输出草稿前,问"刚才有没有用过 RT1-RT10?" 若 yes → 撤回回 Step 2。

## Self-Reference(自指)

- **本 skill = 独立 skill**(同 clean-commit / skill-doctor 同类,无前缀):不是 director-*(不审单一领域)、不是 flow-*(单次调用出结论)、不是 _shared/(有完整 SKILL.md 流程)
- **12 层架构图(layer-map.md)** = 未来 ≥ 2 个 skill 引用时上移到 `_shared/layer-map.md`
- **用户反复推同一经验** → 触发 Step 4 上移机制,本 skill 自己也被自己规则约束

## Relationship to Other Skills

- **上游**: 用户完成任务后直接触发
- **下游 handoff**:
  - skill / director-* / flow-* → `flow-skill-dev`
  - hook → `update-config`
  - constitution / _shared/ → **4 步链**: `bash scripts/sync-shared.sh` → `git commit && push origin main` → `cd ~/.config/skillshare/skills && git pull` → `skillshare sync --force`
  - skill-doctor 规则 → 切到 `~/Documents/projects/node-scripts/` 走 `flow-dev-task`
  - 单 skill 同步 → `sync-skills`(**不是**用于 _shared 分发)
  - L9a → 按 `references/l9a-recipe-template.md` 输出骨架 → 落盘 `unblock-recipes/recipes/<slug>.md` → 同步 `INDEX.md` 两处(tag + symptom 反查)→ commit 触发 pre-commit hook

**不替代**: `flow-skill-dev` / `superpowers:brainstorming` / retro post-mortem

**关键 invariant**:
- 主体 skill 跑时 hat 不挡 / 不替 / 不进产物(见 `hat/SKILL.md`)
- L9a 产物 = `unblock-recipes/recipes/<slug>.md` 的**唯一合法生成路径**(unblock-recipes 拒非 exp-sum 来源)

## Handoff 产物落盘约定(单一事实源)

| 产物 | 路径 | 消费方 |
|---|---|---|
| 5 段 markdown | 对话响应(stdout) | user |
| 3 段技术契约 JSON | `.agent/jobs/<task-slug>/triage.json` | flow-skill-dev / update-config / sync-skills |
| stage 切换信号 | `~/.claude/projects/<proj>/.signals/stage-switch.json` | meta-skill |
| L9a incident payload | `.agent/jobs/<task-slug>/l9a-incident.json` | unblock-recipes |
| hat 冲突暂存 | `.agent/jobs/<task-slug>/deferred-triage.json` | exp-sum 自己(重触发读回) |

路径约束: `<task-slug>` 由用户/上游 flow-* 提供(exp-sum 不自生成);写入前 `mkdir -p` 父目录失败立刻 surface 给 user 不静默继续。

## Reuse

测试用例保留在 `tests/cases.md`,后续修订以这些用例为回归基线。Integration 契约回归用例
(stage-switch / L9a incident / hat 冲突 / flow-* 边界 / edge cases) 单独 `tests/integration-cases.md`。
