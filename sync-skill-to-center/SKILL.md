---
name: sync-skill-to-center
description: Use when a finished skill should be synced into the global `skillshare` source directory and any detected global skill directories for installed AI development tools, excluding `~/.codex/skills` by default to avoid duplicate discovery when Codex already reads other global skill roots, supporting either an explicit source path or the current working directory and overwriting existing destinations by default; 当一个 skill 编写完成，需要把它同步到全局 `skillshare` source 目录以及当前环境中已检测到的其他研发工具全局 skill 目录；默认排除 `~/.codex/skills`，以避免在 Codex 已经读取其他全局 skill 根目录时产生重复发现；支持显式路径或默认当前工作目录，且默认覆盖已有同名目标。
---

# 将 Skill 同步到中心与研发工具全局目录

## 作用

这个 skill 用来把一个已经完成的 skill 目录同步到全局 `skillshare` source 目录，并同步到当前环境中已存在的研发工具全局 skill 目录：

- `~/.config/skillshare/skills/`
- `~/.agents/skills/`
- `~/.claude/skills/`
- 以及脚本已内置的其他常见全局 skill 目录（仅在本机已存在时启用）

这样做的目的：

- 让这份 skill 进入 `skillshare` 的全局 source，便于后续执行 `skillshare sync`
- 让一个工具内创建的全局 skill 自动出现在其他已安装研发工具的全局 skill 目录中
- 避免同一份全局 skill 只存在于单一工具目录，导致跨工具不可见
- 避免 `~/.agents/skills/` 与 `~/.codex/skills/` 同时被 Codex 发现时产生重复枚举和版本歧义

默认行为：

- 支持显式传入 skill 目录路径
- 若未提供路径，则默认使用当前工作目录
- 自动探测当前环境中已存在的研发工具全局 skill 根目录
- 若目标目录已存在同名 skill，默认覆盖
- 默认不把 `~/.codex/skills/` 作为同步目标

## 适用时机

- 某个 skill 已经写完，准备收纳到全局 `skillshare` source，并同步到本机其他研发工具
- 用户明确希望这份 skill 进入全局复用范围
- 该 skill 来自某个工具的全局目录，但也希望其他工具能直接看到
- 后续还需要通过 `skillshare sync` 分发到其他工具

## 不适用时机

- 该 skill 仍然只应保留在项目内，不应进入全局
- skill 目录还未完成，结构不稳定
- 当前只想做本地临时验证，不想覆盖全局同名 skill

## 必要流程

1. 确定源 skill 目录
2. 校验目录中存在 `SKILL.md`
3. 以源目录名作为 skill 名称
4. 探测当前环境中已存在的研发工具全局 skill 根目录
5. 将该目录同步到：
   - `~/.config/skillshare/skills/<skill-name>/`
   - 以及所有已探测到的其他全局 skill 根目录（默认排除 `~/.codex/skills/`）
6. 若目标已存在，默认覆盖
7. 若当前是飞书来源的 cc-connect 会话（`CC_SESSION_KEY` 以 `feishu:` 开头），且 `~/.config/skillshare/skills/` 是 git 仓库，则自动在该目录 `git add <skill-name> && git commit && git push`
8. 输出 `source`、`destination`、`overwrote`、`git_status`

## 飞书来源自动提交

当本 skill 由飞书消息驱动运行时，自动把中心目录的 skill 变更提交并推送到 remote，避免每次都需要手动到 `~/.config/skillshare/skills/` 下跑 `git commit && git push`。

- **触发条件**：环境变量 `CC_SESSION_KEY` 以 `feishu:` 开头（cc-connect 为飞书会话设置的格式）
- **作用对象**：仅 `~/.config/skillshare/skills/`（中心目录）；其他 AI 工具的全局目录不参与 git 操作
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
- 收集已存在的研发工具全局 skill 根目录
- 固定包含 `~/.config/skillshare/skills/`
- 默认排除 `~/.codex/skills/`
- 对每个目标删除已有同名目录后再复制
- 将完整 skill 目录复制到所有目标位置

## 输出要求

至少应明确输出：

- 当前 skill：`sync-skill-to-center`
- `source` 路径（使用 `${HOME}` 变量形式）
- `destination` 路径数组（使用 `${HOME}` 变量形式）
- 是否覆盖了已存在目标
- 是否同步成功
- 建议下一步命令：`skillshare sync`

输出字段约定：

- `source=<path>`
- `destination=["<path>"]`
- `overwrote=<0|1>`
- `git_status=<skipped|no-op|pushed|committed|failed>`
- `git_commit=<shortsha>`（仅当有 commit 产生时）
- `git_reason=<detail>`（当 status 非 pushed 时可选）

## 约束

- 默认覆盖是这个 skill 的预期行为，不需要额外保守确认
- 不要偷偷改成项目内 `.skillshare/skills/`
- 应负责处理当前环境中已存在的研发工具全局 skill 目录
- 默认不要把 skill 同步到 `~/.codex/skills/`
- 缺失的工具目录不应强行创建；只同步到本机已存在的目录
- 不维护 `~/.config/skillshare/skills/index.json`
- 除非用户明确要求，否则不要自动执行 `skillshare sync`
