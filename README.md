# Skills 中心源头

Claude / Codex / 其他 agent 共用的 skill 集合，**单一事实源**是 GitHub `YeomanYe/skills`。

## 🚀 首次 clone 必做

```bash
# 1. 启用 skill-doctor pre-commit hook(每次 commit 自动 lint,ERROR 阻断)
git config core.hooksPath _scripts/git-hooks/

# 2. 确保 skill-doctor 已编译(hook 依赖它)
cd ~/Documents/projects/node-scripts && pnpm install && pnpm run build
```

之后正常 `git commit`,会自动看到:
```
✓ skill-doctor: Errors: 0 · Warnings: N · Info: 0
```
有 ERROR 时会阻断 commit 并列出问题。详见下方 [Lint 闸门](#lint-闸门pre-commit-hook) 段。

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
├── _scripts/
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
bash _scripts/sync-shared.sh

# 3. 提交并推到 GitHub（单一事实源）— pre-commit hook 会自动跑 skill-doctor
git add -A && git commit && git push origin main

# 4. 让 skillshare source 拉取最新（git pull，不是 rsync！）
cd ~/.config/skillshare/skills && git pull origin main
# 或用 skillshare 自带命令（如果支持）：
#   skillshare update --all

# 5. skillshare 把 source 同步到所有 agent target
skillshare sync --force
```

## Lint 闸门(pre-commit hook)

本仓库自带 git pre-commit hook,每次 `git commit` 前自动跑 `skill-doctor` 全规则。**ERROR > 0 阻断 commit**,WARN 只打印不阻断。

### 一次性启用(每个 clone 都要跑一次)

```bash
cd ~/Documents/projects/skills
git config core.hooksPath _scripts/git-hooks/
```

启用后,commit 时若 ERROR > 0 会看到:

```
❌ pre-commit BLOCKED: skill-doctor found 2 error(s)
ERROR  <skill>  <file>  [<rule>]  <message>
ERROR  ...
Fix the errors above, then re-commit.
```

### 紧急绕过(不推荐)

```bash
git commit --no-verify    # 跳过 hook,适合 doctor 自己出 bug 时临时绕开
```

### 依赖

- 依赖 `~/Documents/projects/node-scripts/dist/skill-doctor/index.js`
- 若 doctor 未编译(dist 缺)→ hook 跳过 lint,不阻断 commit,只打印提示
- 编译:`cd ~/Documents/projects/node-scripts && pnpm run build`

### 当前阈值

| 规则 | WARN | ERROR |
|---|---|---|
| `frontmatter`: description 长度 | > 250 | > 1000 |
| `frontmatter`: 缺 name / description | — | always |
| 其他 7 个规则 | 各规则自定 | 各规则自定 |

阈值在 `~/Documents/projects/node-scripts/src/skill-doctor/rules/*.ts` 内,渐进收紧:精简够多 skill 后,可把 WARN 阈值往下调或把 WARN 升 ERROR。

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
| `director-pm` | 产品经理 | clarify / prd / prioritize / critique | 已实现(2026-06) |
| `director-qa` | QA | (规划中) | 未来 |
| `director-security` | 安全官 | (规划中) | 未来 |

**元规范**:所有 director-* 必须对齐 [`_shared/director-template.md`](_shared/director-template.md):
- 13 段标准 SKILL.md 结构(含 Step 0 Question Gate / 各 mode Deep thinking guide)
- N 维 audit checklist + Aggregate → Verdict 映射表(4 档:ready/with-fixes/needs-revision/failed)
- Output Contract 强制佐证字段(`[文件:行号]` / `[截图:坐标]` / `[command 输出]` 等具体引用源)
- 共享 references:[`evidence-discovery.md`](_shared/evidence-discovery.md)(证据查找规范)
  + [`question-gate.md`](_shared/question-gate.md)(Q gate 规则)
- 4 director-* Relationship 互引,Subagent 派工模板显式指挥

新加 director-* 角色:照 `_shared/director-template.md` 模板填,跑 `bash _scripts/sync-shared.sh` 分发共享 references。

参考：这套设计与 [gstack 的 cognitive modes](https://gstacks.org/) 思路一致——"虚拟专家角色"。

## 关键 skill

| 类别 | skill |
|---|---|
| 编排器（flow-*）| flow-codex-goal / flow-cron / flow-dev-task / flow-ext-publish / flow-project-bootstrap / flow-project-finish / flow-skill-dev / flow-skill-research |
| **角色型 agent（director-*）** | **director-design / director-frontend / director-promote / director-ops / director-architect / director-pm** |
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

## 路由分诊表(skill 选择灰区)

> 多个 skill 的 description 触发短语有重叠时,**先看这张表**——按"用户说什么 + 上下文"
> 给出 First Pick 和 Alternatives,挡掉 agent 路由混乱的情况。
>
> 每个 skill 的 description 里都有 Do NOT use 自声明,但**跨 skill 选择的决策标准**
> 集中放在这张表里维护。

### "审一下" / "review"

| 上下文 | First Pick | Alternatives | 决定依据 |
|---|---|---|---|
| RULE.md / CONTRIBUTING.md / 规范文件 | `director-architect` | — | 项目规则结构问题 |
| 截图 / Figma / mockup / 视觉 | `director-design` | huashu-design(只评样例时) | 视觉品味判断 |
| JSX / React / Vue / Svelte 代码 | `director-frontend` | requesting-code-review(纯 PR review)| 前端代码气味 |
| 即将"完成声明"前的产物总审 | `delivery-gate` | — | 通用交付闸门 |
| 推广文案 / 配图 | `director-promote` | — | 平台原生感 / AI 味 |
| 多个 skill 串起来跑不跑通 | `skill-integration-test` | skill-behavior-test(单 skill)| 路由 + handoff |

### "做一个 X" / "实现 X"

| 上下文 | First Pick | Alternatives | 决定依据 |
|---|---|---|---|
| 完整新项目(MVP+规范+设计) | `flow-project-bootstrap` | project-prep(仅 MVP+stack)| 完整 kickoff vs 单阶段 |
| 单个开发任务(功能/bug) | `flow-dev-task` | flow-codex-goal(≥2h 长跑)| 短/长 + 有无 AC |
| 一个 prototype / demo / 动画 | `huashu-design` | frontend-design(生产 React)| 探索 vs 生产 |
| 一张固定尺寸图(海报 / 商店素材) | `web-image` | huashu-design(高保真原型)| 出图 vs 原型 |
| 写一个新 skill | `flow-skill-dev` | — | 唯一入口 |

### "改 / 重构"

| 上下文 | First Pick | Alternatives | 决定依据 |
|---|---|---|---|
| 重构单个 React/JSX 组件 | `director-frontend` | flow-dev-task(完整 task pipeline)| 单一改动 vs commit/test/push |
| 改项目规范结构 | `director-architect` | — | 规则分域 |
| 改设计风格 / 出新方向 | `director-design` | huashu-design(新做不改)| 改现有 vs 重新做 |
| 改一个 skill | `flow-skill-dev` | — | minor-update 走直 Edit / substantial 走 flow |
| 改 todo-flow 的 spec 让 stage 重做 | `todo-flow revise` | — | spec rework 专用 |

### "提交 / 发布 / 上架"

| 上下文 | First Pick | Alternatives | 决定依据 |
|---|---|---|---|
| 把改动整理成一个 git commit | `clean-commit` | — | 唯一入口 |
| 项目主体做完准备对外露出 | `flow-project-finish` | clean-commit(只想 commit)| 完整收尾 vs 单步 |
| 浏览器扩展上架 Chrome/Edge/Firefox | `flow-ext-publish` | ext-preflight(只想检查不上架)| 完整流 vs 单步检查 |
| 发到 v2ex / 少数派 / Appinn / Twitter / Product Hunt | `director-promote` | — | 多平台宣发 |
| 装/卸软件 | `director-ops` | — | 唯一入口 |

### "测一下"

| 上下文 | First Pick | Alternatives | 决定依据 |
|---|---|---|---|
| 测某个 skill 触发条件对不对 | `skill-behavior-test` | — | 单 skill |
| 测多个 skill 串起来路由通不通 | `skill-integration-test` | — | 跨 skill |
| 跑项目自己的 unit/integration test | `flow-dev-task`(包含测试步) | — | 项目专属测试在 flow-dev-task 内 |
| Playwright 走查 UI | `delivery-gate` | agent-browser(自由 dogfood)| 闸门判定 vs 探索 |

### "卡壳了 / 不知道怎么办"

| 上下文 | First Pick | Alternatives | 决定依据 |
|---|---|---|---|
| 反复试错没进展 | `mem`(unblock 分类,原 unblock-recipes) | brainstorming(发散探索)| 错题本 vs 头脑风暴 |
| 探索性问题 / 需求模糊 | `brainstorming` | huashu-design(设计方向顾问 fallback)| 需求 vs 设计方向 |
| 任务跑完想沉淀经验 | `experience-summary` | — | 11 层架构分诊 |
| 切个心态干活 | `hat` | — | 任务开头默认激活 |

### 决策小抄(实在拿不准)

1. **"我能不能自己干?"** — 能 → 不开 skill,直接做
2. **"是单 task 还是完整流程?"** — 单 task → flow-dev-task 或对应 director-\* ;完整流程 → flow-\*
3. **"任务时长?"** — < 2h → flow-dev-task;≥ 2h + 清晰 AC → flow-codex-goal
4. **"是审视还是创造?"** — 审视 → director-\* audit mode;创造 → huashu-design / frontend-design
5. **"用户说的话有'审 / review / 看看'?"** — 第一直觉去 director-\*(按上下文挑哪个)
6. **"涉及多个领域?"** — flow-\* 编排;**单一领域不要用 flow-\***(过度编排)

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
