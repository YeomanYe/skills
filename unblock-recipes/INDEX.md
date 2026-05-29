# unblock-recipes INDEX

> Symptom keyword → recipe slug 反向索引。
> agent 召回流程: 读本文件 → 匹配 symptom 关键词 → 找到 ≤3 条候选 recipe → 只载入这些 recipe 的正文。
> **禁止 `ls recipes/` 后全量 `cat`**,会炸 token。

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

### skillshare
- skillshare-multi-skill-repo-minimal-install
- skillshare-external-repo-wrong-kind

### meegle
- lark-project-url-needs-meegle-cli

### lark
- lark-wiki-docs-use-lark-cli

---

## 按 symptom 关键词反查(精确召回)

| symptom 关键词 | recipe slug | tag |
|---|---|---|
| 302 Found 重定向到 meegle.com 营销页 | lark-project-url-needs-meegle-cli | meegle |
| ecommerce-strapi 等 Lark space 链接抓出营销首页 utm_source=in_meegle | lark-project-url-needs-meegle-cli | meegle |
| Lark Project / Meegle workObjectView / workitem URL 鉴权失败 | lark-project-url-needs-meegle-cli | meegle |
| project.larksuite.com 链接 WebFetch 拿不到内容 | lark-project-url-needs-meegle-cli | meegle |
| Lark wiki 链接跳到 accounts.larksuite.com 登录页 | lark-wiki-docs-use-lark-cli | lark |
| ajx34x51402.sg.larksuite.com/wiki 文档编辑任务 | lark-wiki-docs-use-lark-cli | lark |
| 需要读取/写入 Lark Wiki 文档但 WebFetch/Playwright 拿不到正文 | lark-wiki-docs-use-lark-cli | lark |
| lark-cli docs +update 报 --command is required（v1/v2 参数不同） | lark-wiki-docs-use-lark-cli | lark |
| skillshare install -s <name> --track 报错 --skill cannot be used with --track | skillshare-multi-skill-repo-minimal-install | skillshare |
| skillshare target exclude pattern 对带前缀的 slug 不匹配 | skillshare-multi-skill-repo-minimal-install | skillshare |
| 整 repo 安装后 60+ 子 skill 全进 ~/.claude/skills/ 污染上下文 | skillshare-multi-skill-repo-minimal-install | skillshare |
| 想极简装 multi-skill repo 里的单个 skill 同时保留 update 追踪 | skillshare-multi-skill-repo-minimal-install | skillshare |
| skillshare 装外部 repo 后进了 agents/ 而不是 skills/ | skillshare-external-repo-wrong-kind | skillshare |
| skillshare list 显示装好的 skill 在 agent 段不在 skill 段 | skillshare-external-repo-wrong-kind | skillshare |
| 期望是 skill 却被自动分类为 agent | skillshare-external-repo-wrong-kind | skillshare |
| ~/.config/skillshare/agents/_<source>/ 出现意外目录 | skillshare-external-repo-wrong-kind | skillshare |

---

## 维护规则

- **新 recipe 入册**: 同时在「按 tag 分类」对应分类下追加 1 行(`- <slug>` 格式)+ 在「按 symptom 关键词反查」表追加 1-N 行(每个 symptom 一行,slug 重复多次正常)
- **归档 recipe**: 同步从 INDEX 删除两处(tag 分类 + symptom 反查)
- **新 tag 入册**: 在「按 tag 分类」段开新分类标题,然后入 recipe
- **不要修改本段维护规则文字** —— 改规则要走 `flow-skill-dev` 走完整 substantial-update 流程
