# Skills 中心源头

Claude / Codex / 其他 agent 共用的 skill 集合，**单一事实源**是 GitHub `YeomanYe/skills`。

## 关键认知

GitHub repo `YeomanYe/skills` 是**唯一的真相**。本地有两个 working copy：

| 位置 | 角色 | git remote |
|---|---|---|
| `~/Documents/projects/skills/` | **开发位置**（这里编辑 skill）| `git@github.com:YeomanYe/skills.git` |
| `~/.config/skillshare/skills/` | **skillshare 工具的 source**（同一 repo 的另一个 clone） | `git@github.com:YeomanYe/skills.git` |

skillshare 把 source clone 同步到 agent 目标：

```
GitHub: YeomanYe/skills (单一事实源)
   ↓ git push (开发位置 → GitHub)
   ↓ git pull / skillshare update (GitHub → skillshare source)
~/.config/skillshare/skills/ (skillshare source)
   ↓ skillshare sync
~/.claude/skills/, ~/.agents/skills/ (agent 实际读取的位置)
```

skillshare 工具的配置在 `~/.config/skillshare/config.yaml`，定义了 `source` 和 `targets`。

## 目录结构

```
.
├── README.md              # 本文件
├── _shared/               # skill 之间共享的 reference 源头（不是 skill 本身）
│   ├── README.md
│   ├── parallelization-template.md
│   └── handoff-payload-template.md
├── scripts/
│   └── sync-shared.sh     # 把 _shared/ 复制到各 skill 的 references/
├── flow-codex-goal/       # 各 skill 目录（含 SKILL.md / references/ / tests/）
├── flow-dev-task/
└── ...                    # 共 28+ skill
```

## 修改 / 新建 skill 的工作流（正确版本）

```bash
# 1. 在开发位置改 skill
cd ~/Documents/projects/skills
# 改 SKILL.md / references / tests ...

# 2. 如果改了 _shared/，同步副本到各 skill 的 references/
bash scripts/sync-shared.sh

# 3. 提交并推到 GitHub（单一事实源）
git add -A && git commit && git push origin main

# 4. 让 skillshare source 拉取最新（git pull，不是 rsync！）
cd ~/.config/skillshare/skills && git pull origin main
# 或用 skillshare 自带命令（如果支持）：
#   skillshare update --all

# 5. skillshare 把 source 同步到所有 agent target
skillshare sync --force
```

### ⚠️ 历史踩坑警示

**不要**用 `rsync -a --delete /Users/falcom/Documents/projects/skills/ /Users/falcom/.config/skillshare/skills/`
把开发位置硬覆盖到 skillshare source。

那样会：
- 把开发 repo 的 `.git/` 整个推过去，污染 skillshare clone 的 git 状态
- 绕过 GitHub 单一事实源（GitHub 上没有的本地改动也会被推到 skillshare）
- 删掉 skillshare 工具自己维护的元数据（如果有）

**正确**：开发位置 → GitHub → skillshare source（用 `git pull` / `skillshare update`）。

## 关键 skill

| 类别 | skill |
|---|---|
| 编排器（flow-*）| flow-codex-goal / flow-dev-task / flow-ext-publish / flow-jsx-ui / flow-project-bootstrap / flow-project-finish / flow-project-rules / flow-skill-dev / flow-skill-research |
| 共享工具 | clean-commit / delivery-gate / sync-skills |
| 设计 | project-rules-design / ui-extract / jsx-ui-audit / web-image |
| 浏览器自动化 | cdp-browser-control |
| 系统 | software-install / software-uninstall |
| 测试 meta | skill-behavior-test / skill-integration-test |
| 发布渠道 | appinn-forum-post / post-to-twitter / post-to-v2ex / sspai-publish / producthunt-launch / ext-preflight |

完整列表见各 skill 目录的 `SKILL.md`。

## 共享 reference

详见 [`_shared/README.md`](./_shared/README.md)。

## 重命名 skill 的硬规则

skill 重命名时（比如旧名 → 新名），commit 前必须确认：

```bash
git grep -l "<old-name>" -- '*.md' '*.yaml'  # 必须返回空
```

否则会留下死引用，让其他 skill 路由失败。

历史教训：曾经有 `orchestrating-skill-development` → `flow-skill-dev` 等 6 处死引用，
是 audit 才发现。
