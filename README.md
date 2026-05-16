# Skills 中心源头

Claude / Codex / 其他 agent 共用的 skill 集合，源头位于 `~/Documents/projects/skills/`，
推送到 GitHub `YeomanYe/skills`。

## 目录结构

```
.
├── README.md              # 本文件
├── _shared/               # skill 之间共享的 reference 源头（不是 skill 本身）
│   ├── README.md
│   ├── parallelization-template.md
│   └── handoff-payload-template.md
├── scripts/
│   └── sync-shared.sh     # 把 _shared/ 同步到各 skill 的 references/
├── flow-codex-goal/       # 各 skill 目录（含 SKILL.md / references/ / tests/）
├── flow-dev-task/
└── ...                    # 共 28+ skill
```

## skill 同步流程

中心源头 = `~/Documents/projects/skills/`（这个 repo）。

各 agent 通过两种方式读 skill：

| Agent | 读 skill 的路径 | 同步方式 |
|---|---|---|
| Claude Code | `~/.claude/skills/<skill>/` | 由 `skillshare sync` 创建符号链接到 `~/.config/skillshare/skills/<skill>/` |
| Codex / 其他 | 各 agent 的全局 skill 目录 | 同上，skillshare 把每个含 SKILL.md 的目录同步到所有目标 |

**重要约定**：
- `~/.config/skillshare/skills/` 是 skillshare 的**目标缓存**，**不是源头**
- 源头永远是这个 repo（`~/Documents/projects/skills/`）
- 通过 `skillshare sync --force` 把源头推到所有目标

## 修改 / 新建 skill 的工作流

1. 在源头修改 / 新建 skill 目录
2. 跑 `bash scripts/sync-shared.sh`（如果改动涉及 _shared/）
3. `rsync -a --delete ./ ~/.config/skillshare/skills/`（把源头推到 skillshare 缓存）
4. `skillshare sync --force`（让 skillshare 把缓存符号链接到所有目标）
5. `git add -A && git commit && git push`

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
