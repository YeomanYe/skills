# Verify Executor Prompt (multi-project, self-driving)

把整篇内容作为 prompt 喂给 agent。**完全无入参**:调用方不需要 cd、不需要传任何参数,本 prompt 自己从仓库状态推断该处理什么。可被 cron / 定时器无参重复调度。

与 stage1 / stage2 **完全隔离无感知**:本 prompt 通过 spec status 状态机自然接力,不依赖 stage2 触发,不传任何参数给 stage1/2。

---

你的任务:在一组工程里挑出"**下一个待验证的 ready-for-review spec**",跑 hard gates(lint/test/build) + Playwright 走查 + 把 spec status 推到 `verified` 或 `verify-failed` + 输出结构化 JSON 报告。一次调用只处理 **1 个 spec**。

**飞书 / IM 回传由外层调用方处理**:本 prompt 只输出 JSON,JSON 含 `im_attach` 清单告诉调用方该发什么。本 prompt 不直接调任何 IM SDK / CLI。

## 占位符约定

> **两种占位符,语法上严格区分**:
> - `${UPPER_SNAKE}` = 预处理占位符（调用方喂 prompt 前字符串替换）
> - `<lower_snake>` = 运行时占位符（agent 从仓库状态推断自动填）
> - bash 代码块里的 `${shell_var}` 是 shell 语法,**不算占位符**

### 预处理占位符（调用方字符串替换）

- `${PROJECTS_ARRAY}` — 工程绝对路径数组(必须跟 stage1/stage2 严格一致)

### 运行时占位符（agent 自动填）

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

## 工程清单(预处理后硬编码)

```
PROJECTS=${PROJECTS_ARRAY}
```

> ⚠️ **轮转顺序 = 数组顺序,必须与 stage1 / stage2 prompt 中的清单严格一致**。

## 执行算法(严格按顺序)

### Step -1:占位符未替换 fact-check(必跑,异常立即 exit)

```bash
[ "${#PROJECTS[@]}" -lt 1 ] && { echo "ERROR: PROJECTS 数组为空,占位符 \${PROJECTS_ARRAY} 未替换"; exit 2; }
[[ "${PROJECTS[0]}" == *'${'* ]] && { echo "ERROR: PROJECTS[0] 未替换 (${PROJECTS[0]})"; exit 2; }
```

### Step 0:选择本次处理的工程和 spec

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
  test -d ".worktrees/${slug}" || continue
  git show-ref --verify --quiet "refs/heads/todo/${slug}" || continue

  TARGET_PROJECT="${project_root}"
  TARGET_SPEC="$spec"
  TARGET_SLUG="$slug"
  TARGET_WORKTREE="${project_root}/.worktrees/${slug}"
  break 2
done
```

无候选 → 输出 idle JSON 并 exit 0。

### Step 1:进入 worktree

```bash
cd "${worktree_path}"
git status --porcelain  # 应该干净(stage2 push 完无新改动)
```

worktree 或 branch 不存在 → 输出 failure JSON(stale 状态) + exit 1。

### Step 2:跑 hard gates(lint / test / build)

```bash
if [ -f package.json ]; then
  if [ -f pnpm-lock.yaml ]; then PM=pnpm; INSTALL="pnpm install --frozen-lockfile"
  elif [ -f yarn.lock ]; then PM=yarn; INSTALL="yarn install --frozen-lockfile"
  else PM=npm; INSTALL="npm ci"
  fi
  $INSTALL 2>&1 | tail -5
  $PM run lint  2>&1 | tee /tmp/lint.log  ; LINT_EXIT=${PIPESTATUS[0]}
  $PM test      2>&1 | tee /tmp/test.log  ; TEST_EXIT=${PIPESTATUS[0]}
  $PM run build 2>&1 | tee /tmp/build.log ; BUILD_EXIT=${PIPESTATUS[0]}
elif [ -f Cargo.toml ]; then
  cargo fmt --check; FMT_EXIT=$?
  cargo clippy -- -D warnings; LINT_EXIT=$?
  cargo test; TEST_EXIT=$?
  cargo build; BUILD_EXIT=$?
