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
   - 不要 `git commit`（commit 由 Claude 通过 clean-commit 完成）
   - 不要 `git push`
   - 不要提交 dist/、node_modules/、build artifacts
5. 完成判定：
   - 所有 Acceptance Criteria 都打勾
   - STATUS.md 末尾写入 `GOAL_DONE` 标记（必须是这个字符串，不能改）
   - 等待外部 review，不要自宣告完成

## References
Goal Codex 必须先读：
- 项目根 AGENTS.md（项目规范）
- .agent/tasks/<task-id>/PLAN.md（执行步骤）
- .agent/tasks/<task-id>/EVAL.md（验证命令）
```
