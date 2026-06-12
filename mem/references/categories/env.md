# env 分类:本机/项目环境事实 + 变量登记

env 分类**只装事实陈述**(怎么读 / 在哪 / 叫什么 / 装在哪 / 装了哪个版本),不装解法(那是 unblock)。

继承自原 env-registry 的设计意图(env-registry 未发布到 main,设计意图已融入此处)。

---

## 装什么 / 不装什么

### 装

- 跨 agent / 跨会话有效的环境**事实**
- 通用变量名 + 用途 + 读法(值不存这里)
- 本机装了什么、装在哪、PATH 怎么生效
- 跨 agent 共用的项目环境事实(比如"项目 X 的 fly app 名是 X-backend")

### 不装

- **明文密钥 / token / 密码** → `~/Documents/knowledge/local/.env`(权限 600,不进任何 git)
- **个人偏好**("我喜欢用 pnpm")→ `auto memory`
- **项目内部 .env** → 项目自己的 `.env`,不进 mem
- **软件安装步骤** → `director-ops` 维护 `~/Documents/knowledge/<tool>-install.md`
- **环境踩坑+解法** → 那是 unblock 分类,不是 env

---

## 变量值存放位置(唯一事实源)

```
~/Documents/knowledge/local/.env
```

- 权限 600,仅当前用户可读
- 格式:`NAME=value`,一行一条,`=` 两边无空格,无引号(除非值含空格)
- `#` 开头为注释
- **不进任何 git 仓库**

---

## 读法(推荐顺序)

### 方式 A:只取单个变量(默认,不污染环境)

```bash
grep '^OPENAI_API_KEY=' ~/Documents/knowledge/local/.env | cut -d= -f2-
```

优点:只拿需要的那个,不把整份 secrets 灌进 shell。
用途:临时调一次 API;脚本里 `KEY=$(grep ... | cut ...)` 拿来用。

### 方式 B:临时全量加载到当前命令

```bash
set -a
source ~/Documents/knowledge/local/.env
set +a
your-tool --use-env
```

优点:工具直接读 `$OPENAI_API_KEY` 等。
注意:只在当前 shell 生效;子进程继承到的也只是这条命令之后启动的。

### 方式 C:不要做的事

- ❌ `cat ~/Documents/knowledge/local/.env` 把内容打印到日志 / chat
- ❌ 把值复制粘贴进 commit / PR / issue
- ❌ 把这个文件加进任何 git 仓库
- ❌ `source` 进 `~/.zshrc` 让所有进程都拿到(按需读才安全)

---

## entry 文件 schema

每条 env entry 放 `data/env/<slug>.md`,frontmatter + 几张表。

```md
---
slug: <kebab-case>
scope: vars-registry | local-host-<hostname> | project-<project-slug>
tags: [env-vars | local-host | project-env]
first_seen: 2026-06-12
last_updated: 2026-06-12
hit_count: 0
---

## <slug> — <一句话用途>

### 变量/事实清单

| 名称 / 路径 | 用途 | 是否敏感 | 缺失时 |
|---|---|---|---|
| OPENAI_API_KEY | OpenAI 调用 | 是 | 停下来问用户补,**不要**猜 / 伪造 / 复用其他 key |
| ~/.nvs/default/bin/meegle | 本机 meegle CLI | 否 | 见 unblock/lark-project-url-needs-meegle-cli;若未装提示用户装 |

### 读法

(可写自定义读法。默认走"变量值存放位置"段的方式 A。)

### 出处

- 首次发现 / 登记: <date> / 在 <什么场景 / 哪个项目>
```

字段硬约束:

- `slug`: kebab-case, 3-30 字符, 唯一
- `scope`: 三种之一,清楚标明此 entry 是登记表 / 本机事实 / 项目事实
- `tags`: 至少 1 个,从 `INDEX.md` 的 env tag 词典选

---

## 跟原 env-registry 的关系

原 env-registry skill 提出过"跨 agent 通用环境变量登记册"的概念,但**未发布到 main**(只在 experiment/meta-skill 分支存在)。它的核心设计意图——单一变量值存放位置 + 变量清单只记 metadata + 三种读法 + 严禁明文进 git——全部融入本文件 + `routes.md` + `failure-modes.md` RF-8。

后续 env 变量登记不需要再走 env-registry,直接进 `data/env/<slug>.md`。
