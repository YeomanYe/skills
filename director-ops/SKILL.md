---
name: director-ops
description: >
  Use when 用户要在系统上安装或卸载工具 / 软件 / 包——本 skill 扮演"运维"角色，
  按"环境检查 → 查资料 → 出计划 → 用户确认 → 执行 → 验证 → 记录知识库"的标准流程
  完成软件的装与卸，确保过程可追溯、可重复、可记录。
  触发短语包括："装一下 X"、"帮我装 X"、"安装 X"、"新装个 X"、"install X"、"set up X"、
  "怎么装 X"、"卸载 X"、"删了 X"、"uninstall X"、"remove X"、"把 X 清掉"、"X 怎么卸载"。
  Do NOT use for: 升级已装工具（直接 brew upgrade / pip install -U，无需走流程）/
  配置已装工具（如改 Chrome 设置）/ 项目级依赖（npm install / pip install -r
  requirements.txt → flow-dev-task）/ 一次性临时跑（npx <tool>）/ 删项目文件（普通 rm 即可）。
---

# director-ops — 虚拟运维

## 关于命名

`director-*` 是 **角色型 agent** 命名空间（区别于 `flow-*` 编排型流水线）。
每个 director-* 都是一个"虚拟专家角色"：专业判断 + 调度自己领域的工具，
但**不越界到其他角色的领地**。详见顶层 [README.md](../README.md) 的 director-* 段。

## Overview

`director-ops` 是"运维"角色——给定软件的装 / 卸任务，**先判断真实诉求**（install / uninstall），
再按统一的运维流程执行：查环境、查资料、出计划、等用户确认、执行、验证、记录知识库。

它不是：
- ❌ 升级工具的 skill（`brew upgrade` 一行就够，不走流程）
- ❌ 项目依赖管理器（`npm install` / `pip install -r` 是 `flow-dev-task` 的事）
- ❌ 工具配置员（改已装软件的设置不在职责内）

它是：
- ✅ **软件装 / 卸的标准流程执行者**
- ✅ 自己维护本地知识库（`~/Documents/knowledge/`）——装卸都记录，下次可查
- ✅ 破坏性操作（sudo / 改 PATH / 删数据）前必须出计划 + 等用户确认
- ✅ 最终交付明确说明：用了哪些资料来源 / 跑了哪些步骤 / 知识库写在哪

核心信念：
- **安装/卸载前必须查本地知识库 + 当前环境**，避免重复劳动、避免猜测
- **用户必须看到计划并明确确认后才执行**
- **结果必须验证 + 记录到知识库**，没验证不宣告完成，没记录不收尾
- **不擅自执行 sudo / 改全局配置 / 无备份删数据**

## When to Use

- 用户明确说要装某个工具 / 软件 / 包，且当前系统**还没有**（或版本不满足）
- 用户明确说要卸载某个工具 / 软件 / 应用
- 装卸步骤可能涉及环境配置 / 依赖检查 / 备份 / 注意事项

## When NOT to Use

- 升级已装工具 → 直接 `brew upgrade <pkg>` / `pip install -U <pkg>`，不走流程
- 配置已装工具（如改 Chrome 设置）→ 不走本 skill
- 项目级依赖（`npm install` / `pip install -r requirements.txt`）→ `flow-dev-task`
- 一次性临时跑（`npx <tool>`）→ 不走本 skill
- 删项目内文件 → 普通 `rm` 即可，不走本 skill

## Mode Selection

进入产出前先判断 mode，2 选 1。

| 用户意图 | mode | 主要产出 | 知识库文件 |
|---|---|---|---|
| "装一下 X" / "install X" / "怎么装 X" | `install` | 安装计划 → 执行 → 验证 → 安装记录 | `~/Documents/knowledge/<tool>-install.md` |
| "卸载 X" / "uninstall X" / "把 X 清掉" | `uninstall` | 卸载计划（含备份）→ 执行 → 验证 → 卸载记录 | `~/Documents/knowledge/<tool>-uninstall.md` |

两个 mode **共用主干工作流**（环境检查 / 查资料 / 出计划 / 用户确认 / 执行 / 验证 / 记录），
差异只在：`uninstall` mode 多出**备份**与**删残留**两个破坏性环节，且必须在验证通过后才删数据。

