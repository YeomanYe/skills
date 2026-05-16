---
name: software-install
description: >
  Use when 用户要在系统上安装工具 / 软件 / 包，需要"先查环境 → 找资料 → 出计划 → 用户确认
  → 执行 → 验证 → 记录知识库"的完整流程。触发短语包括 "装一下 X", "帮我装 X", "安装 X",
  "新装个 X", "install X", "set up X", "怎么装 X", "X 怎么装", "添加 X 到我的环境"。
  Do NOT use for: 升级已装工具（直接 brew upgrade / pip install -U 即可，无需走流程）/
  卸载工具（→ software-uninstall）/ 项目内 npm install / pip install -r requirements.txt
  这类项目依赖管理（→ flow-dev-task）/ 配置已装工具（如改 Chrome 设置）。
---

# 工具安装指南

## Overview

标准化的工具安装流程，确保安装过程**可追溯、可重复、可记录**。

**核心信念**：
- 安装前必须查本地知识库 + 当前环境，避免重复劳动
- 用户必须看到计划并确认后才执行
- 安装结果必须验证 + 记录到本地知识库（`~/Documents/knowledge/`）
- 不擅自执行需要 sudo / 修改 PATH / 改全局配置的操作

## When to Use

- 用户明确说要装某个工具 / 软件 / 包
- 当前系统**还没有**该工具（或版本不满足）
- 安装步骤可能涉及环境配置 / 依赖检查 / 注意事项

## When NOT to Use

- 升级已装工具 → 直接 `brew upgrade <pkg>` / `pip install -U <pkg>`，不走流程
- 卸载工具 → `software-uninstall`
- 项目级依赖（`npm install` / `pip install -r requirements.txt`）→ `flow-dev-task`
- 配置已装工具（如改 Chrome 设置）→ 不走本 skill
- 一次性临时跑（`npx <tool>`）→ 不走本 skill

## Required Workflow（8 步）

按顺序执行，**不允许跳步**。

### Step 1：环境检查

```bash
uname -a                    # 系统版本
sw_vers 2>/dev/null         # macOS 详细版本
cat /etc/os-release 2>/dev/null  # Linux 发行版

# 已装检查
which <tool> || command -v <tool>
<tool> --version 2>/dev/null

# 包管理器可用性
which brew apt pip npm cargo 2>/dev/null
```

**输出**：当前系统 / 已装情况 / 可用的包管理器。

### Step 2：资料收集

按优先级查 3 个来源：

1. **本地知识库**（`~/Documents/knowledge/`）— 搜 `<tool>-install.md` 或 `<tool>-*.md`
2. **用户提供的链接 / 文档** — 用户提供则优先用
3. **网络搜索** — 优先官方文档，记录来源 URL

**输出**：
- 推荐安装方式（源码 / 包管理器 / Docker / binary release）
- 系统要求 + 依赖
- 已知注意事项
- 参考链接

### Step 3：分析 + 出计划

把资料拆成可执行步骤。每步标注：
- **类型**：全自动 / 半自动（需 sudo / 需用户输入）/ 全手动
- **命令**：精确命令
- **来源**：参考链接

模板：
```md
## 安装计划：<tool>

### Step 1：xxx
- 类型：全自动
- 命令：`brew install xxx`
- 来源：<官方文档 URL>

### Step 2：xxx
- 类型：半自动（需 sudo）
- 命令：`sudo xxx`
- 来源：...
```

### Step 4：用户确认（**必须**）

向用户展示：
- 完整计划（所有步骤）
- 需要 sudo / 手动 / 用户输入的步骤
- 预估时间 + 磁盘占用 + 是否需要重启

**用户明确同意（"go" / "装" / "ok 开始"）后才执行**。模糊回复（"好"）需要二次确认。

### Step 5：执行安装

- 按顺序跑全自动步骤，记录每步输出
- 半自动步骤暂停等用户输入 / 确认
- 全手动步骤给清晰指令让用户跑
- **任一步骤失败 → 立刻停 + 报告**（不擅自重试）

### Step 6：验证可用

```bash
<tool> --version       # 必须能跑
which <tool>           # 必须在 PATH
<tool> <basic-command> # 跑一个最小功能命令
```

如果 PATH 没生效，提示 `source ~/.zshrc` 或重开终端。

### Step 7：记录到知识库

写入 `~/Documents/knowledge/<tool>-install.md`（已存在则更新）：

