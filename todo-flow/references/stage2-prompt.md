# Dev Executor Prompt (multi-project, self-driving)

把整篇内容作为 prompt 喂给 agent。**完全无入参**：调用方不需要 cd、不需要传任何参数，本 prompt 自己从仓库状态推断该处理什么。可被 cron / 定时器无参重复调度。

---

你的任务：在一组工程里挑出"**下一个待开发的 approved spec**"，开发实现、跑验证、把 spec 状态推到 `ready-for-review`、push branch。一次调用只处理 **1 个 spec**。

## 占位符约定

> **两种占位符,语法上严格区分**:
> - `${UPPER_SNAKE}` = 预处理占位符（调用方喂 prompt 前字符串替换）
> - `<lower_snake>` = 运行时占位符（agent 从仓库状态推断自动填）
> - bash 代码块里的 `${shell_var}` 是 shell 语法,**不算占位符**

### 预处理占位符

- `${PROJECTS_ARRAY}` — 工程绝对路径数组(必须跟 stage1/stage3 严格一致)

### 运行时占位符

- `<slug>` — 来自 spec frontmatter 的 `id`
- `<today>` — `date -u +%Y-%m-%d`
- `<project_root>` — 当前处理工程的绝对路径
- `<default_branch>` — 默认主干分支名，**探测**：

  ```bash
  default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
  default_branch=${default_branch:-main}
  ```

## 工程清单（预处理后硬编码）

```
PROJECTS=${PROJECTS_ARRAY}
```

> ⚠️ **轮转顺序 = 数组顺序,必须与 stage1 / stage3 prompt 中的清单严格一致**。

## 执行算法（严格按顺序）

### Step -1：占位符未替换 fact-check（必跑,异常立即 exit）

```bash
[ "${#PROJECTS[@]}" -lt 1 ] && { echo "ERROR: PROJECTS 数组为空,占位符 \${PROJECTS_ARRAY} 未替换"; exit 2; }
[[ "${PROJECTS[0]}" == *'${'* ]] && { echo "ERROR: PROJECTS[0] 未替换 (${PROJECTS[0]})"; exit 2; }
```

### Step 0：选择本次处理的工程和 spec（无入参，从仓库状态推断）

遍历上面硬编码的 `PROJECTS` 数组，对每个 `<project_root>`：

```bash
cd "${project_root}"
test -d docs/spec || continue
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || continue
# 主仓库工作树脏 → 跳过整个工程（用户可能正在开发，避免卷入）
test -z "$(git status --porcelain)" || { echo "skip: ${project_root} dirty"; continue; }
git fetch origin 2>/dev/null || true
```

按文件名**字典序**遍历 `docs/spec/*.md`（不含 `_done/`），对每个 spec：

1. 读 frontmatter `status`。**`approved` 或 `needs-rework` 进入后续判定**(needs-rework 是 revise mode 触发的返工状态,本 stage 当 approved 处理但要额外读 `## Rework instructions` 段作为补充约束),其它跳过。
2. 解析出 `id` 作为 `<slug>`。
3. 检查 `todo/<slug>` 分支与 worktree 残留状态，并**按状态分类记账**（决定本次循环的报告口径）：

   ```bash
   has_local_branch=$(git show-ref --verify --quiet "refs/heads/todo/<slug>" && echo 1 || echo 0)
   has_remote_branch=$(git ls-remote --exit-code --heads origin "todo/<slug>" >/dev/null 2>&1 && echo 1 || echo 0)
   has_worktree=$([ -e ".worktrees/<slug>" ] && echo 1 || echo 0)
   ```

   - 全为 0 → **选中**该 spec，记下 `<project_root>` `<slug>`，跳出整个遍历
   - 任一为 1 → 跳过该 spec，但**按以下分类**记录到 `stale_slugs[]`（供报告输出，让用户能识别死锁源头）：

     | spec status | branch / worktree | 含义 | 报告分类 |
     |---|---|---|---|
     | `approved` | 残留 | 上次 stage2 跑死或卡住，仍占着 slot | `needs_cleanup` |
     | `ready-for-review` | 残留 | 正常等 done | `awaiting_review` |
     | `approved` | 无残留 | 不可能（互斥），不会走到本分支 | — |

