# skillshare skills

这个仓库是 [`skillshare`](https://github.com/) 的全局 source 目录（`~/.config/skillshare/skills/`），
里面收纳要在多个 AI 研发工具间共享的 skills 和 agents。

跑一次 `skillshare sync`，仓库里的内容就会按当前机器的 target 配置分发到各工具的全局目录。

## 启用 git hook（拉代码后自动同步）

仓库内 `.scripts/git-hooks/post-merge` 会在每次 `git pull` / `git merge` 之后自动跑 `skillshare sync`，
把最新的 skill 推到所有已配置的 target。

因为 `core.hooksPath` 是本地 git config，**每个 clone 都需要执行一次**：

```bash
./.scripts/install-hooks.sh
```

跑完后会把 git 的 hooks 路径指向 `.scripts/git-hooks/`，并赋予可执行权限。

要临时关闭：`git config --unset core.hooksPath`。

## 同步去哪些目录

由 `skillshare target list` 决定。当前机器的配置（示例）：

| Target | 路径 |
|---|---|
| `claude` | `~/.claude/skills`（agents → `~/.claude/agents`） |
| `codex` | `~/.agents/skills`（Codex 也会读这里） |
| `gemini` | `~/.gemini/skills` |

新增工具时跑 `skillshare target add <name> <path>`，hook 会自动覆盖到新 target，无需修改脚本。

## 前置依赖

- `skillshare` CLI 已安装并在 `PATH` 中（`command -v skillshare`）
- 仓库已 clone 到 `~/.config/skillshare/skills/`（默认 source 路径）
