---
name: todo-driver
description: >
  Use when interacting with the human-facing endpoints of the TODO Driver pipeline
  (TODO → spec → dev → merge): initializing a project to support the pipeline,
  appending a new slug-tagged TODO entry, or reviewing-and-merging a ready spec
  back into main. Three modes: `init` to onboard a project (create TODO.md +
  docs/spec/ + .gitignore entries), `add-todo` to append a new TODO entry,
  `review-merge` for the audit + squash merge + cleanup flow.
  用于 TODO Driver 流水线（TODO → spec → dev → merge）的三个人手触发端点：
  初始化项目接入流水线（mode=init，创建 TODO.md + docs/spec/ + 改 .gitignore）、
  追加带 slug 的 TODO 条目（mode=add-todo）、审核并合并 status=ready-for-review
  的 spec（mode=review-merge）。三个 mode 共享 slug 规范、frontmatter 字段约定、
  工程规范三级回退（AGENTS.md → CLAUDE.md → 通用规则）。
  触发短语（init 路径，**初始化项目**）：「初始化 todo-driver」「把这个项目接入 todo-driver」
  「setup todo-driver」「onboard todo-driver」「todo-driver init」「让这个工程支持 todo 流水线」。
  触发短语（add-todo 路径，**加一条 todo**）：「新建 TODO」「加一个待办」「记个新需求带 slug」
  「ext-helper 记个 TODO」「create a TODO」「add todo with slug」「new todo」
  「todo-driver add-todo」。
  触发短语（review-merge 路径）：「review 这个 todo」「合并 todo 分支」
  「审 todo 并 merge」「todo-review-merge」「结清 ready 的 todo」「merge ready spec」
  「合并 ready 的 todo」。
  统一触发：「todo-driver」「跑一下 todo-driver」「todo-driver init」「todo-driver add-todo」
  「todo-driver review-merge」。
  Do NOT use for: 修改已有 TODO（直接用 Edit）/ 不带 slug 的快速备忘（直接 Edit TODO.md）/
  通用 PR review（→ requesting-code-review）/ 不走 todo-driver 流水线的项目 /
  把 draft spec 改成 approved（那是人手动改 frontmatter）/ stage 1/2 cron prompt
  本身的功能（在 references/stage{1,2}-prompt.md，不归本 skill 管）。
---

# todo-driver

## Overview

本 skill 是 TODO Driver 流水线**人手触发**的三个端点：

- **`init`**：把一个普通工程**初始化**为支持 todo-driver 流水线的工程——创建 `TODO.md` + `docs/spec/` + 改 `.gitignore`。一次性动作，幂等。
- **`add-todo`**：向项目 `TODO.md` 追加一条带 slug 的待办，让 stage 1 cron 起草 spec。
- **`review-merge`**：审核 `status: ready-for-review` 的 spec，pass 则 squash merge 到默认分支 + 原子清理 branch/worktree/spec/TODO。

中间的 stage 1（起草 spec）和 stage 2（开发 + 走查 + push branch）由 cron 喂的 prompt 接管（`references/stage{1,2}-prompt.md`），不在本 skill 范围。

核心原则：
- **一次调用只处理一个 mode**，不混做
- mode 解析有明确顺序，不靠模糊推测
- 共享约束严格对齐（slug 格式 / frontmatter 字段名 / 工程规范源头）
- 高风险动作（merge / push / 删 branch）有硬护栏

## Modes

| Mode | 触发场景 | 主要副作用 | 风险等级 |
|---|---|---|---|
| `init` | 用户要把一个项目接入 todo-driver 流水线 | 创建 `TODO.md` + `docs/spec/` + 改 `.gitignore` 加 `.worktrees/`；幂等 | 低 |
| `add-todo` | 用户要新建带 slug 的 TODO | 在 `TODO.md` 对应段末追加一行 | 低 |
| `review-merge` | 用户要审核并合并 ready spec | squash merge + 删 branch + 删 worktree + push 默认分支 | 高 |

## Resolving Mode

按以下顺序判定：

1. **用户显式指定**（如 `todo-driver init` / `todo-driver add-todo` / `todo-driver review-merge`）→ 用指定的
2. **触发短语推断**：
   - 含"初始化"/"接入"/"setup"/"onboard" + "todo-driver"/"todo 流水线" → `init`
   - 含"新建"/"加"/"记"/"create"/"add" + "TODO"/"待办" → `add-todo`
   - 含"review"/"审"/"合并"/"merge" + "todo"/"spec" → `review-merge`
