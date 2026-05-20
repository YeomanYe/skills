# Dev Executor Prompt (multi-project, self-driving)

把整篇内容作为 prompt 喂给 agent。**完全无入参**：调用方不需要 cd、不需要传任何参数，本 prompt 自己从仓库状态推断该处理什么。可被 cron / 定时器无参重复调度。

---

你的任务：在一组工程里挑出"**下一个待开发的 approved spec**"，开发实现、跑验证、把 spec 状态推到 `ready-for-review`、push branch。一次调用只处理 **1 个 spec**。

## 占位符约定

- `${slug}` — 来自 spec frontmatter 的 `id`
- `${today}` — `date -u +%Y-%m-%d`
- `${project_root}` — 当前处理工程的绝对路径
- `${default_branch}` — 默认主干分支名，**探测**：

  ```bash
  default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
  default_branch=${default_branch:-main}
  ```

## 工程清单（在 prompt 内硬编码）

> ⚠️ **使用前修改这份清单为你的实际工程绝对路径**。轮转顺序 = 数组顺序。**必须与 stage1 prompt 中的清单保持一致**。

```
PROJECTS=(
  "/Users/ym/Documents/projects/A"
  "/Users/ym/Documents/projects/B"
  "/Users/ym/Documents/projects/C"
)
```

## 执行算法（严格按顺序）

### Step 0：选择本次处理的工程和 spec（无入参，从仓库状态推断）

遍历上面硬编码的 `PROJECTS` 数组，对每个 `${project_root}`：

```bash
cd "${project_root}"
test -d docs/spec || continue
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || continue
# 主仓库工作树脏 → 跳过整个工程（用户可能正在开发，避免卷入）
test -z "$(git status --porcelain)" || { echo "skip: ${project_root} dirty"; continue; }
git fetch origin 2>/dev/null || true
```

按文件名**字典序**遍历 `docs/spec/*.md`（不含 `_done/`），对每个 spec：

1. 读 frontmatter `status`。**只有 `approved` 进入后续判定**，其它（`draft` / `ready-for-review` / 已合并未归档）跳过。
2. 解析出 `id` 作为 `${slug}`。
3. 检查 `todo/${slug}` 分支与 worktree 残留状态，并**按状态分类记账**（决定本次循环的报告口径）：

   ```bash
   has_local_branch=$(git show-ref --verify --quiet "refs/heads/todo/${slug}" && echo 1 || echo 0)
   has_remote_branch=$(git ls-remote --exit-code --heads origin "todo/${slug}" >/dev/null 2>&1 && echo 1 || echo 0)
   has_worktree=$([ -e ".worktrees/${slug}" ] && echo 1 || echo 0)
   ```

   - 全为 0 → **选中**该 spec，记下 `${project_root}` `${slug}`，跳出整个遍历
   - 任一为 1 → 跳过该 spec，但**按以下分类**记录到 `stale_slugs[]`（供报告输出，让用户能识别死锁源头）：

     | spec status | branch / worktree | 含义 | 报告分类 |
     |---|---|---|---|
     | `approved` | 残留 | 上次 stage2 跑死或卡住，仍占着 slot | `needs_cleanup` |
     | `ready-for-review` | 残留 | 正常等 review-merge | `awaiting_review` |
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
  if ! grep -qxF "# todo-driver pipeline" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# todo-driver pipeline" >> .gitignore
  fi
  echo ".worktrees/" >> .gitignore
  git add .gitignore
  git commit -m "chore: ignore .worktrees/ (todo-driver stage2)"
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

完整读一遍 `docs/spec/${slug}.md`，逐节理解：

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

### Step 5：跑验证（hard gates）

**探测项目类型**，按命中的栈跑：

```bash
if [ -f package.json ]; then
  # JS/TS 优先 pnpm，无锁文件 fallback 到 npm
  if [ -f pnpm-lock.yaml ]; then PM=pnpm; INSTALL="pnpm install --frozen-lockfile"
  elif [ -f yarn.lock ]; then PM=yarn; INSTALL="yarn install --frozen-lockfile"
  else PM=npm; INSTALL="npm ci"
  fi
  $INSTALL 2>&1 | tail -5
  $PM run lint 2>&1 | tail -10  || { echo "lint script missing, skip"; }
  $PM test 2>&1 | tail -20
  $PM run build 2>&1 | tail -10 || { echo "build script missing, skip"; }
elif [ -f Cargo.toml ]; then
  cargo fmt --check && cargo clippy -- -D warnings && cargo test && cargo build
elif [ -f pyproject.toml ]; then
  # 由项目 AGENTS.md / CLAUDE.md 指定具体命令；找不到时报错让调用方补
  echo "Python project: 用 AGENTS.md / CLAUDE.md 指定的 lint+test+build 命令"
elif [ -f go.mod ]; then
  go vet ./... && go test ./... && go build ./...
else
  echo "unknown stack, ask AGENTS.md / CLAUDE.md for verify commands"
fi
```

