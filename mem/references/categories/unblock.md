# unblock 分类:工程经验 / 卡壳→解法

unblock 分类装跨 agent / 跨用户复用的**踩坑案例 + 已验证解法**。**继承自原 unblock-recipes** 设计 + symptom-triggered 硬规则。

---

## 装什么 / 不装什么

### 装

- 跌过的坑(症状)+ 已验证的正确做法
- 强调**症状信号**(死路签名 / 错误片段 / 行为模式)而不是抽象描述
- 解法**具体**到命令 / 配置 / 代码片段

### 不装

- 个人偏好("我喜欢用 X")→ auto memory
- 项目级规则 → 项目 CLAUDE.md
- skill 自身能 lint 的硬规则 → skill-doctor
- 一次性现象(下次大概率不再出现)→ 不沉淀
- 抽象事实("Workers 是什么") → 不沉淀,查文档

---

## 触发硬规则(symptom-triggered,继承自 unblock-recipes 2026-05 harden)

1. **症状触发,不是分支触发**:用"动作失败 / 输出异常 / 进外部鉴权系统"这类**罕见高信号症状**拉起 lookup,**不要**每个 `if` / 分支 / 决策点都查(高频低信噪比 = 机制刷成噪音被略过)。
2. **选工具之前查,不是撞墙之后查**:任务一旦触及外部/鉴权系统或陌生域名,**在挑 WebFetch / 浏览器 / CLI 之前**先读 INDEX.md。错的顺序:"先选浏览器 → 撞重定向 → 才想起查";对的顺序:"先查 → INDEX 告诉你该用哪个工具"。
3. **异常≠正常前置**:看到重定向 / 登录墙 / 鉴权失败时,默认它是 blocked 信号要查 mem,**不要**自我合理化成"哦没登录而已,登录就行"继续原路——那是漏召回的典型死法。

---

## 死路签名清单(强制触发 lookup)

工具输出含以下任一,**必须**进 mem unblock lookup,不要自行合理化:

- HTTP redirect: `302 Found` / `301 Moved` / `Location:` header 指向陌生 host
- 登录墙特征: `accounts.*/login` / `oauth` / `sign_in` / `auth/login`
- 营销重定向: URL 含 `utm_source` / `utm_medium`(尤其 host 改变)
- 鉴权失败: `401 Unauthorized` / `403 Forbidden` / `WWW-Authenticate:`
- 连接失败: `ECONNREFUSED` / `Connection reset` / `EHOSTUNREACH`
- WebFetch / curl 拿不到正文 / 拿到 HTML 但内容空

---

## entry 文件 schema(强约束)

每条 entry 放 `data/unblock/<slug>.md`,frontmatter + 4 段正文,**总长 ≤ 1KB**(短到 agent 能一次性读完判定是否命中):

```md
---
slug: <kebab-case-3-30-chars>          # 跟文件名一致
symptoms:                                # INDEX 索引用关键词(3-8 个)
  - "<具体症状词1>"
  - "<具体症状词2>"
first_seen: 2026-05-25                  # 首次记录日期
last_hit: 2026-05-25                    # 最近一次被召回 + 验证有效的日期
hit_count: 1                            # 累计被召回 + 验证有效的次数
tags: [<tag1>]                          # 大类标签(从 INDEX 维护的词典选)
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
- 首次发现: <date> / 在 <什么场景 / 哪个项目>
- 复现: <累计 hit_count 次>
```

### 字段硬约束

- `slug`: kebab-case, 3-30 字符, 全仓不能重复
- `symptoms`: 至少 3 个**具体**关键词(不能只填"卡壳"这种泛词;要是 agent 真会读到的错误信息片段或具体行为描述)
- `tags`: 至少 1 个,从 INDEX.md 维护的 tag 词典选;新 tag 入册前先 review
- 正文 4 段(症状 / 常见错法 / 正确做法 / 出处)不可省

---

## 写入流程

agent **不能**自助写 unblock。必须经以下入口之一:

1. **exp-sum 分诊**:首次踩坑解决后,走 exp-sum,它判定"跨 agent 跨会话工程经验"路由到 mem unblock,落盘
2. **用户/orchestrator 显式指定**:用户说"把这条记 mem unblock",orchestrator(flow-dev-task)在 retro 阶段记录

不知道是不是 unblock → 默认写 staging,等升格审。

---

## 召回流程(精确召回)

详见 SKILL.md 主体的 Lookup 段。要点:

1. 读 `INDEX.md` 反向索引
2. 字符串 / 语义关键词匹配,**不**用 `grep -E` 扫 data/unblock/
3. 取 top 3 候选
4. 只载入候选 entry 正文(`Read data/unblock/<slug>.md`)
5. 真命中 → 应用 + bump `hit_count` + 更新 `last_hit` + append access-log
6. 不命中 → 退出,不更新计数

**禁止**:
- ❌ `ls data/unblock/ && cat *` — 炸 token
- ❌ 不读 INDEX 直接 cat 单个 entry(slug 怎么知道?除非用户给)

---

## 跟原 unblock-recipes 的关系

原 unblock-recipes skill 已被本 skill (mem) 替代,标记 deprecated。原内容已迁入:

- 触发硬规则 → 本文件 + SKILL.md "触发硬规则"段
- recipes/ → `data/unblock/`
- INDEX.md → `mem/INDEX.md` unblock 分类段
- references/constitution.md → 共享 _shared/constitution.md(已存在,不复制)
- recipe schema → 本文件 "entry 文件 schema" 段

unblock-recipes/SKILL.md 保留作过渡期重定向(banner 指向 mem),并附 `MIGRATED.md` 列迁移清单。
