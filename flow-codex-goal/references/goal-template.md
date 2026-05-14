# GOAL.md 模板

> 这是 Codex Goal 长跑的"目标契约"。**写得越具体，跑飞的概率越低**。

```md
# Goal: <task-id>

## Objective
<一句话说清楚要达成什么。例如："Migrate all class components in src/legacy/ to functional components with hooks">

## Scope
**允许修改的范围**（白名单）：
- src/legacy/**
- src/components/shared/** (only if cross-cutting)

**明确不动**（黑名单）：
- src/api/auth/**
- src/api/payment/**
- migrations/**
- node_modules/**, dist/**, .next/**

## Non-goals
明确不在本次范围内：
- <例：不重写 routing 层，那是另一个任务>
- <例：不升级 React 版本>
- <例：不动测试框架>

## Acceptance Criteria
**量化、可验证**的完成条件，每条必须能通过 EVAL.md 中某条命令验证：

- [ ] grep -r "extends Component\|extends React.Component" src/legacy/ 返回空
- [ ] pnpm test 全部通过（无新增 fail）
- [ ] pnpm build 成功且 bundle size 不增加 > 5%
- [ ] git diff --stat 显示 ≥ 80% 文件位于 src/legacy/

## User Journeys
**Reviewer Codex 的 Step 4 运行时验证会逐条跑这些**。每条要描述清楚"做什么 → 期望看到什么"：

- [ ] J1: 打开 / → 应显示首页 hero + 3 个产品卡片（无 console error）
- [ ] J2: 点击产品卡片 → 跳到 /product/:id → 显示产品详情 + "加入购物车"按钮
- [ ] J3: 加入购物车 → 右上角 badge +1 → 点击 badge → 跳到 /cart 显示该商品
- [ ] J4: 触发 404（访问 /nonexistent）→ 显示自定义 404 页 + 返回按钮
- [ ] J5: 模拟离线（DevTools Network → Offline）→ 显示离线 fallback 而非白屏

## Goal-Attainment Mode
**何时算"达成"**。Step 0.5 已确认，写下来供 watcher 和 reviewer 解析。

```yaml
mode: regression-prevention   # threshold | no-improvement-N | regression-prevention | hybrid
threshold: 4.0                 # 仅 mode=threshold/hybrid 时生效，综合分数下限
no_improvement_n: 3            # 仅 mode=no-improvement-N/hybrid 时生效，连续 N 轮不升即停
baseline_dimensions:           # 仅 mode=regression-prevention/hybrid 时生效，任一维度低于 baseline 即停
  - correctness
  - maintainability
  - ux
  - risk
```

## Stop Conditions
**任一命中必须停止并写入 STATUS.md，等待人类决策**：

- 连续 3 次 `pnpm test` 失败且不能 root cause
- 修改文件 > 50 个
- token 用量 > 500K
- 需要修改 src/api/auth/ 或 src/api/payment/
- 需要破坏性 git 操作（rebase / reset --hard / push --force）
- 发现需求互相冲突（PLAN.md 第 N 步与 Acceptance Criteria 第 M 条矛盾）
- 进入了 Non-goals 范围

## Budget
**硬上限**（超出立即停）：

- Files modified: ≤ 50
- Token consumption: ≤ 500,000
- Wall clock time: ≤ 4 hours
- Failed verification rounds: ≤ 3

## Workflow Rules
Goal Codex 执行时**必须遵守**：

1. 每个 milestone 完成后：
   - 更新 STATUS.md（含 timestamp / phase / step / next action）
   - **写入一行 `MILESTONE: <name>`**（watcher 监这一行触发 mini-review + IM 推送）
   - 运行 EVAL.md 中定义的验证命令
   - 把验证输出 append 到 logs/verify.log
2. 验证失败时：
   - 先分析 root cause（写入 ISSUES.md / Risks 段）
   - 再修复
   - 不要直接重试
3. 计划外发现：
   - 写入 ISSUES.md
   - 不要扩大范围
4. 文件操作禁忌：
   - 不要 `git add .`（必须显式列文件）
   - 不要 `git commit`（commit 由 orchestrator agent 通过 clean-commit 完成）
   - 不要 `git push`
   - 不要提交 dist/、node_modules/、build artifacts
5. 人类反馈：
   - 每个 milestone 开始前先 grep STATUS.md 是否有新的 `## Human Feedback` 段
   - 有则按反馈调整 PLAN，再继续
6. 完成判定：
   - 所有 Acceptance Criteria 都打勾
   - 所有 User Journeys 自测可通过（截图存到 .agent/tasks/<task-id>/screenshots/self/）
   - STATUS.md 末尾写入 `GOAL_DONE` 标记（必须是这个字符串，不能改）
   - 等待外部 review，不要自宣告完成

## References
Goal Codex 必须先读：
- 项目根 AGENTS.md（项目规范）
- .agent/tasks/<task-id>/PLAN.md（执行步骤）
- .agent/tasks/<task-id>/EVAL.md（验证命令）
- .agent/tasks/<task-id>/BASELINE.md（当前系统基线分数，避免越改越差）
```
