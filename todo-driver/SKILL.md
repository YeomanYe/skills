---
name: todo-driver
description: >
  Use when interacting with the human-facing endpoints of the TODO Driver pipeline
  (TODO → spec → dev → merge): either appending a new slug-tagged TODO entry, or
  reviewing-and-merging a ready spec back into main. Two modes: `init` for adding
  TODOs, `review-merge` for the audit + squash merge + cleanup flow.
  用于 TODO Driver 流水线（TODO → spec → dev → merge）的两个人手触发端点：
  追加带 slug 的 TODO 条目（mode=init）或审核并合并 status=ready-for-review 的 spec
  （mode=review-merge）。两个 mode 共享 slug 规范、frontmatter 字段约定、工程规范
  三级回退（AGENTS.md → CLAUDE.md → 通用规则）。
  触发短语（init 路径）：「新建 TODO」「加一个待办」「记个新需求带 slug」
  「ext-helper 记个 TODO」「create a TODO」「add todo with slug」「new todo」
  「todo-init」。
  触发短语（review-merge 路径）：「review 这个 todo」「合并 todo 分支」
  「审 todo 并 merge」「todo-review-merge」「结清 ready 的 todo」「merge ready spec」
  「合并 ready 的 todo」。
  统一触发：「todo-driver」「跑一下 todo-driver」「todo-driver init」「todo-driver review-merge」。
  Do NOT use for: 修改已有 TODO（直接用 Edit）/ 不带 slug 的快速备忘（直接 Edit TODO.md）/
  通用 PR review（→ requesting-code-review）/ 不走 todo-driver 流水线的项目 /
  把 draft spec 改成 approved（那是人手动改 frontmatter）/ stage 1/2 cron prompt
  本身的功能（在 ~/Desktop/todo-driver-stage{1,2}-*.md，不归本 skill 管）。
---

# todo-driver

## Overview

本 skill 是 TODO Driver 流水线**人手触发**的两个端点：

- **`init`**：向项目 TODO.md 追加一条带 slug 的待办，让 stage 1 cron 起草 spec
- **`review-merge`**：审核 `status: ready-for-review` 的 spec，pass 则 squash merge 到 main + 原子清理 branch/worktree/spec/TODO

中间的 stage 1（起草 spec）和 stage 2（开发并 push branch）由 cron 喂的 prompt 接管，不在本 skill 范围。

核心原则：
- **一次调用只处理一个 mode**，不混做
- mode 解析有明确顺序，不靠模糊推测
- 共享约束严格对齐（slug 格式 / frontmatter 字段名 / 工程规范源头）
- 高风险动作（merge / push / 删 branch）有硬护栏

## Modes

| Mode | 触发场景 | 主要副作用 | 风险等级 |
|---|---|---|---|
| `init` | 用户要新建带 slug 的 TODO | 在 TODO.md 末尾追加一行 | 低 |
| `review-merge` | 用户要审核并合并 ready spec | squash merge + 删 branch + 删 worktree + push main | 高 |

## Resolving Mode

按以下顺序判定：

1. **用户显式指定**（如 `todo-driver init` / `todo-driver review-merge`）→ 用指定的
2. **触发短语推断**：
   - 含"新建"/"加"/"记"/"create"/"add" + "TODO"/"待办" → `init`
   - 含"review"/"审"/"合并"/"merge" + "todo"/"spec" → `review-merge`
3. **状态推断**（兜底）：
   - 项目根有 `docs/spec/*.md` 且至少 1 个 `status: ready-for-review` → 倾向 `review-merge`
   - 否则 → 倾向 `init`
4. **仍模糊** → 用 AskUserQuestion 二选一

判定后**立即声明**当前 mode（一句话），再开始执行。用户在调用上下文里明确给了 mode 就不要二次确认。

## When to Use

满足任一即可触发：
- 用户描述了一个想加进 TODO.md 的新需求/功能/重构
- 项目有 `docs/spec/*.md` 文件且其中至少一个 `status: ready-for-review`，用户希望推进 merge
- 用户在 todo-driver 流水线相关的上下文里提及 init / review / merge 这类动作

## When NOT to Use

- 用户在改已有 TODO 条目（直接 Edit）
- 用户只想随手记一行不需要被流水线处理（直接 Edit TODO.md）
- 项目不走 todo-driver（没有 `docs/spec/`、TODO.md 里所有条目都没 slug）
- 用户在做通用 PR 审查（用 `requesting-code-review`）
- 用户要 merge 一个不在 todo-driver 流水线里的分支（直接 `git merge`）
- 用户在问"如何用 todo-driver"等元问题（解释，不真的执行）

---

## Mode `init`

只做一件事：向 `cwd` 下的 `TODO.md` 追加一条带 slug 的新 TODO。

### Required Workflow（init）

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

