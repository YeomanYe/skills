---
name: mem
description: >
  统一记忆入口 — 工程级共享记忆,融合 env(环境事实) + unblock(卡壳→解法) + staging(草稿暂存)。
  翻过往经验来这里;不知道记哪儿的先扔这里。
  触发: 翻记忆 / 查过往经验 / 之前踩过吗 / mem 一下 / lookup memory /
  stuck / blocked / loop / 反复 / 走不通 / hit a wall / 环境变量 /
  API key / token / missing credential / 本机装了什么 / 配置在哪 / 密钥引用 /
  记一下 / 暂存 / log this somewhere。
  症状触发(强制): 死路签名(302 / redirect / utm_source / accounts.*/login /
  401 / 403 / Connection reset / ECONNREFUSED) → 选工具前先 lookup mem。
  上游: experience-summary 分诊 / flow-dev-task / flow-codex-goal 检测 loop 时主动 lookup。
  Do NOT for: 个人偏好(→ auto memory)、跨 skill 价值观(→ constitution)、
  项目规则(→ CLAUDE.md)、可 lint 硬规则(→ skill-doctor)、一次性现象、装/卸软件(→ director-ops)。
  写入优先经 experience-summary;agent 自助写入只允许 staging。
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)
> 本 skill 融合并替代 [[unblock-recipes]](已 deprecated)和原 env-registry 设计意图

# mem —— 统一记忆入口

## Overview

**核心心智:工程级共享记忆**。

- `auto memory` 是 **per-user / per-agent** 的个人偏好(用户身份 / 风格 / 项目状态)
- `mem` 是 **跨 agent / 跨用户** 的工程经验(环境事实 + 卡壳解法 + 草稿)
- 两者并存,职责正交——`mem` 不替代 `auto memory`,也不被它替代

### 三类分类

| 分类 | 装什么 | 例子 | 详细规则 |
|---|---|---|---|
| **env** | 本机/项目环境事实 + 变量登记 | "OPENAI_API_KEY 怎么读" / "fly 装在哪" / "QQ 授权码存哪" | `references/categories/env.md` |
| **unblock** | 跨 agent 工程经验 / 卡壳→解法 | "302 redirect 到 utm_source 怎么办" / "Workers 不支持 imapflow" | `references/categories/unblock.md` |
| **staging** | 不知道归哪类的暂存草稿 | "我先记下来,某 API rate limit 60/min" | `references/categories/staging.md` |

### 召回优先级

agent 卡壳 / 需查时按序:
1. **mem**(本 skill,工程级共享)
2. `auto memory`(per-agent 个人偏好,可能含同类坑修正)
3. 其他(`_shared/constitution.md` / 项目 `CLAUDE.md` / 文档)

## When to Use

### 触发场景(召回侧)

| 场景 | 触发信号 |
|---|---|
| 自动召回(关键词) | `stuck` / `blocked` / `loop` / `反复` / `卡` / `走不通` / `hit a wall` / `can't figure out` / `试了 N 次都不行` / `死循环` / `同样错 N 次` / `之前踩过吗` |
| **症状信号(强制)** | **工具输出出现"死路签名":重定向到营销/登录页(`302` / `redirect` / `utm_source` / `accounts.*/login`)、登录墙、鉴权失败(`401` / `403` / `unauthorized`)、连接重置(`Connection reset` / `ECONNREFUSED`)、`WebFetch` 拿不到正文 → 自动进 mem unblock 分类 lookup,不要自行合理化继续原路** |
| **进外部/鉴权系统** | **任务触及外部 SaaS / 鉴权后台 / 陌生域名(如 `*.larksuite.com` / `project.*` / 内网 GitLab)时,在选工具或动手之前先 lookup** |
| 自动召回(env) | `missing API key` / `xxx is required` / `没找到 X_KEY` / `缺少凭证` / "怎么读 .env" |
| 显式查阅 | "查下 mem" / "翻一下记忆" / "这个之前踩过吗" / "lookup mem" |
| 主动预防 | agent 开新任务前(如重大重构 / 跨模块改动 / 进陌生 SaaS)主动 lookup 相关 tag |

### 触发硬规则(symptom-triggered, 不是 branch-triggered)

继承自原 unblock-recipes,**适用于 unblock 分类**:

1. **症状触发,不是分支触发**:用"动作失败 / 输出异常 / 进外部鉴权系统"这类**罕见高信号症状**拉起 lookup,**不要**每个 `if` / 分支 / 决策点都查(那是高频低信噪比,会把机制刷成噪音被略过)。
2. **选工具之前查,不是撞墙之后查**:任务一旦触及外部/鉴权系统或陌生域名,**在挑 WebFetch / 浏览器 / CLI 之前**先读 `INDEX.md` 做一次 lookup。错的顺序是"先选浏览器 → 撞重定向 → 才想起查";对的顺序是"先查 → INDEX 告诉你该用哪个工具"。
3. **异常≠正常前置**:看到重定向/登录墙/鉴权失败时,默认它是 blocked 信号要查 mem,**不要**自行合理化成"哦没登录而已,登录就行"然后继续原路——那正是漏召回的典型死法。

