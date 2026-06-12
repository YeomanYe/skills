# mem 升格机制

mem 三种升格路径,**全部只给建议,不自动执行**——新分类 / 新 skill 的触发条件必须人/有判断的 agent 拍板,自动孵化容易产生触发不准的垃圾 skill。

---

## 路径 1:staging entry → env / unblock(单条升格)

### 触发

某 staging entry 满足:
- `hit_count ≥ 3`(从 access-log.jsonl 统计或 entry frontmatter 读)
- 内容定型(连续 3 次 hit 时 entry 没被改过)
- 类别明朗(可对应 env 或 unblock 之一)

### 动作

mem 在 lookup 报告或定期扫描时,**在 next_step 字段提建议**:

```
Suggestion:
  - staging/<slug> 已 hit 3 次,内容稳定。建议手动迁到 unblock 分类:
    1. 读 references/categories/unblock.md 模板补齐 schema
    2. mv data/staging/<slug>.md → data/unblock/<slug>.md
    3. INDEX.md staging 段删 + unblock 段加
    4. access-log append op=promote
```

**不自动执行**——staging 字段宽松,迁 unblock 需要补齐 symptoms / 常见错法 / 正确做法等强字段,要人审。

---

## 路径 2:staging/某 tag 累积 ≥ 8 条(分类升格)

### 触发

某 tag 在 staging 累积 ≥ 8 条 entry。

### 动作

mem 报告时建议:

```
Suggestion:
  - staging/<tag>/ 已累积 N 条相关 entry。建议:
    Option A (推荐): 在 mem 新增分类 (走 flow-skill-dev substantial-update)
      → references/categories/<tag>.md
      → data/<tag>/
      → routes.md 加分诊规则
    Option B: 孵化成独立 skill (走 flow-skill-dev new-skill)
      适合该 tag 有独立的触发条件 / 工作流 / 输出契约
```

**不自动孵化**——新分类 / 新 skill 的触发条件 / description / Red Flags 都要人定。

---

## 路径 3:TTL 淘汰(staging 超期)

### 触发

某 staging entry 满足:
- 距 `created_at` ≥ 90 天
- 距最后一次 access 也 ≥ 90 天(查 access-log.jsonl)
- `hit_count == 0` 或 hit 仅来自写入时

### 动作

mem 报告时建议:

```
Suggestion:
  - data/staging/<slug>.md 超期未用 (created N 天前,从未 hit),建议:
    - 归档: mv data/staging/<slug>.md data/staging/_archive/<slug>.md
    - 或删除: rm data/staging/<slug>.md
  - 等用户确认后再执行
```

**不自动删**——可能是用户埋的"以后查"型笔记,自动删会丢失。

---

## env / unblock 分类的升格

env / unblock 的 entry 是定型的,**通常不升格出 mem**。但若某 unblock entry 长期 hit ≥ 20 次,且解法有沉淀为通用规则的潜力:

mem 报告时可建议:

```
Suggestion:
  - unblock/<slug> 已 hit 20+ 次,可考虑升级为:
    - skill-doctor 规则 (若可 lint)
    - _shared/constitution.md 条款 (若属跨 skill 价值观)
    - 单独 unblock-* skill (若解法链路复杂)
```

仍不自动——升级路径由人定。

---

## 升格周期 / 触发时机

mem 不跑定时任务。升格建议在以下时机出现:

1. **每次 lookup 报告**:若本次 lookup 涉及的 entry 命中升格条件,在返回的 `promotion_suggestions` 字段列出
2. **用户显式触发**:"扫一下 mem staging 看有没有要升格的" / "promote mem entries"
3. **orchestrator(experience-summary)分诊后**:写入完成时顺便扫一下当前分类是否有升格信号

定期全量扫描(cron)不是 mem 的责任——用户可挂 `cc-connect cron` 跑周扫描,扫到的建议汇报给用户。

---

## 升格建议格式(强约束)

mem 出的升格建议**必须**:

- 明确指向具体 slug 或 tag
- 给出**手动执行步骤**(不是"你考虑一下要不要升格")
- 不重复建议同一升格 ≥ 3 次(若用户 3 次都没动作,默认放弃,不再吵)

不允许:
- ❌ "建议清理 staging" — 没指具体哪条
- ❌ "考虑升格 lark 相关" — 没给步骤
- ❌ 反复对同一 entry 出同样建议(用户已经看过 3 次了就别再 spam)
