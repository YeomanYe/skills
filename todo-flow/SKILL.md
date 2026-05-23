---
name: todo-flow
description: >
  TODO Flow 流水线(TODO → spec → dev → done)人手触发端点(human-facing endpoints)。
  6 模式:`init`(项目接入流水线 / onboard) / `add`(加带 slug 的 TODO) / `adjust`(panel 调整未起 spec 的 TODO 顺序与 hints) /
  `revise`(给已 verify 的 spec 写返工指令 + status → needs-rework) /
  `exec`(前台 orchestrator 自闭环跑 stage1→2→3 直到 verified/blocked,per-stage subagent + 心跳轮询 + director-* AND-pass + cc-connect 同步推 IM,通用 agent backend) /
  `done`(审 ready spec + squash merge + semver bump + CHANGELOG;旧名 review-merge)。
  触发短语:「todo-flow <mode>」/「初始化 todo-flow」/「加 TODO」/「调整 todo 顺序」/「修订 spec」/「批量执行 todo」/「自动循环 stage 直到 verified」/「done 这个 todo」;
  英文:「setup todo-flow / add todo / reorder todo / revise spec / auto-loop until verified / run all pending specs end-to-end / foreground orchestrator」;
  兼容旧名:「todo-driver <mode>」/「review-merge」。
  Do NOT use for: 改/删 slug、不带 slug 的备忘、通用 PR review(→ requesting-code-review)、
  stage 1/2/3 cron prompt 本身、长跑无验收标准的 codex 后台任务(→ flow-codex-goal)。
  完整触发清单与每 mode 详细流程见 SKILL.md Overview + 各 `## Mode <name>` 段。
---

# todo-flow

## Overview

本 skill 是 TODO Flow 流水线**人手触发**的六个端点：

- **`init`**：把一个普通工程**初始化**为支持 todo-flow 流水线的工程——创建 `TODO.md` + `docs/spec/` + 改 `.gitignore`。一次性动作，幂等。
- **`add`**：向项目 `TODO.md` 追加一条带 slug 的待办，让 stage 1 cron 起草 spec。
- **`adjust`**：进入 TODO panel 模式，用编号表格连续调整**还没起 spec** 的 TODO：改顺序、修改条目内容、追加 hints；直到用户说退出才一次性 commit + push。
- **`revise`**:在 verify 完(stage3 跑出 `verified` / `verify-failed`)或人审 ready-for-review 觉得要改时,用 panel 模式给 spec 写 rework 指令,改 status 为 `needs-rework`,让 stage 2 下次拾起重做。
- **`exec`**:**前台 orchestrator**,对一个或多个项目的若干 spec 自闭环驱动 stage1→stage2→stage3 直到 verified 或 blocked。per-stage 派 subagent(支持 codex / Claude Code 两种 backend),心跳轮询防卡死,stage3 verified 前按 spec frontmatter 增派 director-* 做 AND-pass 仲裁,每步通过 cc-connect 同步推 IM(凭证 + 评论)。**完全无人审介入,但不自动 done**(`done` 仍是高风险最后一关,exec 跑完 verified 后用户手工 `todo-flow done`)。详见 `references/exec-orchestrator-prompt.md`。
- **`done`**：审核 `status: ready-for-review` **或 `verified`**(stage3 通过)的 spec，pass 则 squash merge 到默认分支 + **semver 版本升级**(默认 patch,可 `--version <kind>` 指定) + **写 CHANGELOG.md 条目**(Keep a Changelog 风格) + 归档 spec 到 `_done` + 原子清理 branch/worktree/TODO。`verified` 表示已过 stage3 自动验证,人工 review 时可信度更高。

中间的 stage 1（起草 spec）/ stage 2（开发 + push branch）/ **stage 3（验证 + 飞书回传）**由 cron 喂的 prompt 接管（详见 references 下的 stage1-prompt、stage2-prompt、stage3-verify-prompt 三个文件），不在本 skill 范围。

**stage 3**（`stage3-verify-prompt.md`）独立 cron 跑：选 `status: ready-for-review` 的 spec → 跑 hard gates + Playwright 走查 → 通过 `lark-cli`（headless env-var 模式）发飞书报告（截图 + 错误日志）→ 改 status 为 `verified` 或 `verify-failed`。**跟 stage1/2 完全隔离无感知**，通过 spec status 状态机自然接力。飞书凭证（`${LARK_APP_ID}` / `${LARK_APP_SECRET}` / `${LARK_CHAT_ID}`）和工程清单（`${PROJECTS_ARRAY}`）都是占位符，调用方字符串预处理后再喂给 agent。

核心原则：
- **一次调用只处理一个 mode**，不混做
- mode 解析有明确顺序，不靠模糊推测
- 共享约束严格对齐（slug 格式 / frontmatter 字段名 / 工程规范源头）
- 高风险动作（merge / push / 删 branch）有硬护栏

## Modes

| Mode | 触发场景 | 主要副作用 | 风险等级 |
|---|---|---|---|
| `init` | 用户要把一个项目接入 todo-flow 流水线 | 创建 `TODO.md` + `docs/spec/` + 改 `.gitignore` 加 `.worktrees/` + `.todo-flow/`；幂等 | 低 |
| `add` | 用户要新建带 slug 的 TODO | 在 `TODO.md` 对应段末追加一行 | 低 |
| `adjust` | 用户要给**还没起 spec** 的 TODO 改顺序 / 修改内容 / 补思路 | 进入 panel 模式，连续改 `TODO.md`；退出后 commit + push | 低 |
| `revise` | 用户要给已 verify(失败/通过) 的 spec 写返工指令 | 在 spec 头部插入 `## Rework instructions`,status → `needs-rework`,commit + push | 中 |
| `exec` | 用户要前台自闭环跑完一批 spec(stage1→2→3 直到 verified) | 派 per-stage subagent + 心跳轮询 + 自动重做 verify-failed + 增派 director-* + 每步同步推 IM；不自动调 done | 中 |
| `done` | 用户要审核并完成 ready spec | squash merge + 归档 spec 到 `_done` + 删 branch/worktree + push 默认分支 + semver bump + CHANGELOG | 高 |

## Resolving Mode

按以下顺序判定：

