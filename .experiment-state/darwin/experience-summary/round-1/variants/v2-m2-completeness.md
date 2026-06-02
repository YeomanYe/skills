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

#### Step 1.5: 准入扫描 — 机密/PII redact (必做前置闸)

跑判断树**前**扫用户原话,命中即处理(违规内容不进 5 段产物也不进 handoff JSON):

| 模式 | 处理 |
|---|---|
| 凭据 token (`ghp_*` / `sk-*` / `xoxb-*` / Bearer / `AKIA*`) | **零容忍拒绝整条**,即使 demo/expired 也拒(沉淀进 git/同步链无法撤销) |
| 私有 email / 内网 IP / `*.corp.*` / `*.internal` / `/Users/<realname>/` | redact 为 `<email>` / `<internal-host>` / `~` |
| 客户/合同/真实姓名 | redact 为 `<customer>` / `<contract-id>` |

- redact 后产物末尾标 `<!-- redacted: email/ip/path -->` 便于审计
- 用户坚持保留原值 → 强制降级出口为 L9b auto memory + scope=session(不进 git)

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

#### Step 2 反例 A: Q0-Q10 全 no 兜底 (禁止 silent halt)

如果 Q0-Q10 全 no(用户在 Step 1 塞了"既不丢也分不出层"的混合体)→ **进 split-or-discard 二选一**,
不能 silent halt(白攒经验)也不能强落 L10(破坏用户信任):

- 提示: "(a) 拆 ≥ 2 条分别走 exp-sum, 或 (b) 接受 L10 + 落盘到 `~/.claude/projects/<proj>/memory/unrouted.md` 备查"
- 5 段【后续提醒】追加 `<unrouted: <reason>>` 标签供下次 lookup
- 同 session 内 ≥ 2 次进入兜底 → 提示"判断树有盲区,触发 flow-skill-dev 修订 judgment-tree.md"

#### Step 2 反例 B: 跨会话冲突 — stale 而非删除

旧条目错了不能直接删(可能被其他 skill / 笔记引用,删 = 引用悬空):

1. 旧条目顶部插入 `<!-- STALE since 2026-MM-DD: superseded by <new-location>, reason: <one-line> -->`
2. 新条目【后续提醒】标 `<supersedes: <old-path>:<line-range>>`
3. 旧条目**保留 90 天**给引用方迁移,skill-doctor stale-sweeper 到期提醒清理
4. 旧条目若已分发到 _shared/ 12 个 target → 走完整 4 步同步链才能完成 stale 分发
5. **例外**: 旧条目含 PII / 凭据 → 立即删除跳 90 天窗口,产物末尾标 `<emergency-delete: <reason>>`

#### Step 2 反例 C: 多项目 vs 单项目专属

`~/.claude/projects/` 下同一笔经验可能跨项目。**默认 = 单项目专属**,满足 ≥ 2 个跨项目信号才上抬:
信号包括 (a) 用户原话含"所有项目都" / "across projects"; (b) 工具链层面非业务层面(git/pnpm/Playwright);
(c) 涉及文件类型在 ≥ 2 项目存在(`*.tsx` / `*.go` / `pyproject.toml`); (d) 用户已在 ≥ 2 项目独立踩同一坑。

- 单项目 → L5 nested CLAUDE.md / L8 项目 CLAUDE.md
- 跨项目 → L1 constitution / L2 _shared / L9a unblock-recipes
- 不确定 → **默认单项目**(误升污染所有项目 > 该升没升),【后续提醒】写"如未来 ≥ 2 项目独立踩,上移至 <候选全局层>"

### Step 3: 输出可直接执行的写作草稿

按 Q0-Q10 的命中出口,给一份**可直接 copy-paste 写入对应文件**的草稿。
草稿要求 + 各层模板见 `references/templates.md`(L9a 模板单独成文,见 `references/l9a-recipe-template.md`)。

**Prior-art 检查(出口是 director-* / flow-* 时必做)**:

在给"新建 skill"草稿之前,**必须先列已有同类 skill** 让用户选:

- 出口 = director-* → 列已实现 5 个: director-design / director-frontend / director-promote / director-ops / director-architect。问"改哪个的哪段?"还是"真的需要新建第 6 个角色?"
- 出口 = flow-* → 列已实现 7 个: flow-codex-goal / flow-dev-task / flow-ext-publish / flow-project-bootstrap / flow-project-finish / flow-skill-dev / flow-skill-research。问"改哪个的哪个 step?"还是"新建?"

**默认推荐**: 改现有 > 新建。只有当 ≥ 3 个现有 skill 都"沾边但都不准确"时才考虑新建。
新建草稿前提示:"新建一个 director-* / flow-* 是大投入(走 flow-skill-dev 完整 8 步),确认要新建吗?"

