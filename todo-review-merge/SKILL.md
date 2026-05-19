---
name: todo-review-merge
description: >
  Use when a todo-driver pipeline spec has reached status=ready-for-review and you
  want to audit the branch against the spec + engineering rules, then squash-merge
  it into main and clean up branch/worktree/spec/TODO atomically. Reads
  AGENTS.md / CLAUDE.md as engineering ground truth. Audits self-approval claims.
  用于审核并合并 todo-driver 流水线中 status=ready-for-review 的 spec 对应分支。
  按 AGENTS.md → CLAUDE.md → 通用规则三级回退作为工程规范，跑 hard gates，逐条
  对照验收标准，事后审 self_approved 是否合规。通过即自动 squash merge + 删 branch
  + 删 worktree + 移 spec 到 _done/ + 标 TODO 为 [x]。
  触发短语：「review 这个 todo」「合并 todo 分支」「审 todo 并 merge」「todo-review-merge」
  「结清 ready 的 todo」「merge ready spec」。
  Do NOT use for: 通用 PR review（→ requesting-code-review）、审查任意不在
  todo-driver 流水线里的分支、把 draft spec 改成 approved（那是人手动改 frontmatter）、
  没有 ready-for-review spec 的项目（idle）。
---

# todo-review-merge

## Overview

本 skill 是 todo-driver 流水线的"输出端"：把 stage 2 dev 已完成的 spec 真正合并进 main。

它整合 3 件事到一次调用：
1. **审**：跑 hard gates + 对照 spec 验收 + 工程规范 + 事后审 self-approval
2. **合**：squash merge 到 main
3. **清**：删 branch、删 worktree、移 spec 到 `_done/`、标 TODO 为 `[x]`、(若是 epic 子项) 检查父 epic 是否可关闭

任一审核环节不过 → **不通过路径**：把 findings 写回 spec，status 退回 `approved`，等 stage 2 重做。

核心原则：
- **不绕过 hard gates**（lint / typecheck / test / build 任一红就回退）
- **不替用户决定边缘情况**（diff 看起来有可疑越界改动时，停下让用户判断）
- **每一步都可回滚**：merge / 删分支 / 移文件之间任何一步失败，前面已完成的部分要么留下能继续手动收尾的状态，要么 hard exit 报错不留半成品

## When to Use

- 用户说"review 这个 todo"/"合并 ready 的 todo"/"todo-review-merge"
- 用户提到具体 slug 并希望走 review + merge（如"merge theme-toggle"）
- 项目有 `docs/spec/<x>.md` 且其中至少一个 `status: ready-for-review`

## When NOT to Use

- 用户在做通用 PR 审查（用 `requesting-code-review`）
- 用户要 merge 一个不在 todo-driver 流水线里的分支（直接用 `git merge`）
- 没有 `docs/spec/` 目录的项目（不是 todo-driver 项目）
- 用户在问"如何用 todo-driver"（解释，不真的 merge）

## Required Workflow

按以下顺序执行：

1. 探测候选 spec 列表
2. 若多个 → 用户选一个；若 1 个 → 直接进入；若 0 个 → idle 报告
3. 准备 review 环境（fetch、定位 branch、识别 worktree 位置）
4. 跑 hard gates
5. 对照 spec 验收
6. 工程规范校验
7. 事后审 self_approved
8. 产出 review report → 通过 / 不通过判定
9. 通过路径：squash merge + 清理
10. 不通过路径：findings 回写 spec
11. （若 merged）检查 epic 父项是否可关闭

不要跳过 Step 4-7 中任一个直接进 merge。即使 self_approved=true 也要走完，事后审是这个 skill 的核心价值。

## Step 1: List Candidates

```bash
cd <project-root>  # 用户当前 cwd 假定为项目根
ls docs/spec/*.md 2>/dev/null
```

对每个 spec 文件，读 frontmatter 提取 `id`、`status`、`updated`、`epic`。

筛选 `status: ready-for-review` 的：

- 0 个 → 输出 idle JSON + 提示用户"没有 ready spec，stage 2 还没跑完"
- ≥ 1 个 → 进入 Step 2

## Step 2: Pick Target

