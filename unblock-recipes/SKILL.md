---
name: unblock-recipes
description: >
  Agent 错题本 — 跨 agent 通用的"卡壳→解法"案例库。
  agent 卡壳 / 反复改不对 / 走不通时,先翻这里找已踩过的同类坑 + 已验证的解法,
  避免重蹈覆辙或盲目试错;首次出现的新坑解决后,通过 experience-summary 路由写入。
  自动触发关键词: stuck / blocked / loop / 反复 / 卡 / 走不通 / hit a wall /
  can't figure out / 试了 N 次都不行 / 死循环 / 同样错 N 次 / 之前踩过吗。
  显式触发: 「查下错题本 / 看下 unblock-recipes / 这个之前踩过吗 / 卡壳记录 / 错题集 / lookup pitfalls」。
  上游触发: flow-dev-task / flow-codex-goal 等 orchestrator 检测到 agent loop 信号时主动 lookup。
  优先级: unblock-recipes(通用工程级解法,跨 agent)> auto memory(per-agent 个人偏好)> 其他。
  Do NOT use for: 写入个人偏好(→ auto memory)、跨 skill 通用价值观(→ constitution.md)、
  项目级规则(→ CLAUDE.md / AGENTS.md)、skill 自身可 lint 的硬规则(→ skill-doctor rule)、
  一次性现象(→ 不沉淀)。写入时**必须**先经 experience-summary 分诊路由,不要直接落盘。
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)

# unblock-recipes —— Agent 错题本

## Overview

**核心心智:错题本**。
- 学生:做错的题汇总成本,考试前翻,避免再错
- agent:跌过的坑(symptom)+ 已验证的解法(fix)汇总成 catalog,卡壳时翻,避免重蹈覆辙

**为什么独立成 skill 而不是 memory 子集**:
- `memory` 是 **per-user / per-agent** 的个人偏好(用户 A 用 Claude Code 时记的事)
- `unblock-recipes` 是 **跨 agent / 跨用户** 的工程级反例(任何 agent 卡同样的壳都受益)
- 用户换 agent / 新 user 加入团队时,memory 不通用,unblock-recipes 仍可用

**召回优先级**(agent 卡壳时按序查):
1. `unblock-recipes`(通用工程级解法)
2. `auto memory`(per-agent 个人偏好,可能含同类坑的修正)
3. 其他(constitution / CLAUDE.md / 文档)

## When to Use

### 触发场景(召回侧)

| 场景 | 触发信号 |
|---|---|
| 自动召回 | agent 自身或上游 orchestrator(flow-dev-task / flow-codex-goal)检测到关键词:`stuck` / `blocked` / `loop` / `反复` / `卡` / `走不通` / `hit a wall` / `can't figure out` / `试了 N 次都不行` / `死循环` / `同样错 N 次` |
| 显式查阅 | 用户说"查下错题本" / "这个之前踩过吗" / "lookup pitfalls" / "看下 unblock-recipes" |
| 主动预防 | agent 开新任务前(如重大重构 / 跨模块改动)主动 lookup 相关 tag |

### 写入场景(写入侧)

写入路径**唯一入口是 experience-summary 分诊路由**(本 skill 不直接接受写入)。

experience-summary Q9 判定"跨会话长期经验 + 跨 agent 通用 + 卡壳-解法模式" → 路由到本 skill。