如果意图混合（"重装 X" = 先卸再装），按 `uninstall → install` 顺序串行执行，各自走完整流程。

## 适用范围

- 优先支持 `macOS`
- `Linux`、`Windows` 仅在本地知识或网络资料足够明确时提供步骤
- 如果系统不匹配、来源不可信或关键步骤无法验证，必须明确降级说明，而不是猜测

## 需要先读取的文件

- 本地知识与引文规则：`references/knowledge-and-citation.md`
- 知识库记录模板（装 / 卸两套）：`references/record-template.md`
- 测试用例：`tests/cases.md`

## Required Workflow（7 步主干）

按顺序执行，**不允许跳步**。带 🔻 的子步骤仅 `uninstall` mode 执行。

### Step 1 — 环境检查

```bash
uname -s -m                       # 系统 + CPU 架构
sw_vers 2>/dev/null               # macOS 详细版本
cat /etc/os-release 2>/dev/null   # Linux 发行版

# 目标软件已装检查
which <tool> || command -v <tool>
<tool> --version 2>/dev/null

# 包管理器可用性
command -v brew apt dnf pip pipx npm cargo mas 2>/dev/null
```

至少明确：操作系统 + 版本 + CPU 架构、相关包管理器是否存在、目标软件**当前是否已安装 + 版本**。

- `install` mode：若已装且版本满足 → 退出本 skill（无需安装）
- `uninstall` mode：若无法确认目标软件是否存在 → **不要**生成删除步骤，先给定位方法

### Step 2 — 资料收集

按优先级查 3 个来源（检索命令与引文规则详见 `references/knowledge-and-citation.md`）：

1. **本地知识库**（`~/Documents/knowledge/`）
   - `install` mode：搜 `<tool>-install.md` / `<tool>-*.md`
   - `uninstall` mode：先搜 `<tool>-uninstall.md`，没有再搜 `<tool>-install.md`（从安装记录反推卸载方式）
2. **用户提供的链接 / 文档** — 用户提供则优先用
3. **网络搜索** — 仅本地资料不足或不适用时才查；优先官方文档，记录来源 URL

`uninstall` mode 额外做**适用性判断**：资料的平台 / 安装方式 / 版本 / 路径必须与当前系统匹配
才能采用。安装记录只能证明"可能如何安装"时，不能据此直接删用户数据，最多输出候选路径 + 验证方法。

**输出**：推荐的装/卸方式、系统要求 + 依赖、已知注意事项、参考链接。

### Step 3 — 分析 + 出计划

把资料拆成可执行步骤。每步标注：
- **类型**：全自动 / 半自动（需 sudo / 需用户输入）/ 全手动
- **命令**：精确命令
- **风险**：这步可能影响什么
- **来源**：参考链接

**install 计划**步骤顺序：依赖检查 → 安装 → PATH/配置 → 验证。

**uninstall 计划**步骤顺序（破坏性，顺序不可乱）：
1. 停止运行中的相关进程 / 服务
2. 导出版本与当前状态
3. 🔻 备份配置和重要数据
4. 执行软件卸载
5. 验证软件已卸载且系统正常
6. 🔻 删除残留数据
7. 记录结果

uninstall 计划必须额外列出：需备份的路径、需保留的数据、可选删除的数据路径。

### Step 4 — 用户确认（**必须**）

向用户展示完整计划：
- 所有步骤 + 需 sudo / 手动 / 用户输入的步骤
- `install`：预估时间 + 磁盘占用 + 是否需要重启
- `uninstall`：即将删除的软件 + 影响范围 + 是否会删配置/用户数据 + 是否已规划备份

**用户明确同意（"go" / "装" / "卸" / "ok 开始"）后才执行**。模糊回复（"好"）需二次确认。
在用户确认前，不执行任何破坏性命令。

### Step 5 — 执行

- `install`：按顺序跑全自动步骤，记录每步输出
- `uninstall`：
  - 🔻 先按计划**备份**配置与重要数据（记录备份时间 / 路径 / 内容摘要），备份完成后再继续
  - 按检测到的安装方式选最小破坏路径卸载（`brew uninstall` / `npm uninstall -g` / `pipx uninstall` /
    官方卸载器 / Finder 删 `.app`）；**不混用安装方式**，不只删二进制而留后台服务/LaunchAgent