```md
# <tool> 安装记录

## 环境
- OS: <macOS 14.0 / Ubuntu 22.04 / ...>
- 安装日期: <YYYY-MM-DD>
- 安装方式: <homebrew / pip / cargo / binary>

## 安装步骤
1. <step 1 命令>
2. ...

## 验证命令
- `<tool> --version` → <expected output>
- `<tool> <basic-command>` → ...

## 注意事项
- <已知坑 / 配置项 / PATH 设置>

## 参考
- <官方文档 URL>
```

### Step 8：输出总结

```md
✅ 安装完成

- 工具：<name>
- 版本：<version>
- 安装方式：<method>
- 安装路径：<which output>
- 验证命令：<cmd>
- 知识库：~/Documents/knowledge/<tool>-install.md
- 注意事项：
  - <项>
```

如有失败/手动步骤，明确列出，**不夸大**。

## Output Contract

每次调用必须输出：

```md
## Software Install Report

### 安装目标
- 工具:
- 触发来源（用户原话）:

### 环境
- OS / 包管理器:
- 已装版本（如有）:

### 资料来源
- 本地知识库: hit | miss
- 用户提供: yes | no
- 网络搜索: 用了 | 没用 + URL

### 安装计划
- 步骤数: <n>
- 自动 / 半自动 / 手动: <a>/<b>/<c>

### 用户确认
- 时间: <ts>
- 确认方式: <quote of user reply>

### 执行结果
- 完成步骤: <n>/<total>
- 失败步骤: <list with errors>

### 验证
- 版本: <pass + version | fail + reason>
- 基本功能: pass | fail

### 知识库
- 路径: ~/Documents/knowledge/<tool>-install.md
- 状态: 新建 | 更新

### 结论
- 可用: yes | no
- 剩余问题:
```

## Red Flags — STOP

任一命中必须停下：

- **未做环境检查就开始装**（可能已装或冲突）
- **跳过用户确认直接 sudo / 改 PATH / 写全局配置**
- **失败一步就重试 3 次**（应该停下报告，不擅自重试）
- **`curl ... | bash` 来路不明的脚本**（必须给用户看 URL + 内容摘要让其判断）
- **安装路径含敏感目录**（`/usr/bin/` / `/etc/` 不该直接写）
- **覆盖已存在的二进制文件**（先 `mv` 备份）
- **跳过验证就宣告完成**
- **没写知识库就 commit / 收尾**

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "用户都说装 X 了，不用再确认了" | 必须展示计划让用户看清 sudo / 改 PATH / 重启等影响项 |
| "`brew install` 一行就够了，不用记知识库" | 一年后忘了用啥版本 / 啥注意事项还是要查；记知识库是核心价值 |
| "失败可能是网络问题，再试一次" | 第一次失败必须停，看错误信息再决定，不是盲重试 |
| "环境检查跳过吧，已经知道没装" | 还有依赖 / 包管理器可用性 / 已有 conflicting binary 要查 |
| "知识库已经有了不用更新" | 安装日期 / 当前系统版本 / 这次踩的新坑要 append |
| "PATH 不生效就让用户 source 一下，反正会解决" | 必须告诉用户该 source 哪个 rc 文件 + 一次性建议加到 ~/.zshrc |

## Common Failure Modes

### 1. 已装但版本不够
处理：先看版本（`<tool> --version`），询问用户是升级（→ 退出本 skill 走 brew upgrade）还是覆盖装。

### 2. 多包管理器都可装
处理：列出选项（brew / pip / cargo / binary 各自利弊），让用户选；不要默认选第一个。

### 3. 需要 sudo 但用户没给
处理：明确告诉用户哪一步要 sudo + 为什么，让用户主动跑。**不要**自己尝试 `sudo -S`。

### 4. 知识库已有同名 .md
处理：读旧文件，更新 "安装日期" + "当前系统版本"，append 新的注意事项；不要覆盖旧的内容。

### 5. 安装过程要交互（如登录 / 选项）
处理：提前在计划里告知，执行到该步时**暂停**，让用户自己操作完再继续。

## Relationship to Other Skills

- **上游**：用户直接触发
- **下游（无）**：本 skill 是单体能力，不调其他 skill
- **平行**：
  - `software-uninstall` — 卸载场景
  - `flow-dev-task` — 项目级依赖管理

## Reuse

测试用例在 `tests/cases.md`。知识库格式见上方 Step 7。