详见下方 [Writing 段](#writing写入流程详见-experience-summary)。

## When NOT to Use

- 写入**个人偏好** → `auto memory`(per-agent / per-user 风格)
- 写入**跨 skill 通用价值观** → `_shared/constitution.md`
- 写入**项目级规则** → 项目 `CLAUDE.md` / `AGENTS.md`
- 写入**skill 自身可 lint 的硬规则** → `skill-doctor` 新规则
- **一次性现象**(下次大概率不会再出现)→ 不沉淀
- agent 在做新任务而非卡壳 → 用 flow-dev-task / flow-codex-goal,不要预防性翻错题本浪费 token

## 目录结构

```
unblock-recipes/
  ├─ SKILL.md           # 本文件
  ├─ INDEX.md           # symptom keyword → recipe slug 反向索引(轻,~2KB,优先载入)
  ├─ recipes/
  │   ├─ <slug>.md      # 单条 recipe(详,~500B-1KB,命中后载入 1-2 条)
  │   ├─ ...
  │   └─ .gitkeep       # 保留空目录
  ├─ _archive/          # 90 天没命中的归档(后期机制,MVP 不实现)
  └─ tests/
      └─ cases.md
```

**recipes/ 的关键约束**: agent 召回时**禁止全量载入**(防 token 爆炸)。
载入流程: 先读 INDEX.md → 关键词匹配最多 3 条 → 只载入命中的 recipe。

## Recipe 条目结构(强约束)

每条 recipe 是 `recipes/<slug>.md`,frontmatter + 4 段正文,**总长 ≤ 1KB**(短到 agent 能一次性读完判断是否命中):

```md
---
slug: <kebab-case-3-30-chars>            # 跟文件名一致
symptoms:                                  # INDEX 索引用的关键词清单(3-8 个)
  - "<具体症状词1>"
  - "<具体症状词2>"
first_seen: 2026-05-25                    # 首次记录日期
last_hit: 2026-05-25                      # 最近一次被召回 + 验证有效的日期
hit_count: 1                              # 累计被召回 + 验证有效的次数
tags: [<tag1>, <tag2>]                    # 大类标签(codex / playwright / sandbox / git / pnpm / typescript ...)
---

## <slug> — <一句话症状,≤30 字>

### 症状信号
<agent 怎么识别"我在踩这个坑">
- 错误信息典型片段: <如有>
- 行为模式: <如反复 retry 同一动作>
- 上下文条件: <如使用某 backend / 某版本>

### 常见错法
<agent 默认会怎么试,为什么不通>(≤3 行)

### 正确做法
<实际走得通的路,带具体命令 / 代码 / 配置>(≤80 字 / ≤5 行)

### 出处
- 首次发现: <date> / 在 <什么场景 / 哪个项目 / 哪个 skill>
- 复现: <累计 hit_count 次>
```

**字段硬约束**:
- `slug`: kebab-case, 3-30 字符, 唯一(全仓不能重复)
- `symptoms`: 至少 3 个具体关键词(不能只填"卡壳"这种泛词;要是 agent 真会读到的错误信息片段或具体行为描述)
- `tags`: 至少 1 个,从 `INDEX.md` 维护的 tag 词典选;新 tag 入册前先 review
- 正文 4 段不可省

## INDEX.md 格式

INDEX 是反向索引,agent 召回时**优先且唯一**先读这个文件(轻,~2KB)。

```md
# unblock-recipes INDEX

> Symptom keyword → recipe slug 反向索引。
> agent 召回流程: 读本文件 → 匹配 symptom 关键词 → 找到 ≤3 条候选 recipe → 只载入这些 recipe 的正文。
> **禁止 ls recipes/ 后全量 cat**,会炸 token。

## 按 tag 分类

### codex
- (空,等首条 recipe 写入)

### playwright
- (空)

### git
- (空)

### pnpm / npm
- (空)

### typescript / type system
- (空)

### sandbox / permission
- (空)

### im / cc-connect
- (空)

### subagent / orchestration
- (空)

## 按 symptom 关键词反查(精确召回)

| symptom 关键词 | recipe slug | tag |
|---|---|---|
| (空表,等首条 recipe 写入,按 alphabetical 排) | | |
```

**维护规则**:
- 每加一条 recipe → 必须同时在 INDEX.md 的"按 tag 分类"对应分类下追加 1 行 + "按 symptom 关键词反查"表追加 1-N 行(每个 symptom 一行)
- 归档 recipe → 同步从 INDEX.md 删除
- 新 tag 入册 → 在"按 tag 分类"段加新分类

## Workflow

### Lookup(召回流程)

agent / orchestrator 检测到卡壳信号后:

1. **读 INDEX.md**(必须先读,~2KB)
2. **匹配关键词**(**字符串/语义包含匹配,不是 bash grep**):
   - 自动召回 → 从当前 error message / agent 行为提取关键词(如 "ECONNREFUSED" / "sandbox denied" / "permission denied"),在 INDEX "按 symptom 关键词反查"表里逐行做字符串包含或语义近似匹配
   - 显式召回 → 用用户给的关键词(如"播 ECONNREFUSED 9222")做同样匹配
   - 不要用 `grep -E` 直接扫 recipes/(违反轻载入约束)
3. **筛选候选**: 取 top 3 命中(命中数排序);多 tag 时优先匹配 tag
4. **载入候选 recipe**: `cat recipes/<slug>.md`,逐条读"症状信号"段判定是否真命中
5. **应用解法**:
   - 真命中 → 按"正确做法"段执行 + 该 recipe 的 `last_hit` 更新为今天 + `hit_count + 1`
   - 看似命中实际不是 → 不更新计数,继续 lookup 下一候选
   - 全 3 条都不命中 → 退出 lookup,回到默认调试流程;若解决后是新坑 → 走 experience-summary 路由考虑入册

### Writing(写入流程,详见 experience-summary)

**本 skill 不接受直接写入**。所有新 recipe 必须经 `experience-summary` 分诊:

1. 用户 / agent 解决了一个卡壳问题后,调 `experience-summary`
2. experience-summary Q9 判定:
   - 跨 agent 通用 + 卡壳-解法模式 → 路由到 unblock-recipes(本 skill)
   - per-user 偏好 → 路由到 auto memory
   - 其他出口同 experience-summary 原 11 个分类
3. 若出口是 unblock-recipes,experience-summary 输出写作模板,然后**由用户 / agent 把 recipe 文件落盘到 `recipes/<slug>.md`** + 同步更新 INDEX.md
4. commit 到中心仓库(skill-doctor pre-commit hook 会自动 lint)

### MVP 阶段(前 30 天,2026-05-25 起):无写入门槛

不强制"≥2 次复现"、不强制"主动验证过 N 个 agent",**碰到就记**。
唯一硬要求: Recipe 条目结构 4 段完整 + INDEX.md 同步。

### 后期收敛机制(占位,MVP 不实现)

- **90 天 audit**: `hit_count == 1` 且 `last_hit > 90 天前` → 归档到 `_archive/<slug>.md`
- **自动合并相似 recipe**: 根据 `symptoms` 重叠度 ≥ 60% 提示合并
- **复现门槛**: 升级到"只入 ≥ 2 次踩过的坑",MVP 后期再开

## Output Contract

### Lookup 输出

agent 召回后向调用方(用户或 orchestrator)给:

```
【lookup 结果】
- 匹配 recipe: <N> 条
- 命中 recipe slug: [<slug1>, <slug2>, ...]
- 应用解法: <一句话总结>
- 状态: 解决 / 部分解决 / 未命中
【调用计数】
- <slug1> hit_count: <旧 N> → <新 N+1>(若完全解决)
- <slug1> hit_count: <旧 N> → <旧 N>(若部分解决/未命中,**不 +1**)
【召回链路日志】
- 是否查 memory: 跳过(unblock-recipes 已命中)/ 已查(unblock-recipes 未命中后兜底)
```

未命中时:
```
【lookup 结果】
- 匹配 recipe: 0 条
- 建议: 按常规调试流程继续;解决后考虑通过 experience-summary 入册新 recipe
【召回链路日志】
- 是否查 memory: 已查(unblock-recipes 未命中后兜底);memory 结果: <命中/未命中>
```

### Writing 输出(由 experience-summary 调用本 skill 模板时)

写入模板见 [Recipe 条目结构](#recipe-条目结构强约束) + INDEX 同步段。

## Red Flags — STOP

命中任一**停止并修正**:

- agent 卡壳但**没读 INDEX.md** 就直接 grep recipes/(违反轻载入约束)
- 全量 `cat recipes/*.md`(token 爆炸)
- 不经 experience-summary 直接写 `recipes/<slug>.md`(绕过分诊,垃圾入册)
- 新 recipe 缺 symptoms / tags / 出处任一字段(catalog 垃圾化前兆)
- 新 recipe symptoms 只有"卡壳" / "走不通"这种泛词(无法匹配真实信号)
- 应用 recipe 解法后**不更新** `hit_count` + `last_hit`(后期 audit 没数据)
- 应用 recipe 解法**无效**却仍 +1(污染统计)
- 应用 recipe 解法**部分有效**却按"完全解决"+1(应按"部分解决"记,**不 +1**,可考虑在 recipe 加 `partial_hit_count` 字段后期跟踪)
- 把**项目特有问题**写入本 skill(应进项目 CLAUDE.md;本 skill 只收跨项目通用问题)
- 把**用户个人偏好**写入本 skill(应进 memory)

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "agent 卡了就直接 cat recipes/*,反正不多" | 早晚会多;一开始就守轻载入纪律,后期才不会被迫重构 |
| "这条 recipe 我自己就解决了,直接写盘吧" | 跳过 experience-summary = 跳过分诊 = 可能本该进 memory / CLAUDE.md |
| "symptoms 写'各种报错'吧,反正以后再细化" | 召回时一个都匹配不上 = 等于没写 |
| "解法没真验证,但我觉得对,先入册" | 错误 recipe 比没 recipe 更糟 — agent 按错指引浪费时间 |
| "项目特有的 bug 也很烦,塞这里方便查" | 本 skill 是**跨项目通用**;项目特有的坑写项目 CLAUDE.md |
| "MVP 阶段没门槛,什么都能记" | "无写入门槛"指**不强制 ≥ 2 次复现**,不指"质量也可以放水" |

## Relationship to Other Skills

- **上游(写入路径)**: `experience-summary` 是**唯一**写入入口(分诊 Q9 路由)
- **上游(召回路径)**:
  - 用户显式触发("查下错题本")
  - agent 自身检测卡壳关键词
  - orchestrator(flow-dev-task / flow-codex-goal)在 loop 信号时主动 lookup
- **下游**: 无 — 本 skill 是终点(召回结束后用户/agent 继续原任务)
- **不替代**:
  - `auto memory`(per-agent / per-user 偏好,优先级低于本 skill)
  - `_shared/constitution.md`(跨 skill 价值观,跟"卡壳-解法"无关)
  - 项目 `CLAUDE.md`(项目级规则,跟跨项目通用无关)
  - `skill-doctor` 规则(可机器 lint 的,跟"经验型解法"无关)

## Self-Reference(自指)

本 skill 自己也遵循它的写入约束:
- 本 skill 不是 director-*(不审单一专业,而是 catalog 性质)
- 不是 flow-*(无 orchestration,单次 lookup 即出结论)
- 不是 _shared/ metaspec(有完整 SKILL.md 流程)
- 是独立 catalog skill,同 clean-commit / skill-doctor 同类(无前缀)

11 层架构图(完整定义见 `experience-summary` skill 的 layer-map 文档)在 unblock-recipes 引入后变为 12 层(`L9a` 跨 agent 卡壳-解法案例库 → 本 skill;`L9b` 个人偏好 → auto memory)。

## Reuse

测试用例保留在 `tests/cases.md`,后续修订以这些用例为回归基线。
