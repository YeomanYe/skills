# unblock-recipes INDEX

> Symptom keyword → recipe slug 反向索引。
> agent 召回流程: 读本文件 → 匹配 symptom 关键词 → 找到 ≤3 条候选 recipe → 只载入这些 recipe 的正文。
> **禁止 `ls recipes/` 后全量 `cat`**,会炸 token。

**当前状态**: MVP 启动期。首条 recipe 通过 `experience-summary` 分诊路由后由用户/agent 真实落盘。

---

## 按 tag 分类

每条 recipe 进来时,同时追加到这里对应分类 + 下方"按 symptom 关键词反查"表。

### codex
- (空)

### claude-code
- (空)

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

### file-system / path
- (空)

### skill-development
- (空)

### meegle
- lark-project-url-needs-meegle-cli

---

## 按 symptom 关键词反查(精确召回)

| symptom 关键词 | recipe slug | tag |
|---|---|---|
| 302 Found 重定向到 meegle.com 营销页 | lark-project-url-needs-meegle-cli | meegle |
| ecommerce-strapi 等 Lark space 链接抓出营销首页 utm_source=in_meegle | lark-project-url-needs-meegle-cli | meegle |
| Lark Project / Meegle workObjectView / workitem URL 鉴权失败 | lark-project-url-needs-meegle-cli | meegle |
| project.larksuite.com 链接 WebFetch 拿不到内容 | lark-project-url-needs-meegle-cli | meegle |

---

## 维护规则

- **新 recipe 入册**: 同时在「按 tag 分类」对应分类下追加 1 行(`- <slug>` 格式)+ 在「按 symptom 关键词反查」表追加 1-N 行(每个 symptom 一行,slug 重复多次正常)
- **归档 recipe**: 同步从 INDEX 删除两处(tag 分类 + symptom 反查)
- **新 tag 入册**: 在「按 tag 分类」段开新分类标题,然后入 recipe
- **不要修改本段维护规则文字** —— 改规则要走 `flow-skill-dev` 走完整 substantial-update 流程
