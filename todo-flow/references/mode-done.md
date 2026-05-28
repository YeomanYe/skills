# Mode `done` — 审 ready spec + squash merge + 发版

整合 3 件事到一次调用:审 → 合 → 归档为 done。任一审核环节不过 → 走 **reject 路径**(findings 回写 spec,status 退回 approved 让 stage 2 重做)。

> 旧名:`review-merge`。看到 `review-merge` 时按 `done` 处理。

## Required Workflow

按以下顺序:

0. 解析 CLI 参数(支持 `--version patch|minor|major|<x.y.z>`)
1. 探测候选 spec 列表
2. 若多个 → 用户选;1 个 → 直接进入;0 个 → idle 报告
3. 准备 review 环境(fetch、定位 branch、识别 worktree 位置、检查脏工作树)
4. 跑 hard gates
5. 对照 spec 验收
6. 工程规范校验
7. 事后审改动规模 / 高风险信号
8. 产出 review report → 通过 / 不通过判定
9. **通过路径**:squash merge + **semver bump** + **写 CHANGELOG.md** + 清理
10. **不通过路径**:findings 回写 spec(头部 `## Review feedback` 段),status 退回 approved 让 stage 2 重做
11. (若 done)检查 epic 父项是否可关闭

不要跳过 Step 4-7 任一个直接进 merge。**stage1 一律 approved 不代表免审**——事后审 diff 是否符合 spec 估算才是本 mode 的核心价值。

### Step 9 增强:Semver bump + CHANGELOG(通过路径)

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

### Step 1: List Candidates

```bash
ls docs/spec/*.md 2>/dev/null
```

对每个 spec 读 frontmatter 提取 `id`、`status`、`updated`、`epic`。筛 **`status: ready-for-review` 或 `status: verified`** 的(后者表示已过 stage3 自动验证):

- 0 个 → 输出 idle JSON + 提示"stage 2/3 还没跑完"
- ≥ 1 个 → 进入 Step 2;同时存在两种状态时 `verified` 优先(自动验证过的更可信)

### Step 2: Pick Target

- 只有 1 个 → 直接用
- 多个 → AskUserQuestion 列出来让用户选,附 `updated` 时间
- 用户在调用 prompt 里指定了 slug → 校验该 slug 在 ready 列表里;不在 → 报错并列实际 ready 的

### Step 3: Prepare Review Environment

```bash
git fetch origin
git rev-parse --verify todo/<slug>           # 校验 branch 存在
test -d .worktrees/<slug> && WORKTREE_PATH=.worktrees/<slug> || WORKTREE_PATH=""
```

worktree 存在 → 在 worktree 内跑 hard gates;不存在但 branch 存在 → 主仓库 `git checkout todo/<slug>`(保存初始 branch 名)。

**工作树脏检查**:主仓库 `git status --porcelain` 非空 → **拒绝执行**。

### Step 4: Hard Gates

按 `package.json scripts` / `Makefile` / `Cargo.toml` / `pyproject.toml` 选命令。常见 JS:

```bash
pnpm install --frozen-lockfile 2>&1 | tail -5  # 仅 lockfile 改了才必跑
pnpm lint 2>&1 | tail -10
pnpm test -- --run 2>&1 | tail -20
pnpm build 2>&1 | tail -10
```

每个 gate 记 command / exit code / 关键输出 tail。任一失败 → Step 8 判 REJECT。

**禁止**:`--no-verify` 跳 hook;"flake" 重跑;跳 build。

### Step 5: Acceptance Criteria 对照

从 spec `## 验收标准` 提取所有 checkbox。逐条判 `pass` / `fail` / `subjective`。

- 可自动验证 → 直接判
- 主观项 → 标 `subjective`,留到 report 让用户最后决定

任一 `fail` → REJECT。全 `pass` 或 (`pass` + `subjective`) → 进 Step 6。

### Step 6: 工程规范校验

按三级回退找规范源头:

1. `<project-root>/AGENTS.md` ← 首选
2. `<project-root>/CLAUDE.md` ← 次选
3. 都没有 → 仅通用检查

通用检查(永远跑):
- diff 无 `console.log` / `debugger` / 未关联 issue 的 `TODO:`
- 不改 lockfile 除非 spec 授权新依赖
- commit message 风格对齐 `git log --oneline -10`

硬规则违反 → REJECT。建议性违反 → subjective。

### Step 7: 事后审改动规模(取代旧 self_approved 审计)

> 历史背景:旧版 stage1 prompt 用 `self_approved: true/false` 决定要不要进 stage2,这里事后审。新版 stage1 取消了人工审核环节——所有 spec 一律 `status: approved` 直接进 stage2。**事后审依然必要**,但审的对象从"声明是否成立"变成"实际 diff 是否符合 spec 估算"。

读 spec frontmatter 与正文,提取:

- spec 在"影响范围"区段的**估算文件数 / 行数**
- spec 在"风险"区段是否标了**高风险信号**(⚠️ 标记)

对照实际 diff:

```bash
git diff --shortstat ${default_branch}...todo/<slug>
git diff --name-only ${default_branch}...todo/<slug>
```

判定规则:

- 实际改动文件数 / 行数**显著超过** spec 估算(如估 5 文件实际 20 文件 / 估 200 行实际 800 行)→ PASS 但 report 高亮 `change_size_drift: true`,让 review 关注是否 scope creep
- 实际改动**触及高风险类别**(auth / payments / 加密 / 数据迁移 / 跨模块重构 / 新增依赖 / 公开 API 变更)但 spec 风险区段**未标注** → PASS 但 report 高亮 `unflagged_risk: <类别>`
- 实际改动文件**严重超出** spec 影响范围列表(命中规模漂移**且**高风险未声明,二者并存)→ REJECT,理由 "actual diff diverges from spec significantly"