1. **用户显式指定**（如 `todo-flow init` / `todo-flow add` / `todo-flow adjust` / `todo-flow revise` / `todo-flow exec` / `todo-flow done`；旧 mode `todo-flow review-merge` 与旧 skill 名 `todo-driver <mode>` 同样兼容）→ 用指定的
2. **触发短语推断**：
   - 含"初始化"/"接入"/"setup"/"onboard" + "todo-flow"/"todo-driver"/"todo 流水线" → `init`
   - 含"新建"/"加"/"记"/"create"/"add" + "TODO"/"待办" → `add`
   - 含"调整"/"排序"/"插到前/后"/"挪"/"补思路"/"补充 hints"/"修改 todo"/"panel 模式"/"reorder"/"move X before/after"/"add hints" + "todo"/具体 slug → `adjust`
   - 含"修订"/"revise"/"返工指令"/"rework"/"needs-rework" + "spec"/"todo" → `revise`
   - 含"批量执行"/"并发跑"/"自动跑完"/"自动循环 stage"/"无人值守"/"exec"/"foreground orchestrator"/"auto-loop until verified" + "todo"/"spec" → `exec`
   - 含"done"/"完成"/"标记完成"/"review"/"审"/"合并"/"merge" + "todo"/"spec"/"ready" → `done`
3. **状态推断**（兜底）：
   - 项目根**没有** `TODO.md` 也**没有** `docs/spec/` → 倾向 `init`（流水线还没接入）
   - 项目根有 `docs/spec/*.md` 且至少 1 个 `status: ready-for-review` → 倾向 `done`
   - 否则 → 倾向 `add`（注：`adjust` / `revise` / `exec` 不进兜底——它们需要明确的意图,不应被状态推断自动选中）
4. **模糊但含"跑/执行/批量/自动/无人值守/auto"等动作词** → 用 AskUserQuestion 在 `exec` / `done` 之间二选一(都是"推进流水线"语义,但安全等级差很多);**不要**默认 `add`
5. **仍模糊** → 用 AskUserQuestion 多选一（init / add / done / exec）

判定后**立即声明**当前 mode（一句话），再开始执行。用户在调用上下文里明确给了 mode 就不要二次确认。

> ⚠️ **历史改名**：v1 的 `init` 是"追加 TODO"，v2 重命名为 `add`，`init` 这个词回归"初始化"本意。看到旧调用 `todo-flow init` 而上下文是"加 todo"语义时，自动按 `add` 处理并提示一次新名字。

> ⚠️ **skill 改名**：本 skill 旧名是 `todo-driver`，现名 `todo-flow`。看到 `todo-driver <mode>` 时按 `todo-flow <mode>` 处理，并在报告里提示一次旧名兼容；不要因为旧名存在就拒绝执行。

> ⚠️ **mode 改名**：最终收口 mode 旧名是 `review-merge`，现名是 `done`。看到 `review-merge` 时按 `done` 处理，并在报告里提示一次旧 mode 兼容；对外输出优先使用 `mode: done`、`verdict: done`。

## When to Use

满足任一即可触发：
- 用户想把一个项目接入 todo-flow 流水线（无 `TODO.md` / `docs/spec/` 的工程）
- 用户描述了一个想加进 `TODO.md` 的新需求/功能/重构
- 用户想给一个**还没起 spec** 的 TODO 改顺序 / 修改内容 / 补 hints（关键交互路径 / 核心思路 / 新约束）
- 用户想给一个已经 stage2/3 跑过的 spec 写返工指令(verify-failed 或不满意 verified)
- 用户想前台自闭环跑完一批 spec(stage1→2→3 直到 verified 或 blocked,无人审介入)
- 项目有 `docs/spec/*.md` 文件且其中至少一个 `status: ready-for-review`，用户希望审核并完成该 TODO
- 用户在 todo-flow 流水线相关的上下文里提及 init / add / adjust / revise / exec / done / review / merge 这类动作

## When NOT to Use

- 用户在做不需要编号面板、也不需要 commit/push 的随手 TODO 文案小改（直接 Edit）
- 用户只想随手记一行不需要被流水线处理（直接 Edit TODO.md）
- 用户在做通用 PR 审查（用 `requesting-code-review`）
- 用户要 merge 一个不在 todo-flow 流水线里的分支（直接 `git merge`）
- 用户在问"如何用 todo-flow"等元问题（解释，不真的执行）

> 注：之前列的"项目不走 todo-flow" 已不再是 NOT to use 条件——因为 `init` mode 正是用来把这种项目接入的。

---

## Mode `init`

把一个普通工程**初始化**为支持 todo-flow 流水线的工程。一次性、幂等——已经初始化过再跑只会补缺失项，不破坏现有内容。

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

确保 `.worktrees/`（stage2 创建的开发隔离区）在 ignore 列表里。stage2 把走查产物 `.review-artifacts/` 存在 worktree 内部，已经被 `.worktrees/` 一并忽略，**不需要单独列**。

```bash
add_if_missing() {
  local pattern="$1"
  if [ ! -f .gitignore ] || ! grep -qxE "$(echo "$pattern" | sed 's@/@/?@')" .gitignore; then
    [ -f .gitignore ] || touch .gitignore
    # 第一次追加 todo-flow 区块时打个 header
    if ! grep -qxF "# todo-flow pipeline" .gitignore; then
      echo "" >> .gitignore
      echo "# todo-flow pipeline" >> .gitignore
    fi
    echo "$pattern" >> .gitignore
  fi
}

add_if_missing ".worktrees/"
```

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

git commit -m "chore(todo-flow): init pipeline skeleton

Initialize project for todo-flow pipeline:
- TODO.md (or kept existing)
- docs/spec/ + docs/spec/_done/ with .gitkeep
- .gitignore += .worktrees/

Next: use 'todo-flow add' to append items; cron will pick up via stage1."

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
  - 全新初始化：`项目已就位。下一步：跑 'todo-flow add' 添加第一条 TODO；或者直接编辑 TODO.md`
  - 幂等空跑：`项目已经初始化过，无需操作`

### Common Failure Modes（init）

**1. 不在 git 仓库 / 不在根目录**：Step 1 拦截，报错 stop。本 mode 不替用户跑 `git init`。

**2. 工作树脏被卷入 init commit**：Step 1 检测脏拒绝执行；Step 5 staged 文件白名单校验是双保险。

**3. 不在默认分支跑 init**：可能把 init commit 落在 feature branch 然后被忘掉。Step 1 强制拒绝。