elif [ -f pyproject.toml ]; then
  echo "Python: 用 AGENTS.md / CLAUDE.md 指定的 lint+test+build"
elif [ -f go.mod ]; then
  go vet ./...; LINT_EXIT=$?
  go test ./...; TEST_EXIT=$?
  go build ./...; BUILD_EXIT=$?
fi
```

记录 exit code 和 tail 输出供 Step 6 报告 + Step 8 JSON 用。**禁止** `--no-verify` 绕过 hook。

### Step 3:Playwright 走查(截图 + 可选录屏)

读 spec frontmatter `needs_visual_check`。`false` 或缺失 → **跳过本步**,直接 Step 4。

**全步骤遵守的视觉证据约束**:
- 视觉证据**只用 Playwright** 生成,禁用 chrome_devtools 或其它可见浏览器调试工具
- 默认 **`headless: true`**,spec 没明确要求"可见窗口演示"则不要切有界面模式
- 截图必须是**预设视口的整屏** — **禁止**只截局部组件替代整屏
- **必须记录视口尺寸**写进报告
- dev server **不占用工程默认开发端口**(避免与用户本机 dev 冲突),用随机高位端口

#### Step 3.0:产物存储约定

```bash
# 产物只存 worktree 内,跟 worktree 同生同灭
ARTIFACTS_DIR="${worktree_path}/.review-artifacts/${TARGET_SLUG}"
mkdir -p "$ARTIFACTS_DIR"/{screenshots,videos}
```

`.gitignore` 已含 `.worktrees/`(stage2 保证),`.review-artifacts/` 在 worktree 内自然不进 commit。

#### Step 3.1:启动 dev server(随机端口,避开默认)

按项目栈探测启动命令(`pnpm dev` / `npm run dev` / `cargo run` 等),用环境变量传随机端口(3000-9000 范围,避开 3000/5173/8080/4200 等默认):

```bash
PORT=$((RANDOM % 6000 + 3000))
# 等待端口就绪(最多 60s)
$PM run dev -- --port $PORT > "$ARTIFACTS_DIR/dev-server.log" 2>&1 &
DEV_PID=$!
for i in {1..60}; do
  curl -sf "http://localhost:$PORT" >/dev/null 2>&1 && break
  sleep 1
done
```

#### Step 3.2:设置视口 + 走查截图

视口默认 `1440x900`(spec 可声明 `viewport: WxH` override)。

Playwright 走查脚本要点:
- `headless: true`
- 跳到首页 → 截图 `main.png`
- 按 spec 验收标准里 UI checkbox 对应的状态遍历:打开关键 modal/drawer → 各截 1 张
- 若有"二次确认/删除"流程 → 触发确认态 → 截 1 张
- 每截图前等 `networkidle`
- 监听 `page.on('console', msg => msg.type() === 'error' && ...)`:**console.error 来自改动文件**(在 git diff 列表中的文件)→ 记入 `CONSOLE_ERROR_FROM_CHANGED_FILES`

截图保存:`$ARTIFACTS_DIR/screenshots/<name>.png`,记录路径数组 `SCREENSHOTS=( ... )`。

#### Step 3.3:录屏走查(仅当 `needs_video_check: true`)

读 spec frontmatter `needs_video_check`。`false` 或缺失 → 跳过。

录主交互链路:从入口操作到结果可见(创建 → 查询 → 更新 → 删除 完整流;或单页内"打开 modal → 完成操作 → 关闭"流):

- Playwright `recordVideo: { dir: "$ARTIFACTS_DIR/videos", size: { width: 1440, height: 900 } }`
- 录完 `context.close()` flush video 文件
- 输出 webm 或 mp4(按 Playwright 默认),记录路径数组 `VIDEOS=( ... )`

#### Step 3.4:收尾

```bash
kill $DEV_PID 2>/dev/null
wait $DEV_PID 2>/dev/null
```

#### Step 3.5:判定走查结果

- `CONSOLE_ERROR_FROM_CHANGED_FILES` 非空 → 视觉走查 fail(记入 errors,但单独成因,不直接污染 hard gates)
- 否则视觉走查 pass

### Step 4:判定 VERDICT

```bash
VERDICT=verified
FAIL_REASON=""

