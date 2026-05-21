# Verify Executor Prompt (multi-project, self-driving)

把整篇内容作为 prompt 喂给 agent。**完全无入参**:调用方不需要 cd、不需要传任何参数,本 prompt 自己从仓库状态推断该处理什么。可被 cron / 定时器无参重复调度。

与 stage1 / stage2 **完全隔离无感知**:本 prompt 通过 spec status 状态机自然接力,不依赖 stage2 触发,不传任何参数给 stage1/2。

---

你的任务:在一组工程里挑出"**下一个待验证的 ready-for-review spec**",跑验证(hard gates + Playwright 走查) + 飞书回传报告 + 把 spec status 推到 `verified` 或 `verify-failed`。一次调用只处理 **1 个 spec**。

## 占位符约定

> **两种占位符,语法上严格区分**:
> - `${UPPER_SNAKE}` = **预处理占位符**(调用方喂 prompt 前字符串替换)
> - `<lower_snake>` = **运行时占位符**(agent 从仓库状态推断自动填)
> - bash 代码块里的 `${shell_var}` 是 shell 语法,**不算占位符**(由 agent 在脚本内赋值后展开)

### 运行时占位符(agent 自动填,语法 `<lower_snake>`)

- `<slug>` — 来自 spec frontmatter 的 `id`
- `<today>` — `date -u +%Y-%m-%d`
- `<now_iso>` — `date -u +%Y-%m-%dT%H:%M:%SZ`
- `<project_root>` — 当前处理工程的绝对路径
- `<default_branch>` — 默认主干分支名,**探测**:

  ```bash
  default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
  default_branch=${default_branch:-main}
  ```

- `<worktree_path>` — `<project_root>/.worktrees/<slug>`(stage2 创建的,stage3 复用)

### 预处理占位符(调用方字符串替换,语法 `${UPPER_SNAKE}`)

- `${LARK_APP_ID}` — 飞书 bot 的 app_id(如 `cli_a95e48e3e1b89bb6`)
- `${LARK_APP_SECRET}` — 飞书 bot 的 app_secret(headless tenant_access_token 模式)
- `${LARK_CHAT_ID}` — 接收 verify 报告的群/会话 ID(如 `oc_e26cf931bd620d2c...`)
- `${LARK_RECEIVE_ID_TYPE}` — 默认 `chat_id`(也可 `user_id` / `open_id` / `email`)
- `${PROJECTS_ARRAY}` — 工程绝对路径数组(跟 stage1/stage2 **必须一致**),格式见下

`${PROJECTS_ARRAY}` 替换示例(替换后):

```bash
PROJECTS=(
  "/Users/ym/Documents/projects/A"
  "/Users/ym/Documents/projects/B"
  "/Users/ym/Documents/projects/C"
)
```

## 工程清单(预处理后硬编码)

```
PROJECTS=${PROJECTS_ARRAY}
```

> ⚠️ **轮转顺序 = 数组顺序,必须与 stage1 / stage2 prompt 中的清单严格一致**。

## 飞书凭证(预处理后硬编码,env 形式)

```bash
export LARK_APP_ID="${LARK_APP_ID}"
export LARK_APP_SECRET="${LARK_APP_SECRET}"
LARK_CHAT_ID="${LARK_CHAT_ID}"
LARK_RECEIVE_ID_TYPE="${LARK_RECEIVE_ID_TYPE}"
```

`lark-cli` 自动读 `LARK_APP_ID` + `LARK_APP_SECRET` env,**无浏览器、无 OAuth、stateless 并发安全**。

## 执行算法(严格按顺序)

### Step -1:占位符未替换 fact-check(必跑,异常立即 exit)

调用方应在喂 prompt 前预处理替换所有 `${...}` 占位符。agent 启动后**必须**校验关键占位符已替换,避免污染 spec 状态:

```bash
# 校验 LARK_* 凭证不是字面 ${...}
for var in LARK_APP_ID LARK_APP_SECRET LARK_CHAT_ID; do
  val=$(eval echo "\$$var")
  if [[ "$val" == *'${'* ]] || [ -z "$val" ]; then
    echo "ERROR: $var 未替换或为空 (got: '$val'),拒绝执行"
    exit 2
  fi
done

# 校验 PROJECTS 数组不是字面 ${PROJECTS_ARRAY}
[ "${#PROJECTS[@]}" -lt 1 ] && { echo "ERROR: PROJECTS 数组为空,占位符未替换"; exit 2; }
[[ "${PROJECTS[0]}" == *'${'* ]] && { echo "ERROR: PROJECTS[0] 未替换 (${PROJECTS[0]})"; exit 2; }
```

**禁止**:任何占位符未替换就照常往下跑(会用错误凭证调 lark-cli + 错误标 spec 状态)。

### Step 0:选择本次处理的工程和 spec(无入参,从仓库状态推断)