- 只有 1 个 → 直接用，告诉用户"将 review <slug>"
- 多个 → 用 AskUserQuestion 列出来让用户选，附 `updated` 时间方便判断哪个最新
- 用户在调用 prompt 里已经指定了 slug → 直接用，校验该 slug 是否在 ready 列表里；不在 → 报错说明实际状态

## Step 3: Prepare Review Environment

```bash
git fetch origin
git rev-parse --verify todo/<slug>           # 校验 branch 存在
test -d .worktrees/<slug> && WORKTREE_PATH=.worktrees/<slug> || WORKTREE_PATH=""
```

如果 worktree 存在 → 优先在 worktree 内跑 hard gates（已经 checkout 在对的 branch）
如果 worktree 不存在但 branch 存在 → 在主仓库 `git checkout todo/<slug>`（保存当前 branch 名以便最后回切）

记录主仓库**进入 skill 时的初始分支**（通常是 main），用于不通过路径结束时回到该分支。

**工作树脏检查**：如果主仓库 `git status --porcelain` 非空 → 拒绝执行（不要把用户的脏改动卷入 review）。

## Step 4: Hard Gates

按顺序跑（任一失败 → Step 8 判定为 reject，跳到 Step 10）：

依据项目类型选命令（`package.json scripts` 优先，其次 `Makefile`、`Cargo.toml`、`pyproject.toml`）：

JS/TS：
```bash
pnpm install --frozen-lockfile 2>&1 | tail -5  # 仅在 lockfile 改了时才必跑
pnpm lint 2>&1 | tail -10
pnpm test -- --run 2>&1 | tail -20
pnpm build 2>&1 | tail -10
```

记录每个 gate：command / exit code / 关键输出 tail。

**禁止**：
- 用 `--no-verify` 跳 hook
- 因为"看起来是 flake"重跑测试（应该报告 flake 让用户决定）
- 跳过 build（即使没改源码，spec 改动也可能让构建挂）

## Step 5: Acceptance Criteria 对照

从 spec `## 验收标准` 区段提取所有 `- [ ]` 或 `- [x]` 行。

对每条逐条判定：
- 可以通过 diff / 文件存在性 / 跑命令直接验证 → 验证
- 需要主观判断（如"UX 友好"）→ 标为 "subjective" 留 review report 里让用户最后决定

输出对每条标准的判定：`pass` / `fail` / `subjective:<待用户判断>`

任一 `fail` → reject。
全 `pass` 或 (`pass` + `subjective`) → 进 Step 6。

## Step 6: 工程规范校验

按三级回退找规范源头：

1. `<project-root>/AGENTS.md` ← 首选
2. `<project-root>/CLAUDE.md` ← 次选
3. 都没有 → 仅通用检查（继续到下一步）

如果找到规范源头，提取其中的硬规则（命名约定、目录结构、依赖管理、commit message 规范、API 边界、禁止行为等），对照本次 diff 逐条评估。

通用检查（永远跑，不依赖 AGENTS.md）：
- diff 中没有 `console.log` / `debugger` / `TODO:`(未关联 issue) 等遗留
- 不修改 `package-lock.json` / `pnpm-lock.yaml` 除非 spec 明确授权新依赖
- commit message 跟项目 commit 历史风格一致（必要时跑 `git log --oneline -10` 对比）

任一硬规则违反 → reject。"建议性" 违反 → subjective。

## Step 7: 事后审 self_approved

读 spec frontmatter：

- `self_approved: false` → 跳过本步
- `self_approved: true` → 对照实际改动审：

```bash
git diff --shortstat main...todo/<slug>
git diff --name-only main...todo/<slug>
```

逐条核对 self-approval 6 条硬条件：

1. 改动 ≤ 5 文件 且 ≤ 200 行
2. 不触及 auth / payments / 加密 / 数据迁移 / 跨模块重构
3. 方案选项里无业务判断二选一
4. 不引入新依赖
5. 不修改公开 API / 类型签名
6. 非 epic

**任一违反** → review report 标记 `self_approval_abused: true`，列出具体违反条款。这**不**自动 reject（spec 内容可能本身没问题，只是当时该走人审），但要在 report 里高亮。

如果违反 ≥ 2 条 → reject，理由："self-approval claim doesn't match actual changes"。