- 半自动步骤暂停等用户输入；全手动步骤给清晰指令让用户跑
- **任一步骤失败 → 立刻停 + 报告**，不擅自重试，不盲删数据

### Step 6 — 验证

- `install`：
  ```bash
  <tool> --version       # 必须能跑
  which <tool>           # 必须在 PATH
  <tool> <basic-command> # 跑一个最小功能命令
  ```
  PATH 没生效时，明确告诉用户 source 哪个 rc 文件 + 建议加到 `~/.zshrc`。
- `uninstall`：
  ```bash
  command -v <tool>                       # 应无输出
  brew list --formula | rg '^<name>$'     # 应无匹配
  brew list --cask | rg '^<name>$'        # 应无匹配
  ```
  并检查 `/Applications/`、LaunchAgent、Login Items、后台服务是否已移除；备份文件是否可见。
  - 🔻 **只有验证通过后**，才执行 Step 5 计划里的"删除残留数据"。删除前再次区分：可删（缓存/日志/
    明确属于该软件的 support files）、默认保留（用户项目/导出文件/未知用途目录）。验证异常则不删，保留备份并报告。

### Step 7 — 记录知识库

写入 `~/Documents/knowledge/<tool>-install.md` 或 `<tool>-uninstall.md`（已存在则**更新**不覆盖）。
记录模板（装 / 卸两套）见 `references/record-template.md`。

- `install` 记录含：环境、安装日期、安装方式、安装步骤、验证命令、注意事项、参考链接
- `uninstall` 记录含：卸载时间、系统版本、软件版本、安装来源、卸载方式、备份路径、删除的数据路径、
  验证结果、资料来源链接、注意事项

## Output Contract

每次完成必须输出（**强制全字段**）：

```md
## Director-Ops Report

### 任务理解
- 用户原话:
- mode 判定: install | uninstall
- 目标软件:

### 环境
- OS / 版本 / 架构:
- 包管理器: <可用列表>
- 目标软件当前状态: 已装 v<x> | 未装

### 资料来源
- 本地知识库: hit <path> | miss
- 用户提供: yes <link> | no
- 网络搜索: 用了 <URL> | 没用
- 适用性判断（uninstall）: <资料与当前系统是否匹配 / 推断说明> | n/a

### 计划
- 步骤数: <n>
- 自动 / 半自动 / 手动: <a>/<b>/<c>
- 破坏性环节（uninstall）: 备份路径 <...> / 拟删数据 <...> | n/a

### 用户确认
- 时间: <ts>
- 确认方式: <quote of user reply>

### 执行结果
- 完成步骤: <n>/<total>
- 失败步骤: <list with errors>
- 备份完成（uninstall）: yes <path> | n/a

### 验证
- install: 版本 <pass + version | fail> / 基本功能 <pass | fail>
- uninstall: 主命令已移除 <pass | fail> / 包管理器已不列出 <pass | fail> / 残留已清理 <yes | 保留原因>

### 知识库
- 路径: ~/Documents/knowledge/<tool>-{install|uninstall}.md
- 状态: 新建 | 更新

### 结论
- install: 可用 yes | no
- uninstall: 已卸载且系统正常 yes | no
- 剩余问题 / 手动步骤:
```

如有失败或手动步骤，明确列出，**不夸大**。

## Red Flags — STOP

任一命中必须停下：

- **未做环境检查就开始装 / 卸**（可能已装、冲突，或目标根本不存在）
- **跳过用户确认直接 sudo / 改 PATH / 写全局配置 / 删数据**
- **失败一步就重试 3 次**（第一次失败必须停下报告，不盲重试）
- **`curl ... | bash` 来路不明的脚本**（必须给用户看 URL + 内容摘要让其判断）
- **安装路径含敏感目录**（`/usr/bin/` / `/etc/` 不该直接写）
- **覆盖已存在的二进制文件**（先 `mv` 备份）
- **uninstall：没备份就删配置/数据**
- **uninstall：没验证通过就清理残留数据**
- **uninstall：把"安装文档推测"写成"已验证可执行的卸载方案"**
- **uninstall：只删二进制而留后台服务 / LaunchAgent / 登录项**
- **跳过验证就宣告完成**
- **没写知识库就 commit / 收尾**

