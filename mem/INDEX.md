# mem INDEX

> 跨分类 symptom keyword → entry slug 反向索引。
> agent 召回流程: 读本文件 → 匹配 symptom 关键词 → 找到 ≤ 3 条候选 entry → 只载入这些 entry 的正文。
> **禁止 `ls data/<cat>/` 后全量 `cat`**,会炸 token。

---

## portable 分类(持久区 / 跨 agent 常驻事实)

> 与下面 env/unblock 不同:portable 是**常驻**(同步进各 agent 的 resident loader),不是 on-demand 召回。
> 规则见 `references/categories/portable.md`。

- knowledge-base — 个人知识库位置 + 写入/查询(人工 LLM Wiki / agent 读文件)+ 密钥读法(`~/Documents/knowledge/`)

---

## env 分类

### 按 tag 分类

#### env-vars
- (空) — 通用 API key / token 登记,值存 `~/Documents/knowledge/local/.env`

#### local-host
- knowledge-base-location — 本机装了什么、装在哪、PATH 怎么生效

#### project-env
- (空) — 跨 agent 共用的项目环境事实(不是项目内部 .env)

### 按 symptom 关键词反查

| symptom 关键词 | entry slug | tag |
|---|---|---|
| 知识库在哪 / knowledge base 位置 / 个人知识库路径 | knowledge-base-location | local-host |
| 写入知识库 / 安装配置记录写到哪 / `<tool>-install.md` 放哪(→ ~/Documents/knowledge 目录) | knowledge-base-location | local-host |
| 查询/检索知识库用什么 / 知识库搜索工具(→ LLM Wiki app / llm-wiki) | knowledge-base-location | local-host |
| 明文密钥/.env/token 存哪(~/Documents/knowledge/local/.env) | knowledge-base-location | local-host |
| TODOS 待办清单在哪 | knowledge-base-location | local-host |

---

## unblock 分类

### 按 tag 分类

#### codex
- (空)

#### claude-code
- (空)

#### playwright
- (空)

#### browser-automation
- cdp-browser-control-blocked

#### git
- (空)

#### pnpm / npm
- (空)

#### typescript / type system
- (空)

#### sandbox / permission
- (空)

#### im / cc-connect
- (空)

#### subagent / orchestration
- (空)

#### file-system / path
- (空)

#### skill-development
- (空)

#### skillshare
- skillshare-multi-skill-repo-minimal-install
- skillshare-external-repo-wrong-kind

#### meegle
- lark-project-url-needs-meegle-cli

#### lark
- lark-wiki-docs-use-lark-cli

### 按 symptom 关键词反查(精确召回)

| symptom 关键词 | entry slug | tag |
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
| 站点提示 此浏览器或应用可能不安全 无法登录 | cdp-browser-control-blocked | browser-automation |
| computer-use 浏览器 read-only tier 无法点击 | cdp-browser-control-blocked | browser-automation |
| Chrome DevTools MCP / Playwright 打开新浏览器不共享登录 cookie | cdp-browser-control-blocked | browser-automation |
| ECONNREFUSED port 9222 CDP 自动化 | cdp-browser-control-blocked | browser-automation |
| Browser context management is not supported | cdp-browser-control-blocked | browser-automation |
| WebSocket 404 Not Found CDP session | cdp-browser-control-blocked | browser-automation |

---

## staging 分类

### 按 tag 分类

#### (无固定 tag,自由暂存)
- (空)

### 按时间排查

| created_at | slug | hit_count | note |
|---|---|---|---|
| (空) | | | |

---

## 维护规则

- **新 entry 入册**: 同时在「按 tag 分类」对应分类下追加 1 行 + 在「按 symptom 关键词反查」表追加 1-N 行(每个 symptom 一行,slug 重复多次正常)
- **归档 entry**: 同步从 INDEX 删除两处(tag 分类 + symptom 反查)
- **新 tag 入册**: 在「按 tag 分类」段开新分类标题,然后入 entry
- **staging 升格到 env / unblock**: 从 staging 表移除 + 加到目标分类的 tag + symptom 表
- **不要修改本段维护规则文字** —— 改规则要走 `flow-skill-dev` 走完整 substantial-update 流程