#### Step 3 反例: L9a 唯一生成路径 — 无 incident 禁止提前 skeleton

用户原话提 "unblock-recipes" 但本会话**无实际 incident** → **禁止生成 skeleton**
(空 skeleton 污染 INDEX.md 反查表 + future lookup 时 false-positive 误导)。处理:
- (a) 提供历史 incident(症状 + 解法验证过程) → 走 Q9a 正常出口
- (b) 只想学结构 → 引导读 `references/l9a-recipe-template.md`,不落盘
- 【分诊结论】标 `<L9a-deferred: awaiting-real-incident>`
- 特例: "在另一会话踩过来归档" → 凑齐 ≥ 3 字段(symptom / root-cause / fix-verified-by)才生成

### Step 4: 上移提醒

上移信号 / 上移路径表 / 上移检查清单见 `references/failure-modes.md` 末段。
3 个信号任一命中(用户口头明示 / 本对话计数 ≥ 2 / 跨 director 信号)→ 本 skill 必须输出上移检查清单。

#### Step 4 反例: stage_switch 信号外送 meta-skill

用户本会话从 dev (flow-dev-task) 切到 finish (flow-project-finish) 并触发 exp-sum。
meta-skill 不知道 stage 已切换会持续推 dev reminder 造成冗余。

**信号 schema** 写入 `.agent/jobs/<task-slug>/stage-signal.json`:

```json
{
  "type": "stage_switch",
  "from": "dev",
  "to": "finish",
  "triggered_by": "experience-summary",
  "session_id": "<uuid>",
  "timestamp": "2026-06-03T10:00:00Z",
  "exp_sum_exit": "L8",
  "suppress_followups": ["dev-reminder", "code-review-nag", "test-coverage-nag"],
  "active_until": "stage=finish completes OR 24h timeout"
}
```

- **写入时机**: 用户原话含"切到 finish / 进收尾 / wrap up" + 上一 active flow ≠ 当前推断 flow → **Step 5 生成前**必须落盘
- **写入失败** → 【后续提醒】标 `<stage-signal-write-failed: <err>>`,降级口头告知 user 手动通知 meta-skill
- **何时去除冗余**: meta-skill 下个 turn 开头读到 → 按 `suppress_followups` 静默 reminder;`active_until` 到期失效;stage 切回 dev → 写新信号覆盖
- **反例**: 用户顺口"以后收尾时也注意 X" — **不算** stage_switch,只是经验适用场景描述。判据:本会话有无**真切换** flow orchestrator,非未来式假设

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

### 灾难性失败模式(显式拦截,不输出 5 段产物)

任一命中立即停 → 转人工:
1. **凭据沉淀**: Step 1.5 漏了 token → 紧急停 + emergency-delete 已落盘条目
2. **stale 误覆盖**: 新条目路径 == 旧路径但未标 STALE → 停,走 supersedes 流程
3. **L9a 无 incident 落盘**: 出口 9a 但 incident 字段缺 ≥ 1 → 退 Step 3 反例
4. **跨项目误升**: 跨项目信号 < 2 但写入 _shared/ → 降级回项目级
5. **stage-signal 写失败但继续**: 信号必须落盘成功才进 Step 5,否则 meta-skill 重复推 reminder

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

## 回归测试用例(必须全过)

`tests/cases.md` 维护,以下 8 类必须覆盖(M2 新增 case 4-8):

| # | case | 输入 | 期望 |
|---|---|---|---|
| 1 | 正常 L1 | "agent 不要假装跑了测试" | L1 + 4 步同步链 |
| 2 | 正常 L5 | "this dir 下 .tsx 全用 server component" | L5 nested CLAUDE.md |
| 3 | Prior-art | "新增审 perf 的 director" | 引导改 director-frontend |
| 4 | **PII redact** | 原话含 `ghp_abc123` | Step 1.5 拒绝,不进产物 |
| 5 | **跨会话冲突** | 旧条目 CLAUDE.md, 新条目下沉 skill | 旧 STALE 90 天 + 新 supersedes |
| 6 | **Q0-Q10 全 no** | 用户塞混合体 | split-or-discard,不 silent halt |
| 7 | **L9a 无 incident** | 提 unblock-recipes 无 incident | 拒 skeleton + L9a-deferred |
| 8 | **stage_switch** | "切到收尾" + 上一 flow=dev | stage-signal.json + suppress list |

## Reuse

测试用例保留在 `tests/cases.md`,后续修订以这些用例为回归基线。新增 edge case (4-8) 对应
Step 1.5 / Step 2 兜底 / Step 2 stale / Step 3 L9a-deferred / Step 4 stage-signal 5 个补丁段。