## Step 8: Output Review Report

报告结构（先在对话中给用户看，再决定 merge 或 reject）：

```md
## Review Report: <slug>

### Hard Gates
- lint: pass | fail (<reason>)
- typecheck: pass | fail
- test: <n> passed | <m> failed (<details>)
- build: pass | fail

### Acceptance Criteria
- [x] criterion 1 (verified by ...)
- [x] criterion 2
- [ ] criterion 3 (subjective, needs user judgement)
- [ ] criterion 4 (FAIL — <reason>)

### Engineering Rules (source: AGENTS.md | CLAUDE.md | generic)
- ✅ rule 1
- ❌ rule 2: <violation>

### Self-Approval Audit (仅当 self_approved=true)
- 改动: <n> files / <m> lines
- 违反条款: [3, 5]  # 列出违反的硬条件编号
- 结论: self_approval_abused: true

### Verdict
PASS | REJECT
- 原因: <一句话>
- Must-fix（仅 REJECT 时）:
  - <item 1>
  - <item 2>
```

判定规则：
- 任一 hard gate fail → REJECT
- 任一 acceptance criterion fail → REJECT
- 工程规范硬规则违反 → REJECT
- self-approval 违反 ≥ 2 条 → REJECT
- 否则 → PASS

## Step 9: Pass Path (Squash Merge + Cleanup)

按以下顺序执行，**每一步失败都报错并 stop**，不要静默继续：

```bash
# 1. 回到主仓库 + main
cd <project-root>
git checkout main
git pull --ff-only origin main   # 确保 main 最新

# 2. squash merge
git merge --squash todo/<slug>
# message 用 spec.title 作为主题，body 引用 spec 路径
SQUASH_MSG="<spec.title>

Source: docs/spec/<slug>.md
Spec was reviewed and merged via todo-review-merge."
git commit -m "$SQUASH_MSG"

# 3. 移 spec 到 _done/（这步必须在 commit 之后，因为要进入下一个 commit）
mkdir -p docs/spec/_done
git mv docs/spec/<slug>.md docs/spec/_done/<slug>.md

# 4. 标 TODO 为 [x]
# 用 sed/Edit 把 `- [ ] \`<slug>\`` 这一行改为 `- [x] \`<slug>\``
# （注意：epic 子项的缩进要保留）

# 5. 第二个 commit：spec 归档 + TODO 标记
git add docs/spec/_done/<slug>.md TODO.md
git commit -m "chore(todo): archive <slug> spec and mark TODO as done"

# 6. 删 worktree（若存在）
test -d .worktrees/<slug> && git worktree remove .worktrees/<slug>

# 7. 删本地 branch
git branch -D todo/<slug>

# 8. 删远程 branch（若存在）
git push origin --delete todo/<slug> 2>/dev/null || echo "remote branch already gone"

# 9. push main
git push origin main
```

**Constitution gate**：步骤 9（push main）是高风险动作。
- 如果当前是 IM 会话（`CC_SESSION_KEY` 非空）→ 自动 push（用户调用本 skill 已是显式授权 full flow）
- 终端直连且 main 是 protected branch（GitHub 设置）→ 让 push 失败，告知用户手动处理
- **不要** 用 `--force` 或 `--force-with-lease`

## Step 10: Reject Path (Findings → Spec)

判定为 reject 时：

1. **不动 main**（不 merge）
2. **不删 branch / worktree**（用户可能要去 fix）
3. 切到 branch `todo/<slug>`（或进 worktree）
4. 在 spec 末尾追加 review feedback：

```md
## Review feedback (<today T HH:MM Z>)

### Verdict
REJECT

### Must-fix
- <item 1>
- <item 2>