3. **状态推断**（兜底）：
   - 项目根**没有** `TODO.md` 也**没有** `docs/spec/` → 倾向 `init`（流水线还没接入）
   - 项目根有 `docs/spec/*.md` 且至少 1 个 `status: ready-for-review` → 倾向 `review-merge`
   - 否则 → 倾向 `add-todo`
4. **仍模糊** → 用 AskUserQuestion 二选一（或三选一）

判定后**立即声明**当前 mode（一句话），再开始执行。用户在调用上下文里明确给了 mode 就不要二次确认。

> ⚠️ **历史改名**：v1 的 `init` 是"追加 TODO"，v2 重命名为 `add-todo`，`init` 这个词回归"初始化"本意。看到旧调用 `todo-driver init` 而上下文是"加 todo"语义时，自动按 `add-todo` 处理并提示一次新名字。

## When to Use

满足任一即可触发：
- 用户想把一个项目接入 todo-driver 流水线（无 `TODO.md` / `docs/spec/` 的工程）
- 用户描述了一个想加进 `TODO.md` 的新需求/功能/重构
- 项目有 `docs/spec/*.md` 文件且其中至少一个 `status: ready-for-review`，用户希望推进 merge
- 用户在 todo-driver 流水线相关的上下文里提及 init / add-todo / review / merge 这类动作

## When NOT to Use

- 用户在改已有 TODO 条目（直接 Edit）
- 用户只想随手记一行不需要被流水线处理（直接 Edit TODO.md）
- 用户在做通用 PR 审查（用 `requesting-code-review`）
- 用户要 merge 一个不在 todo-driver 流水线里的分支（直接 `git merge`）
- 用户在问"如何用 todo-driver"等元问题（解释，不真的执行）

> 注：之前列的"项目不走 todo-driver" 已不再是 NOT to use 条件——因为 `init` mode 正是用来把这种项目接入的。

---

## Mode `init`

把一个普通工程**初始化**为支持 todo-driver 流水线的工程。一次性、幂等——已经初始化过再跑只会补缺失项，不破坏现有内容。

### Required Workflow（init）

按以下顺序：

1. 探测当前状态
2. 一次性收集所需输入（仅当真要新建 TODO.md 时问 1 个问题）
3. 创建 / 补齐流水线骨架
4. 改 `.gitignore`
5. 一次性 commit + push
6. 输出报告

#### Step 1: Probe Environment

```bash
# 必须在 git 仓库根目录
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || { echo "ERROR: not a git repo"; exit 1; }
test "$(git rev-parse --show-toplevel)" = "$(pwd -P)" || { echo "ERROR: must run at repo root"; exit 1; }

# 探测默认分支
default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
default_branch=${default_branch:-main}
current_branch=$(git rev-parse --abbrev-ref HEAD)
[ "$current_branch" = "$default_branch" ] || { echo "ERROR: must run on ${default_branch}, currently on ${current_branch}"; exit 1; }

# 工作树必须干净（避免把用户脏改动卷进 init commit）
test -z "$(git status --porcelain)" || { echo "ERROR: working tree dirty, commit or stash first"; exit 1; }

# 探测 4 个骨架项的存在状态
test -f TODO.md && HAS_TODO=1 || HAS_TODO=0
test -d docs/spec && HAS_SPEC_DIR=1 || HAS_SPEC_DIR=0
test -d docs/spec/_done && HAS_DONE_DIR=1 || HAS_DONE_DIR=0
{ test -f .gitignore && grep -qxE '\.worktrees/?' .gitignore; } && HAS_GITIGNORE=1 || HAS_GITIGNORE=0
```

任一硬错（非 git 仓库 / 不在根目录 / 不在默认分支 / 工作树脏）→ 报错 stop，不动任何文件。

**幂等检查**：4 个骨架项都已就位（`HAS_TODO=1 && HAS_SPEC_DIR=1 && HAS_DONE_DIR=1 && HAS_GITIGNORE=1`） → 输出"already initialized"报告 + exit 0，**不重复执行**。

#### Step 2: Collect Inputs (仅当真要建 TODO.md 时问)

- 4 个骨架项**全部缺失**：用 AskUserQuestion 问 1 个问题——"TODO.md 的初始项目类型是什么"，3 选 1：`Features` 段（默认，UI/产品类）/ `TODO` 段（通用）/ `Backlog` 段（偏 backlog 文化）。用户在调用 prompt 里说了类型 → 跳过问。
- 部分骨架已在 → **不问**，直接进 Step 3 补缺失项。

#### Step 3: Create / Patch Skeleton

按 `HAS_*` 标记**只补缺失项**，绝不覆盖已有：