- `TODO.md` 不存在 → **报告用户先 `touch TODO.md` 再来**，stop。不要替用户创建
- `TODO.md` 存在但 `docs/spec/` 不存在 → 提示"todo-driver 流水线还没初始化，TODO 可以照样写"，继续
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

如有 hints，用 `(<hints>)` 拼到行末：

```md
- [ ] `theme-toggle` 主题切换 — 支持深色/浅色/跟随系统三态 (优先 uiStore)
```

如有 depends_on：**不**写入 TODO.md（depends_on 是 spec 字段，stage 1 起草 spec 时再写），仅在报告中提示。校验每个 depends_on 在 TODO.md 或 `docs/spec/_done/` 中是否存在，不存在的列出来警告但**不阻止**追加。

#### Step 5: Verify and Report

```bash
grep -n "^\- \[ \] \`<slug>\`" TODO.md
```

返回 1 行 → 成功，记录行号。
返回 0 或 >1 行 → 写入异常，stop 并报告。

### Output Contract（init）

报告必须包含：

- `mode: init`
- `slug`: 最终 slug
- `title`: 提取的 title
- `line`: 在 TODO.md 中的行号
- `depends_on`: 数组（若提供）
- `depends_warn`: 未找到的依赖 slug 列表（若有）
- `next_step`:
  - 走 todo-driver：`等 stage 1 cron 起草 spec，到时审 docs/spec/<slug>.md`
  - 未启用 todo-driver：`已记录到 TODO.md。你可以手动起草 spec`

### Common Failure Modes（init）

**1. 替用户创建 TODO.md**：可能在不该有 TODO 的目录留下空文件。处理：报告"不存在"，stop。

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
7. 事后审 self_approved
8. 产出 review report → 通过 / 不通过判定
9. **通过路径**：squash merge + 清理
10. **不通过路径**：findings 回写 spec
11. （若 merged）检查 epic 父项是否可关闭

不要跳过 Step 4-7 任一个直接进 merge。**即使 self_approved=true 也要走完**——事后审是本 mode 的核心价值。

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

#### Step 7: 事后审 self_approved

读 spec frontmatter，`self_approved: false` → 跳过本步。

`self_approved: true` → 对照实际 diff：

```bash
git diff --shortstat main...todo/<slug>
git diff --name-only main...todo/<slug>
```

核对 self-approval 6 条硬条件：

1. 改动 ≤ 5 文件 且 ≤ 200 行
2. 不触及 auth / payments / 加密 / 数据迁移 / 跨模块重构
3. 方案选项无业务判断二选一
4. 不引入新依赖
5. 不修改公开 API / 类型签名
6. 非 epic

- 违反 1 条 → PASS 但 report 高亮 `self_approval_abused: true`
- 违反 ≥ 2 条 → REJECT，理由 "self-approval claim doesn't match actual changes"

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

### Self-Approval Audit (仅 self_approved=true)
- 改动: <n> files / <m> lines
- 违反条款: [3, 5]
- 结论: self_approval_abused: true | false

### Verdict
PASS | REJECT
- 原因: <一句话>
- Must-fix（仅 REJECT）:
  - <item>
```

判定规则：
- 任一 hard gate fail / acceptance fail / 工程规范硬规则违反 / self-approval 违反 ≥ 2 条 → REJECT
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

**3. self-approval 违反不阻止**：违反 ≥ 2 条硬条件 → 必 REJECT。仅违反 1 条 → 仍 merge 但 report 高亮。

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
| `references/stage1-prompt.md` | Stage 1 cron 喂给 agent 的 prompt：扫 TODO → 出 spec → 自审决策 → 输出 JSON | 用户要把 stage 1 接到 cron / 想手动跑一次起草 spec 时 |
| `references/stage2-prompt.md` | Stage 2 cron 喂给 agent 的 prompt：找 approved spec → 开 worktree → 实现 + 验证 → 推 branch | 用户要把 stage 2 接到 cron / 想手动跑一次 dev 时 |

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
`id` / `title` / `status` / `kind` / `epic` / `depends_on` / `attempts` / `self_approved` / `self_approved_reasons` / `created` / `updated`

### 工程规范源头（三级回退）
1. `<project-root>/AGENTS.md`
2. `<project-root>/CLAUDE.md`
3. 通用规则（lint / typecheck / tests / 无意外依赖）

### TODO.md 格式
```md
- [ ] `<slug>` <title> — <summary> (optional hints)
```

- `- [ ]` = 未合并（pending / draft / approved / in-progress / ready）
- `- [x]` = 已合并（由 review-merge mode 在 merge 后改）

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
- 共享约束严格执行，**绝不**为了"流畅"绕过 hard gates、subjective 判定、self-approval 审计
- "merge 了一半"比"完全没 merge"更糟；任何清理步骤失败 → 报错 stop
- mode 边界清晰：init **不**碰 git 状态；review-merge **不**新增 TODO 条目

若做不到"原子干净"，就不要假装能安全完成。
