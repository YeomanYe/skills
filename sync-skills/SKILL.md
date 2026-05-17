---
name: sync-skills
description: Use when a finished skill should be synced into the central skills directory at `~/Documents/projects/skills/`, supporting either an explicit source path or the current working directory, overwriting existing destinations by default; 当一个 skill 编写完成，需要把它同步到中心 skills 目录 `~/Documents/projects/skills/`；支持显式路径或默认当前工作目录，且默认覆盖已有同名目标。
---

# 将 Skill 同步到中心目录

## 作用

这个 skill 用来把一个已经完成的 skill 目录同步到中心 skills 目录：

- `~/Documents/projects/skills/<skill-name>/`

这样做的目的：

- 让这份 skill 进入统一的中心目录，便于版本管理（默认 git 仓库）和后续分发
- 所有变更只落在一个地方，避免多副本漂移

默认行为：

- 支持显式传入 skill 目录路径
- 若未提供路径，则默认使用当前工作目录
- 若目标目录已存在同名 skill，默认覆盖
- 不再向其他 AI 工具的全局 skill 目录 fan-out

## 适用时机

- 某个 skill 已经写完，准备收纳到中心目录
- 用户明确希望这份 skill 进入全局复用范围

## 不适用时机

- 该 skill 仍然只应保留在项目内，不应进入中心目录
- skill 目录还未完成，结构不稳定
- 当前只想做本地临时验证，不想覆盖中心同名 skill

## 必要流程

1. 确定源 skill 目录
2. 校验目录中存在 `SKILL.md`
3. 以源目录名作为 skill 名称；若源在 AI 工具的 sync target 路径下（`~/.claude/skills/` / `~/.agents/skills/` / `~/.codex/skills/`），自动剥 plugin 前缀（匹配 `^_<plugin>__(skills__)?<naked>$`，例如 `_YeomanYe-skills__foo` → `foo`、`_obra-superpowers__skills__bar` → `bar`）；如需强制覆盖，可用 `DEST_NAME=<name>` env var
4. 将该目录同步到 `~/Documents/projects/skills/<skill-name>/`
5. 若目标已存在，默认覆盖
6. 若当前是飞书来源的 cc-connect 会话（`CC_SESSION_KEY` 以 `feishu:` 开头），且中心目录是 git 仓库，则自动 `git add <skill-name> && git commit && git push`
7. 输出 `source`、`destination`、`effective_skill_name`、`overwrote`、`git_status`

## 飞书来源自动提交

当本 skill 由飞书消息驱动运行时，自动把中心目录的 skill 变更提交并推送到 remote。

- **触发条件**：环境变量 `CC_SESSION_KEY` 以 `feishu:` 开头（cc-connect 为飞书会话设置的格式）
- **作用对象**：`~/Documents/projects/skills/`
- **前置要求**：中心目录已是 git 仓库并配置了 remote（脚本不会自动 `git init`，也不会自动配 remote）
- **Commit message**：`feat(<skill-name>): sync from feishu session`
- **Env 覆盖**：
  - `NICHE_AUTOSYNC_GIT=0`：强制禁用 git 步骤，即使当前是飞书会话
  - `NICHE_AUTOSYNC_GIT=1`：强制启用，即使当前不是飞书会话
- **结果字段**（在脚本 stdout）：
  - `git_status=skipped`：非飞书会话或被显式禁用
  - `git_status=no-op`：飞书会话但 skill 内容无变化
  - `git_status=pushed`：成功 `git commit && git push`（带 `git_commit=<shortsha>`）
  - `git_status=committed`：commit 成功但 push 失败（`git_reason` 含原因；本地已写入，不回滚）
  - `git_status=failed`：前置条件不满足（非 git 仓 / 未装 git / commit 失败）
- **非飞书会话不触发**：其他平台（Telegram / Discord / 本地 CLI 直接调用）均走原有流程，不做 git 动作

## 输入规则

- 若用户明确给出 skill 目录路径，使用该路径
- 若用户未给出路径，使用当前工作目录
- 在执行前，将路径解析为绝对路径

## 校验规则

执行前必须确认：

- 源目录存在
- 源目录中包含 `SKILL.md`
- 源目录名非空

若任一项不满足，停止并明确说明原因。

## 执行方式

使用附带脚本：

```bash
bash scripts/sync_skill_to_center.sh "<source-dir>"
```

脚本会完成以下动作：

- 解析源目录绝对路径
- 校验 `SKILL.md`
- 删除中心目录中已有同名目录
- 将完整 skill 目录复制到 `~/Documents/projects/skills/<skill-name>/`

## 输出要求

至少应明确输出：

- 当前 skill：`sync-skills`
- `source` 路径（使用 `${HOME}` 变量形式）
- `destination` 路径（使用 `${HOME}` 变量形式）
- 是否覆盖了已存在目标
- 是否同步成功

输出字段约定：

- `source=<path>`
- `destination=["<path>"]`
- `effective_skill_name=<name>`（最终用作中心目录名的 skill 名称；若发生 plugin 前缀剥离或 `DEST_NAME` override，可在此回显确认）
- `overwrote=<0|1>`
- `git_status=<skipped|no-op|pushed|committed|failed>`
- `git_commit=<shortsha>`（仅当有 commit 产生时）
- `git_reason=<detail>`（当 status 非 pushed 时可选）

## 约束

- 默认覆盖是这个 skill 的预期行为，不需要额外保守确认
- 不要偷偷改成项目内 `.skillshare/skills/` 或 `~/.config/skillshare/skills/`
- 不要向 `~/.claude/skills/`、`~/.agents/skills/`、`~/.codex/skills/` 等 AI 工具目录 fan-out
- 不维护 index 文件
