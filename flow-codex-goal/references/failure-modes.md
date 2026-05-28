# Failure Modes — Red Flags + Rationalizations

SKILL.md "Red Flags" 与 "Rationalizations to Reject" 两段统一收录在此。
主体 SKILL.md 不再展开，订正/新增条目在本文件维护。

---

## Red Flags — STOP

任一命中必须停下：

### Phase 0 / 契约
- 在主分支裸跑 `/goal` 没开 worktree
- **APPROVAL.md 不存在**就启动 Goal Codex（Phase 0 没签字）
- 跳过 Step 0.1（未确认 AC / mode / budget / 自定义维度 / **Reviewer Plan**）就启动 Goal
- **Reviewer Plan 未经用户确认就启动 Goal**（reviewer 阵容 + 各自检查维度是 Phase 0 合同的一部分）
- **EVAL.md 有维度无任何 reviewer 的 `checks` 认领**（漏审维度，必须补 reviewer 或重分配）
- **IM 会话下 Reviewer Plan 没发回来源通道**（飞书等发起的 goal，确认表必须发回该通道）
- 跳过 Step 0.3 baseline scoring 就启动 Goal
- **BASELINE.md 由 orchestrator 自己当 reviewer**（reviewer_pid == orchestrator_pid）

### Reviewer 隔离
- **Reviewer Codex 复用 Goal Codex 的 session/thread**（reviewer_pid == goal_pid）
- **Reviewer 工作在 Goal worktree**（不是独立 readonly worktree）
- **Reviewer 能读到 STATUS.md / 历史 REVIEW.md**（隔离失效）
- **Reviewer 启动时未 `env -i`**（凭据泄漏到 reviewer）
- Reviewer prompt 含实施者解释 / 历史评分 / 上一轮失败原因

### Execution / Watcher
- watcher 没启动就让 Goal 跑（CLI-YOLO / TMUX-YOLO / CLI-EXEC 模式）
- Goal Codex 报"完成"但 STATUS.md 没写 `GOAL_DONE`
- Goal Codex 修改了 SPEC 范围外文件 / boundary-watch 命中
- 修改文件超 GOAL.md Budget 但继续推进
- token 用量接近 budget 但不停
- 跳过运行时证据收集就裁决 verdict

### Score / Snapshot
- 检测到分数低于 baseline 但继续推进（regression-prevention 模式下）
- **3 轮不涨分但 commit 最后一轮**（必须回到 HIGHEST_TAG）
- **mini-review 把 1-5 改成 1-10**（脚本拒绝接受这种 score）
- **同分时选了有硬规则风险的版本**（必须按 STOP-CONDITIONS.md 硬规则段裁决）

### Delivery
- review verdict pass 但 risk_class=high 时 orchestrator 没自跑验证
- 把 Codex 修改全部 `git add .` 而不是选择性 staging
- IM 会话下跳过 milestone 推送 / UI 任务不发截图
- **截图文件名 ≠ 内容**但 orchestrator 没 view_image 校验就发出去（UI 任务下）

---

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "Goal 跑得挺顺，跳过 review 直接 commit 吧" | review 是本 skill 的 50% 价值，跳了就退化成裸 /goal |
| "Reviewer 也是 Codex，让它复用 thread 省 token" | 复用 = 污染独立性 = review 失效 |
| "Reviewer 跟 Goal 在同一 worktree 也能跑" | 文件系统不隔离 = reviewer 能瞥见 STATUS / logs，自我评估又回来了 |
| "watcher 太啰嗦，先不跑了" | 没 watcher = goal silent pause + 烧 quota + 错过人类反馈 |
| "Goal 说完成了，STATUS.md 应该也写了吧" | 必须 grep `GOAL_DONE` 确认 |
| "改的就是 main 分支文件，不开 worktree 也行" | --yolo + main + 长跑 = 灾难 |
| "Verdict pass 应该没问题，不用再跑测试" | 高风险任务必须自跑，低风险才能信 reviewer |
| "Stalled 3 次了，再等等可能就好了" | 硬阈值，必须 notify 人类 |
| "AC 已经在 prompt 里了，不用再确认了" | 用户口语化 AC 多半模糊，必须 Phase 0 量化 + APPROVAL 签字 |
| "Baseline scoring 太花时间，我自己当代理打个分吧" | 你当 reviewer = 后续 mini-review 评分基准漂移 = 退化检测失效 |
| "Reviewer 看 diff 就够了，不用真跑" | 编译过 ≠ 跑得起来 ≠ 用户旅程能走通 |
| "milestone 推送太烦人，等 Goal 完成再发结果就行" | 人类校准窗口在中间，结尾发就晚了 |
| "分数稍微低于 baseline 没关系，整体在涨" | regression-prevention 模式下任一维度低就停 |
| "最后一轮没创新高，但是 reviewer pass 了，commit 最后一轮吧" | 必须回到 HIGHEST_TAG，最终交付的是历史最高分 |
| "reviewer 要拆 sanitize.ts，那就拆吧" | 黑名单优先 reviewer Must Fix，必须仲裁拒绝 |
| "UI 截图 Goal Codex 截过了，reviewer 不用再截" | reviewer 必须自己截，可能 Goal 截的是好看但不工作的状态 |
| "subagent 跑过测试就够了，我不用复验" | risk_class=high 必须复验；risk_class=low 才允许跳 |