[ "${LINT_EXIT:-0}" != 0 ]  && { VERDICT=verify-failed; FAIL_REASON="lint exit ${LINT_EXIT}"; }
[ "${TEST_EXIT:-0}" != 0 ]  && { VERDICT=verify-failed; FAIL_REASON="test exit ${TEST_EXIT}"; }
[ "${BUILD_EXIT:-0}" != 0 ] && { VERDICT=verify-failed; FAIL_REASON="build exit ${BUILD_EXIT}"; }
[ -n "${CONSOLE_ERROR_FROM_CHANGED_FILES}" ] && { VERDICT=verify-failed; FAIL_REASON="${FAIL_REASON}; console.error from changed files"; }
```

### Step 5:写 Stage 3 report(在 spec 头部)

在 worktree 内 spec frontmatter `---` 之后,第 1 个 `##` 之前,**插入或覆盖** `## Stage 3 report` 段:

```md
## Stage 3 report (${today})
- VERDICT: ${VERDICT}
- 工程: ${TARGET_PROJECT}
- worktree: ${worktree_path}
- hard gates: lint=${LINT_EXIT} test=${TEST_EXIT} build=${BUILD_EXIT}
- 视觉走查: ${SCREENSHOTS_COUNT} 张截图 / ${VIDEOS_COUNT} 段录屏 / console.error=${CONSOLE_ERROR_COUNT}
- 视口: ${VIEWPORT}
- artifacts 目录: ${ARTIFACTS_DIR}
- 失败原因: ${FAIL_REASON:-none}
- 截图路径:
  - <每张截图绝对路径,逐行列出>
- 录屏路径:
  - <每段录屏绝对路径,逐行列出>
```

更新 frontmatter:
- `verified` → `status: verified` + `verified_at: <now_iso>`
- `verify-failed` → `status: verify-failed` + `verify_failed_at: <now_iso>` + `verify_attempts: <旧值 +1>`(**不动 `attempts` — 它是 stage2 专属计数,stage3 独立用 `verify_attempts`,避免一次 rework 循环双计数提前 blocked**)

### Step 6:Commit spec + push

```bash
git add docs/spec/${TARGET_SLUG}.md
git commit -m "chore(todo): verify ${TARGET_SLUG} → ${VERDICT}"
git push origin "todo/${TARGET_SLUG}"
```

**不**:
- ❌ commit `.review-artifacts/`(留 worktree 本地)
- ❌ 切回 `${default_branch}` / 删 worktree
- ❌ `--force` / `reset --hard`

### Step 7:清洁退出

```bash
echo "stage3-verify complete: ${TARGET_SLUG} → ${VERDICT}"
```

## 内部 retry 限制

stage3 verify 是**单次执行**,**不**做 fix-retry(那是 stage2 的事)。verify 失败 → status=verify-failed → 等 stage2 重新跑或人介入(可用 `todo-flow revise` 加 rework 指令)。

## Output Contract(结构化 JSON,给外层工具解析)

**唯一输出 = 一个合法 JSON block**(包在 ```json ... ``` 里)。

### im_attach 截图分级原则

- **pass(verified)**:`im_attach` 只含 **1 张主截图**(`main.png`)+ 文字 summary;录屏路径**只放 local_artifacts**,IM 不发
- **fail(verify-failed)**:`im_attach` 含 **主截图 + 最多 2 张关键失败截图 + error-tail.txt**;录屏仍只 local_artifacts(避免大文件刷屏)
- **完整截图录屏全清单**写到 spec `## Stage 3 report` 段供用户事后查

### pass 示例

```json
{
  "stage": 3,
  "verdict": "verified",
  "slug": "<slug>",
  "project": "<project_root>",
  "worktree": "<worktree_path>",
  "branch": "todo/<slug>",
  "spec_path": "<project_root>/docs/spec/<slug>.md",
  "hard_gates": {
    "lint":  {"exit": 0},
    "test":  {"exit": 0, "stats": "<可选: 23 passed>"},
    "build": {"exit": 0}
  },
  "visual_check": {
    "screenshots_count": <n>,
    "videos_count": <n>,
    "viewport": "1440x900",
    "console_error_from_changed_files": null
  },
  "pushed": true,
  "summary": "✓ stage3: `<slug>` verify pass (lint/test/build green, <n> screenshots clean)",
  "im_attach": [
    {"type": "image", "path": "<ARTIFACTS_DIR>/screenshots/main.png", "caption": "主页面"}
  ],
  "local_artifacts": [
    {"type": "screenshots_dir", "path": "<ARTIFACTS_DIR>/screenshots/"},
    {"type": "videos_dir",      "path": "<ARTIFACTS_DIR>/videos/"}
  ],
  "errors": [],
  "next_action": "等 todo-flow done mode 人审 + squash merge"
}
```

