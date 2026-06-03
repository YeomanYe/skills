# Halt Protocol — 终止 + 通知协议

## 触发条件(任一命中即触发)

| 条件 | 检测点 | 后果 |
|---|---|---|
| 所有阶段都 ✅ | 唤醒时 Read STATUS 后 | normal-complete halt |
| 当前时间 ≥ deadline | 唤醒判停 step 3 | deadline halt |
| 连续 K 轮 skip(默认 K=5) | 唤醒判停 step 3 + counter ≥ K | budget-jam ping(**不自停**) |
| STATUS.md 损坏 / 缺字段 | 唤醒 step 1 | error halt |
| budget 检测命令连续 N 次报错(默认 N=3)| 唤醒 step 2 + 累计 | dependency-broken halt |
| user 显式说"停" / "halt" | 任何时候(IM inbox poll)| user-requested halt |

## Halt 标准动作序列(必须按这个顺序)

```bash
# 1. 写 STATUS.md 加 terminated_at + reason
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat >> <STATUS.md path> <<EOF

## 终止
- terminated_at: ${TS}
- reason: <normal-complete | deadline | error | budget-jam-ping-only | user-requested>
- 完成阶段: <N>/<M>
EOF

# 2. 通知 user(必须先通知,后删 cron)
cc-connect send --message "<task-id> 终止: <reason>
完成 <N>/<M> 阶段
最终 STATUS: <abs path>
自删 cron job: <job-id>"

# 3. 自删 cron
cc-connect cron del <job-id>
# 或 system crontab:
# crontab -l | grep -v "<task-id>" | crontab -

# 4. 验证 cron 真删了
cc-connect cron list | grep <job-id> && echo "WARN: cron 没删干净,请 user 手动 cc-connect cron del <job-id>" || echo "cron 删除成功"
```

## 各 reason 的具体处理差异

### normal-complete(所有阶段 ✅)
- 必须真的所有阶段 ✅,不能因为"剩下两个不重要"就 normal-complete
- 通知里附最终产物列表(每阶段一行)
- 删 cron

### deadline(时间过点)
- 不强行做完剩余阶段,**立刻**halt
- 通知里说清"完成 N/M,未完成 <list>"
- user 后续若想续:手动调本 skill,deadline 改新时间,新建 cron
- 删 cron

### error(STATUS / dep 异常)
- 通知里说**具体什么坏了**(STATUS 字段名 / 命令 stderr 关键行)
- 不删 STATUS.md(留给 user 排查)
- 删 cron(避免一直撞同个错)

### budget-jam-ping-only(连续 K 轮 skip)
- **不删 cron,不写 terminated_at**
- 只发一条通知:"budget 卡顶 K 次,deadline 还有 H 小时,要不要调 threshold 或换 cron 频率?"
- 等 user 回复 → STATUS.md 加 ack 字段 → 重置 skip counter → 继续 cron 节奏
- **不能无 ack 持续 ping**(spam 风险):同一个 jam 期只发一次,user 不回也不发第二次,直到自然脱离 jam 后下次又卡才重 ping

### user-requested(IM 说停)
- 立刻 halt + 删 cron
- 不强求"做完当前阶段",停就停
- 通知回声"收到 halt 指令,已自删 cron,当前进度 N/M"

## 反例(以下做法是 bug,不是变体)

❌ **先删 cron 再通知**:删完后通知失败(网络问题 / cc-connect 挂)→ user 永远不知道任务为啥停了
  → 顺序必须 "先通知 → 再删 cron"

❌ **通知失败就跳过删 cron**:cron 留着继续唤醒 → 重复触发同样的 halt → 重复通知失败循环
  → 通知失败必须 log + 仍删 cron + 在 STATUS.md 加 `notification_failed: true` 字段

❌ **budget-jam 时自删 cron**:user 没说放弃,自停等于擅自终止任务
  → budget-jam 只 ping,不删

❌ **删 cron 不 verify**:`cc-connect cron del` 偶尔失败(网络 / id 错),不 verify 会留僵尸 cron
  → 删完必跑 `cc-connect cron list | grep <job-id>`,有则警告 user

❌ **同一个任务多次 halt 协议触发**:cron 在第一次 halt 后还没真删,被下一轮唤醒,又走 halt
  → 进 halt 第一步先在 STATUS.md 写 `halting: true` 字段;
     下次唤醒看到 `halting: true` → 不重复 halt 流程,只重试删 cron

## Halt 后续(给 user 的 follow-up)

通知里建议三件事:
1. 看 `<STATUS.md path>` 了解每阶段产物
2. 看 `<workspace>/.experiment-state/<task>/cron-log.txt` 了解每次唤醒决策
3. 若想接着跑(deadline / budget-jam 场景),调本 skill 新建 cron(不能直接 revive 旧 cron)