4. 全部 spec 遍历完都没选中 → 该工程无候选，跳过。

遍历完所有工程都没选中任何 spec → 报告 `🟰 nothing to develop` + `stale_slugs[]` 明细 并 exit 0。**这是用户唯一能看出"卡住"的信号源**——如果你看到同一个 slug 在 `needs_cleanup` 分类里反复出现多次 cron 循环，说明它需要人工介入：

```bash
cd <project_root>
git worktree remove .worktrees/<slug> --force   # 仅当确认产物无价值
git branch -D todo/<slug>
git push origin --delete todo/<slug>   # 若 remote 也有
# 然后改 spec / 删 spec 让下次 cron 重做或跳过
```

**自愈策略说明**：stage2 **不会**自动 `--force` 删残留 worktree / branch，因为里面可能有未推送的产物或诊断信息。看到 `needs_cleanup` 是有意的"求救信号"，而不是 bug。

**轮转效果**：每次都挑"全新无残留的第一个 approved spec"。已开过的 slug 因为留下了 branch/worktree 自然跳过；新的 approved spec 进入候选。**无状态、无 round 概念、断点续跑天然安全**——只要不出现 `needs_cleanup` 卡 slot 的情况。

### Step 1：探测默认分支

Step 0 已经做完了 cwd / 仓库 / 工作树 / spec 状态 / branch 状态的全部筛选。这里只需补一个 default branch：

```bash
set -euo pipefail
default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
default_branch=${default_branch:-main}
```

### Step 2：创建 worktree

**先保证 `.gitignore` 含 `.worktrees/`**（必须在 worktree 创建之前完成，否则下次循环 Step 0 会因 `.worktrees/` untracked 跳过整个工程）：

```bash
# 此时仍在主仓库根目录
if [ ! -f .gitignore ] || ! grep -qxE '\.worktrees/?' .gitignore; then
  [ -f .gitignore ] || touch .gitignore
  if ! grep -qxF "# todo-flow pipeline" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# todo-flow pipeline" >> .gitignore
  fi
  echo ".worktrees/" >> .gitignore
  git add .gitignore
  git commit -m "chore: ignore .worktrees/ (todo-flow stage2)"
  git push origin "${default_branch}" 2>&1 || echo "WARN: push .gitignore failed, local only"
fi
```

这是**幂等单点修补**——首次发现缺失时追加并提交，后续 cron 调用无 op。commit message 明确写来源。

然后创建 worktree：

```bash
mkdir -p .worktrees
worktree_dir=".worktrees/${slug}"
# Step 0 已保证此目录不存在；若中间被人加进来 → exit 1，让下次循环重新选 spec
test ! -e "$worktree_dir" || { echo "worktree dir appeared mid-run, abort"; exit 1; }

git worktree add -b "todo/${slug}" "$worktree_dir" "$default_branch"
cd "$worktree_dir"
```

**从这一步开始，所有 git/编辑操作都在 worktree 内完成**。要改 spec 也改 worktree 里的副本。

### Step 3：理解 spec

完整读一遍 `docs/spec/<slug>.md`，逐节理解：

- "目标" → 做什么
- "推荐方案 + 理由" → 怎么做
- "影响范围" → 预期改动文件清单（**实际改动不应显著超出**）
- "验收标准" → self-check 的最终依据
- "风险" → 主动规避

把验收标准的每条 checkbox 贴到 TodoWrite（如果可用）跟踪。

### Step 4：实现

工程规范找的顺序：

1. `AGENTS.md` ← 工程规范首选
2. `CLAUDE.md` ← 次选
3. 都没有 → 用通用规范（小步快跑、命名清晰、加测试、注释只写 why）