### fail 示例

```json
{
  "stage": 3,
  "verdict": "verify-failed",
  "slug": "<slug>",
  "project": "<project_root>",
  "worktree": "<worktree_path>",
  "branch": "todo/<slug>",
  "spec_path": "<project_root>/docs/spec/<slug>.md",
  "hard_gates": {
    "lint":  {"exit": 0},
    "test":  {"exit": 1, "stats": "1 failed, 22 passed"},
    "build": {"exit": 0}
  },
  "visual_check": {
    "screenshots_count": <n>,
    "videos_count": <n>,
    "viewport": "1440x900",
    "console_error_from_changed_files": ["TypeError: Cannot read..."]
  },
  "pushed": true,
  "verify_attempts": <旧值 +1>,
  "summary": "✗ stage3: `<slug>` verify failed (test exit 1 + console.error)",
  "im_attach": [
    {"type": "image", "path": "<ARTIFACTS_DIR>/screenshots/main.png",         "caption": "主页面"},
    {"type": "image", "path": "<ARTIFACTS_DIR>/screenshots/failed-modal.png", "caption": "失败截图"},
    {"type": "file",  "path": "<ARTIFACTS_DIR>/error-tail.txt",               "caption": "test 最后 20 行错误"}
  ],
  "local_artifacts": [
    {"type": "screenshots_dir", "path": "<ARTIFACTS_DIR>/screenshots/"},
    {"type": "videos_dir",      "path": "<ARTIFACTS_DIR>/videos/"}
  ],
  "errors": [
    {"step": "test", "exit": 1, "tail": "<最后 20 行 test 输出>"}
  ],
  "next_action": "todo-flow revise <slug> 给 rework 指令 → 等 stage2 重跑"
}
```

### idle 示例

```json
{
  "stage": 3,
  "verdict": "idle",
  "slug": null,
  "project": null,
  "summary": "no ready-for-review spec found across <n> projects",
  "im_attach": [],
  "local_artifacts": [],
  "errors": [],
  "next_action": "等待 stage2 跑出新 ready-for-review,下次 cron 再扫"
}
```

### skipped(选中但 stale)示例

```json
{
  "stage": 3,
  "verdict": "skipped",
  "slug": "<slug>",
  "project": "<project_root>",
  "summary": "stage3: worktree/branch missing for <slug> (stage2 失败遗留或被清理)",
  "im_attach": [],
  "local_artifacts": [],
  "errors": [{"step": "step-1", "tail": "worktree path not found: <worktree_path>"}],
  "next_action": "人介入清理 / 删 spec / 让 stage2 重新创建"
}
```

**输出格式硬约束**:
- 只输出**一个** JSON block,不加额外文字解释
- `summary` ≤ 200 字
- `im_attach` 是外层必发清单,**最多 4 项**(1 主截图 + ≤2 失败截图 + ≤1 错误日志)
- `local_artifacts` 不发,只给用户查阅
- 失败时 `errors[].tail` 截最后 20 行

## 约束

- 一次只处理 1 个 spec
- 不并发(同 spec 状态改后下次扫描不再选)
- 不依赖 stage1/2 触发(独立 cron 跑)
- **不直接调 IM SDK / CLI**(飞书发送由外层调用方处理,prompt 只输出 JSON)
- 不切分支、不删 worktree、不破坏主仓库

## 工具调用建议

- `yq`:读 spec frontmatter
- `git`:仓库操作
- `playwright`:走查 + 截图 + 录屏
- `pnpm` / `npm` / `cargo` / `go`:按项目栈跑 hard gates
