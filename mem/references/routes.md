# mem 路由表 + 反例

写入分诊时**优先**读本文件。判定不准会让条目落错分类,后续 lookup 找不到。

---

## env(本机/项目环境事实 + 变量登记)

### 装什么

- 跨 agent / 跨会话有效的**事实陈述**
- 变量值存放规则、配置文件路径、本机装了什么、装在哪
- 密钥**引用**(只记"叫什么 / 怎么读 / 存哪个文件"),**不记明文**

### 正例

- "QQ 邮箱授权码我存哪了" → env (密钥引用 → `~/Documents/knowledge/local/.env`)
- "这台 Mac 装了 fly / pnpm 在 ~/.local/share/pnpm" → env (本机装了什么)
- "OPENAI_API_KEY 怎么读" → env (变量清单 + 读法)
- "lark-cli 装在哪 / meegle CLI 装在哪" → env (本机工具位置)

### 反例

- "上次 fly deploy 失败因为没绑卡" → **unblock** (解法已知的坑,不是环境事实)
- "我喜欢用 pnpm 不用 npm" → **auto memory** (个人偏好)
- "项目内 .env.local" → 项目自己的 .env,不进 mem
- "这台机器我什么时候买的" → 跟工程无关,不进 mem
- "我装 mysql 的步骤" → director-ops 维护 `~/Documents/knowledge/mysql-install.md`,不进 mem

---

## unblock(工程经验/卡壳→解法,跨 agent 跨用户复用)

### 装什么

- 跌过的坑 + 已验证的解法
- 症状信号 + 常见错法 + 正确做法
- 强调**症状触发**(死路签名 / 外部鉴权系统 / 陌生域名)而不是分支触发

### 正例

- "Workers 不支持 imapflow,要迁 Node.js + Fly.io" → unblock
- "Lark Wiki 别用 WebFetch,用 lark-cli docs +fetch" → unblock
- "302 redirect 到 utm_source 的链接走不通" → unblock (死路签名)
- "skillshare install -s 跟 --track 互斥,要整 repo 装 + .skillignore 反向放行" → unblock

### 反例

- "Cloudflare Workers 是什么" → 不是经验,是事实查询 (不写 mem,查文档)
- "下次我应该用 Hono 不要用 Express" → **auto memory** (个人偏好,不是踩坑)
- "skill 本身能 lint 的硬规则" → **skill-doctor** (不写 mem)
- "本项目用 mobx,组件不要直接订阅" → **项目 CLAUDE.md** (项目级规则)
- "Cursor 的 chat 卡了刷新一下" → 一次性现象,不沉淀

---

## staging(分不清就先放这,带 TTL)

### 装什么

- 类别不明 / 暂时不确定要不要长期保留 / 等下次遇到再看
- 字段最小化(slug + 时间 + 内容 + 上下文)
- 带 TTL=90 天,无 access 自动建议归档

### 正例

- "我先记下来:某 API rate limit 是 60/min,以后查"
- "这个 lib 我可能要用,链接是 X,先记着"
- "刚发现 cf 的某个新功能,以后可能用得上"

### 反例

- 已经明确是 env / unblock / 用户偏好 / 项目规则 → 走正经分类,**不要偷懒丢 staging**(staging 是兜底,不是默认)
- 任何含明文密钥 / token / 密码的内容 → 不进 mem(staging 也不行),敏感值只存 `~/Documents/knowledge/local/.env`

---

## 不写 mem 的内容(明确边界)

| 内容类型 | 应该去 |
|---|---|
| 用户身份 / 偏好 / 项目状态 / 跨会话 user-context | `auto memory` |
| 跨 skill 通用价值观 / 安全 / 身份 | `_shared/constitution.md` |
| 项目级规则 / 项目特定约定 | 项目根 `CLAUDE.md` / `AGENTS.md` |
| skill 自身可 lint 的硬规则 | `skill-doctor` 新规则 |
| 软件安装步骤 + 验证 | `director-ops` 维护 `~/Documents/knowledge/<tool>-install.md` |
| 一次性现象(下次大概率不再出现) | 不沉淀,丢弃 |
| 明文密钥 / token / 密码 | `~/Documents/knowledge/local/.env`(权限 600,不进任何 git) |

---

## 分诊决策树(写入时按序自检)

```
1. 这是个人偏好(我喜欢 X / 我不用 Y)? → auto memory,STOP
2. 这是跨 skill 价值观 / 安全边界? → _shared/constitution.md,STOP
3. 这是当前项目特定的? → 项目 CLAUDE.md,STOP
4. 这是软件装/卸步骤? → director-ops,STOP
5. 这是一次性现象? → 不沉淀,STOP
6. 这是密钥/token 明文? → ~/Documents/knowledge/local/.env,不进 mem,STOP
7. 这是环境事实(怎么读 / 在哪 / 叫什么) → mem env
8. 这是卡壳→解法(症状 + 错法 + 正解) → mem unblock
9. 以上都不是 / 拿不准 → mem staging(TTL=90 天兜底)
```
