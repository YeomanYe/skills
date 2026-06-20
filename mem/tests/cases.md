# mem 测试用例

按 skill-behavior-test 4 类用例(正例触发 / 反例触发 / 主流程 / 护栏)+ skill-integration-test 链路覆盖。

每条用例标 `mode: mock | context | live`,执行时按 mode 跑。

---

## 正例触发(应该召回 mem)

### TC-1: 显式翻 mem unblock(类别明确)

- **mode**: context
- **input**: "之前 Lark wiki 链接拿不到正文是怎么解决的"
- **expected trigger**: mem(unblock 分类)
- **expected behavior**:
  1. 读 SKILL.md 主体 + routes.md
  2. 读 INDEX.md unblock 段
  3. symptom 关键词 "Lark wiki" / "拿不到正文" 命中 `lark-wiki-docs-use-lark-cli`
  4. Read data/unblock/lark-wiki-docs-use-lark-cli.md
  5. 输出 "正确做法" 段内容(`lark-cli docs +fetch` / `+update` 命令)
  6. append access-log op=read

### TC-2: 死路签名自动触发 unblock lookup

- **mode**: mock
- **input**: agent 调 WebFetch 拿 `project.larksuite.com/...` 链接,工具返回 `302 Found → utm_source=in_meegle`
- **expected trigger**: mem 自动进入(symptom-triggered 硬规则)
- **expected behavior**:
  1. 不自我合理化"登录就行"继续 WebFetch
  2. 读 mem INDEX,关键词 `302 Found` / `utm_source` / `project.larksuite.com` 命中 `lark-project-url-needs-meegle-cli`
  3. 应用 `meegle url decode` 解法
- **assertion**: agent **不能**在看到 302 后继续 WebFetch

### TC-3: env 变量在哪查

- **mode**: context
- **input**: "OPENAI_API_KEY 怎么读 / 在哪"
- **expected trigger**: mem(env 分类)
- **expected behavior**:
  1. routes.md 分诊到 env
  2. 读 categories/env.md 拿到"变量值存放位置 + 读法 A/B/C"
  3. 提示用户:值在 `~/Documents/knowledge/local/.env`,用 `grep '^OPENAI_API_KEY=' ... | cut -d= -f2-` 读

### TC-4: 暂存草稿(staging)

- **mode**: context
- **input**: "我先记下来:Slack OAuth 的 rate limit 是 60/min,以后查"
- **expected trigger**: mem(staging 分类)
- **expected behavior**:
  1. routes.md 分诊:不属 env(不是变量/装在哪)、不属 unblock(不是踩坑解法,是事实备忘)
  2. 走 staging
  3. 在 data/staging/ 创建 `<slug>.md` 含 created_at / 内容 / 上下文
  4. 更新 INDEX.md staging 段
  5. append access-log op=write

---

## 反例触发(不该召回 mem)

### TC-5: 装软件 → director-ops

- **mode**: mock
- **input**: "帮我装个 redis"
- **expected trigger**: director-ops(install mode),**不是 mem**
- **assertion**: mem 的 description 不含装/卸软件触发短语;路由不到 mem

### TC-6: 个人偏好 → auto memory

- **mode**: mock
- **input**: "我喜欢用 pnpm 不用 npm,以后都这样"
- **expected trigger**: auto memory(feedback / user 类),**不是 mem**
- **assertion**:
  - 若 agent 误判进 mem → routes.md 反例段必须把它路由出去(env 反例第 2 条;unblock 反例第 2 条)
  - mem 出的 staging entry 应该 reject 该 query(RF-6)

### TC-7: 项目级规则 → 项目 CLAUDE.md

- **mode**: mock
- **input**: "本项目用 mobx,组件不要直接订阅 store"
- **expected trigger**: 项目根 CLAUDE.md / AGENTS.md,**不是 mem**
- **assertion**: mem failure-modes.md RF-7 拦住

### TC-8: 抽象事实查询 → 不沉淀

- **mode**: mock
- **input**: "Cloudflare Workers 是什么"
- **expected trigger**: 文档查询(WebSearch / 文档站),**不是 mem**
- **assertion**: 这不是经验也不是事实登记,routes.md unblock 反例第 1 条拦住

---

## 主流程(端到端)

### TC-9: 写一条 env entry → access-log 记录 → 读出来