任一失败 → Step 7 失败路径。**禁止**用 `--no-verify` / `-n` 绕过 hook 或测试。

**验收标准复核**：在 worktree 内的 spec 里把已确认满足的 `- [ ]` 改成 `- [x]`。无法验证的条目保留 `- [ ]` 并在 Decisions log 注明原因。

> 注：新 worktree 没有 `node_modules` / `target/` / 虚拟环境，首次 install 可能耗时（几分钟到十几分钟），不要误判为卡死。

### Step 5.5：Playwright 走查（截图 + 可选录屏）

读 spec frontmatter `needs_visual_check`。`false` 或缺失 → **跳过本步**，直接进 Step 6。

**全步骤遵守的视觉证据约束**（借鉴 [[delivery-gate]]）：

- 视觉证据**只用 Playwright** 生成，禁用 chrome_devtools 或其它可见浏览器调试工具
- 默认 **`headless: true`**，spec 没明确要求"可见窗口演示"则不要切有界面模式
- 截图必须是**预设视口的整屏**——**禁止**只截局部组件替代整屏
- **必须记录视口尺寸**写进 Visual review 报告
- dev server **不占用工程默认开发端口**（避免与用户本机开着的 dev 冲突），用随机高位端口

#### Step 5.5.0：产物存储约定（重要）

```bash
# 产物只存 worktree 内，跟 worktree 同生同灭
artifacts_dir=".review-artifacts/${slug}"
mkdir -p "$artifacts_dir"
```

**严格规则**：
- 产物**永不 commit**，永远不 `git add` 这个目录
- 主仓库 `.gitignore` 必须包含 `.worktrees/`（worktree 在主仓库根目录可见，必须忽略）；自愈逻辑已在 Step 2 完成
- review-merge 或人工 review 时，agent / 用户**直接读本机 `${project_root}/.worktrees/${slug}/.review-artifacts/`**
- 失败路径同样不 commit artifacts；报告里吐绝对路径

#### Step 5.5.1：启动 dev server（随机端口，避开默认）

> `.gitignore` 自愈已在 Step 2 完成，这里直接起 dev server。

```bash
PORT=$(shuf -i 30000-50000 -n 1)
export PORT
```

按命中的栈选启动命令：

| 栈 | 启动命令 | 端口传递 |
|---|---|---|
| Plasmo 扩展（有 `plasmo` deps） | `pnpm dev:web` | env `PORT=${PORT}`（vite 会读） |
| Vite | `pnpm dev` | `pnpm dev --port ${PORT}` |
| Next.js | `pnpm dev` | `pnpm dev --port ${PORT}` |
| Astro | `pnpm dev` | `pnpm dev --port ${PORT}` |
| 其它 | 读 `package.json` `scripts.dev` 推断 | 找不到 → 跳过走查并在 Decisions log 写"无法启动 dev server" |

**后台启动**（不阻塞 agent）：

```bash
($DEV_CMD > "$artifacts_dir/dev-server.log" 2>&1) &
DEV_PID=$!
# 等待端口就绪（最多 60s）
for i in $(seq 1 60); do
  curl -sf "http://localhost:${PORT}" > /dev/null && break
  sleep 1
done
```

dev server 60s 内没起来 → kill 进程、把 log tail 写进 spec Decisions log，跳过本步（不算失败，因为本意是辅助 review，不是 hard gate）。

#### Step 5.5.2：设置视口 + 走查截图

视口尺寸默认 `1440x900`（PC 主流验收尺寸）；spec 明确要求移动端则用 `390x844`（iPhone 14）。**记录最终使用的视口尺寸**，要写进 5.5.5 的报告。

按以下顺序操作（用 `mcp__playwright__*` 工具）：