```bash
# 创建 TODO.md（仅 HAS_TODO=0 时）
if [ "$HAS_TODO" = "0" ]; then
  section_name="${SECTION_NAME:-Features}"   # Step 2 收集的；默认 Features
  cat > TODO.md <<EOF
# TODO

## ${section_name}

EOF
fi

# 创建 docs/spec/ 和 docs/spec/_done/（git 不追踪空目录，用 .gitkeep 占位）
if [ "$HAS_SPEC_DIR" = "0" ]; then
  mkdir -p docs/spec
  touch docs/spec/.gitkeep
fi
if [ "$HAS_DONE_DIR" = "0" ]; then
  mkdir -p docs/spec/_done
  touch docs/spec/_done/.gitkeep
fi
```

**禁止动作**：
- 已有 `TODO.md` 不重写（即使内容不规范也只警告，让用户自己调）
- 已有 `docs/spec/` 不清空、不动其内容
- 不创建 `.worktrees/` 目录本身（stage2 创建 worktree 时自然产生）

#### Step 4: Patch .gitignore

仅当 `HAS_GITIGNORE=0` 时：

```bash
# 如果 .gitignore 不存在 → 新建
if [ ! -f .gitignore ]; then
  cat > .gitignore <<EOF
# todo-driver pipeline
.worktrees/
EOF
else
  # 已有 .gitignore 但没含 .worktrees/ → 追加
  echo "" >> .gitignore
  echo "# todo-driver pipeline" >> .gitignore
  echo ".worktrees/" >> .gitignore
fi
```

**不**追加 `.review-artifacts/` —— stage2 把它放在 worktree 内部，`.worktrees/` 一忽略就连带忽略了。

#### Step 5: Commit + Push

```bash
# 校验 staged 列表只包含本次预期变更（防御性检查）
git add TODO.md docs/spec/ .gitignore 2>/dev/null
staged=$(git diff --cached --name-only)
# 允许的文件清单
expected_re='^(TODO\.md|docs/spec/(\.gitkeep|_done/\.gitkeep)|\.gitignore)$'
unexpected=$(echo "$staged" | grep -vE "$expected_re" || true)
if [ -n "$unexpected" ]; then
  echo "ERROR: unexpected staged files:"
  echo "$unexpected"
  git reset HEAD
  exit 1
fi

# Staged 为空（全部已存在）→ 进幂等分支（理论上 Step 1 已经拦掉，这是双保险）
if [ -z "$staged" ]; then
  echo "nothing to commit, already initialized"
  exit 0
fi

git commit -m "chore(todo-driver): init pipeline skeleton

Initialize project for todo-driver pipeline:
- TODO.md (or kept existing)
- docs/spec/ + docs/spec/_done/ with .gitkeep
- .gitignore += .worktrees/

Next: use 'todo-driver add-todo' to append items; cron will pick up via stage1."

init_sha=$(git rev-parse HEAD)
git push origin "${default_branch}" 2>&1 || echo "WARN: push failed, init committed locally only (sha=${init_sha})"
```

#### Step 6: Verify and Report

```bash
# 验证最终状态
test -f TODO.md && test -d docs/spec && test -d docs/spec/_done && \
  grep -qxE '\.worktrees/?' .gitignore || { echo "ERROR: post-init verification failed"; exit 1; }
```

### Output Contract（init）

报告必须包含：

- `mode: init`
- `project_root`: 工程绝对路径
- `default_branch`: 探测出的默认分支
- `actions_taken`: 数组，列出本次实际做了哪些动作（如 `["created TODO.md", "created docs/spec/", "patched .gitignore"]`）；幂等空跑时为 `[]`
- `init_commit`: commit SHA（`pushed | local-only | no-op`）
- `next_step`:
  - 全新初始化：`项目已就位。下一步：跑 'todo-driver add-todo' 添加第一条 TODO；或者直接编辑 TODO.md`
  - 幂等空跑：`项目已经初始化过，无需操作`

### Common Failure Modes（init）

**1. 不在 git 仓库 / 不在根目录**：Step 1 拦截，报错 stop。本 mode 不替用户跑 `git init`。

**2. 工作树脏被卷入 init commit**：Step 1 检测脏拒绝执行；Step 5 staged 文件白名单校验是双保险。

**3. 不在默认分支跑 init**：可能把 init commit 落在 feature branch 然后被忘掉。Step 1 强制拒绝。

