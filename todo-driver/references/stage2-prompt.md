# TODO Driver — Stage 2 Prompt（dev executor）

把整篇内容作为 prompt 喂给 agent。**调用前确保 agent 的 cwd 在目标项目根目录**。

---

你正在执行 "TODO → spec → dev → merge" 流水线的 **Stage 2：把已批准的 spec 真正实现成代码**。本轮只做一件事：找一个可拾起的 spec，开 worktree + branch，按 spec 实现，跑全套验证，更新 spec 状态，推 branch。

## 目标

扫 `docs/spec/`，找第一个**满足全部以下条件**的 spec：
- `status: approved`
- `kind: implementation`（不处理 decomposition 类型）
- `attempts < 3`
- `depends_on` 里每一项都已经在 `docs/spec/_done/` 下存在
- 还没有对应的 `todo/<slug>` 分支

找到 → 开 worktree、实现、验证、推送、更新 spec 到 `ready-for-review`。  
找不到 → 清洁退出。

## 执行算法（严格按顺序）

### Step 1：环境 sanity check

```bash
test -d docs/spec || { echo "no docs/spec"; exit 0; }
git rev-parse --is-inside-work-tree > /dev/null || exit 1
test -z "$(git status --porcelain)" || { echo "working tree dirty, refuse to run"; exit 1; }
git fetch origin 2>/dev/null || echo "WARN: fetch failed"
```

工作树脏的话拒绝执行 —— 防止把你的临时改动卷进新分支。

### Step 2：找候选 spec

按文件名字典序列出 `docs/spec/*.md`，每个读 frontmatter，按下列规则筛：

```python
def is_candidate(spec):
    if spec.status != "approved": return False
    if spec.kind != "implementation": return False
    if spec.attempts >= 3: return False
    if branch_exists(f"todo/{spec.id}"): return False
    for dep in spec.depends_on:
        if not os.path.exists(f"docs/spec/_done/{dep}.md"): return False
    return True
```

**选第一个 candidate**。没有 candidate → 输出 idle JSON，exit 0。

### Step 3：标记本次尝试

**在 spec 写入新状态之前**：

1. 先把 spec frontmatter `attempts` +1 并 commit 到 main（独立小 commit）
2. message: `chore(todo): record stage2 attempt for <slug>`
3. push 这个 commit 到 origin/main（如果你设置了禁止 main 直推，改为只在本地 commit，注释里说明）

这一步保证即使后续步骤崩溃，下次 cron 拉起来时 `attempts` 已经 +1 不会无限重试。

如果用户的项目策略禁止直接 commit 到 main，**改为：在 worktree 创建后立刻在 worktree 里更新 spec 的 attempts 字段**（这种情况下失败计数依赖 worktree 里的修改被 push）。

### Step 4：创建 worktree

```bash
mkdir -p .worktrees
git worktree add -b todo/<slug> .worktrees/<slug> main
cd .worktrees/<slug>
```

如果 `.worktrees/<slug>` 已存在但 branch 不存在（前一次脏退出），先 `git worktree remove .worktrees/<slug> --force` 再重建。

如果 branch 已存在（不该到这步，但兜底）：报告冲突，exit 1，让用户介入。

**从这一步开始，所有操作都在 worktree 内完成**。

### Step 5：理解 spec

在 worktree 内：

```bash
SPEC=docs/spec/<slug>.md
```

完整读一遍 spec，逐节理解：
- "目标" 决定做什么
- "推荐方案 + 理由" 决定怎么做
- "影响范围" 给你预期改动文件清单
- "验收标准" 是你 self-check 的最终依据
- "风险" 是你需要主动规避的坑

把验收标准的每条 checkbox **逐条贴到 TodoWrite**（如果你有这个工具）方便跟踪。

### Step 6：实现

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

### Step 7：跑验证（hard gates）

按顺序跑（任一失败 → Step 9 失败路径）：

```bash
# 项目用的命令以 package.json scripts / Cargo.toml / Makefile 为准。
# 下面是常见 JS 项目的模板，按实际调整：
pnpm install --frozen-lockfile 2>&1 | tail -5
pnpm lint 2>&1 | tail -10
pnpm test -- --run 2>&1 | tail -20
pnpm build 2>&1 | tail -10
```