1. `playwright_navigate` → `http://localhost:${PORT}`（首次调用时显式设 `headless: true` + `viewport: { width, height }`）
2. **默认截图清单**（兜底，不依赖 spec 完整性）：
   - `${artifacts_dir}/01-landing.png` — 主页面整屏（`fullPage: true`）
   - 若 spec 提到新弹窗 / modal / drawer / 二次确认态 → 触发到该状态后截 `${artifacts_dir}/02-<state-slug>.png`、`03-...`
3. **验收标准遍历**：spec "验收标准" 里每一条非"测试通过/lint clean"的条目：
   - 描述了可点击元素（按钮 / 链接 / 设置项 / tab）→ 尽力定位并 `playwright_click`
   - 每次有意义的状态变化后 → 截图存 `${artifacts_dir}/<序号>-<criterion-slug>.png`
   - 用 `playwright_console_logs` 抓 console，append 到 `${artifacts_dir}/console.log`

**禁止局部截图**：不允许只截一个组件来代替整屏视口截图。每张图必须是 `fullPage: true` 的整屏。

#### Step 5.5.3：录屏走查（仅当 `needs_video_check: true`）

读 spec frontmatter `needs_video_check`。`false` 或缺失 → **跳过本节**，直接进 5.5.4。

录屏覆盖主交互链路——从入口操作到结果可见的端到端流程，不录孤立的按钮点击。

Playwright 录屏（用 `recordVideo` 启动 context；具体参数视 MCP 工具能力而定）：

- 输出到 `${artifacts_dir}/walkthrough.webm`（webm 是 Playwright 默认格式，体积小）
- 视口尺寸跟 5.5.2 保持一致
- 录制 spec 在"验收标准"里描述的主交互链路（一次连续操作，不要分段）
- 录屏结束后 `playwright_close` 触发文件 flush

录屏文件 > 50MB → 记进 Decisions log 提示用户"录屏体积偏大，建议人工查看后清理"，但不算失败。

#### Step 5.5.4：收尾

```bash
# 关 Playwright + kill dev server
# (mcp__playwright__playwright_close)
kill $DEV_PID 2>/dev/null
wait $DEV_PID 2>/dev/null || true
```

#### Step 5.5.5：判定走查结果

收集：
- `${artifacts_dir}/console.log` 中 `error` / `Error` / `Uncaught` 行数 → `console_errors`
- 截图总数 → `screenshots`
- 录屏文件大小（如有）→ `video_size_mb`

判定规则：

| 情况 | 处理 |
|---|---|
| `console_errors > 0` 且来源是 spec 改动文件 | **Step 7 失败路径**，错误日志写进 Attempt failure |
| `console_errors > 0` 但来源是无关第三方 / 已知噪音 | 在 Decisions log 注明 + 留待 review 时人工判断，**不算失败** |
| `screenshots == 0`（一张都没成功） | Decisions log 标"走查未执行成功"，**不算失败**（不卡 hard gate） |
| 都通过 | 进 5.5.6 写报告。**不要 commit artifacts**——它们只在 worktree 本地 |

#### Step 5.5.6：在 spec 末尾追加走查报告

```md
## Visual review (${today})
- Viewport: 1440x900   # 或实际使用值
- Headless: true
- Dev port: 30137      # 实际随机端口
- Screenshots: <n>（见 ${project_root}/.worktrees/${slug}/.review-artifacts/${slug}/）
- Video: walkthrough.webm（<size> MB）/ N/A
- Console errors: <n>（详见 console.log）
- 验收标准覆盖: <已截图条目 / 总条目>
- 备注: <一句>
```

**注意**：报告里写**绝对路径**，让 review-merge / 人工 review 时能直接打开本机文件。artifacts **不进 git 历史**。

### Step 6：成功路径

全部 hard gates 通过 + 验收标准全部满足（Step 5.5 不通过不阻塞，仅 console.error 来自改动文件时才阻塞）：

1. 更新 spec frontmatter：
   - `status: ready-for-review`
   - `updated: ${today}`
2. 在 `## Decisions log` 追加：`- **${today}**: 实现完成，<一句重要决定>`
3. commit 顺序（**只 commit 代码 + spec，绝不 commit `.review-artifacts/`**）：
   - 先 commit 代码实现（subject 用 `feat:` / `fix:` / 按 spec 性质）
   - 再 commit spec 更新（subject `chore(todo): mark ${slug} ready-for-review`）
   - `.review-artifacts/${slug}/` 留在 worktree 本地，不进 git 历史；review-merge 时 agent 从本地读