实现遵循：

- **TDD**：新功能 → 先写 failing test → 再写实现 → tests 通过
- **修 bug**：先写 failing repro test → 再修
- **纯样式改动**：可豁免 TDD（**spec 里必须明确写了"纯样式"才能豁免**）
- 改动**只动 spec "影响范围" 里列出的文件**；范围外文件改动需有充分理由 + 在 spec 末尾追加一条 Decisions log
- 不引入 spec 未列出的新依赖
- 不修改公开 API / 类型签名（spec 未授权时）

### Step 5：实现完成判定（stage2 跑轻量编译自检 + 自判定）

stage2 **不**跑完整 lint/test/Playwright(那是 stage3 的事),但**必须**跑**轻量编译自检**拦掉 typo / syntax error / 缺依赖等"代码起码能跑"信号(避免把死活跑不起来的代码 push 到 todo branch,浪费 stage3 一轮):

```bash
# 按项目栈跑轻量自检(不算 hard gate,只 fail-fast)
if [ -f package.json ]; then
  $INSTALL 2>&1 | tail -5 || { IMPL_FAIL=1; FAIL_REASON="install failed"; }
  # tsconfig 存在则 typecheck
  [ -f tsconfig.json ] && (npx tsc --noEmit 2>&1 | tail -5 || { IMPL_FAIL=1; FAIL_REASON="tsc --noEmit failed"; })
elif [ -f Cargo.toml ]; then
  cargo check 2>&1 | tail -10 || { IMPL_FAIL=1; FAIL_REASON="cargo check failed"; }
elif [ -f go.mod ]; then
  go vet ./... 2>&1 | tail -10 || { IMPL_FAIL=1; FAIL_REASON="go vet failed"; }
fi
```

然后判 `IMPL_OK`:

- 改动文件清单覆盖 spec "影响范围" 列表(允许范围内任意子集)
- 至少 1 个 commit(代码 + 必要的 test) — 改动应包含 spec "验收标准" 的可测条件对应的实现
- worktree `git status --porcelain` 干净(没漏 add)
- (TDD 流程下)至少存在一个 test 文件被新增或修改

判 `IMPL_FAIL`(任一命中):

- agent 自己写代码陷入循环(同一处编译/类型错误 3 次未自愈)
- spec "影响范围" 列出的关键文件 agent 找不到 / 误读
- 用户在 spec 里硬约束的禁项被自己违反(如"不引新依赖"却 install 了)

### Step 6：成功路径(`IMPL_OK`)

在 worktree 内的 spec **头部**(frontmatter `---` 之后,第 1 个 `##` 之前)**写或覆盖** `## Stage 2 report` 段:

```md
## Stage 2 report (${today})
- 实现自:stage2 cron prompt
- worktree: ${worktree_path}
- branch: todo/${slug}
- commits: <n>
- 改动文件: <count>(<file 1>, <file 2>, ...)
- 关键决定: <一句>
- needs-rework 兜底: <如本次接的是 needs-rework,这里说"按 ## Rework instructions 第 N 条调整了 X">
```

更新 frontmatter:

- `status: ready-for-review`
- `updated: ${today}`

commit 顺序(**只 commit 代码 + spec,绝不 commit `.review-artifacts/`**):

1. 先 commit 代码实现(subject 用 `feat:` / `fix:` / 按 spec 性质)
2. 再 commit spec 更新(subject `chore(todo): ${slug} → ready-for-review`)

```bash
git push -u origin "todo/${slug}"
```

### Step 7：失败路径(`IMPL_FAIL`)

在 worktree spec **头部** 写或覆盖 `## Stage 2 report` 段(同 Step 6 格式),但额外含失败信息:

```md
## Stage 2 report (${today})
- 实现自:stage2 cron prompt
- VERDICT: failure
- worktree: ${worktree_path}
- branch: todo/${slug}
- 失败原因: <精确错误源 + file:line>
- 诊断: <agent 已尝试的路径 + 卡住的具体步骤>
- attempts: <旧值 +1>
```

