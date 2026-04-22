---
name: committing-clean-changes
description: Use when a task's code changes are ready to be recorded as one clean git commit and you need help selecting relevant files, composing the commit message, and committing safely
---

# Committing Clean Changes

## Overview

这个 skill 只负责把当前任务成果整理成一次干净的 git 提交。

它不负责流程编排，不负责 PR、merge、删分支或清理 worktree，也不会默认把改动拆成多个 commit。

核心原则：

- 一次调用，默认只产出一次 commit
- 优先收敛本次任务相关文件，避免粗暴 `git add .`
- 如果改动边界不清，停止并说明原因，不要擅自拆分或混提

## Commit Modes

本 skill 支持两种提交模式：

- `select-and-commit`
  - 默认模式
  - 由 skill 检查工作区、选择本次任务相关文件、生成 message 并提交
- `staged-only`
  - 只基于已经暂存的内容生成 message 并提交
  - 不再额外挑选文件

如果用户没有明确指定模式，默认使用 `select-and-commit`。

## When to Use

以下情况使用本 skill：

- 当前任务已经形成一个明确的逻辑单元，准备提交
- 你需要根据当前 diff 收敛本次应提交的文件
- 你需要生成清晰的 commit message
- 你不想直接执行 `git add . && git commit`

以下情况不要使用本 skill：

- 你还在决定整体流程怎么编排
- 你还没完成本次任务，改动范围仍在变化
- 你准备做 PR、merge、删分支或 worktree 清理
- 你明确要拆成多个 commit

## Required Workflow

按以下顺序执行：

1. 检查当前工作区与暂存区状态
2. 识别本次任务相关文件
3. 排除不应进入这次提交的文件
4. 生成一次 commit message
5. 执行一次 `git add` 与一次 `git commit`
6. 若本次会话来自 IM 通道（见下方 "IM 会话自动推送"），在 commit 成功后执行一次 `git push`

除非用户明确要求拆分提交，否则不要创建多个 commit。

## Step 1: Inspect Git State

先检查：

- `git status --short`
- 必要时查看 `git diff --stat`
- 必要时查看具体文件 diff

如果当前模式是 `staged-only`，应额外确认：

- 已暂存内容是否完整覆盖本次任务
- 未暂存内容是否会污染本次提交判断

先区分三类改动：

- 已暂存改动
- 未暂存改动
- 与当前任务无关的改动

如果没有任何待提交改动，直接说明，不要继续执行提交。

## Step 2: Select Relevant Files

目标是只提交“本次任务成果”对应的文件。

如果当前模式是 `staged-only`，这一阶段的目标变为：

- 校验当前暂存内容是否适合作为一次原子提交
- 识别未暂存内容是否会带来边界风险

此模式下，不额外执行新的文件选择，除非用户改回 `select-and-commit`。

优先纳入：

- 本次任务直接修改的源码或文档
- 与当前任务直接相关的测试
- 为这次任务新增且确实应纳入版本库的文件

默认排除：

- `.tmp/`、日志、临时报告、缓存文件
- 构建产物
- 截图、录屏、调试输出，除非本次任务明确要求纳入
- 与当前任务无关的已有脏改动

如果工作区混有多件事，且无法安全判断本次应提交哪些文件，停止并说明风险，不要擅自提交。

## Step 3: Decide the Commit Scope

默认一次调用只做一次提交，因此必须先判断这些文件能否合理组成一个原子提交。

可以继续的条件：

- 改动围绕同一个明确目标
- 提交后能用一句简洁 message 概括
- 没有明显应该拆开的独立逻辑块

应停止的情况：

- 改动明显包含两件以上独立工作
- 当前任务边界无法从 diff 中可靠识别
- 用户明确要求拆成多个 commit

如果停止，输出原因，但不要擅自开始做多次提交。

## Step 4: Compose the Commit Message

生成 commit message 时遵循：

- 简洁
- 直接描述结果
- 与本次提交范围一致
- 不夸大未完成内容

优先使用常见前缀风格，例如：

- `feat:`
- `fix:`
- `refactor:`
- `docs:`
- `chore:`
- `test:`

如果仓库已有明确提交规范，应遵守仓库规范。

## Step 5: Commit Safely

在文件边界明确后，执行：