4. push branch：

   ```bash
   git push -u origin "todo/${slug}"
   ```

5. 报告成功（见输出格式）

### Step 7：失败路径

任何 hard gate 失败、验收标准对不上、或 Step 4/5 内部 fix-retry **同一类错误 ≥ 3 次仍无进展**：

1. 在 worktree 里的 spec 末尾追加：

   ```md
   ## Attempt failure (${today} HH:MM Z)
   - 错误: <精确错误源 + file:line>
   - 原因: <诊断>
   - 已尝试: <做过哪些修复>
   - 卡在哪: <停下的具体步骤>
   ```

2. 更新 frontmatter `updated: ${today}`，**不改 `status`**（保持 approved；调用方判断后续）
3. commit 到 worktree branch：**只** spec（artifacts 留在本地 worktree 不进 commit）；report 里吐 artifacts 绝对路径帮诊断
4. **仍然 push branch**（让调用方能看到半成品 diff 诊断 + 本地 worktree 还在能看截图）
5. 报告失败

### Step 8：清洁

不论成功失败：
- **不**切回 `${default_branch}` / 其它分支
- **不**删 worktree 或 branch（调用方决定何时清理）
- **不**强 push / reset hard / 改远程 `${default_branch}`
- **不**在主仓库目录留下修改

## 内部 fix-retry 限制

允许的循环：

```
write code → run hard gates → fail → diagnose → fix → run again
```

**同一类错误**（同一个测试名 / 同一处 lint rule / 同一个 build error）最多重试 **3 次**。3 次仍不过 → Step 7。

## 输出格式

成功：

```
✅ Ready for review: ${slug}
- Project: ${project_root}
- Branch: todo/${slug} (pushed)
- Worktree: ${project_root}/.worktrees/${slug}
- Files changed: <n>
- Tests: <n> passed
- Visual review: <skipped | n screenshots / m console-errors / video <size>>（仅 needs_visual_check=true）
- Artifacts (local, NOT in git): ${project_root}/.worktrees/${slug}/.review-artifacts/${slug}/
- Spec: docs/spec/${slug}.md (status now ready-for-review)
- Awaiting review: <list of slugs that are ready-for-review with branch/worktree>
- Needs cleanup: <list of slugs with approved+残留 worktree/branch — 用户要手动清理>
- Skipped projects: <dirty / 不是 git 仓库 等>
- Next: 等 todo-driver review-merge / 下次 cron 接下一条
```

失败：

```
❌ Failed: ${slug}
- Project: ${project_root}
- Branch: todo/${slug} (pushed for diagnosis)
- Worktree: ${project_root}/.worktrees/${slug}
- 卡在: <stage>
- 失败原因: <one-line>
- Failure log: 追加在 docs/spec/${slug}.md 末尾
- Next: 失败的 branch 会阻塞下次循环对该 slug 的重试（设计如此，避免无限循环）。人工介入：删 local + remote `todo/${slug}` branch + 删 `.worktrees/${slug}` + 改 spec 后下次 cron 自然重做
```

空跑（Step 0 全跳完）：

```
🟰 Nothing to develop
- Awaiting review: <list — 等 review-merge>
- Needs cleanup: <list — ⚠️ approved spec 但残留 worktree/branch，要手动清理才能继续>
- Skipped projects: <list — dirty / 不是仓库等>
- 下次 cron 触发再扫
```

特别注意：如果同一个 slug **连续多次** cron 都出现在 `needs cleanup` 里，意味着流水线被它卡住。按"自愈策略说明"里的命令手动清理。

## 约束（合并自原 "边界"）

- 单次调用最多处理 **1 个 spec**
- 不 merge 到 `${default_branch}`
- 不改其他 spec 文件、不改 `TODO.md`
- 不在主仓库目录留下修改（所有改动只在 worktree 内）
- 调用方负责后续清理 `.worktrees/${slug}`
- 如果 spec 验收标准内部矛盾（实现时发现做不到），把矛盾点写进 failure log 让调用方改 spec

## 工具调用建议

- Read / Glob / Grep：理解 spec + 现状
- Edit / Write：实现
- Bash：测试、lint、build、git、启动 dev server
- TodoWrite：跟踪验收标准
- `mcp__playwright__*`：仅 Step 5.5 走查时用（navigate / screenshot / click / console_logs / close）
- WebFetch / WebSearch：**仅**查官方文档解 lib 报错时允许；不要用来抄实现