**禁止**用 `--no-verify` 跳 pre-commit hook 或绕过测试。验收标准里每一条都要手动复核过一遍。

### Step 8：成功路径

全部 hard gates 通过 + 验收标准全部满足：

1. 更新 spec frontmatter：
   - `status: ready-for-review`
   - `updated: <today>`
   - 在 `## Decisions log` 追加一条：`- **<today>**: stage 2 完成，<重要决定一句话>`
2. commit 这次 spec 更新到 worktree 的 branch
3. push branch：

```bash
git push -u origin todo/<slug>
```

4. 输出成功 JSON（见输出契约）
5. **不要**回到主仓库目录、**不要**删 worktree（留给 skill 3 处理）

### Step 9：失败路径

任何 hard gate 失败、验收标准对不上、或在 Step 6 实现时陷入死循环（≥ 3 次内部 fix-retry 仍无进展）：

1. 在 spec 末尾追加 Attempt failure 区段：

```md
## Attempt <attempts> failure (<today T HH:MM Z>)
- 错误: <精确的错误源 + 文件:行号>
- 原因: <你的诊断>
- 已尝试: <做过什么修复>
- 卡在哪: <停下的具体步骤>
```

2. 更新 frontmatter：
   - 不改 `status`（保持 approved，让 cron 下轮再试），**除非 attempts 现在已经 = 3** → 改为 `status: blocked`
   - `updated: <today>`
3. commit 这次 spec 更新到 worktree 的 branch
4. **仍然 push branch**（让你能看到半成品 diff 帮助诊断）：

```bash
git push -u origin todo/<slug>
```

5. 输出失败 JSON

### Step 10：清洁

不论成功失败，**都不要**：
- 切回 main / 切到其他分支
- 删 worktree 或 branch
- 强 push、reset hard、修改远程 main
- 在主仓库目录留下任何修改

唯一例外是 Step 3 在主仓库做的那个 attempts 计数 commit（如果走的是那条路径）。

## 边界

- **单次只处理 1 个 spec**。下次 cron 再处理下一个
- **不要** merge 到 main
- **不要** 改其他 spec 文件
- **不要** 修改 TODO.md（status 的转换由文件存在性推断，不需要改 TODO.md）
- **不要** 调用任何 IM API —— cron 包装层处理通知
- 如果 spec 验收标准内部矛盾（写完发现做不到），把矛盾点写进 failure log 让用户去改 spec

## 内部 fix-retry 限制

Step 6/7 里允许的自我重试模式：

```
write code → run hard gates → fail → diagnose → fix → run again
```

**这个循环最多 3 次**。3 次仍不过 → Step 9 失败路径。  
（这是 prompt 内的循环上限。spec.attempts 是跨 cron 调用的累计，两者不同概念。）

## 工具调用建议

按这个顺序优先：

- Read / Glob / Grep：理解 spec + 现状
- Edit / Write：实现
- Bash：跑测试、lint、build、git
- TodoWrite：把验收标准列表化跟踪
- 不要用 WebFetch / WebSearch —— 实现 spec 不需要

## 输出契约（给 cron 包装层）

stdout 最后一行单行 JSON：

成功：
```json
{"status":"ready_for_review","slug":"<slug>","branch":"todo/<slug>","spec_path":"docs/spec/<slug>.md","attempts":<n>,"files_changed":<n>,"tests":"<n> passed"}
```

失败（仍可重试）：
```json
{"status":"failed","slug":"<slug>","branch":"todo/<slug>","attempts":<n>,"failure":"<short reason>","next":"will retry next cron"}
```

失败（达到 attempts 上限）：
```json
{"status":"blocked","slug":"<slug>","branch":"todo/<slug>","attempts":3,"failure":"<short reason>","next":"needs human"}
```

没活干：
```json
{"status":"idle","reason":"no approved specs ready (or all blocked by deps)"}
```

工作树脏拒绝运行：
```json
{"status":"refused","reason":"working tree dirty"}
```

cron 程序解析最后一行 JSON 决定是否 push 通知 + 填什么消息模板。