frontmatter:

- `updated: ${today}`
- `attempts: <旧值 +1>`
- **不改 `status`**(保持 approved / needs-rework,等下次 cron 或人介入)
- `attempts >= 3` → 自动 `status: blocked`

commit spec(不 commit 半成品代码),push branch(让调用方能看到 diff 诊断)。

### Step 8：清洁

不论成功失败:

- **不**切回 `${default_branch}` / 其它分支
- **不**删 worktree 或 branch
- **不**强 push / reset hard / 改远程 `${default_branch}`
- 主仓库目录留干净状态

## 内部 fix-retry 限制

允许循环:`write code → 自测语法 → fail → diagnose → fix → 再写`。

**同一类错误**(同一处编译/类型错误 / 同一处找不到的文件)最多 **3 次**。3 次仍不过 → Step 7(`IMPL_FAIL`)。

## Output Contract(结构化 JSON,给外层工具解析)

**唯一输出 = 一个合法 JSON block**(包在 ```json ... ``` 里)。

成功(`IMPL_OK`):

```json
{
  "stage": 2,
  "verdict": "success",
  "slug": "<slug>",
  "project": "<project_root>",
  "worktree": "<worktree_path>",
  "branch": "todo/<slug>",
  "spec_path": "<project_root>/docs/spec/<slug>.md",
  "commit_shas": ["<code sha>", "<spec sha>"],
  "pushed": true,
  "files_changed": <n>,
  "rework_iteration": <true | false>,  // 是否接的 needs-rework
  "summary": "✓ stage2: implemented `<slug>` (<n> commits) → ready-for-review",
  "im_attach": [],
  "local_artifacts": [
    {"type": "worktree_dir", "path": "<worktree_path>"}
  ],
  "errors": [],
  "next_action": "等 stage3 跑 verify"
}
```

失败(`IMPL_FAIL`):

```json
{
  "stage": 2,
  "verdict": "failure",
  "slug": "<slug>",
  "project": "<project_root>",
  "worktree": "<worktree_path>",
  "branch": "todo/<slug>",
  "attempts": <旧值 +1>,
  "summary": "✗ stage2: failed at impl (<原因摘要>, attempts=<n>)",
  "im_attach": [],
  "local_artifacts": [{"type": "worktree_dir", "path": "<worktree_path>"}],
  "errors": [
    {"step": "impl", "tail": "<具体错误源 + 卡住步骤>"}
  ],
  "next_action": "attempts>=3 → status=blocked 人介入;否则等 cron 重跑或人改 spec"
}
```

空跑/无候选(全 idle):

```json
{
  "stage": 2,
  "verdict": "idle",
  "slug": null,
  "project": null,
  "stale_slugs": [
    {"slug": "<...>", "category": "needs_cleanup | awaiting_review", "project": "<...>"}
  ],
  "summary": "no approved/needs-rework spec available across <n> projects (<n> stale)",
  "im_attach": [],
  "errors": [],
  "next_action": "若 needs_cleanup 反复出现 → 人工 git worktree remove + git branch -D"
}
```

## 约束

- 一次只处理 1 个 spec
- 不并发(同 slug 不会被多次拾起,因为 branch/worktree 残留检测)
- **stage2 不跑 lint/test/build/Playwright**(交给 stage3),只对"实现是否落地"自我判定
- 处理 `needs-rework` spec 时必须读 `## Rework instructions` 段作为补充约束
- 飞书发送由外层调用方处理(stage2 只输出 JSON,不调 lark-cli)
- 不切分支、不删 worktree、不破坏主仓库

## 工具调用建议

- `yq`:读 spec frontmatter
- `git`:仓库操作
- `pnpm` / `npm` / `cargo` / `go`:按项目栈(仅用于 install 依赖,不跑 test)
