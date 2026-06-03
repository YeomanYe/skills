---
name: env-registry
description: >
  跨 agent 通用的环境变量 / API key / token 查找登记册。
  agent 在调用外部服务时如果不知道某个变量叫什么名字、放在哪里、怎么读，
  来这里查；所有变量值统一存放在 `~/Documents/knowledge/local/.env`，
  本 skill 只记录"清单 + 读法 + 缺失时的处理"，不存任何明文密钥。
  自动触发关键词: env / 环境变量 / API key / token / secret / 凭证 /
  "没找到 X_KEY" / "需要 OPENAI_API_KEY" / "缺少凭证" / missing credential /
  where is the key / 怎么读 .env / load env。
  显式触发: 「查下 env-registry / 看下变量登记册 / 这个 key 叫啥 /
  哪里有 X 的 token / lookup env var」。
  Do NOT use for: 写入个人偏好(→ auto memory)、卡壳→解法案例
  (→ unblock-recipes)、项目内私有的一次性变量(→ 项目自己的 .env)、
  存放密钥明文(→ 直接编辑 `~/Documents/knowledge/local/.env`，不写进本 skill)。
---

# env-registry —— 跨 agent 环境变量登记册

## 作用

一个固定位置、一份清单、所有 agent 都知道去哪读。

- **变量值**统一存放：`~/Documents/knowledge/local/.env`（权限 600，永不提交）
- **变量清单**登记在本 skill：name / 用途 / 来源行 / 缺失时怎么办
- agent 需要某个 key 时：先查本 skill 拿到变量名 → 按下文读法读 → 读不到就问用户补，不要猜值

## 适用时机

- agent 准备调用某个外部服务（OpenAI / GitHub / TTS / …），不确定 env 变量叫什么
- agent 拿到 `xxx is required` / `missing API key` 这类错误，要先确认变量名再补
- 用户明确说"看下登记册" / "这个 key 在哪" / "查下 env-registry"
- 新增 / 修改一个跨 agent 复用的 key，需要登记下来

## 不适用时机

- 项目内私有的一次性变量 → 放项目自己的 `.env`，不进本 skill
- 用户个人偏好（如默认模型）→ `auto memory`
- 卡壳→解法案例 → `unblock-recipes`
- 存放密钥**明文** → **永远不要**写进本 skill；明文只存在 `~/Documents/knowledge/local/.env`

## 变量存放位置（唯一事实源）

```
~/Documents/knowledge/local/.env
```

- 权限 600，仅当前用户可读
- 格式：`NAME=value`，一行一条，`=` 两边无空格，无引号（除非值本身含空格）
- `#` 开头为注释
- **不进任何 git 仓库**

## 读法（推荐顺序）

### 方式 A：只取单个变量（默认，不污染环境）

```bash
grep '^OPENAI_API_KEY=' ~/Documents/knowledge/local/.env | cut -d= -f2-
```

- 优点：只拿需要的那个，不把整份 secrets 灌进 shell
- 用途：临时调一次 API；脚本里 `KEY=$(grep ... | cut ...)` 拿来用

### 方式 B：临时全量加载到当前命令

```bash
set -a
source ~/Documents/knowledge/local/.env
set +a
# 然后调你的命令，比如
your-tool --use-env
```

- 优点：工具直接读 `$OPENAI_API_KEY` 等
- 注意：只在当前 shell 生效；子进程继承到的也只是这条命令之后启动的

### 方式 C：不要做的事

- ❌ 不要 `cat ~/Documents/knowledge/local/.env` 把内容打印到日志 / chat
- ❌ 不要把值复制粘贴进 commit / PR / issue
- ❌ 不要把这个文件加进任何 git 仓库
- ❌ 不要把它 `source` 进 `~/.zshrc` 让所有进程都拿到（按需读才安全）

## 变量清单

> 实际变量值不在这张表里，在 `~/Documents/knowledge/local/.env`。
> 这张表只告诉 agent："这个名字存在、它是干什么的、缺了怎么办"。

| 变量名 | 用途 | 是否敏感 | 缺失时 |
|---|---|---|---|
| (待登记) | | | |

**登记格式说明：**
- **变量名**：与 `.env` 中的 KEY 完全一致
- **用途**：一句话说明这个 key 给哪个服务 / 哪类调用用
- **是否敏感**：是 / 否（决定能否在日志里 echo 出来；敏感的连"已设置"以外的回显都不要做）
- **缺失时**：agent 读不到该变量时的处理动作（默认：停下来问用户补，不要猜、不要伪造）

## Agent 使用流程

1. **遇到需要 env 的场景** → 先来本 skill 查变量名
2. **查清单**：在上面的表里找到目标变量行
3. **按读法取值**：默认用方式 A（grep 单值）；工具明确需要环境变量才用方式 B
4. **读不到怎么办**：
   - 文件不存在 → 提示用户先建 `~/Documents/knowledge/local/.env`
   - 文件存在但变量不在 → 告诉用户"需要在 `~/Documents/knowledge/local/.env` 加一行 `XXX=...`"，**不要自己编一个假值继续跑**
   - 文件存在但值为空 → 同上
5. **用完即丢**：不要把读到的明文写进任何持久化位置（log / 文档 / chat / commit）

## 新增 / 修改变量的规则

- **该登记**：跨 agent / 跨项目复用的 key、token、endpoint、账号 ID
- **不该登记**：单个项目专属变量、一次性临时值、值本身（值永远在 `.env`，不在 skill）
- 加新变量：
  1. 在 `~/Documents/knowledge/local/.env` 加一行 `NAME=value`
  2. 在本 skill "变量清单" 表里加一行（只写元数据，不写值）
  3. 不需要 commit `.env`；本 skill 的清单变更随 skills 中心仓库一起 commit

## Red Flags — STOP

- 把明文 key 写进本 SKILL.md
- `cat` 整份 `.env` 到日志 / chat / 文档
- 读不到变量就**编一个假值**继续跑（应停下来问用户）
- 把 `~/Documents/knowledge/local/.env` 加进任何 git 仓库
- 把 `.env` source 进 `~/.zshrc` 让所有进程默认拿到
- 把项目专属变量塞进本 skill（应进项目本地 `.env`）

## 与其他 skill 的关系

- `unblock-recipes`：卡壳→解法案例库；与本 skill 互不替代——找变量名来这里，踩坑找解法去那里
- `auto memory`：per-agent 个人偏好；不存共享密钥
- 项目内 `.env` / `CLAUDE.md`：项目专属变量与规则；不进本 skill