单一信号触发只标注、不 REJECT;多信号叠加才 REJECT。

### Step 8: Output Review Report

报告结构:

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
- Must-fix(仅 REJECT):
  - <item>
```

判定规则:
- 任一 hard gate fail / acceptance fail / 工程规范硬规则违反 / diff audit 多信号叠加(change_size_drift + unflagged_risk 同时命中)→ REJECT
- 否则 → PASS

### Step 9: Pass Path (Squash Merge + Cleanup)

按顺序,**每一步失败都报错并 stop**,不要静默继续:

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

# 4. 标 TODO 为 done — 把 `- [ ]` 改成 `- [x]`(注意保留 epic 子项缩进)

# 5. archive commit
git add docs/spec/_done/<slug>.md TODO.md
git commit -m "chore(todo): archive <slug> spec and mark TODO as done"

# 6. 删 worktree(删之前检查 .worktrees/<slug> 工作树是否干净)
git -C .worktrees/<slug> status --porcelain # 非空 → 拒绝 remove
test -d .worktrees/<slug> && git worktree remove .worktrees/<slug>

# 7. 删 local branch
git branch -D todo/<slug>

# 8. 删 remote branch(若存在)
git push origin --delete todo/<slug> 2>/dev/null || echo "remote branch already gone"

# 9. push main
git push origin main
```

**Constitution gate**(Step 9 高风险):
- IM 会话(`CC_SESSION_KEY` 非空)→ 自动 push(用户调用本 skill 已是显式授权 full flow)
- 终端直连 + protected branch → 让 push 失败,告知用户手动处理
- **永远不**用 `--force` / `--force-with-lease`

### Step 10: Reject Path (Findings → Spec)

1. **不动 main**(不 merge)
2. **不删** branch / worktree(用户要去 fix)
3. 切到 branch `todo/<slug>`(或进 worktree)
4. spec 末尾追加:

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

5. 更新 frontmatter:
   - `status: approved`(不是 draft —— 避免人重审)
   - `updated: <today>`
   - `attempts` 不变(review 不算 stage 2 尝试)

6. commit + push spec 修改:

```bash
git add docs/spec/<slug>.md
git commit -m "chore(todo): review feedback for <slug>"
git push origin todo/<slug>
```

7. 切回主仓库初始 branch

### Step 11: Epic Auto-Close(仅 Pass Path 后)

如果刚 merged 的 slug 是某 epic 子项(命名 `<epic-slug>-<suffix>`):

```bash
# 找父 epic:往上找最近的非缩进 `- [ ] \`<epic-slug>\``
grep -rE "^  - \[.\] \`<slug>\`" TODO.md
```

如果找到父 epic:

1. 列 epic 所有子 slug(TODO.md 中缩进在 epic 下方的所有 `- [ \`<x>\`` 行)
2. 检查每个子 slug 对应的 spec 是否在 `docs/spec/_done/`(**只看 `_done/`,不看 TODO 复选框**)
3. 全部 done:
   - epic 行 `- [ ]` → `- [x]`
   - epic 对应 spec 若在 `docs/spec/`,mv 到 `_done/`
   - 多一个 commit:`chore(todo): close epic <epic-slug>`
   - push

未全 done → 不动 epic,输出 "epic <epic-slug> 进度 X/Y,未关闭"

## Output Contract

报告必须包含:

- `mode: done`
- `slug`: 处理的 slug
- `verdict`: `done` / `rejected` / `idle` / `refused`
- `done_sha`: 仅 done 时(main 上的 squash commit SHA)
- `must_fix`: 仅 rejected 时的清单
- `epic_closed`: 若关联 epic 也关闭了,列出 epic slug
- `push_status`: `pushed` / `failed`(push main 是否成功)
- `cleanup_status`: `complete` / `partial`(branch/worktree 是否全清掉)
- `next_step`:
  - done: `done 完成,下一个 TODO 可让 stage 2 拾起`
  - rejected: `findings 已写回 spec,等 stage 2 重做`
  - idle: `没有 ready-for-review 的 spec`
  - refused: `<拒绝原因>`

## Common Failure Modes

**1. Hard gates 红了还推**:lint fail 视为"小事"。任一 red → 必 REJECT,不豁免。

**2. Subjective acceptance 自动判通过**:spec 写"UX 友好"agent 自己判 pass。处理:subjective 必须让用户确认。

**3. diff audit 信号被忽略**:实际改动远超 spec 估算或触及未声明的高风险类别,仍照常合并。处理:单信号高亮、双信号叠加必 REJECT。

**4. Pass path 中途失败留半成品**:squash commit 成功,spec 归档 commit 失败。处理:报错 stop,给用户手动收尾命令,**不**尝试 reset 已合并 commit。

**5. 误删用户自己的 worktree**:worktree 内有未提交修改被 remove 删掉。处理:删前检查 `status --porcelain`,非空拒绝 remove。

**6. epic 误关闭**:父 epic 还有子项 status=draft 在 `docs/spec/`(没 done),但 TODO.md 上看起来都 [x]。处理:epic 关闭判定**只**看 `docs/spec/_done/`,不看 TODO 复选框。

**7. 主仓库工作树脏照样开干**:把用户脏改动卷入 review。处理:Step 3 检查到脏 → refuse。

**8. 跨过用户确认 force push**:push main 被 protected 拒,改用 `--force-with-lease`。处理:永远不 force push 到 main。push 失败 → 报告手动处理。
