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
│   ├── constitution.md         # always-follow 顶层契约(身份/安全/输入信任/注入防御/高风险动作门)
│   ├── director-template.md    # director-* 元规范(13 段结构)
│   ├── evidence-discovery.md   # 证据查找规范(5 层优先级)
│   ├── question-gate.md        # Step 0 Q gate 规则
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

## Skill 命名空间约定

| 前缀 | 含义 | 例子 |
|---|---|---|
| `flow-*` | **编排型流水线**（既定流程，强制阶段，按 step 推进） | flow-codex-goal / flow-dev-task |
| `director-*` | **角色型 agent**（专业判断 + 自己领域工具调度，不越界） | director-design / director-ops |
| 无前缀 | **单体能力**（工具 / 资源 / 单一职责） | clean-commit / web-image |

### director-* 与 flow-* 的关键差别

- **flow-*** 是"流水线编排器"——每个 step 强制执行，跨多个不同领域的 skill
- **director-*** 是"专家角色"——只在**单一专业领域**内做判断 + 调度自己领域工具，**handoff 给其他角色**而不越界

director-* 现状与扩展：

| Skill | 角色 | Modes | 状态 |
|---|---|---|---|
| `director-design` | 设计师 | audit / direction / variants / mockup / handoff | 已实现 |
| `director-frontend` | 前端工程师 | audit / boundaries / implement / extract / handoff | 已实现(2026-05) |
| `director-promote` | 宣发者 | audit / draft / variants / dispatch / recap | 已实现(2026-05) |
| `director-ops` | 运维 | install / uninstall | 已实现(2026-05) |
| `director-architect` | 架构师 | research(联合评估) → approval → land(自带 mini-orchestration) | 已实现(2026-05) |
| `director-pm` | 产品经理 | (规划中) | 未来 |
| `director-qa` | QA | (规划中) | 未来 |
| `director-security` | 安全官 | (规划中) | 未来 |

**元规范**:所有 director-* 必须对齐 [`_shared/director-template.md`](_shared/director-template.md):
- 13 段标准 SKILL.md 结构(含 Step 0 Question Gate / 各 mode Deep thinking guide)
- N 维 audit checklist + Aggregate → Verdict 映射表(4 档:ready/with-fixes/needs-revision/failed)
- Output Contract 强制佐证字段(`[文件:行号]` / `[截图:坐标]` / `[command 输出]` 等具体引用源)
- 共享 references:[`evidence-discovery.md`](_shared/evidence-discovery.md)(证据查找规范)
  + [`question-gate.md`](_shared/question-gate.md)(Q gate 规则)
- 4 director-* Relationship 互引,Subagent 派工模板显式指挥

新加 director-* 角色:照 `_shared/director-template.md` 模板填,跑 `bash scripts/sync-shared.sh` 分发共享 references。

参考：这套设计与 [gstack 的 cognitive modes](https://gstacks.org/) 思路一致——"虚拟专家角色"。

## 关键 skill

| 类别 | skill |
|---|---|
| 编排器（flow-*）| flow-codex-goal / flow-dev-task / flow-ext-publish / flow-project-bootstrap / flow-project-finish / flow-skill-dev / flow-skill-research |
| **角色型 agent（director-*）** | **director-design / director-frontend / director-promote / director-ops / director-architect** |
| 共享工具 | clean-commit / delivery-gate / sync-skills |
| **经验治理** | **experience-summary**（任务结束后分诊经验到 11 层架构正确出口） |
| **个性切换** | **hat**（任务开始时戴帽:收/散/严/快/挑/教/问 7 种 persona，事后告知） |
| 设计/视觉 | web-image（出图） / director-design（视觉判断 / mockup） |
| 前端工程 | director-frontend（合并自原 flow-jsx-ui + jsx-ui-audit + ui-extract） |
| 浏览器自动化 | cdp-browser-control |
| 系统运维 | director-ops（软件装 / 卸，合并自原 software-install + software-uninstall） |
| 测试 meta | skill-behavior-test / skill-integration-test |
| 宣发/发布渠道 | director-promote（合并自原 post-to-twitter / post-to-v2ex / appinn-forum-post / sspai-publish / producthunt-launch，5 平台内置） / ext-preflight（扩展上架前检查） |

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
