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

## Output Contract

完成后至少要明确说明：

- 提交模式
- 本次纳入提交的文件
- 被排除的文件或目录
- commit message
- 是否成功创建 commit
- 若成功，附上 commit SHA

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

## Minimal Operating Principle

这个 skill 的目标不是“尽快提交”，而是“把当前任务成果收敛成一次干净提交”。

若做不到“干净”，就不要假装能安全提交。