### 写入场景(写入侧)

写入路径**优先入口是 experience-summary 分诊**(分诊后判定走 mem 的具体分类)。

agent **自助写入**只允许写入 `staging/`(不知道归哪类时);写 env / unblock 必须先经 experience-summary 或显式由用户/orchestrator 指定分类。

详见下方 [Writing 段](#writing写入流程)。

## When NOT to Use

- 写入**个人偏好** / 用户身份 / 项目状态 → `auto memory`(per-agent / per-user)
- 写入**跨 skill 通用价值观 / 安全边界** → `_shared/constitution.md`
- 写入**项目级规则** → 项目 `CLAUDE.md` / `AGENTS.md`
- 写入**skill 自身可 lint 的硬规则** → `skill-doctor` 新规则
- **一次性现象**(下次大概率不会再出现)→ 不沉淀
- **装 / 卸软件** → `director-ops`(它自己维护 `~/Documents/knowledge/<tool>-install.md` 知识库)
- agent 在做新任务而非卡壳 → 用 `flow-dev-task` / `flow-codex-goal`,不要预防性翻 mem 浪费 token

## 目录结构

```
mem/
├── SKILL.md                       # 本文件 — 路由/触发/读写流程(薄)
├── INDEX.md                       # 跨分类 symptom→entry 反向索引(轻,优先载入)
├── references/
│   ├── routes.md                  # 详细路由表 + 反例(写入分诊用)
│   ├── access-log.md              # access-log.jsonl 格式 spec
│   ├── promotion.md               # 升格机制 + 阈值
│   ├── failure-modes.md           # 红线 + rationalizations
│   └── categories/
│       ├── env.md                 # env 分类: 写入规则 + 变量清单格式 + 读法
│       ├── unblock.md             # unblock 分类: recipe schema + symptom 硬规则
│       └── staging.md             # staging 分类: 最小字段 + TTL + 升格阈值
├── data/
│   ├── env/                       # 变量清单 + 项目/本机环境事实
│   │   ├── README.md              # 变量值存放规则
│   │   └── <slug>.md              # 一个 host/project 一个文件
│   ├── unblock/                   # 卡壳→解法 recipes
│   │   └── <slug>.md              # 一条 recipe 一个文件
│   ├── staging/                   # 草稿区
│   │   └── <slug>.md              # 一条草稿一个文件
│   └── access-log.jsonl           # 每次 lookup 写一行 JSON
└── tests/cases.md                 # 测试用例
```

**data/ 关键约束**:agent 召回时**禁止全量载入**(防 token 爆炸)。
载入流程:**先读 INDEX.md** → 关键词匹配 ≤ 3 条 → 只载入命中的 entry 正文。

## Workflow

### Lookup(读取流程)

agent / orchestrator 检测到召回信号后:

1. **读 SKILL.md(本文件)主体** → 根据 query 关键词路由到分类(env / unblock / staging / 全扫)
2. **读 INDEX.md**(必须先读,~2-5KB)
3. **关键词匹配**(字符串/语义包含,不是 `grep -E`):
   - 自动召回 → 从 error message / agent 行为提取关键词,在 INDEX "按 symptom 关键词反查"表逐行匹配
   - 显式召回 → 用用户给的关键词匹配
   - **禁止 `ls data/unblock/` 后全量 `cat`**(违反轻载入约束)
4. **筛选 ≤ 3 候选**:命中数排序,多 tag 时优先匹配 tag
5. **载入候选 entry**:`Read data/<cat>/<slug>.md`,逐条读"症状信号"段判定是否真命中
6. **应用 + 更新计数**:
   - 真命中 → 按"正确做法"执行 + `last_hit=today` + `hit_count+1`
     - ⚠️ 这笔 bump 必须改在中心源仓库 `~/Documents/projects/skills/mem/`(`sync-skills` 推 GitHub 的单一事实源)并 commit。**禁止**改下游副本(`~/.config/skillshare/skills/...` / `~/.claude/skills/...`),改了会被下次 sync 覆盖丢失。
   - 看似命中实际不是 → 不更新计数,继续 lookup 下一候选
   - 全 3 条都不命中 → 退出 lookup,回默认调试流程;若解决后是新坑/新事实 → 走 experience-summary 路由考虑入册
7. **append access-log**(无论命中与否,**仅在中心仓库**):
   - `data/access-log.jsonl` 追加一行 JSON,格式见 `references/access-log.md`

### Writing(写入流程)

**优先入口:experience-summary 分诊**。

experience-summary 判定"跨会话长期经验 + 跨 agent 通用"后,按记忆类型路由:
- 工程级环境事实(本机装啥 / 变量在哪) → 调 mem 写入 env 分类
- 工程级卡壳→解法 → 调 mem 写入 unblock 分类
- 类别不明确 → 调 mem 写入 staging 分类
- 个人偏好 → auto memory(不进 mem)

**agent 自助写入**(没经 experience-summary):

只允许写 `staging/`。流程:
1. 读 `references/routes.md` 自检——确认不该走 env / unblock / auto memory / constitution / 项目 CLAUDE.md
2. 真不确定 → 在 `data/staging/<slug>.md` 写最小字段(见 `references/categories/staging.md`)
3. 更新 INDEX.md(staging 段)
4. append access-log(`op: "write"`)

**直接写 env / unblock**(skip experience-summary):
- 仅允许在以下情况:用户明确指定分类 / orchestrator 持有上下文证据 / mem 自身的迁移操作
- 写入时必须按 `references/categories/<cat>.md` 的模板和字段约束
- 更新 INDEX.md(对应分类段)
- append access-log

### Promote(升格)

详见 `references/promotion.md`。三种升格触发,全部**只给建议不自动执行**:

| 触发 | 动作 |
|---|---|
| staging 单条 `hit_count ≥ 3` + 内容定型 | mem 报告时建议手动迁到 env / unblock |
| staging 某 tag 累积 `≥ 8` 条 | 报告"建议跑 flow-skill-dev 孵化成独立 skill 或 mem 新分类" |
| staging 单条 90 天没 access | 报告"X 条草稿超期未用,确认归档/删除"(不自动删) |

## Output Contract

mem 不是 orchestrator,**每次 lookup / write 返回的是命中的 entry 内容 + 元数据**:

```json
{
  "operation": "lookup | write | promote-report",
  "category": "env | unblock | staging | all",
  "query_keywords": ["..."],
  "index_hits": ["<slug1>", "<slug2>"],
  "loaded_entries": ["data/<cat>/<slug>.md"],
  "applied_recipe": "<slug or null>",
  "hit_count_bumped": true | false,
  "promotion_suggestions": [
    { "type": "staging-to-unblock", "slug": "...", "reason": "..." }
  ],
  "next_step": "<summary or null>"
}
```

## Red Flags — STOP

任一命中立刻停下,不要合理化继续:

1. **召回时 `ls data/<cat>/` 后全量 `cat`** — 直接炸 token,违反"先读 INDEX"硬规则
2. **看到死路签名继续原路** — 302 redirect / 401 / 403 / ECONNREFUSED 后自我合理化"登录就行"继续走,跳过 lookup
3. **改下游副本** — 在 `~/.claude/skills/mem/` 或 `~/.config/skillshare/skills/_*/mem/` 直接编辑(改了等于白改,下次 sync 覆盖)
4. **agent 自助写 env / unblock** — 没经 experience-summary 也没用户明确指定分类
5. **跳过 access-log** — 写入或命中不 append,升格阈值统计失效
6. **把个人偏好写进 mem** — "我喜欢用 pnpm" 这种应该去 auto memory,不进 mem
7. **把项目级规则写进 mem** — "本项目用 mobx" 这种应该去项目 CLAUDE.md,不进 mem

详细 rationalizations 拆穿见 `references/failure-modes.md`。

## Relationship to Other Skills

### 上游(调用 mem)
- `experience-summary` — 写入主入口(分诊后调 mem 写对应分类)
- `flow-dev-task` / `flow-codex-goal` — orchestrator 检测 loop / 死路签名时 lookup
- `director-architect` 等 — 主动预防性 lookup(进陌生 SaaS 前)
- 用户直接触发

### 平行(并存,职责正交)
- `auto memory` — per-user 个人偏好,**不被 mem 替代**
- `_shared/constitution.md` — 跨 skill 价值观 / 安全
- `director-ops` 维护的 `~/Documents/knowledge/<tool>-install.md` — 软件安装知识库(不进 mem)

### 已被本 skill 替代(deprecated)
- `unblock-recipes` — 内容已迁入 `mem/data/unblock/`,触发改走 mem
- 原 `env-registry` 设计意图 — 融入 `mem/references/categories/env.md`(未发布过,仅在 experiment 分支存在)

### 不调用 / 不越界
- 不替 director-ops 装软件
- 不替 auto memory 记个人偏好
- 不替 skill-doctor lint skill 文件

## Reuse

- 测试用例:`tests/cases.md`
- 路由表 + 反例:`references/routes.md`
- 升格机制:`references/promotion.md`
- access-log 格式:`references/access-log.md`
- 失败模式:`references/failure-modes.md`
- 三个分类的领域规则:`references/categories/{env,unblock,staging}.md`