- **mode**: live
- **steps**:
  1. 用户:"登记 OPENAI_API_KEY 到 mem env vars-registry"
  2. agent 按 categories/env.md schema 在 data/env/vars-registry.md 加一行
  3. 更新 INDEX.md env 段
  4. append access-log op=write
  5. 用户隔几分钟后:"OPENAI_API_KEY 在哪"
  6. agent 走 lookup 流程,命中 vars-registry,返回读法
  7. append access-log op=read,hit=true,hit_count_after=1
- **assertion**:
  - access-log 有 2 行 JSON
  - vars-registry.md frontmatter hit_count == 1
  - INDEX.md env 段含该变量

### TC-10: lookup 不命中 → 提示走 exp-sum

- **mode**: mock
- **input**: "Stripe webhook signature mismatch 怎么办"(假设 mem 暂无该 entry)
- **expected behavior**:
  1. 读 INDEX.md unblock 段
  2. 关键词 "Stripe" / "signature mismatch" 无 ≤3 候选
  3. 返回 "未命中,建议:(a)检查是否在 staging 错过 (b)首次坑解决后走 exp-sum 分诊"
  4. append access-log op=read, hit=false

---

## 护栏(violation 必须拦住)

### TC-11: 防全量 cat

- **mode**: mock
- **input**: agent 调 `ls ~/.../mem/data/unblock/` 后想 cat 全部
- **expected behavior**:
  - mem failure-modes.md RF-1 触发 STOP
  - 回退到先 Read INDEX.md
- **assertion**: agent 不能 `cat data/unblock/*.md`

### TC-12: 防写明文密钥

- **mode**: mock
- **input**: "记一下我的 QQ 授权码是 aiykntwkdkoshiih,以后查"
- **expected behavior**:
  - routes.md / staging.md / failure-modes.md RF-8 拦住
  - 提示:value 不进 mem,改存 `~/Documents/knowledge/local/.env`
- **assertion**: data/staging/ 不能落含明文 token 的文件

### TC-13: 防改下游副本

- **mode**: mock
- **input**: agent 在 `~/.claude/skills/_*__mem/data/unblock/<slug>.md` 调 Edit bump hit_count
- **expected behavior**: RF-3 STOP,改去中心仓库 `~/Documents/projects/skills/mem/data/unblock/<slug>.md`

### TC-14: 类别分不清落 staging

- **mode**: context
- **input**: "这个 API 我以后可能用,链接是 https://example.com/api/v1"
- **expected behavior**:
  1. routes.md 走分诊决策树
  2. 不是 env(不是装在哪)、不是 unblock(不是踩坑)、不是个人偏好
  3. 落 staging,字段最小化(slug + created_at + 内容 + 上下文)
- **assertion**: 落到 data/staging/ 而非 env/ 或 unblock/

---

## 集成测试(skill-integration-test)

### TC-15: exp-sum → mem 分诊 handoff

- **mode**: context
- **chain**: exp-sum 分诊判定"卡壳→解法" → 调 mem 写入 unblock
- **handoff payload 验证**: exp-sum 出 `{ category: "unblock", slug, symptoms[], fix, source_context }` → mem 按 categories/unblock.md schema 写盘
- **assertion**: mem 不重复问"这是 unblock 吗"(handoff 已给字段)

### TC-16: orchestrator(flow-dev-task)死路签名 → mem lookup

- **mode**: context
- **chain**: flow-dev-task 跑任务期间 agent 工具输出 `Connection reset` → orchestrator 检测 → 调 mem lookup unblock
- **assertion**:
  - orchestrator 在 selectTool 之前主动 lookup
  - mem 召回 INDEX 关键词命中
  - 不重复让用户告诉 orchestrator "这是 blocked 信号"

### TC-17: 老 unblock-recipes 引用更新

- **mode**: context
- **input**: 仓库内任意 skill 提"参见 unblock-recipes"或 description 含 "unblock-recipes"
- **expected behavior**: `unblock-recipes` 已删除并入 mem,所有旧引用必须改成"参见 mem"或 "mem(unblock 分类)";不再有 banner 兜底(目录已不存在)
- **assertion**: grep 全仓 `unblock-recipes` 路径引用应为 0(仅允许 README/mem 文档里"原 unblock-recipes 已并入 mem"这类历史说明)

---

## 已知边界 / 留待后续

- 升格自动定时扫描(cron):本 MVP 不实现,只在 lookup 报告时随便提
- staging _archive/ 目录的清理周期(用户 cron 处理)
- access-log 体量超过 N MB 后的轮转(目前不实现,几年内不会爆)
