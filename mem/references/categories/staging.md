# staging 分类:草稿暂存

staging 是 mem 的**兜底层**:分不清归 env / unblock 的内容、暂时不确定要不要长期保留的笔记、等下次遇到再看的零散信息。

带 TTL=90 天,无 access 自动建议归档。

---

## 装什么 / 不装什么

### 装

- 类别不明,但你认为以后**可能**会用上的事实 / 经验 / 链接
- 字段最小化(slug + 时间 + 内容 + 上下文)
- 任何"我先记下来以后再说"的内容

### 不装

- 已经明确分类 → 走 env / unblock,**不要偷懒丢 staging**(staging 是兜底,不是默认)
- 含明文密钥 / token / 密码 → 只存 `~/Documents/knowledge/local/.env`,staging 也不行(进 git 就泄露)
- 个人偏好 / 项目规则 → 走 auto memory / 项目 CLAUDE.md

---

## entry 文件 schema(宽松字段)

每条 staging entry 放 `data/staging/<slug>.md`:

```md
---
slug: <kebab-case>
created_at: 2026-06-12T15:00:00Z
last_access: 2026-06-12T15:00:00Z
hit_count: 0
tag: <可选,自由 tag>
suggested_promote_to: env | unblock | unknown    # 写入时的初步直觉,辅助升格判断
---

## <slug> — <一句话主旨>

### 内容
<想记的事 / 链接 / 片段>

### 上下文
<为什么记的 / 在干什么时遇到的>

### 后续动作(可选)
- 下次遇到 X 时翻一下
- 或:90 天没用就丢
```

### 字段硬约束

- `slug`: kebab-case, 3-50 字符(staging 允许稍长,因为草稿可能比较 verbose)
- `created_at` + `last_access`: ISO 8601 UTC,**必填**(TTL / 升格判断的依据)
- `hit_count`: 整数,初始 0
- `tag`: 可选;若稳定 ≥ 8 条同 tag → 触发"路径 2 分类升格"

正文 3 段都允许缺(但**至少**有"内容"段)。

---

## 写入流程

agent 自助写入只允许进 staging。流程:

1. 读 `references/routes.md` 自检——确认不该走 env / unblock / auto memory / constitution / 项目 CLAUDE.md
2. 真不确定 → 写 `data/staging/<slug>.md`,按本文件 schema 填字段
3. 更新 `INDEX.md` staging 段
4. append `data/access-log.jsonl` op=write

**禁止**:
- ❌ 含明文密钥
- ❌ 个人偏好(应去 auto memory)
- ❌ "懒得分诊就丢 staging"(staging 是兜底,不是 fallback)

---

## TTL 淘汰

- 距 `created_at` ≥ 90 天 且距 `last_access` ≥ 90 天 且 `hit_count == 0`
  → mem 报告建议归档 / 删除(**不自动删**)
- 用户确认后:`mv data/staging/<slug>.md data/staging/_archive/<slug>.md` 或直接删

详见 `references/promotion.md` 路径 3。

---

## 升格

详见 `references/promotion.md`:

- 单条 `hit_count ≥ 3` + 内容定型 → 升格到 env / unblock
- 某 tag 累积 ≥ 8 条 → 升格成 mem 新分类或独立 skill

升格**只给建议**,不自动执行。