1. 如果是 `select-and-commit`，只 `git add` 本次任务相关文件
2. 如果是 `staged-only`，保持当前暂存内容不变
3. 再执行一次 `git commit`

不要使用：

- `git add .`
- `git commit -a`

除非用户明确要求，否则不要：

- amend 现有 commit
- force push
- 自动拆成多个 commit

## Step 6: IM 会话自动推送

当本次调用来自 IM 通道的 cc-connect 会话时，在 commit 成功后应立刻把 commit 推送到 remote，避免用户每次都要到终端再跑一次 `git push`。

**触发条件**：环境变量 `CC_SESSION_KEY` 非空。cc-connect 会为每个 IM 会话设置 `<platform>:<chat>:<user>` 格式的 key，涵盖 `feishu` / `lark` / `telegram` / `discord` / `wecom` / `weixin` / `qq` / `ding` / `slack` 等所有已接入的通道。直接终端调用（无 cc-connect 代理）时 `CC_SESSION_KEY` 不存在，则跳过本步骤。

**执行规则**：

- 仅在 Step 5 的 commit **成功**后触发
- 使用普通 `git push`，不带 `--force` 或 `--force-with-lease`
- 若当前分支**没有 upstream**，使用 `git push -u origin HEAD` 首次建立追踪
- 不检出分支，不切换分支，不修改 remote 配置
- 不重试；一次 push 失败就把原因记录到 push_status，不做隐式回滚

**Env 覆盖**：

- `CCC_AUTOPUSH=0`：强制禁用自动推送，即使在 IM 会话中
- `CCC_AUTOPUSH=1`：强制启用自动推送，即使 `CC_SESSION_KEY` 未设置

**结果状态**：

- `pushed`：commit 成功 + push 成功
- `committed`：commit 成功但 push 失败（远端拒绝、无网络、凭证问题等）；本地改动保持不动
- `skipped`：非 IM 会话，或被 `CCC_AUTOPUSH=0` 显式禁用
- `n/a`：commit 本身未成功（上游流程已终止在更早步骤）

**安全边界**（不得突破）：

- 不允许 force push，无论 IM 会话还是终端直连
- 不允许推送到用户未明确工作过的分支（默认 `origin` 是唯一目标）
- commit 失败不触发 push；push 失败不触发 amend/reset/revert
- 用户若在本次对话里显式要求"只提交不推送"，该指令优先于 IM 自动推送规则

## Output Contract

完成后至少要明确说明：

- 提交模式
- 本次纳入提交的文件
- 被排除的文件或目录
- commit message
- 是否成功创建 commit
- 若成功，附上 commit SHA
- `push_status`: `pushed` / `committed` / `skipped` / `n/a`
- 若 push 失败，附上失败原因（push_reason）
- 若 push 成功，附上目标分支 + remote（例如 `origin/main`）

如果未提交成功，也要明确说明停在哪一步。

## Common Failure Modes

### 1. 贪心提交

问题：
把无关改动、临时文件或测试产物一起提上去。

处理：
缩小提交边界，只纳入当前任务相关文件。

### 2. 边界不清还强行提交

问题：
明明混了多件事，仍硬做一次提交。

处理：
停止并解释为什么当前不适合直接提交。

### 3. 擅自拆分成多个 commit

问题：
用户没有要求拆分，skill 却变成轻量流程编排器。

处理：
默认一次调用只做一次 commit；需要拆分时由用户明确提出。

### 4. 粗暴使用 `git add .`

问题：
把本不该提交的内容一起纳入。

处理：
显式选择文件，不做整仓全加。

### 5. IM 会话下漏推送

问题：
在飞书/Telegram/Discord 等 IM 会话里完成了 commit，但忘记 push，导致用户在手机上看到"commit 成功"却以为已经推送到 remote。

处理：
在 IM 会话（`CC_SESSION_KEY` 非空）中，commit 后必须跑一次 `git push`，并把 push_status 写进输出契约。不要默认"commit = 推送"但实际上未推送。

### 6. IM 会话下强行 force push

问题：
把 IM 自动推送误解为"什么都可以自动做"，包括 `--force`。

处理：
自动推送只做普通 push；force push 仍需要用户在对话里显式要求。

## Minimal Operating Principle

这个 skill 的目标不是“尽快提交”，而是“把当前任务成果收敛成一次干净提交”。

若做不到“干净”，就不要假装能安全提交。
