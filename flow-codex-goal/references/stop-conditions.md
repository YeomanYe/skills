# 停止条件清单（Stop Conditions）

> 任一命中**立即**停 Goal Codex，写入 `STATUS.md`，通过 cc-connect 通知人类（如果可用），不要自动恢复。

## 1. 验证类停止

| 条件 | 阈值 | 检测方 | 记录字段 |
|---|---|---|---|
| 连续验证失败 | 3 次 | Goal Codex 自检 | `STOPPED: 3-fail-rule` |
| Review 连续 fail | 2 轮 | orchestrator agent 编排逻辑 | `STOPPED: review-2-fail` |
| 测试新增失败（regression）| 1 个 | Goal Codex 自检 | `STOPPED: regression-introduced` |

## 2. 资源类停止

| 条件 | 阈值 | 检测方 | 记录字段 |
|---|---|---|---|
| 修改文件数超 Budget | GOAL.md Budget.files | watcher / Goal | `STOPPED: file-budget-exceeded` |
| Token 用量超 Budget | GOAL.md Budget.tokens | watcher (估算) | `STOPPED: token-budget-exceeded` |
| 时间超 Budget | GOAL.md Budget.wall_clock | watcher | `STOPPED: time-budget-exceeded` |
| 健康检查 stalled | 连续 3 次（约 15 分钟）| watcher | `STOPPED: stalled` |

## 3. 范围 / 安全类停止

| 条件 | 阈值 | 检测方 | 记录字段 |
|---|---|---|---|
| 修改 Non-goals 文件 | 1 个 | watcher diff 检查 | `STOPPED: scope-violation` |
| 修改 auth/支付/加密 | 1 个 | watcher pattern 匹配 | `STOPPED: high-risk-touched` |
| 引入未授权依赖 | 1 个 | watcher package.json diff | `STOPPED: unauthorized-dep` |
| 破坏性 git 操作尝试 | 1 次 | git pre-* hooks | `STOPPED: destructive-git` |

## 4. 决策类停止

| 条件 | 触发 | 记录字段 |
|---|---|---|
| 需求互相冲突 | Goal Codex 发现 PLAN.md 第 N 步与 GOAL.md 第 M 条冲突 | `STOPPED: requirement-conflict` |
| 需要产品决策 | Goal Codex 遇到 UX 多解、命名歧义等 | `STOPPED: needs-product-decision` |
| 需要扩大范围 | Goal Codex 发现 Acceptance Criteria 实际依赖 Non-goals 文件 | `STOPPED: scope-expansion-needed` |

## 5. 系统类停止

| 条件 | 检测方 | 记录字段 |
|---|---|---|
| Codex 进程崩溃 | watcher (`ps -p $PID`) | `STOPPED: process-crashed` |
| Codex 认证失效（401）| watcher 监 stderr | `STOPPED: auth-expired` |
| Codex quota 耗尽（429/402）| watcher 监 stderr | `STOPPED: quota-exhausted` |
| 长时间网络异常 | watcher | `STOPPED: network-down` |

## 停止后必须输出

Goal Codex 自停时，STATUS.md 末尾必须有：

```md
## Stopped

- Reason: <STOPPED: ... 之一>
- Timestamp: <ISO>
- Current Phase: Phase N
- Current Step: M N.k
- Last successful verification: <ts or never>
- Last command output: <tail 20 行>
- Hypothesis (root cause if known):
- Suggested human action:
  - <option 1>
  - <option 2>
- Resume safe?: yes | no | needs-cleanup
```

watcher 检测到停止时（自停 / 崩溃 / quota）：

1. 把 `STOPPED: <reason>` 写入 STATUS.md（如果 Goal Codex 没写）
2. 收集诊断包到 `.agent/tasks/<TASK_ID>/diagnostics/`：
   - 最后 100 行 logs/goal.log
   - `git diff main` 当时状态
   - `ps -ef | grep codex` 输出
   - 系统 console 最后 30 秒
3. 如果在 IM 会话（`CC_SESSION_KEY` 非空）→ 发 cc-connect notify
4. 不要尝试自动恢复——等人类决策

## 人类响应选项（标准 4 选）

收到停止通知后，人类应该选 4 个动作之一：

| 选项 | 含义 | 后续 |
|---|---|---|
| **continue** | 我看了，问题已解决，让 Goal 继续 | 重启 Goal Codex from STATUS.md current step |
| **abort** | 终止任务，丢弃 worktree | watcher 关、worktree 删（可选）、清空 task dir |
| **handoff** | 转给我手动接管 | watcher 关、Goal 关、worktree 保留待人类操作 |
| **rescope** | 改 GOAL.md 后重启 | 人类编辑 GOAL.md / PLAN.md，orchestrator agent 重新进 Step 1 |

cc-connect 通知应该带上这 4 个选项让人类回复。

## 资源记录的可信度

- **Token 用量**：Codex CLI 没暴露官方计数 API，watcher 只能从 logs 估算（粗略）。建议 Budget 留 30% 余量。
- **修改文件数**：`git diff --stat | wc -l` 准确
- **时间**：`date +%s` 比对 STATUS.md 中的 task start ts
