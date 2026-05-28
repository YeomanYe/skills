# Mode `init` — 项目接入 todo-flow 流水线

把一个普通工程**初始化**为支持 todo-flow 流水线的工程。一次性、幂等——已经初始化过再跑只会补缺失项,不破坏现有内容。

## Required Workflow

按以下顺序:

1. 探测当前状态
2. 一次性收集所需输入(仅当真要新建 TODO.md 时问 1 个问题)
3. 创建 / 补齐流水线骨架
4. 改 `.gitignore`
5. 一次性 commit + push
6. 输出报告

### Step 1: Probe Environment

```bash
# 必须在 git 仓库根目录
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || { echo "ERROR: not a git repo"; exit 1; }
test "$(git rev-parse --show-toplevel)" = "$(pwd -P)" || { echo "ERROR: must run at repo root"; exit 1; }

# 探测默认分支
default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
default_branch=${default_branch:-main}
current_branch=$(git rev-parse --abbrev-ref HEAD)
[ "$current_branch" = "$default_branch" ] || { echo "ERROR: must run on ${default_branch}, currently on ${current_branch}"; exit 1; }

# 工作树必须干净(避免把用户脏改动卷进 init commit)
test -z "$(git status --porcelain)" || { echo "ERROR: working tree dirty, commit or stash first"; exit 1; }

# 探测 4 个骨架项的存在状态
test -f TODO.md && HAS_TODO=1 || HAS_TODO=0
test -d docs/spec && HAS_SPEC_DIR=1 || HAS_SPEC_DIR=0
test -d docs/spec/_done && HAS_DONE_DIR=1 || HAS_DONE_DIR=0
{ test -f .gitignore && grep -qxE '\.worktrees/?' .gitignore; } && HAS_GITIGNORE=1 || HAS_GITIGNORE=0
```

任一硬错(非 git 仓库 / 不在根目录 / 不在默认分支 / 工作树脏)→ 报错 stop,不动任何文件。

**幂等检查**:4 个骨架项都已就位(`HAS_TODO=1 && HAS_SPEC_DIR=1 && HAS_DONE_DIR=1 && HAS_GITIGNORE=1`)→ 输出"already initialized"报告 + exit 0,**不重复执行**。

### Step 2: Collect Inputs (仅当真要建 TODO.md 时问)

- 4 个骨架项**全部缺失**:用 AskUserQuestion 问 1 个问题——"TODO.md 的初始项目类型是什么",3 选 1:`Features` 段(默认,UI/产品类)/ `TODO` 段(通用)/ `Backlog` 段(偏 backlog 文化)。用户在调用 prompt 里说了类型 → 跳过问。
- 部分骨架已在 → **不问**,直接进 Step 3 补缺失项。

### Step 3: Create / Patch Skeleton

按 `HAS_*` 标记**只补缺失项**,绝不覆盖已有:

```bash
# 创建 TODO.md(仅 HAS_TODO=0 时)
if [ "$HAS_TODO" = "0" ]; then
  section_name="${SECTION_NAME:-Features}"   # Step 2 收集的;默认 Features
  cat > TODO.md <<EOF
# TODO

## ${section_name}

EOF
fi

# 创建 docs/spec/ 和 docs/spec/_done/(git 不追踪空目录,用 .gitkeep 占位)
if [ "$HAS_SPEC_DIR" = "0" ]; then
  mkdir -p docs/spec
  touch docs/spec/.gitkeep
fi
if [ "$HAS_DONE_DIR" = "0" ]; then
  mkdir -p docs/spec/_done
  touch docs/spec/_done/.gitkeep
fi
```

**禁止动作**:
- 已有 `TODO.md` 不重写(即使内容不规范也只警告,让用户自己调)
- 已有 `docs/spec/` 不清空、不动其内容
- 不创建 `.worktrees/` 目录本身(stage2 创建 worktree 时自然产生)

### Step 4: Patch .gitignore

确保 `.worktrees/`(stage2 创建的开发隔离区)在 ignore 列表里。stage2 把走查产物 `.review-artifacts/` 存在 worktree 内部,已经被 `.worktrees/` 一并忽略,**不需要单独列**。

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

### Step 5: Commit + Push

```bash
# 校验 staged 列表只包含本次预期变更(防御性检查)
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

# Staged 为空(全部已存在)→ 进幂等分支(理论上 Step 1 已经拦掉,这是双保险)
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

### Step 6: Verify and Report

```bash
# 验证最终状态
test -f TODO.md && test -d docs/spec && test -d docs/spec/_done && \
  grep -qxE '\.worktrees/?' .gitignore || { echo "ERROR: post-init verification failed"; exit 1; }
```

## Output Contract

报告必须包含:

- `mode: init`
- `project_root`: 工程绝对路径
- `default_branch`: 探测出的默认分支
- `actions_taken`: 数组,列出本次实际做了哪些动作(如 `["created TODO.md", "created docs/spec/", "patched .gitignore"]`);幂等空跑时为 `[]`
- `init_commit`: commit SHA(`pushed | local-only | no-op`)
- `next_step`:
  - 全新初始化:`项目已就位。下一步:跑 'todo-flow add' 添加第一条 TODO;或者直接编辑 TODO.md`
  - 幂等空跑:`项目已经初始化过,无需操作`

## Common Failure Modes

**1. 不在 git 仓库 / 不在根目录**:Step 1 拦截,报错 stop。本 mode 不替用户跑 `git init`。

**2. 工作树脏被卷入 init commit**:Step 1 检测脏拒绝执行;Step 5 staged 文件白名单校验是双保险。

**3. 不在默认分支跑 init**:可能把 init commit 落在 feature branch 然后被忘掉。Step 1 强制拒绝。

**4. 重写已有 TODO.md / docs/spec/**:本 mode 是**补缺失项**模式,已存在的内容一律不动,哪怕看着不规范也只警告不修改。

**5. push 失败导致下次 cron 看到本地有 commit 远端没有 → 状态不一致**:push 失败不报错只 WARN(本地 commit 已落地,stage2 同机能看到);多机协作场景下用户该手动 push。
