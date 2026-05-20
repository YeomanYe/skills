# Dev Executor Prompt

把整篇内容作为 prompt 喂给 agent。调用前确保 agent 的 cwd 在目标项目根目录。

---

你的任务：按指定的 spec 文档实现代码，跑全套验证，把 spec 状态推到 ready-for-review，推 branch。

## 输入

调用方必须提供：

- `slug`：目标 spec 标识，对应 `docs/spec/<slug>.md`

要求该 spec 必须满足：
- 文件存在
- frontmatter `status: approved`

不满足 → 拒绝执行并报告原因。

## 执行算法（严格按顺序）

### Step 1：环境 sanity check

```bash
test -d docs/spec || { echo "no docs/spec"; exit 1; }
test -f docs/spec/<slug>.md || { echo "spec not found"; exit 1; }
git rev-parse --is-inside-work-tree > /dev/null || { echo "not a git repo"; exit 1; }
test -z "$(git status --porcelain)" || { echo "working tree dirty, refuse to run"; exit 1; }
git fetch origin 2>/dev/null || echo "WARN: fetch failed"
```

工作树脏 → **拒绝执行**，防止把临时改动卷进新分支。

校验 spec frontmatter：
- `status` 必须是 `approved`，否则拒绝
- 检查 `todo/<slug>` 分支是否已存在；存在 → 报告冲突 + 拒绝（不覆盖之前的工作）

### Step 2：创建 worktree

```bash
mkdir -p .worktrees
git worktree add -b todo/<slug> .worktrees/<slug> main
cd .worktrees/<slug>
```

如果 `.worktrees/<slug>` 目录已存在但 branch 不存在（前一次脏退出），先 `git worktree remove .worktrees/<slug> --force` 再重建。

**从这一步开始，所有操作都在 worktree 内完成**。

### Step 3：理解 spec

完整读一遍 `docs/spec/<slug>.md`，逐节理解：

- "目标" 决定做什么
- "推荐方案 + 理由" 决定怎么做
- "影响范围" 给你预期改动文件清单
- "验收标准" 是 self-check 的最终依据
- "风险" 是要主动规避的坑

把验收标准的每条 checkbox **逐条贴到 TodoWrite**（如果你有这个工具）方便跟踪。

### Step 4：实现

按工程规范来。规范找的顺序：

1. `AGENTS.md` ← 工程规范首选
2. `CLAUDE.md` ← 次选
3. 都没有 → 用通用规范（小步快跑、命名清晰、加测试、注释只写 why）

实现遵循：

- **TDD**：新功能 → 先写 failing test → 再写实现 → tests 通过
- **修 bug**：先写 failing repro test → 再修
- **样式纯前端改动**：可豁免 TDD（spec 必须明确写了"纯样式"才能豁免）
- 改动**只动 spec "影响范围" 里列出的文件**。要动范围外文件必须有充分理由 + 在 spec 末尾追加一条 Decisions log 说明
- 不引入 spec "影响范围" 没列出来的新依赖
- 不修改公开 API / 类型签名（spec 未授权时）

### Step 5：跑验证（hard gates）

按顺序跑（任一失败 → Step 7 失败路径）：

```bash
# 项目用的命令以 package.json scripts / Cargo.toml / Makefile 为准。
# 下面是常见 JS 项目的模板，按实际调整：
pnpm install --frozen-lockfile 2>&1 | tail -5
pnpm lint 2>&1 | tail -10
pnpm test -- --run 2>&1 | tail -20
pnpm build 2>&1 | tail -10
```

**禁止**用 `--no-verify` 跳 pre-commit hook 或绕过测试。验收标准里每一条都要手动复核过一遍。

### Step 6：成功路径

全部 hard gates 通过 + 验收标准全部满足：

1. 更新 spec frontmatter：
   - `status: ready-for-review`
   - `updated: <today>`
   - 在 `## Decisions log` 追加一条：`- **<today>**: 实现完成，<重要决定一句话>`
2. commit 这次 spec 更新到 worktree 的 branch
3. push branch：

```bash
git push -u origin todo/<slug>
```

4. 报告成功（见输出格式）
5. **不要**回到主仓库目录、**不要**删 worktree（调用方决定后续清理）

### Step 7：失败路径

任何 hard gate 失败、验收标准对不上、或在 Step 4 实现时陷入死循环（≥ 3 次内部 fix-retry 仍无进展）：

1. 在 spec 末尾追加 Attempt failure 区段：

```md
## Attempt failure (<today T HH:MM Z>)
- 错误: <精确的错误源 + 文件:行号>
- 原因: <你的诊断>
- 已尝试: <做过什么修复>
- 卡在哪: <停下的具体步骤>
```

2. 更新 frontmatter `updated: <today>`，**不改 `status`**（保持 approved，让调用方决定怎么走：人改 spec / 重新调本 prompt / 放弃）

3. commit spec 更新到 worktree 的 branch

4. **仍然 push branch**（让调用方能看到半成品 diff 帮助诊断）：

```bash
git push -u origin todo/<slug>
```

5. 报告失败（见输出格式）

### Step 8：清洁

不论成功失败，**都不要**：
- 切回 main / 切到其他分支
- 删 worktree 或 branch
- 强 push、reset hard、修改远程 main
- 在主仓库目录留下任何修改

## 输出格式

成功时报告：

```
✅ Ready for review: <slug>
- Branch: todo/<slug> (pushed)
- Worktree: .worktrees/<slug>
- Files changed: <n>
- Tests: <n> passed
- Spec: docs/spec/<slug>.md (status now ready-for-review)
- Next: 调用方 review + merge
```

失败时报告：

```
❌ Failed: <slug>
- Branch: todo/<slug> (pushed for diagnosis)
- Worktree: .worktrees/<slug>
- 卡在: <stage>
- 失败原因: <one-line>
- Failure log: 追加在 docs/spec/<slug>.md 末尾
- Next: 调用方决定改 spec 还是重调本 prompt
```

拒绝执行时报告：

```
⏸ Refused: <slug>
- 原因: <working tree dirty | spec not found | status not approved | branch exists>
- 不动任何文件、不创建任何 branch
```

## 边界

- **单次只处理 1 个 spec**
- **不要** merge 到 main
- **不要** 改其他 spec 文件
- **不要** 修改 TODO.md
- 如果 spec 验收标准内部矛盾（写完发现做不到），把矛盾点写进 failure log 让调用方去改 spec

## 内部 fix-retry 限制

Step 4/5 里允许的自我重试模式：

```
write code → run hard gates → fail → diagnose → fix → run again
```

**这个循环最多 3 次**。3 次仍不过 → Step 7 失败路径。

## 工具调用建议

按这个顺序优先：

- Read / Glob / Grep：理解 spec + 现状
- Edit / Write：实现
- Bash：跑测试、lint、build、git
- TodoWrite：把验收标准列表化跟踪
- 不要用 WebFetch / WebSearch —— 实现 spec 不需要