**4. 重写已有 TODO.md / docs/spec/**：本 mode 是**补缺失项**模式，已存在的内容一律不动，哪怕看着不规范也只警告不修改。

**5. push 失败导致下次 cron 看到本地有 commit 远端没有 → 状态不一致**：push 失败不报错只 WARN（本地 commit 已落地，stage2 同机能看到）；多机协作场景下用户该手动 push。

---

## Mode `add`

只做一件事：向 `cwd` 下的 `TODO.md` 追加一条带 slug 的新 TODO。

> 历史：本 mode 在 v1 叫 `init`，v2 改名 `add`（init 让位给真正的初始化 mode）。

### Required Workflow（add）

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

- `TODO.md` 不存在 → **报告用户先跑 `todo-flow init` 初始化项目**，stop。本 mode 不替用户创建（这是 init mode 的职责）
- `TODO.md` 存在但 `docs/spec/` 不存在 → 同样提示用户跑 `todo-flow init` 把流水线补齐，**但允许继续追加**（TODO 可以照样写）
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

### Output Contract（add）

报告必须包含：

- `mode: add`
- `slug`: 最终 slug
- `title`: 提取的 title
- `line`: 在 TODO.md 中的行号
- `depends_on`: 数组（若提供）
- `depends_warn`: 未找到的依赖 slug 列表（若有）
- `next_step`:
  - 走 todo-flow：`等 stage 1 cron 起草 spec，到时审 docs/spec/<slug>.md`
  - 未启用 todo-flow：`已记录到 TODO.md。你可以手动起草 spec`

### Common Failure Modes（add）

**1. 替用户创建 TODO.md**：可能在不该有 TODO 的目录留下空文件。处理：报告"不存在"，提示跑 `todo-flow init`，stop。本 mode 永远不替用户做初始化。

**2. slug 冲突时数字递增**：`theme-toggle` 已存在 → 自动用 `theme-toggle-2`。处理：用语义后缀，或问用户。

**3. 把 hints 当依赖写**：hints 是自由文本写到行末括号；depends_on 必须是合法 slug 引用。

**4. 修改已有 TODO 条目**：本 mode **只追加**，不改已有。即使重复也作为新条目。**改顺序 / 补 hints 应该走 `adjust` mode**。

**5. 在非项目根调用**：只看 cwd 一级，不向上找。

---

## Mode `adjust`

进入 **TODO panel 模式**，用编号表格连续调整 TODO：改位置（影响 stage1 下次挑哪条）、修改条目内容、追加 hints。面板不会在每次小改后立刻 commit；只有用户明确说"退出模式" / "退出" / "exit" / "done" 时，才统一校验、commit，并尝试 push。

> 设计原则：**一旦 stage1 给该 slug 起过 spec（`docs/spec/${slug}.md` 存在），spec 就成了事实源，本 mode 不再改 TODO 行的位置或实质内容**。要影响实现，直接 Edit `docs/spec/${slug}.md`。已 merge 的 `_done/${slug}.md` 一律不可改。

> 硬规则：`adjust` panel 退出时，只要 `TODO.md` 有实际改动，就必须创建一次 git commit，并且必须尝试 `git push origin ${default_branch}`。未 commit 的本地修改不能报告为完成；push 失败时只允许报告 `local-only`，不得静默吞掉。

### Required Workflow（adjust）

按以下顺序：

1. 探测环境
2. 进入 panel，输出完整 TODO 表格
3. 循环接收用户指令：移动 / 交换 / 修改 TODO / 添加 hint / 退出
4. 每次成功修改后立即输出完整表格
5. 单个 TODO 内容被改时，额外原封不动输出该 TODO 行
6. 用户退出后校验单文件改动 + commit + push
7. 输出报告

#### Step 1: Probe Environment

```bash
# 必须 git 仓库根 + 默认分支 + 工作树干净（panel 期间会产生 TODO.md 脏改动）
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || { echo "ERROR: not a git repo"; exit 1; }
test "$(git rev-parse --show-toplevel)" = "$(pwd -P)" || { echo "ERROR: must run at repo root"; exit 1; }

default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
default_branch=${default_branch:-main}
[ "$(git rev-parse --abbrev-ref HEAD)" = "$default_branch" ] || { echo "ERROR: must run on ${default_branch}"; exit 1; }
test -z "$(git status --porcelain)" || { echo "ERROR: working tree dirty before panel"; exit 1; }

test -f TODO.md || { echo "ERROR: no TODO.md, run 'todo-flow init' first"; exit 1; }
```

任一硬错 → stop，不进入 panel，不改文件。`.zread/`、临时文件、其它未跟踪文件都算脏工作树，避免退出时把用户改动卷入 commit。

#### Step 2: Render Panel Table（强制）

进入 panel 后，必须把 `TODO.md` 中所有未完成 TODO 以 Markdown 表格输出；每一行前面必须有从 1 开始的编号。每次成功修改后都重新输出完整表格，方便用户继续用编号调整。

表格字段固定：

```md
| # | slug | title | summary | hints | spec_state |
|---:|---|---|---|---|---|
| 1 | `theme-toggle` | 主题切换 | 支持深色 / 浅色 / 跟随系统三态 | 用 uiStore 管理 | none |
```

解析规则：
- 默认列出所有 `- [ ]` TODO 行；如果未来支持多段且用户指定段名，再只列该段。
- `spec_state`：
  - `none`：`docs/spec/${slug}.md` 和 `docs/spec/_done/${slug}.md` 都不存在
  - `pending-spec`：`docs/spec/${slug}.md` 存在
  - `done`：`docs/spec/_done/${slug}.md` 存在
- `hints` 取 TODO 行末最后一对括号内容；没有则填 `-`。
- 表格外不要省略长行。必要时保留完整内容，不能用 `...` 截断。

#### Step 3: Panel Commands

panel 持续到用户说"退出模式" / "退出" / "exit" / "done"。用户每次输入只解析为以下命令之一；不清楚时重新输出表格并用一句话提示支持的命令，不要猜。

| 命令 | 例子 | 行为 |
|---|---|---|
| 移动 | `9 放到 3 后面` / `move 9 after 3` / `8 移到 2` | 用当前表格编号解析目标和锚点，移动整行 |
| 交换 | `3,6 交换` / `swap 3 6` | 交换两条 TODO 行 |
| 修改 TODO | `改 4 title 为 大模型分组` / `改 4 summary 为 ...` / `改 4 为 <完整 TODO 行>` | 修改单行 title / summary / hints，或用一整条合法 TODO 行替换该行 |
| 添加 hint | `给 4 加 hint 设置里支持本地模型和远程模型` | 把一条 hint 追加到目标行末括号内 |
| 退出 | `退出模式` / `退出` / `exit` / `done` | 结束 panel，进入提交与 push |

编号必须来自当前表格。每次修改后编号可能变化；下一条用户指令必须基于最新表格重新解析。

判定矩阵：

| 状态 | 允许的动作 |
|---|---|
| `none`（spec 还没起） | **移动 / 交换 / 修改 TODO / 添加 hint 都允许** |
| `pending-spec`（已起 spec，未 merge） | **拒绝移动、交换、修改 TODO、添加 hint**；提示直接编辑 `docs/spec/${slug}.md` |
| `docs/spec/_done/${slug}.md` 存在（已 merge） | **全部拒绝**——该项应该已经是 `- [x]`，TODO 行不该被动 |

#### Step 4: Apply One Panel Command

**追加 hints**（如有）：

```bash
# 把 hints 数组追加到目标行末
# 1. 抽出现有 hints
existing_hints=$(echo "$target_line" | sed -nE 's/.*\(([^)]+)\)[[:space:]]*$/\1/p')

# 2. 拼接新旧 hints（用英文分号；分隔，与 Shared Constraints 对齐）
if [ -n "$existing_hints" ]; then
  new_hints_block="$existing_hints; $(IFS='; '; echo "${new_hints[*]}")"
else
  new_hints_block=$(IFS='; '; echo "${new_hints[*]}")
fi

# 3. 用 sed 替换该行末尾——优先保留行内已有的部分，仅在末尾改/加括号
```

**校验**：
- 单条 hints 内**禁止**含 `;`（会破坏分隔）；含则报错让用户改写。
- 修改 TODO 时必须保持合法格式：`- [ ] \`<slug>\` <title> — <summary> (...)`。默认不允许改 slug；用户明确要求改 slug 时，拒绝并说明应删旧项 + add 新项。
- 单个 TODO 内容改动后，必须额外输出该行完整 Markdown 原文，格式为：

```md
updated_line:
- [ ] `slug` 标题 — 摘要 (hint)
```

**移动行**（如有）：

| 动作 | 行为 |
|---|---|
| `--before <S>` | 把目标行剪切，插到 `\`<S>\`` 所在行**之前** |
| `--after <S>` | 同上，插到**之后** |
| `--top` | 移到目标行所在段（`## Features` / `## TODO` / `## Backlog`）的**段首**（标题下第一条） |
| `--bottom` | 移到所在段**段末** |
| 编号交换（如 `3,6 交换`） | 用 Step 1.5 编号清单解析两个编号对应的 slug，交换两行位置 |
| 编号移动（如 `8 移到 2`） | 用 Step 1.5 编号清单解析目标编号和目标位置，把目标行移动到该序号所在位置 |

锚点 slug（`<S>`）必须也存在且未完成；否则报错。

**不跨段移动**：目标 TODO 在哪个 `##` 段下就只能在该段内移动。需要跨段先用 Edit 改段名。

每次成功应用命令后必须：
1. 重新解析 `TODO.md`
2. 校验所有被调整 slug 仍唯一存在
3. 输出完整 panel 表格
4. 若是单行内容改动，再输出 `updated_line`

#### Step 5: Exit Panel + Commit + Push

这是 `adjust` 的硬门，不是可选收尾。用户退出 panel 后，只要 `TODO.md` 相比进入 panel 时有实际改动，就必须执行本步。若没有实际改动，输出 `adjust_commit: no-op`，不 commit、不 push。

```bash
# staged 必须只有 TODO.md
git add TODO.md
staged=$(git diff --cached --name-only)
[ "$staged" = "TODO.md" ] || { echo "ERROR: unexpected staged files: $staged"; git reset HEAD; exit 1; }

# 校验每个被调整的目标 slug 仍唯一存在
for adjusted_slug in "${adjusted_slugs[@]}"; do
  hits=$(grep -cE "^- \[ \] \`${adjusted_slug}\` " TODO.md)
  [ "$hits" = "1" ] || { echo "ERROR: target line not unique after adjust: ${adjusted_slug} (${hits} hits)"; exit 1; }
done

git commit -m "chore(todo): adjust TODO panel

$(adjust_summary)"   # body 内容见下方
adjust_sha=$(git rev-parse HEAD)
if git push origin "${default_branch}"; then
  push_status="pushed"
else
  push_status="local-only"
  echo "WARN: push failed, adjust committed locally only (sha=${adjust_sha})"
fi
```

`adjust_summary` 由本次实际做了哪些动作生成，例：

```
Move `ai-group-suggestions` after `theme-toggle`
Edit `theme-toggle` summary
Append hint to `keyboard-shortcuts`: 使用 chrome.commands API
```

### Output Contract（adjust）

进入 panel 时必须输出：

- `mode: adjust`
- `panel: open`
- 完整 TODO 表格
- `commands`: 一行提示支持 `移动 / 交换 / 修改 TODO / 添加 hint / 退出模式`

每次成功修改后必须输出：

- `mode: adjust`
- `panel: open`
- `actions_taken`: 本轮动作数组，如 `["moved ai-group-suggestions after theme-toggle"]`
- `updated_line`: 仅当单个 TODO 内容被改时输出，且必须是该行完整 Markdown 原文
- 完整 TODO 表格
- `next_step`: `继续输入调整指令，或说"退出模式"提交并 push`

退出 panel 后必须输出：

- `mode: adjust`
- `panel: closed`
- `actions_taken`: panel 内累计动作数组
- `changed_slugs`: panel 内动过的 slug 数组
- `final_table`: 完整 TODO 表格
- `adjust_commit`: SHA
- `push_status`: `pushed` / `local-only`
- `next_step`:
  - 顺序变了：`下次 stage1 cron 会按新顺序挑选`
  - 加了 hints 且 spec 不存在：`stage1 起 spec 时会读到新 hints 并写进 spec`
  - 没有实际改动：`panel closed with no changes`

### Common Failure Modes（adjust）

**1. 改已经起过 spec 的 TODO 位置**：位置变了但 stage1 不会重选该项（spec 已存在），徒劳。处理：Step 1 判定矩阵直接拒绝改位置。

**2. 改已 merge 项**：`- [x]` 应该是不可变历史。处理：Step 1 检测到 `_done/${slug}.md` 直接拒绝所有动作。

**3. hints 含 `;` 把分隔符破坏**：用户写 `--add-hint "支持 A; 支持 B"` 期望一次加两条，结果被当成一条。处理：Step 3 校验单条 hints 内不含 `;`，让用户改成两次 `--add-hint`。

**4. 移动行时锚点 slug 不存在**：`--before nonexistent` 静默无操作。处理：Step 3 校验锚点 slug 存在且未完成，否则报错。

**5. 跨段移动破坏组织**：用户期望从 `## Backlog` 移到 `## Features` 顶。处理：本 mode 不跨段；用户先 Edit 改段名再 adjust。

**6. 编号动作未先列表格**：用户说“3、8 交换”，agent 直接按自己脑中顺序改。处理：panel 打开和每次改后都必须输出当前 TODO 表格，再把编号解析成 slug；编号越界必须 stop 并重印表格。

**7. 每次小改后就 commit**：panel 还没退出就创建多次 commit。处理：面板期间只改 `TODO.md` 和展示表格；只有用户说退出模式后才 commit + push。

**8. 单行内容改了但没输出原文**：用户无法审查最终 TODO 行。处理：凡是 title / summary / hints / 整行替换这类单行内容改动，都必须输出 `updated_line`，内容必须与 `TODO.md` 中该行完全一致。

**9. 退出后未提交或未推送**：agent 改了 `TODO.md` 就直接回复“已调整”。处理：Step 5 是硬门；必须 commit，并且必须尝试 push。commit 失败 → 不允许成功；push 失败 → 报告 `push_status: local-only` 和失败原因。

---

## Mode `revise`

verify 完(stage3 给 `verified` / `verify-failed`)或人审 ready-for-review 觉得要改时,用 panel 模式给 spec 写 **Rework instructions**(返工指令),改 status 为 `needs-rework`,让 stage 2 下次轮转拾起按指令重做。

跟 `adjust` 的区别:`adjust` 改的是**还没起 spec** 的 TODO 行;`revise` 改的是**已起 spec 且已 stage2 实现过**的 spec(给二次/三次实现的指令)。

### Step 1: 解析参数 + 列候选

- `todo-flow revise <slug>` → 直接处理该 slug 的 spec
- `todo-flow revise` → 扫工程列出所有 status ∈ `{ready-for-review, verified, verify-failed}` 的 spec,让用户选

筛选条件:
- spec frontmatter `status` 在 `ready-for-review` / `verified` / `verify-failed` 之中
- 工程根目录 git 仓库且工作树干净(避免误卷入用户改动)

### Step 2: 显示上下文(让用户基于事实写 rework)

agent 输出三段:
1. **spec 头部已有报告**(`## Stage 2 report` / `## Stage 3 report` 段),让用户看上次实现 + 验证结果
2. **本次改动 diff 摘要**(`git diff <default_branch>...todo/<slug> --stat`)
3. **现有验收标准 + Rework instructions(若有上次留的)**

### Step 3: Panel 模式收集 rework 指令

进入对话循环(类似 adjust 模式),让用户给"修订指令"。每条 instruction 应:
- **具体**:指明哪个文件 / 哪段代码 / 哪个验收标准对不上
- **可测**:stage2 跑完能客观对照(避免"实现得不好"这种废话)
- 一行一条,用 `- ` 列表

支持的快捷模板(用户输入数字编号):
1. `测试覆盖不够: <说明>`
2. `实现偏离 spec <X> 段: <说明>`
3. `走查截图显示 <UI 问题>`
4. `引入了 spec 未授权的依赖 <X>`
5. `修改了 spec 范围外文件 <X>`
6. `性能/可用性问题: <说明>`
7. `<自由文本>`

用户说 "退出" / "exit" / "done" → 进 Step 4。

### Step 4: 写 Rework instructions 到 spec 头部

在 spec frontmatter `---` 之后,所有 `## Stage N report` 段之后,第 1 个业务 `##`(目标 / 现状 ...)之前,**插入或覆盖** `## Rework instructions (<today>)` 段:

```md
## Rework instructions (<today>)
> 由 todo-flow revise 收集。stage2 下次拾起本 spec 时**必读**本段作为补充约束,在原 spec 之上做修正。

- <用户指令 1>
- <用户指令 2>
- ...

(本段每次 revise 都覆盖重写;历史指令归档到下文 ## Decisions log)
```

同时:
- frontmatter `status` 改为 `needs-rework`(stage 2 兼容,当 approved 处理但读本段)
- `updated: <today>`
- 不重置 `attempts`(累积计数,防止无限 rework — `attempts >= 3` 自动 blocked)

### Step 5: Commit + push

```bash
cd <worktree if exists, else project root>
git add docs/spec/<slug>.md
git commit -m "chore(todo): revise ${slug} → needs-rework"
git push  # 默认分支或 todo/<slug> branch,看 spec 在哪
```

### 输出

```json
{
  "mode": "revise",
  "slug": "<slug>",
  "previous_status": "verified | verify-failed | ready-for-review",
  "new_status": "needs-rework",
  "instructions_count": <n>,
  "spec_path": "<...>",
  "summary": "✓ revise: <slug> → needs-rework with <n> instructions",
  "im_attach": [],
  "next_action": "stage 2 下次 cron 会拾起 needs-rework,按指令重做"
}
```

### Common failure modes

- **Step 2 显示阶段没读 worktree diff** → 用户基于陈旧 spec 写指令,失真
- **指令写成废话**("做得更好") → agent 必须用 7 条快捷模板引导,拒绝空话
- **status 不是 ready-for-review/verified/verify-failed 却允许 revise** → 必须先 Step 1 校验,否则会把 draft/approved 的 spec 错误标 needs-rework

---

## Mode `done`

整合 3 件事到一次调用：审 → 合 → 归档为 done。任一审核环节不过 → 走 **reject 路径**（findings 回写 spec，status 退回 approved 让 stage 2 重做）。

### Required Workflow（done）

按以下顺序：

0. 解析 CLI 参数(支持 `--version patch|minor|major|<x.y.z>`)
1. 探测候选 spec 列表
2. 若多个 → 用户选；1 个 → 直接进入；0 个 → idle 报告
3. 准备 review 环境（fetch、定位 branch、识别 worktree 位置、检查脏工作树）
4. 跑 hard gates
5. 对照 spec 验收
6. 工程规范校验
7. 事后审改动规模 / 高风险信号
8. 产出 review report → 通过 / 不通过判定
9. **通过路径**：squash merge + **semver bump** + **写 CHANGELOG.md** + 清理
10. **不通过路径**：findings 回写 spec(头部 `## Review feedback` 段),status 退回 approved 让 stage 2 重做
11. （若 done）检查 epic 父项是否可关闭

不要跳过 Step 4-7 任一个直接进 merge。**stage1 一律 approved 不代表免审**——事后审 diff 是否符合 spec 估算才是本 mode 的核心价值。

#### Step 9 增强:Semver bump + CHANGELOG(通过路径)

squash merge 成功后,在默认分支上做版本升级:

**Bump 类型决策**(优先级从高到低):
1. CLI 参数 `--version patch|minor|major|<x.y.z>` (显式指定)
2. spec frontmatter `bump_hint: patch|minor|major` (stage1 起 spec 时建议,可选)
3. 默认 `patch` (保守兜底)

**探测版本文件**(按存在顺序处理一个):
- `package.json` → `.version` 字段
- `Cargo.toml` → `[package] version = ".."`
- `pyproject.toml` → `[project] version = ".."` 或 `[tool.poetry] version = ".."`
- `VERSION` 文件 → 单行版本号
- 都不存在 → **跳过 bump**(报告中标 `version_bump: skipped`,不报错)

**bump 算法**(语义化):
- `patch`: `1.2.3` → `1.2.4`
- `minor`: `1.2.3` → `1.3.0`
- `major`: `1.2.3` → `2.0.0`
- 显式 `<x.y.z>`: 直接覆盖

**生成 CHANGELOG.md 条目**(Keep a Changelog 风格):

**前置处理**(必跑):
- `CHANGELOG.md` 不存在 → 先 `printf '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\nThe format is based on [Keep a Changelog](https://keepachangelog.com/).\n\n' > CHANGELOG.md`
- 已存在 `## [Unreleased]` 段 → 把本次 entry 先 append 到 Unreleased 段对应分类,再把整个 Unreleased 段 promote 成 `## [<new_version>] - <today>`(避免留孤段)
- 不存在 `[Unreleased]` 段 → 直接在 `# Changelog` 标题之后插入新版本段

在 `CHANGELOG.md` 顶部(`# Changelog` 标题之后,第一个 `##` 之前)插入:

```md
## [<new_version>] - <today>
### <category>
- <spec.title>(`<slug>`):<spec ## 目标 段第一句>
```

`<category>` 按 spec frontmatter `change_type` 决定:
- `added` → `### Added`
- `changed` → `### Changed`
- `fixed` → `### Fixed`
- 缺省 / 未声明 → 按 spec `kind` 推断:`implementation` 默认 `Added`,bug 修复关键词("修" / "fix" / "bug")默认 `Fixed`,其他默认 `Changed`

**Commit**(版本文件 + CHANGELOG.md 合一):

```bash
git add <version_file> CHANGELOG.md
git commit -m "chore(release): v<new_version>"
git push origin <default_branch>
```

如版本文件探测不到 → 仍写 CHANGELOG(无版本号,标 `## [Unreleased]` 累加 entry),commit message `chore(release): unreleased entry for <slug>`

#### Step 1: List Candidates

```bash
ls docs/spec/*.md 2>/dev/null
```

对每个 spec 读 frontmatter 提取 `id`、`status`、`updated`、`epic`。筛 **`status: ready-for-review` 或 `status: verified`** 的(后者表示已过 stage3 自动验证):

- 0 个 → 输出 idle JSON + 提示"stage 2/3 还没跑完"
- ≥ 1 个 → 进入 Step 2;同时存在两种状态时 `verified` 优先(自动验证过的更可信)

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
Spec was reviewed and merged via todo-flow done."
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

### Output Contract（done）

报告必须包含：

- `mode: done`
- `slug`: 处理的 slug
- `verdict`: `done` / `rejected` / `idle` / `refused`
- `done_sha`: 仅 done 时（main 上的 squash commit SHA）
- `must_fix`: 仅 rejected 时的清单
- `epic_closed`: 若关联 epic 也关闭了，列出 epic slug
- `push_status`: `pushed` / `failed`（push main 是否成功）
- `cleanup_status`: `complete` / `partial`（branch/worktree 是否全清掉）
- `next_step`:
  - done: `done 完成，下一个 TODO 可让 stage 2 拾起`
  - rejected: `findings 已写回 spec，等 stage 2 重做`
  - idle: `没有 ready-for-review 的 spec`
  - refused: `<拒绝原因>`

### Common Failure Modes（done）

**1. Hard gates 红了还推**：lint fail 视为"小事"。任一 red → 必 REJECT，不豁免。

**2. Subjective acceptance 自动判通过**：spec 写"UX 友好"agent 自己判 pass。处理：subjective 必须让用户确认。

**3. diff audit 信号被忽略**：实际改动远超 spec 估算或触及未声明的高风险类别，仍照常合并。处理：单信号高亮、双信号叠加必 REJECT。

**4. Pass path 中途失败留半成品**：squash commit 成功，spec 归档 commit 失败。处理：报错 stop，给用户手动收尾命令，**不**尝试 reset 已合并 commit。

**5. 误删用户自己的 worktree**：worktree 内有未提交修改被 remove 删掉。处理：删前检查 `status --porcelain`，非空拒绝 remove。

**6. epic 误关闭**：父 epic 还有子项 status=draft 在 `docs/spec/`（没 done），但 TODO.md 上看起来都 [x]。处理：epic 关闭判定**只**看 `docs/spec/_done/`，不看 TODO 复选框。

**7. 主仓库工作树脏照样开干**：把用户脏改动卷入 review。处理：Step 3 检查到脏 → refuse。

**8. 跨过用户确认 force push**：push main 被 protected 拒，改用 `--force-with-lease`。处理：永远不 force push 到 main。push 失败 → 报告手动处理。

---

## Mode `exec`

**前台自闭环 orchestrator**:对一个或多个项目的若干 spec 自动驱动 stage1→stage2→stage3 直到每个 slug 进入终态(`verified` 或 `blocked`),不需人审介入。

跟 cron 模式(state-model.md 调用拓扑里的 stage1/2/3)的区别:

- **cron**: 慢节奏后台,每个 stage 独立 cron,一轮只处理 1 个 spec,适合"放着自己跑"
- **exec**: 前台 orchestrator 进程,**并发** + **per-slug 紧逼到 verified/blocked**,适合"今晚把这批 TODO 推完"

### Required Workflow（exec）

按以下顺序：

0. 解析 CLI 参数(`--project <p1> [<p2> ...]`、可选 `--slug <s1> [<s2> ...]`、`--max-verify-attempts <n>`(默认 5)、`--poll-interval <sec>`(默认 300)、`--stuck-after <sec>`(默认 900)、`--backend codex|claude`、`--resume`、`--no-im`、`--exclude-needs-rework`)
   - **`--resume` 行为**:跳过 Step 0 队列构建,直接读 `.todo-flow/exec/.session-state.json` 恢复上次中断时的 in-flight + pending queue。续跑过程中按需 re-check 各 spec 当前 status(允许用户在中断期手工改 spec)。续跑成功完成后删除 `.session-state.json`。文件不存在 → idle 退出 + 提示"无可续跑 session"
1. 校验环境:`cc-connect` 可用(除非 `--no-im`)+ subagent backend 可用 + 各 project 是 git 仓库
2. 读 `references/exec-orchestrator-prompt.md` 整篇,**字面替换**以下占位符:
   - `${PROJECTS_ARRAY}` → JSON 数组 `[{name, abs_path, default_branch}, ...]`
   - `${SLUGS_FILTER}` → 用户指定的 slug 数组(可空)
   - `${MAX_VERIFY_ATTEMPTS}` → 默认 5
   - `${POLL_INTERVAL_SEC}` → 默认 300
   - `${STUCK_AFTER_SEC}` → 默认 900
   - `${SUBAGENT_BACKEND}` → `codex` 或 `claude`
   - `${IM_ENABLED}` → `true` 或 `false`
3. **以替换后的 prompt 作为 agent 自身的工作指令**继续执行(主 agent 本身就是 orchestrator)。**不要再派一层 subagent 当 orchestrator**——orchestrator 由当前 agent 直接扮演,这是为了让用户能 Ctrl+C 中断 + 看实时进度
4. 主循环跑到队列空 / 死锁 / 用户中断
5. 输出标准 JSON(详见 exec-orchestrator-prompt.md "输出契约"段)

### 关键设计原则

- **per-stage subagent**:不派一个 subagent 跑完整 slug,而是每次只派一个 subagent 跑一个 stage。stage 返回后 orchestrator 看 spec status 决定下派什么 stage。这样故障粒度最小、状态机最干净
- **stage1 只跑 1 次**:spec 一旦生成视为给定,exec 模式不允许循环重做 stage1(spec 本身怀疑错 → blocked 求人)
- **强制 auto-approved**:exec 不看 stage1 self_approved,所有 spec 直接进 stage2
- **stage3 verify-failed 自动生成 `## Rework instructions`** 写到 spec 头部,stage2 下轮必读。**不调** `revise` 模式
- **director-* AND-pass**:stage3 Playwright 通过后,按 spec frontmatter `director_audit` + `required_directors` 增派 director-* 并行 audit,**全 pass** 才标 verified
- **IM 同步阻塞**:cc-connect send 失败 = orchestrator 停下来报警,不重试不静默丢弃
- **不自动 done**:exec 跑完 verified 后停止,用户手工 `todo-flow done` 完成 merge

### 硬护栏(5 种 blocked 触发,与 state-model.md "Exec 模式 blocked 触发"段完全对齐)

| 触发 | 谁标记 | 说明 |
|---|---|---|
| `attempts >= 3`(stage2 内部 IMPL_FAIL 累积) | stage2 prompt 自己标 | 保留现有 cron 模式逻辑,exec 不绕开 |
| `verify_attempts >= --max-verify-attempts`(默认 5) | exec orchestrator 标 | exec 专属硬上限 |
| 连续 3 次 stage3 failure signature hash 相同(归一化后) | exec orchestrator 标 | 防"换汤不换药"循环 |
| `relaunch_count >= 3`(心跳 L3:重派 3 次仍 L2 卡死) | exec orchestrator 标 | 心跳 L1 唤醒 → L2 kill+重派 → 第 3 次重派后仍 L2 → L3 blocked |
| 循环依赖检测(spec depends_on 形成环) | exec orchestrator 标 | 涉及所有环上 slug 一起 blocked + IM 告知 |

blocked 标完 → IM 通知用户 + 该 slug 移出队列 + 保留 `.todo-flow/exec/<slug>/` 不清理(供人 review)。

### 与其他 mode 的关系

- `add` / `adjust`:可在 exec 跑期间运行,但 adjust **应避免**(状态机可能不一致)
- `revise`:exec 不会自动调;`revise` 后改 spec 为 needs-rework,**下一次** `todo-flow exec --resume` 才会被纳入(needs-rework 在 exec Step 0 默认过滤;`--include-needs-rework` 可纳入)
- `done`:exec 跑完 verified 后 **必须** 用户手工 done(squash merge + 版本升级 + CHANGELOG)

### Output Contract（exec）

详见 `references/exec-orchestrator-prompt.md` "输出契约" 段。核心字段:

```json
{
  "mode": "exec",
  "verdict": "completed | interrupted | deadlock | skipped",
  "total": <n>, "verified": <n>, "blocked": <n>, "interrupted": <n>,
  "per_slug": [{project, slug, final_status, stages_run, directors, duration_sec, evidence_dir}],
  "duration_sec": <n>,
  "summary": "exec <n> verified, <n> blocked across <n> projects",
  "next_action": "blocked 项需人 review:todo-flow revise 给新指令,或人工修后 todo-flow done"
}
```

### Common Failure Modes（exec）

**1. 不读 exec-orchestrator-prompt.md 直接凭脑补跑**:模式定义在 reference 里,SKILL.md 只列 mode 入口。Step 2 必读全文 + 字面替换占位符,**不要** 把占位符当字符串保留。

**2. subagent 自己发 IM 而不通过 orchestrator**:IM 出口必须单一,subagent prompt 里要明确禁止;若发现重复 IM,检查 stage prompt 是否被污染。

**3. cc-connect send 失败后继续派 stage**:IM 是关键反馈通道,失败必须停;后续 IM 漏发等于盲跑。

**4. director-* audit pass 但有 must_fix 被忽略**:AND-pass 的 pass 必须 must_fix 为空;非空一律按 needs-fix 走 verify-failed 路径。

**5. exec 跑完顺手帮用户调 `todo-flow done`**:严禁。done 是高风险动作,保留人审最后关口。

**6. 在 exec 期间用户改了 spec**:每轮 orchestrator 重读 spec status,以最新为准;若变 verified/blocked → 从队列移除。

**7. backend=claude 主会话退出后 subagent 也死**:Claude Code Agent 后台是同会话内有效,**用户要真后台 exec 应用 `--backend codex`**;SKILL 解析 mode 时检测主 agent 是 Claude Code 且未显式 `--backend codex`,提示用户改 backend。

---

## Templates / Reference Files

要在新项目上启用 TODO Flow 流水线，下列模板存在本 skill 的 `references/` 下，可以直接复制到项目或喂给 cron agent：

| 文件 | 用途 | 何时取出 |
|---|---|---|
| `references/state-model.md` | 完整系统说明：状态机 / TODO.md 格式 / spec.md frontmatter / Worktree 命名 / 调用拓扑 | 用户问"todo-flow 是什么 / 怎么用"时；首次给项目初始化流水线时 |
| `references/stage1-prompt.md` | Stage 1 cron 喂给 agent 的 prompt：**完全无入参 self-driving**，遍历硬编码工程清单 → 找首个未起 spec 的 TODO → 出 spec（一律 `status: approved`）→ commit + push 到默认分支 | 用户要把 stage 1 接到 cron / 想手动跑一次起草 spec 时 |
| `references/stage2-prompt.md` | Stage 2 cron 喂给 agent 的 prompt：**完全无入参 self-driving**，遍历工程清单 → 找首个无残留 worktree/branch 的 approved spec → 开 worktree → 实现 + 验证 + 可选 Playwright 走查 → push branch；遇到残留按 `needs_cleanup` / `awaiting_review` 分类报告 | 用户要把 stage 2 接到 cron / 想手动跑一次 dev 时 |
| `references/stage3-verify-prompt.md` | Stage 3 cron 喂给 agent 的 prompt:**完全无入参 self-driving**,遍历工程清单 → 找首个 `ready-for-review` spec → 跑 hard gates + Playwright 走查 → 写 `## Stage 3 report` + status 改 `verified`/`verify-failed` + 标准 JSON 输出 | 用户要把 stage 3 接到 cron / exec 模式 Step 2 派 stage3 subagent 时 |
| `references/exec-orchestrator-prompt.md` | **`exec` 模式核心 prompt**:per-stage subagent 调度 + 心跳 + IM + director-* 增派。Pure prompt 设计,任何 agent(Claude Code / codex / 别的)读完都能当 orchestrator | `todo-flow exec` 被触发时,SKILL 必读全文 + 字面替换占位符再执行 |

**怎么给用户**：
- 用户问"用法"/"怎么部署" → Read `references/state-model.md` 节选关键部分回答
- 用户要"试跑 stage 1 / 我想看看 prompt 长啥样" → 用 Read 工具读 `references/stage1-prompt.md` 整篇，或 cp 到用户指定路径
- 用户要"接 cron" → 给出读取这两个 prompt 文件的具体命令（cron 程序按需 `cat` / 加载）

**这些 reference 是状态机的契约定义**。改它们等于改 stage 1/2 prompt 端的行为，必须同步审视 `init` / `done` 两个 mode 的 SKILL.md 是否还对齐。普通迭代只动 SKILL.md 不动 references/。

---

## Shared Constraints

四个 mode 都必须遵守，**不可妥协**：

### Slug 格式
正则 `^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$`，kebab-case，3-30 字符。slug 是流水线内部标识，**不论项目本身用什么语言，slug 永远是 kebab-case 英文**。

### 写入内容的语言：中文

**TODO.md 与 spec 文件里所有用户可读的文本内容一律用中文**——这是中文项目的硬约定。

具体覆盖范围：

| 位置 | 必须中文 | 例外（保持英文/原文） |
|---|---|---|
| `TODO.md` 行的 title | ✅ "主题切换" | — |
| `TODO.md` 行的 summary（破折号后描述） | ✅ "支持深色/浅色/跟随系统三态" | — |
| `TODO.md` 行末 hints（括号内每条） | ✅ "复用 src/hooks/useDarkMode" | 文件路径 / API 名 / 命令 / 第三方库名 / 代码片段保持原文 |
| spec frontmatter `title` | ✅ | — |
| spec 七章正文（目标/现状/方案选项/推荐方案+理由/影响范围/验收标准/风险） | ✅ | 同上：file:line 引用、API 名、命令、库名、代码 |
| spec 验收标准 `- [ ]` checkbox 描述 | ✅ "在 dir=\"rtl\" 下所有交互元素位置正确" | — |
| spec Decisions log 条目正文 | ✅ | — |
| spec ❌ 反例文字 | ✅ | — |

**永远是英文 / 保持原状**（与本规则无冲突）：

- `slug` 本身（kebab-case 英文，前面有规定）
- frontmatter 字段名 `id` / `title` / `status` / ...（字段名是结构契约，不翻）
- frontmatter 枚举值 `approved` / `ready-for-review` / `true` / `false` / `1440x900` 等
- commit message subject 用 conventional commits 英文前缀（`feat:` / `docs:` / `chore:`），body 可中文
- 代码 / 文件路径 / API / 库名 / 命令永远原样

判定原则：**结构性字段（字段名 / 枚举 / 标识符）保持英文；叙述性内容（人读的句子）一律中文**。

### Spec frontmatter 字段名（严格对齐 stage 1/2/3 prompt + exec-orchestrator-prompt.md + cases.md）

**基础字段**(各 mode 都用):
`id` / `title` / `status` / `kind` / `epic` / `depends_on` / `attempts` / `project_root` / `needs_visual_check` / `needs_video_check` / `created` / `updated`

**stage3 / done 相关**(可选,按需写):
`verify_attempts`(stage3 失败计数,独立于 attempts) / `verified_at`(stage3 verified ISO ts) / `verify_failed_at`(stage3 verify-failed ISO ts) / `change_type`(added/changed/fixed,done 写 CHANGELOG 用) / `bump_hint`(patch/minor/major,done 决定 semver 用,优先级低于 `--version`)

**exec 相关**(可选,按需写):
`director_audit`(`always` / `last-pass`(默认) / `never`) / `required_directors`(数组,如 `[design, frontend]`,空则自动嗅探)

> ⚠️ 旧字段 `self_approved` / `self_approved_reasons` 在 v2 stage1 prompt 中已删除（所有 spec 一律 `status: approved`，无人工审核环节）。如读到老 spec 仍带这两个字段，忽略即可。

> ⚠️ `exec` 模式**忽略** `self_approved` 字段(即便老 spec 留着也无视),强制按 approved 进 stage2。

### 工程规范源头（三级回退）
1. `<project-root>/AGENTS.md`
2. `<project-root>/CLAUDE.md`
3. 通用规则（lint / typecheck / tests / 无意外依赖）

### TODO.md 格式
```md
- [ ] `<slug>` <title> — <summary> (<hint 1>; <hint 2>; <hint 3>)
```

- `- [ ]` = 未合并（pending / draft / approved / in-progress / ready）
- `- [x]` = 已合并（由 done mode 在 merge 后改）

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

本 skill 是 TODO Flow 流水线**人手触发端**的统一入口。

- 一次调用 = 一个 mode；`adjust` 是唯一允许在同一 mode 内持续交互的 panel，会在退出时一次性收口
- 共享约束严格执行，**绝不**为了"流畅"绕过 hard gates、subjective 判定、diff audit
- "merge 了一半"比"完全没 merge"更糟；任何清理步骤失败 → 报错 stop
- mode 边界清晰：add **不**碰 git 状态；done **不**新增 TODO 条目；adjust **不**在退出前 commit

若做不到"原子干净"，就不要假装能安全完成。