**4. 重写已有 TODO.md / docs/spec/**：本 mode 是**补缺失项**模式，已存在的内容一律不动，哪怕看着不规范也只警告不修改。

**5. push 失败导致下次 cron 看到本地有 commit 远端没有 → 状态不一致**：push 失败不报错只 WARN（本地 commit 已落地，stage2 同机能看到）；多机协作场景下用户该手动 push。

---

## Mode `add-todo`

只做一件事：向 `cwd` 下的 `TODO.md` 追加一条带 slug 的新 TODO。

> 历史：本 mode 在 v1 叫 `init`，v2 改名 `add-todo`（init 让位给真正的初始化 mode）。

### Required Workflow（add-todo）

按以下顺序：

1. 探测环境
2. 一次性收集所需输入（summary + 可选 hints + 可选 depends_on）
3. 生成或校验 slug
4. 追加条目到 TODO.md 正确位置
5. 输出报告

不要在 Step 2 之后还重复追问已知信息。

#### Step 1: Probe Environment

```bash
test -f TODO.md && echo "TODO_MD_EXISTS" || echo "TODO_MD_MISSING"
test -d docs/spec && echo "DRIVER_ACTIVE" || echo "DRIVER_INACTIVE"
```

判定：

- `TODO.md` 不存在 → **报告用户先跑 `todo-driver init` 初始化项目**，stop。本 mode 不替用户创建（这是 init mode 的职责）
- `TODO.md` 存在但 `docs/spec/` 不存在 → 同样提示用户跑 `todo-driver init` 把流水线补齐，**但允许继续追加**（TODO 可以照样写）
- 两者都在 → 标准流程

同时收集 TODO.md 中所有已存在的 slug：

```bash
grep -oE '`[a-z0-9][a-z0-9-]*[a-z0-9]`' TODO.md | tr -d '`' | sort -u
```

#### Step 2: Collect Inputs (一次问完)

用 **AskUserQuestion** 一次性问完，最多 3 个 question，绝不分轮追问。

| 问题 | 必答? | 说明 |
|---|---|---|
| Summary | 是 | 一句话描述这个 TODO 要做什么 |
| Hints / 约束 | 否 | 任何对实现的偏好或限制；会原样附在 TODO 行末括号里 |
| Depends on（slug 列表）| 否 | 必须在哪些 slug 完成后才能做；逗号分隔 |

如果用户在调用时已经把这些信息**完整**写在 prompt 里 → **不要**再问，直接进 Step 3。

模糊回复（"随便"/"都行"）→ 取空值默认，不追问。

#### Step 3: Generate or Validate Slug

**生成规则**（用户没指定 slug 时）：

1. 从 summary 提取 3-5 个关键词（去虚词、动词转名词形式）
2. 中文 summary → 用关键词的英文翻译，例：
   - "支持主题切换" → `theme-toggle`
   - "扩展使用日志" → `extension-usage-log`
   - "多浏览器同步" → `multi-browser-sync`
3. kebab-case 拼接，3-30 字符，仅 `a-z0-9-`
4. 校验唯一性：不在 Step 1 收集的现有 slug 集合中
5. 若冲突 → 加**语义**后缀（`-ui` / `-api` / `-system`），不用数字递增

**手动指定 slug 时**：

- 校验正则 `^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$`
- 不合法 → 拒绝，给用户合法版本，让用户回 yes/no
- 已存在 → 拒绝，告诉用户在哪一行已经用了
- 这是本 mode 唯一允许的二次追问场景

#### Step 4: Append to TODO.md

定位写入位置（优先级）：

1. 有 `## Features` 区段 → append 到该区段末尾
2. 有 `## TODO` 或 `## Backlog` 区段 → 同上
3. 都没有 → 在文件末尾新增 `## TODO` 段 + 该条目

条目格式（严格遵守）：

```md
- [ ] `<slug>` <title> — <summary>
```

如有 hints，用 `(<hint 1>; <hint 2>; ...)` 拼到行末，**多条 hints 必须用英文分号 `;` 分隔**（详见"Shared Constraints → TODO.md 格式"节），单条 hints 内可自然使用任何标点：

```md
- [ ] `theme-toggle` 主题切换 — 支持深色/浅色/跟随系统三态 (复用 src/hooks/useDarkMode; 不引入新依赖; 必须支持 RTL)
```

收集 hints 时**鼓励一次到位**，每条聚焦一个约束方向（实现倾向 / 范围限制 / 必达指标 / 走查要求 / 已知风险），stage1 起 spec 时会按语义路由到对应章节。

如有 depends_on：**不**写入 TODO.md（depends_on 是 spec 字段，stage 1 起草 spec 时再写），仅在报告中提示。校验每个 depends_on 在 TODO.md 或 `docs/spec/_done/` 中是否存在，不存在的列出来警告但**不阻止**追加。

#### Step 5: Verify and Report

```bash
grep -n "^\- \[ \] \`<slug>\`" TODO.md
```

返回 1 行 → 成功，记录行号。
返回 0 或 >1 行 → 写入异常，stop 并报告。

### Output Contract（add-todo）

报告必须包含：

- `mode: add-todo`
- `slug`: 最终 slug
- `title`: 提取的 title
- `line`: 在 TODO.md 中的行号
- `depends_on`: 数组（若提供）
- `depends_warn`: 未找到的依赖 slug 列表（若有）
- `next_step`:
  - 走 todo-driver：`等 stage 1 cron 起草 spec，到时审 docs/spec/<slug>.md`
  - 未启用 todo-driver：`已记录到 TODO.md。你可以手动起草 spec`

### Common Failure Modes（add-todo）

**1. 替用户创建 TODO.md**：可能在不该有 TODO 的目录留下空文件。处理：报告"不存在"，提示跑 `todo-driver init`，stop。本 mode 永远不替用户做初始化。

**2. slug 冲突时数字递增**：`theme-toggle` 已存在 → 自动用 `theme-toggle-2`。处理：用语义后缀，或问用户。

**3. 把 hints 当依赖写**：hints 是自由文本写到行末括号；depends_on 必须是合法 slug 引用。

**4. 修改已有 TODO 条目**：本 mode **只追加**，不改已有。即使重复也作为新条目。

**5. 在非项目根调用**：只看 cwd 一级，不向上找。

---

## Mode `review-merge`

整合 3 件事到一次调用：审 → 合 → 清。任一审核环节不过 → 走 **reject 路径**（findings 回写 spec，status 退回 approved 让 stage 2 重做）。

### Required Workflow（review-merge）

按以下顺序：

1. 探测候选 spec 列表
2. 若多个 → 用户选；1 个 → 直接进入；0 个 → idle 报告
3. 准备 review 环境（fetch、定位 branch、识别 worktree 位置、检查脏工作树）
4. 跑 hard gates
5. 对照 spec 验收
6. 工程规范校验
7. 事后审改动规模 / 高风险信号
8. 产出 review report → 通过 / 不通过判定
9. **通过路径**：squash merge + 清理
10. **不通过路径**：findings 回写 spec
11. （若 merged）检查 epic 父项是否可关闭

不要跳过 Step 4-7 任一个直接进 merge。**stage1 一律 approved 不代表免审**——事后审 diff 是否符合 spec 估算才是本 mode 的核心价值。

#### Step 1: List Candidates

```bash
ls docs/spec/*.md 2>/dev/null
```

对每个 spec 读 frontmatter 提取 `id`、`status`、`updated`、`epic`。筛 `status: ready-for-review` 的：

- 0 个 → 输出 idle JSON + 提示"stage 2 还没跑完"
- ≥ 1 个 → 进入 Step 2

#### Step 2: Pick Target

- 只有 1 个 → 直接用
- 多个 → AskUserQuestion 列出来让用户选，附 `updated` 时间
- 用户在调用 prompt 里指定了 slug → 校验该 slug 在 ready 列表里；不在 → 报错并列实际 ready 的

#### Step 3: Prepare Review Environment

```bash
git fetch origin
git rev-parse --verify todo/<slug>           # 校验 branch 存在
test -d .worktrees/<slug> && WORKTREE_PATH=.worktrees/<slug> || WORKTREE_PATH=""
```

worktree 存在 → 在 worktree 内跑 hard gates；不存在但 branch 存在 → 主仓库 `git checkout todo/<slug>`（保存初始 branch 名）。

**工作树脏检查**：主仓库 `git status --porcelain` 非空 → **拒绝执行**。

#### Step 4: Hard Gates

按 `package.json scripts` / `Makefile` / `Cargo.toml` / `pyproject.toml` 选命令。常见 JS：

```bash
pnpm install --frozen-lockfile 2>&1 | tail -5  # 仅 lockfile 改了才必跑
pnpm lint 2>&1 | tail -10
pnpm test -- --run 2>&1 | tail -20
pnpm build 2>&1 | tail -10
```

每个 gate 记 command / exit code / 关键输出 tail。任一失败 → Step 8 判 REJECT。

**禁止**：`--no-verify` 跳 hook；"flake" 重跑；跳 build。

#### Step 5: Acceptance Criteria 对照

从 spec `## 验收标准` 提取所有 checkbox。逐条判 `pass` / `fail` / `subjective`。

- 可自动验证 → 直接判
- 主观项 → 标 `subjective`，留到 report 让用户最后决定

任一 `fail` → REJECT。全 `pass` 或 (`pass` + `subjective`) → 进 Step 6。

#### Step 6: 工程规范校验

按三级回退找规范源头：

1. `<project-root>/AGENTS.md` ← 首选
2. `<project-root>/CLAUDE.md` ← 次选
3. 都没有 → 仅通用检查

通用检查（永远跑）：
- diff 无 `console.log` / `debugger` / 未关联 issue 的 `TODO:`
- 不改 lockfile 除非 spec 授权新依赖
- commit message 风格对齐 `git log --oneline -10`

硬规则违反 → REJECT。建议性违反 → subjective。

#### Step 7: 事后审改动规模（取代旧 self_approved 审计）

> 历史背景：旧版 stage1 prompt 用 `self_approved: true/false` 决定要不要进 stage2，这里事后审。新版 stage1 取消了人工审核环节——所有 spec 一律 `status: approved` 直接进 stage2。**事后审依然必要**，但审的对象从"声明是否成立"变成"实际 diff 是否符合 spec 估算"。

读 spec frontmatter 与正文，提取：

- spec 在"影响范围"区段的**估算文件数 / 行数**
- spec 在"风险"区段是否标了**高风险信号**（⚠️ 标记）

对照实际 diff：

```bash
git diff --shortstat ${default_branch}...todo/<slug>
git diff --name-only ${default_branch}...todo/<slug>
```

判定规则：

- 实际改动文件数 / 行数**显著超过** spec 估算（如估 5 文件实际 20 文件 / 估 200 行实际 800 行）→ PASS 但 report 高亮 `change_size_drift: true`，让 review 关注是否 scope creep
- 实际改动**触及高风险类别**（auth / payments / 加密 / 数据迁移 / 跨模块重构 / 新增依赖 / 公开 API 变更）但 spec 风险区段**未标注** → PASS 但 report 高亮 `unflagged_risk: <类别>`
- 实际改动文件**严重超出** spec 影响范围列表（命中规模漂移**且**高风险未声明，二者并存）→ REJECT，理由 "actual diff diverges from spec significantly"

单一信号触发只标注、不 REJECT；多信号叠加才 REJECT。

#### Step 8: Output Review Report

报告结构：

```md
## Review Report: <slug>

### Hard Gates
- lint: pass | fail (<reason>)
- typecheck: pass | fail
- test: <n> passed | <m> failed
- build: pass | fail

### Acceptance Criteria
- [x] criterion 1 (verified by ...)
- [ ] criterion 2 (subjective)
- [ ] criterion 3 (FAIL — <reason>)

### Engineering Rules (source: AGENTS.md | CLAUDE.md | generic)
- ✅ / ❌ each rule

### Diff Audit (取代旧 Self-Approval Audit)
- 改动: <n> files / <m> lines
- spec 估算: <n> files / <m> lines
- change_size_drift: true | false
- unflagged_risk: <none | auth/payments/migration/...>
- 结论: diff_diverges_from_spec: true | false

### Verdict
PASS | REJECT
- 原因: <一句话>
- Must-fix（仅 REJECT）:
  - <item>
```

判定规则：
- 任一 hard gate fail / acceptance fail / 工程规范硬规则违反 / diff audit 多信号叠加（change_size_drift + unflagged_risk 同时命中）→ REJECT
- 否则 → PASS

#### Step 9: Pass Path (Squash Merge + Cleanup)

按顺序，**每一步失败都报错并 stop**，不要静默继续：

```bash
# 1. 回主仓库 + main
cd <project-root>
git checkout main
git pull --ff-only origin main

# 2. squash merge
git merge --squash todo/<slug>
SQUASH_MSG="<spec.title>

Source: docs/spec/<slug>.md
Spec was reviewed and merged via todo-driver review-merge."
git commit -m "$SQUASH_MSG"

# 3. mv spec 到 _done/
mkdir -p docs/spec/_done
git mv docs/spec/<slug>.md docs/spec/_done/<slug>.md

# 4. 标 TODO 为 [x]（注意保留 epic 子项缩进）

# 5. archive commit
git add docs/spec/_done/<slug>.md TODO.md
git commit -m "chore(todo): archive <slug> spec and mark TODO as done"

# 6. 删 worktree（删之前检查 .worktrees/<slug> 工作树是否干净）
git -C .worktrees/<slug> status --porcelain # 非空 → 拒绝 remove
test -d .worktrees/<slug> && git worktree remove .worktrees/<slug>

# 7. 删 local branch
git branch -D todo/<slug>

# 8. 删 remote branch（若存在）
git push origin --delete todo/<slug> 2>/dev/null || echo "remote branch already gone"

# 9. push main
git push origin main
```

**Constitution gate**（Step 9 高风险）：
- IM 会话（`CC_SESSION_KEY` 非空）→ 自动 push（用户调用本 skill 已是显式授权 full flow）
- 终端直连 + protected branch → 让 push 失败，告知用户手动处理
- **永远不**用 `--force` / `--force-with-lease`

#### Step 10: Reject Path (Findings → Spec)

1. **不动 main**（不 merge）
2. **不删** branch / worktree（用户要去 fix）
3. 切到 branch `todo/<slug>`（或进 worktree）
4. spec 末尾追加：

```md
## Review feedback (<today T HH:MM Z>)

### Verdict
REJECT

### Must-fix
- <item 1>
- <item 2>

### Details
<逐条详细 + 引用 file:line>
```

5. 更新 frontmatter：
   - `status: approved`（不是 draft —— 避免人重审）
   - `updated: <today>`
   - `attempts` 不变（review 不算 stage 2 尝试）

6. commit + push spec 修改：

```bash
git add docs/spec/<slug>.md
git commit -m "chore(todo): review feedback for <slug>"
git push origin todo/<slug>
```

7. 切回主仓库初始 branch

#### Step 11: Epic Auto-Close（仅 Pass Path 后）

如果刚 merged 的 slug 是某 epic 子项（命名 `<epic-slug>-<suffix>`）：

```bash
# 找父 epic：往上找最近的非缩进 `- [ ] \`<epic-slug>\``
grep -rE "^  - \[.\] \`<slug>\`" TODO.md
```

如果找到父 epic：

1. 列 epic 所有子 slug（TODO.md 中缩进在 epic 下方的所有 `- [ \`<x>\`` 行）
2. 检查每个子 slug 对应的 spec 是否在 `docs/spec/_done/`（**只看 `_done/`，不看 TODO 复选框**）
3. 全部 done：
   - epic 行 `- [ ]` → `- [x]`
   - epic 对应 spec 若在 `docs/spec/`，mv 到 `_done/`
   - 多一个 commit：`chore(todo): close epic <epic-slug>`
   - push

未全 done → 不动 epic，输出 "epic <epic-slug> 进度 X/Y，未关闭"

### Output Contract（review-merge）

报告必须包含：

- `mode: review-merge`
- `slug`: 处理的 slug
- `verdict`: `merged` / `rejected` / `idle` / `refused`
- `merge_sha`: 仅 merged 时（main 上的 squash commit SHA）
- `must_fix`: 仅 rejected 时的清单
- `epic_closed`: 若关联 epic 也关闭了，列出 epic slug
- `push_status`: `pushed` / `failed`（push main 是否成功）
- `cleanup_status`: `complete` / `partial`（branch/worktree 是否全清掉）
- `next_step`:
  - merged: `merge 完成，下一个 TODO 可让 stage 2 拾起`
  - rejected: `findings 已写回 spec，等 stage 2 重做`
  - idle: `没有 ready-for-review 的 spec`
  - refused: `<拒绝原因>`

### Common Failure Modes（review-merge）

**1. Hard gates 红了还推**：lint fail 视为"小事"。任一 red → 必 REJECT，不豁免。

**2. Subjective acceptance 自动判通过**：spec 写"UX 友好"agent 自己判 pass。处理：subjective 必须让用户确认。

**3. diff audit 信号被忽略**：实际改动远超 spec 估算或触及未声明的高风险类别，仍照常合并。处理：单信号高亮、双信号叠加必 REJECT。

**4. Pass path 中途失败留半成品**：squash commit 成功，spec 归档 commit 失败。处理：报错 stop，给用户手动收尾命令，**不**尝试 reset 已合并 commit。

**5. 误删用户自己的 worktree**：worktree 内有未提交修改被 remove 删掉。处理：删前检查 `status --porcelain`，非空拒绝 remove。

**6. epic 误关闭**：父 epic 还有子项 status=draft 在 `docs/spec/`（没 done），但 TODO.md 上看起来都 [x]。处理：epic 关闭判定**只**看 `docs/spec/_done/`，不看 TODO 复选框。

**7. 主仓库工作树脏照样开干**：把用户脏改动卷入 review。处理：Step 3 检查到脏 → refuse。

**8. 跨过用户确认 force push**：push main 被 protected 拒，改用 `--force-with-lease`。处理：永远不 force push 到 main。push 失败 → 报告手动处理。

---

## Templates / Reference Files

要在新项目上启用 TODO Driver 流水线，下列模板存在本 skill 的 `references/` 下，可以直接复制到项目或喂给 cron agent：

| 文件 | 用途 | 何时取出 |
|---|---|---|
| `references/state-model.md` | 完整系统说明：状态机 / TODO.md 格式 / spec.md frontmatter / Worktree 命名 / 调用拓扑 | 用户问"todo-driver 是什么 / 怎么用"时；首次给项目初始化流水线时 |
| `references/stage1-prompt.md` | Stage 1 cron 喂给 agent 的 prompt：**完全无入参 self-driving**，遍历硬编码工程清单 → 找首个未起 spec 的 TODO → 出 spec（一律 `status: approved`）→ commit + push 到默认分支 | 用户要把 stage 1 接到 cron / 想手动跑一次起草 spec 时 |
| `references/stage2-prompt.md` | Stage 2 cron 喂给 agent 的 prompt：**完全无入参 self-driving**，遍历工程清单 → 找首个无残留 worktree/branch 的 approved spec → 开 worktree → 实现 + 验证 + 可选 Playwright 走查 → push branch；遇到残留按 `needs_cleanup` / `awaiting_review` 分类报告 | 用户要把 stage 2 接到 cron / 想手动跑一次 dev 时 |

**怎么给用户**：
- 用户问"用法"/"怎么部署" → Read `references/state-model.md` 节选关键部分回答
- 用户要"试跑 stage 1 / 我想看看 prompt 长啥样" → 用 Read 工具读 `references/stage1-prompt.md` 整篇，或 cp 到用户指定路径
- 用户要"接 cron" → 给出读取这两个 prompt 文件的具体命令（cron 程序按需 `cat` / 加载）

**这些 reference 是状态机的契约定义**。改它们等于改 stage 1/2 prompt 端的行为，必须同步审视 `init` / `review-merge` 两个 mode 的 SKILL.md 是否还对齐。普通迭代只动 SKILL.md 不动 references/。

---

## Shared Constraints

两个 mode 都必须遵守，**不可妥协**：

### Slug 格式
正则 `^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$`，kebab-case，3-30 字符。

### Spec frontmatter 字段名（严格对齐 stage 1/2 prompt + cases.md）
`id` / `title` / `status` / `kind` / `epic` / `depends_on` / `attempts` / `project_root` / `needs_visual_check` / `needs_video_check` / `created` / `updated`

> ⚠️ 旧字段 `self_approved` / `self_approved_reasons` 在 v2 stage1 prompt 中已删除（所有 spec 一律 `status: approved`，无人工审核环节）。如读到老 spec 仍带这两个字段，忽略即可。

### 工程规范源头（三级回退）
1. `<project-root>/AGENTS.md`
2. `<project-root>/CLAUDE.md`
3. 通用规则（lint / typecheck / tests / 无意外依赖）

### TODO.md 格式
```md
- [ ] `<slug>` <title> — <summary> (<hint 1>; <hint 2>; <hint 3>)
```

- `- [ ]` = 未合并（pending / draft / approved / in-progress / ready）
- `- [x]` = 已合并（由 review-merge mode 在 merge 后改）

**hints 抽取规则**（stage1 / agent 都按此处理，不允许另行解释）：

- 行末**一对**括号 `( ... )` 内是 hints；正则 `\(([^)]+)\)\s*$` 抽出整段
- 整段内用**英文分号 `;`** 分隔成多条 hints；中文逗号 / 英文逗号 / 中文分号 **都不当分隔符**——这样允许单条 hints 内自然使用逗号
- 每条 hints 是对本 spec 的硬性约束。语义自由（实现倾向 / 范围限制 / 必达指标 / 走查要求 / 已知风险都可以），由 stage1 路由到 spec 对应章节
- 无 hints 时整对括号可省略

示例：

```md
- [ ] `theme-toggle` 主题切换 — 三态切换 (复用 src/hooks/useDarkMode; 不引入新依赖; 必须支持 RTL)
```

### 高风险动作护栏
- merge / push main / 删 branch 都属高风险，**永远不 force**
- IM 会话调用即视为 full flow 授权；终端调用且 main protected → push 失败让用户手动
- 工作树脏 → refuse；半成品 commit → stop 不静默继续
- 不修改 stage 1/2 prompt 的状态机定义（cron 端的文件不动）

### 不重复追问
若用户在调用 prompt 里已经把 mode + summary / slug + 其他参数说全 → 不再追问，直接执行。

## Minimal Operating Principle

本 skill 是 TODO Driver 流水线**人手触发端**的统一入口。

- 一次调用 = 一个 mode = 一个具体动作（追加 TODO **或** 合并 ready spec）
- 共享约束严格执行，**绝不**为了"流畅"绕过 hard gates、subjective 判定、diff audit
- "merge 了一半"比"完全没 merge"更糟；任何清理步骤失败 → 报错 stop
- mode 边界清晰：init **不**碰 git 状态；review-merge **不**新增 TODO 条目

若做不到"原子干净"，就不要假装能安全完成。