### Details
<逐条详细说明 + 引用具体 file:line>
```

5. 更新 frontmatter：
   - `status: approved`（让 stage 2 重做；不是回到 draft，避免人重审）
   - `updated: <today>`
   - `attempts` 不变（review 不算 stage 2 尝试）

6. commit 这次 spec 修改：

```bash
git add docs/spec/<slug>.md
git commit -m "chore(todo): review feedback for <slug>"
git push origin todo/<slug>
```

7. 切回主仓库初始 branch

## Step 11: Epic Auto-Close (仅 Pass Path 后执行)

如果刚 merged 的 slug 是某个 epic 的子项（命名约定：`<epic-slug>-<suffix>`），检查 epic：

```bash
# 找父 epic
grep -rE "^  - \[.\] \`<slug>\`" TODO.md
# 如果匹配到一行，往上找最近的非缩进 `- [ ] \`<epic-slug>\``
```

如果找到父 epic：

1. 列出该 epic 的所有子 slug（TODO.md 中缩进在 epic 下方的所有 `- [ \`<x>\`` 行）
2. 检查每个子 slug 对应的 spec 是否在 `docs/spec/_done/`
3. 若全部 done：
   - 把 epic 行的 `- [ ]` 改为 `- [x]`
   - 如果 epic 对应的 spec（kind: decomposition）还在 `docs/spec/`，移到 `_done/`
   - 多一个 commit：`chore(todo): close epic <epic-slug>`
   - push

如果未全 done → 不动 epic，输出"epic <epic-slug> 进度 X/Y，未关闭"

## Output Contract

完成后报告：

- `slug`: 处理的 slug
- `verdict`: `merged` | `rejected` | `idle` | `refused`
- `merge_sha`: 仅 merged 时（main 上的 squash commit SHA）
- `must_fix`: 仅 rejected 时的清单
- `epic_closed`: 若关联的 epic 也关闭了，列出 epic slug
- `next_step`:
  - merged: `merge 完成，下一个 TODO 可让 stage 2 拾起`
  - rejected: `findings 已写回 spec，等 stage 2 下轮拾起重做`
  - idle: `没有 ready-for-review 的 spec`
  - refused: `<拒绝原因>`

## Common Failure Modes

### 1. Hard gates 红了还往下推
问题：lint fail 但 agent 想"反正就一个 warning"继续 merge。
处理：任一 hard gate red → 必 reject，不允许"小事"豁免。

### 2. Subjective acceptance 自动判通过
问题：spec 验收标准里有"UX 友好"，agent 自己判"pass"。
处理：subjective 标准必须停下来让用户确认。不要 AI 自己拍板。

### 3. self-approval 违反不阻止
问题：agent 看到 self_approved=true 但实际改了 8 文件，只在 report 写 abused 就继续 merge。
处理：违反 ≥ 2 条硬条件 → 必 reject。仅违反 1 条 → 仍 merge 但 report 高亮 + 提醒用户事后调整 stage 1 prompt 的判定门槛。

### 4. Pass path 中途失败但前面已 commit
问题：squash commit 成功，spec 归档 commit 失败，状态半成品。
处理：报错 stop，告诉用户当前已 commit 但未归档，给出手动收尾命令（`git mv` + `git commit` + `git push`）。不要尝试 reset 已经合并的 commit。

### 5. 误删用户自己的 worktree
问题：`.worktrees/<slug>` 里有用户未提交的修改，被 `git worktree remove` 删掉。
处理：删 worktree 前 `git -C .worktrees/<slug> status --porcelain`，非空 → 拒绝 remove，告诉用户先处理。

### 6. epic 误关闭
问题：父 epic 还有子项 status=draft 在 docs/spec/ 里（没 done），但 TODO.md 上看起来都 [x] 了（因为子项还没真的 merge）。
处理：epic 关闭判定**只**看 `docs/spec/_done/`，不看 TODO.md 的复选框状态。

### 7. 主仓库工作树脏照样开干
问题：用户工作树有未提交改动，agent 切 branch 把改动卷进 review。
处理：Step 3 检查到脏 → refuse，要求用户先 stash / commit。

### 8. 跨过用户确认直接 force push
问题：push main 被 protected branch 拒，agent 改用 `--force-with-lease`。
处理：永远不 force push 到 main。push 失败 → 报告用户手动处理。

## Minimal Operating Principle

这个 skill 的目标是"**安全地把一个 ready spec 合进 main，并把所有相关状态原子地清理干净**"。
不是"尽快 merge"，不是"宽容处理边界情况"。
任一审核维度过不去 → reject。
任一清理步骤失败 → stop 报错。
"merge 了一半"是最坏的结局，比"完全没 merge"更糟。