遍历 `PROJECTS` 数组,对每个 `<project_root>`:

```bash
cd "${project_root}"
test -d docs/spec || continue
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || continue
git fetch origin 2>/dev/null || true

# 找 status: ready-for-review 的 spec(stage2 跑完留下的)
for spec in docs/spec/*.md; do
  status=$(yq -e '.status' "$spec" 2>/dev/null) || continue
  [ "$status" = "ready-for-review" ] || continue

  slug=$(yq -e '.id' "$spec")
  # 必须有对应 worktree(stage2 创建的)
  test -d ".worktrees/${slug}" || continue
  # 必须有对应 branch
  git show-ref --verify --quiet "refs/heads/todo/${slug}" || continue

  # 命中!
  TARGET_PROJECT="${project_root}"
  TARGET_SPEC="$spec"
  TARGET_SLUG="$slug"
  TARGET_WORKTREE="${project_root}/.worktrees/${slug}"
  break 2
done

# 无候选 → 整轮跳过,报告 "no ready-for-review spec found",exit 0
```

**禁止**:同时处理多个 spec(本 prompt 一次只动一个)。

### Step 1:进入 worktree

```bash
cd "${worktree_path}"
git status --porcelain  # 应该是干净的(stage2 push 完后无新改动)
```

worktree 不存在或 branch 不存在 → 报告 "worktree/branch missing,可能 stage2 失败或 worktree 被清理" → exit 1。

### Step 2:跑验证(hard gates)

**探测项目类型**,按命中的栈跑:

```bash
if [ -f package.json ]; then
  if [ -f pnpm-lock.yaml ]; then PM=pnpm; INSTALL="pnpm install --frozen-lockfile"
  elif [ -f yarn.lock ]; then PM=yarn; INSTALL="yarn install --frozen-lockfile"
  else PM=npm; INSTALL="npm ci"
  fi
  $INSTALL 2>&1 | tail -5
  $PM run lint 2>&1 | tail -10 || { echo "lint missing, skip"; }
  $PM test 2>&1 | tail -20
  $PM run build 2>&1 | tail -10 || { echo "build missing, skip"; }
elif [ -f Cargo.toml ]; then
  cargo fmt --check && cargo clippy -- -D warnings && cargo test && cargo build
elif [ -f pyproject.toml ]; then
  echo "Python project: 用 AGENTS.md / CLAUDE.md 指定 lint+test+build"
elif [ -f go.mod ]; then
  go vet ./... && go test ./... && go build ./...
fi
```

记录每个命令的 exit code 和 tail 输出,用于 Step 5 飞书报告。

### Step 3:Playwright 走查(截图 + 可选录屏)

按 spec frontmatter 的 `needs_visual_check` / `needs_video_check` 决定跑哪些。

**产物存储约定**(同 stage2):

```bash
ARTIFACTS_DIR="${worktree_path}/.review-artifacts/${TARGET_SLUG}"
mkdir -p "$ARTIFACTS_DIR"/{screenshots,videos}
```

走查脚本细节、dev server 端口处理、视口设置等 — **复用 stage2-prompt.md 的 Step 5.5.1 / 5.5.2 / 5.5.3 段**(逐字搬过来或引用,本文档不重复)。

走查产物路径记下:`SCREENSHOTS=( ... )` `VIDEOS=( ... )`,用于 Step 5。

### Step 4:判定验证结果

```bash
VERDICT=pass
FAIL_REASON=""

# hard gates 任一失败
[ "$LINT_EXIT" != 0 ] && { VERDICT=fail; FAIL_REASON="lint failed"; }
[ "$TEST_EXIT" != 0 ] && { VERDICT=fail; FAIL_REASON="test failed"; }
[ "$BUILD_EXIT" != 0 ] && { VERDICT=fail; FAIL_REASON="build failed"; }
# Playwright console.error 来自改动文件 → 阻塞
[ -n "$CONSOLE_ERROR_FROM_CHANGED_FILES" ] && { VERDICT=fail; FAIL_REASON="visual check console.error"; }
```

### Step 5:飞书回传(lark-cli)

