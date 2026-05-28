# Orchestrator Wake-up Combo（A + B 兜底方案）

SKILL.md Step 1.2 / Orchestrator Idle Model 引用本文件。

**根问题**：watcher 退出时通过 `cc-connect send` 发的是 **bot → user** 消息，
不会反弹回来唤醒 orchestrator session。结果 watcher 写到磁盘的
`.review-pending` / `.retry-needed` / `.stop-signal` 没人读，
exit code 3（auto-retry signal）失效。

**组合解法**：A 主路 + B 兜底，两路独立失效不影响另一路。

---

## A 方案 — Bash run_in_background（主路，0 token 成本）

orchestrator 用支持后台任务通知的工具启动 watcher（Claude Code 的
`Bash(run_in_background=true)`）。watcher 退出时，宿主 agent 收到 tool notification，
自动按 exit code 走"Watcher Exit Code → Orchestrator 行为映射"。

```bash
# orchestrator 端（伪代码，实际由 Claude Code Bash 工具调用）：
Bash(command="bash references/watcher.sh $TASK_ID", run_in_background=true)
# → 返回 shell_id，watcher 在后台跑
# → watcher 退出时 BashOutput tool 立刻 surface exit code，wake orchestrator
```

**优点**：响应延迟近 0；无额外 token；exit code 完整保留。
**失效场景**：orchestrator 不是 Claude Code（裸 shell / cron / 其他 agent）→ 走 B 方案兜底。

---

## B 方案 — cc-connect cron 30 min 安全网（fallback，约 $0.5–1 / 4h 任务）

watcher **启动时**自动注册 30 min 周期的 cc-connect cron，每 30 min 把一条
`[watcher-wake-poll]` prompt 注入 **来源 IM 会话**（按 `CC_SESSION_KEY` 路由），
强制 orchestrator session 醒来读 STATUS.md。

```bash
# watcher.sh 主循环开头自动注册（仅在 CC_PROJECT + CC_SESSION_KEY 双双非空时生效）：
schedule_orchestrator_wake   # → cc-connect cron add --cron "*/30 * * * *" --desc "wake-orchestrator-${TASK_ID}"

# wake prompt 设计成"幂等 + 短回复"：
#   - 35 min 内 STATUS.md 有更新 → orchestrator 回复 "normal" 一个词即可（cheap）
#   - 否则读 .review-pending / .retry-needed / .stop-signal / .boundary-violation 决定下一步
```

**自管理**：watcher 所有非 retry 终止分支（pass / 3-fail STOP / boundary / failed /
stopped / unparseable）退出前调 `cleanup_orchestrator_wake` 删除 cron job，
**避免任务终止后 cron 永久 ping**。exit 3（auto-retry）**故意不删**——保活穿越
retry 循环，等下个 round 启 watcher 时复用同名 cron（`grep -q "$WAKE_CRON_DESC"` 去重）。

---

## Token 成本权衡（为什么选 30 min 而不是 5 min）

| cron 间隔 | 4h 任务唤醒次数 | 估算 token 成本 | 响应延迟（A 失效时） |
|---|---|---|---|
| 5 min | 48 次 | $4–5 | < 5 min |
| 15 min | 16 次 | $1.5–2 | < 15 min |
| **30 min**（默认）| **8 次** | **$0.5–1** | **< 30 min** |
| 60 min | 4 次 | $0.3 | < 60 min |

30 min 是"A 方案 99% 都生效，B 兜底偶发用上 → 别太频繁烧钱"的折中。
要更敏感可手改 watcher.sh 的 `WAKE_CRON_DESC` 段 cron 表达式。

---

## 不可破坏的纪律

- A + B 并存时 orchestrator **不允许两边都响应**：B 触发时先 check `STATUS.md` mtime，
  35 min 内有更新就只回 `normal`，不重复 A 已经处理的事件
- A 失效场景（CC_SESSION_KEY 为空 / cc-connect 不可用）watcher 日志会写
  `非 IM 会话,跳过 wake cron`——属于已知降级，不当 bug
- 跨 task 不复用 cron：每个 task 一个 `WAKE_CRON_DESC=wake-orchestrator-${TASK_ID}`，
  不会互相覆盖

---

## "watcher 不可用" 的兜底（SUBAGENT 模式）

SUBAGENT 模式下 orchestrator 无法持有后台 watcher 进程。此时 orchestrator
**被迫兼任 watcher**：

- 派完一个 Phase 的 codex-rescue 后立刻 git diff --stat 自检
- 区分 "subagent 真完成" vs "agent 转发后台但实际 idle 退出"（Claude 经验文档第 1 条教训）
- 必须主动跑 mini-review codex-rescue（不能省）
- 必须主动写 review-audit / snapshot
- IM 推送由 orchestrator 自己发

但**仍然不破坏**两 Codex 硬隔离原则——subagent 也是新进程，启动方式仍走
`codex exec` + readonly worktree。