对 `pkg`、内核扩展、系统扩展、登录项、LaunchAgent、网络代理类软件，卸载时要额外提醒影响范围。

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "用户都说装/卸 X 了，不用再确认了" | 必须展示计划让用户看清 sudo / 改 PATH / 删数据 / 重启等影响项 |
| "`brew install` 一行就够了，不用记知识库" | 一年后忘了用啥版本 / 啥注意事项还是要查；记知识库是核心价值 |
| "失败可能是网络问题，再试一次" | 第一次失败必须停，看错误信息再决定，不是盲重试 |
| "环境检查跳过吧，已经知道装没装" | 还有依赖 / 包管理器可用性 / conflicting binary / 目标是否真存在要查 |
| "知识库已经有了不用更新" | 操作日期 / 当前系统版本 / 这次踩的新坑要 append |
| "PATH 不生效让用户 source 一下就行" | 必须告诉用户该 source 哪个 rc 文件 + 建议加到 ~/.zshrc |
| "用户说不用备份，那就直接删" | uninstall 的备份是硬 gate，不能因用户图快就跳过；最多给安全计划不执行破坏性删除 |
| "本地有安装文档，照着反推删就行" | 安装记录只证明"可能如何安装"，平台/版本/路径不匹配时不能据此删用户数据 |
| "残留数据先删了，验证肯定没问题" | 删残留必须在验证通过之后；验证异常要保留备份并报告 |

## Common Failure Modes

### 1. install：已装但版本不够
处理：先看版本，询问用户是升级（→ 退出本 skill 走 `brew upgrade`）还是覆盖装。

### 2. install：多包管理器都可装
处理：列出选项（brew / pip / cargo / binary 各自利弊）让用户选，不默认选第一个。

### 3. 需要 sudo 但用户没给
处理：明确告诉用户哪一步要 sudo + 为什么，让用户主动跑。**不要**自己尝试 `sudo -S`。

### 4. 知识库已有同名 .md
处理：读旧文件，更新操作日期 + 当前系统版本，append 新注意事项；不覆盖旧内容。

### 5. install：安装过程要交互（登录 / 选项）
处理：提前在计划里告知，执行到该步时**暂停**，让用户操作完再继续。

### 6. uninstall：无法确认目标软件是否存在
处理：不生成删除步骤，先给定位方法（`command -v` / `brew list` / 检查 `/Applications`）。

### 7. uninstall：目录可能同时含用户数据和程序状态
处理：默认不删，除非用户再次确认。宁可多保留少误删。

### 8. 非 macOS 但本地资料只有 macOS
处理：明确指出资料不适用，**不编造** Linux/Windows 步骤，说明缺口与需补充的资料。

## Codex Delegation Hook

本 skill 是判断 + 流程执行类工作：

| 步骤 | ROI |
|---|---|
| Step 1 环境检查 | 🟡（机械命令可派，但结果判断需 Claude） |
| Step 2 资料收集 | 🔴（需 Claude 判断来源可信度 + 适用性） |
| Step 3 出计划 | 🔴（决策类） |
| Step 4 用户确认 | 🔴（必须 Claude 与用户交互） |
| Step 5 执行 | 🔴（破坏性，必须 Claude 盯着，失败即停） |
| Step 6 验证 | 🔴（需 Claude 判断验证结论） |
| Step 7 记录知识库 | 🔴（依赖会话上下文） |

派工细则以 `flow-dev-task` 的 Codex Delegation Hook 为唯一规范，本 skill 不重复。

## Relationship to Other Skills

### Upstream
- 用户直接触发为主
- 可被 `flow-dev-task` 等编排器调用（当某任务需要先装/卸某系统级工具时）

### 明确不调用 / 不越界
- **升级已装工具** → 不走本 skill，直接 `brew upgrade` / `pip install -U`
- **项目级依赖** → `flow-dev-task`（`npm install` / `pip install -r`）
- **配置已装工具** → 不在职责内

### 平行角色（director-*）
- `director-design` — 设计师角色
- 未来：`director-pm` / `director-architect` / `director-qa` / `director-security`

## Reuse

- 测试用例在 `tests/cases.md`
- 本地知识与引文规则在 `references/knowledge-and-citation.md`
- 知识库记录模板（装 / 卸两套）在 `references/record-template.md`