**先 fact-check `lark-cli im` 子命令格式**(实跑 `lark-cli im --help`,或参考 [larksuite/cli 文档](https://github.com/larksuite/cli)):

```bash
# 通用模板(子命令名以实际 --help 为准,以下是 2026-05 推断)
COMMON_FLAGS="--receive-id ${LARK_CHAT_ID} --receive-id-type ${LARK_RECEIVE_ID_TYPE}"

# 发文字摘要
SUMMARY="[${VERDICT}] ${TARGET_SLUG} verify\n工程: ${TARGET_PROJECT}\n时间: ${now_iso}"
[ "$VERDICT" = "fail" ] && SUMMARY="${SUMMARY}\n失败: ${FAIL_REASON}"
lark-cli im +messages-send $COMMON_FLAGS --text "$SUMMARY"

# 发截图(每张一条,避免单条过大)
for img in "${SCREENSHOTS[@]}"; do
  lark-cli im +messages-send $COMMON_FLAGS --image "$img"
  sleep 0.2  # rate limit: ≤5 msg/s
done

# 录屏(若有)
for vid in "${VIDEOS[@]}"; do
  lark-cli im +messages-send $COMMON_FLAGS --file "$vid"
done

# 失败时附最后 20 行错误日志
if [ "$VERDICT" = "fail" ]; then
  ERROR_LOG=$(echo "${TEST_OUTPUT}\n${BUILD_OUTPUT}" | tail -20)
  echo "$ERROR_LOG" > "${ARTIFACTS_DIR}/error-tail.txt"
  lark-cli im +messages-send $COMMON_FLAGS --file "${ARTIFACTS_DIR}/error-tail.txt"
fi
```

**Rate limit**: 每 app 100 msg/min, 5 msg/s。若截图 > 5 张,sleep 200ms 间隔。

**飞书失败不阻塞 verify 流程**:lark-cli 出错只记录到 spec,不改 verify VERDICT。

### Step 6:更新 spec status + 追加 verify 报告

在 worktree 内的 spec frontmatter 改:

- VERDICT = pass:
  - `status: verified`
  - `verified_at: <now_iso>`
- VERDICT = fail:
  - `status: verify-failed`
  - `verify_failed_at: <now_iso>`
  - `attempts: <原值 +1>`(stage2 已有 attempts 字段,本步只 +1)

在 spec 末尾追加:

```md
## Verify report (${today} HH:MM Z)
- VERDICT: ${VERDICT}
- 工程: ${TARGET_PROJECT}
- worktree: ${worktree_path}
- hard gates: lint=${LINT_EXIT} test=${TEST_EXIT} build=${BUILD_EXIT}
- 截图数: ${#SCREENSHOTS[@]}
- 录屏数: ${#VIDEOS[@]}
- 飞书回传: ${LARK_NOTIFY_STATUS}  # sent / fallback / failed
- 失败原因(若有): ${FAIL_REASON}
```

### Step 7:Commit spec 改动 + push

```bash
git add docs/spec/${TARGET_SLUG}.md
git commit -m "chore(todo): verify ${TARGET_SLUG} → ${VERDICT}"
git push origin "todo/${TARGET_SLUG}"
```

**不**:
- ❌ commit `.review-artifacts/`(留在 worktree 本地)
- ❌ 切回 `<default_branch>` / 删 worktree(调用方决定何时清理)
- ❌ `--force` / `reset --hard` / 改远程 `<default_branch>`

### Step 8:清洁退出

```bash
echo "stage3-verify complete: ${TARGET_SLUG} → ${VERDICT}"
exit 0
```

## 内部 retry 限制

stage3 verify 是**单次执行**,**不**做 fix-retry(那是 stage2 的事)。verify 失败 → status = verify-failed → 等 stage2 重新跑(或人介入)。

## 输出格式

```
stage3-verify report
─────────────────────
slug:         ${TARGET_SLUG}
project:      ${TARGET_PROJECT}
worktree:     ${worktree_path}
verdict:      ${VERDICT}
fail_reason:  ${FAIL_REASON}    (仅 fail)
hard_gates:
  lint:       exit=${LINT_EXIT}
  test:       exit=${TEST_EXIT}
  build:      exit=${BUILD_EXIT}
visual_check:
  screenshots: ${#SCREENSHOTS[@]}
  videos:      ${#VIDEOS[@]}
  console.error: ${CONSOLE_ERROR_FROM_CHANGED_FILES:-none}
lark_notify:
  status:     sent | partial | failed
  app_id:     ${LARK_APP_ID}
  chat_id:    ${LARK_CHAT_ID}
spec_status:  ready-for-review → ${VERDICT}
commit:       <sha>
pushed:       todo/${TARGET_SLUG}
```

无候选 spec 时:

```
stage3-verify: no ready-for-review spec found in ${#PROJECTS[@]} projects, exit 0
```

## 约束

- 一次只处理 1 个 spec
- 不并发跑 verify(同 spec 不会被多次拾起,因为 status 改了)
- 不依赖 stage1/2 触发(独立 cron 跑)
- 不依赖 cc-connect daemon(直接 lark-cli + env var)
- 飞书 secret 通过 env 传入,**绝不写进 spec 或 git**
- 跑完不切分支、不删 worktree、不破坏主仓库

## 工具调用建议

- `yq`:读 spec frontmatter
- `lark-cli`:发飞书(全局装一次 `npm i -g @larksuite/cli`)
- `git`:仓库操作
- `pnpm` / `npm` / `cargo` / `go`:按项目栈
