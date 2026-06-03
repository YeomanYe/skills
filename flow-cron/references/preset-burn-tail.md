# 预设 #1 — burn-tail(5h budget 尾巴 burn)

> 用 5h budget 窗口 reset 前的尾巴跑长任务,**不抢用户日常额度,只用反正会被 reset 掉的剩余**。

## 适用场景

- 长跑任务跨数日 / 数周才能完(如 darwin 演化 16 个 skill)
- 任务可分割成 ~18 min 工作量的 batch
- 每个 batch 有持久化产物(commit / file 落盘)
- 不能影响用户白天的常规 Claude 使用 → 只能用 "反正要 reset 的尾巴"

## 核心机制 — 动态一次性 cron 两件套 + watchdog

不是固定时间触发,**根据当前 5h 窗口 `resetsAt` 动态预排** 2 个一次性 cron:

| 角色 | 时机 | 模式 | 干啥 |
|---|---|---|---|
| **main** | `resetsAt - 20min`(在工作窗内才排)| `--exec` | budget gate 通过则调 `claude -p` 跑 1 batch |
| **reschedule** | `resetsAt + 1min`(无窗口约束)| `--exec` | 查新 `resetsAt` → 删旧 → 排新一组(链心脏) |
| **watchdog** | 每天 12:00 + 22:00 recurring | `--exec` | reboot/睡眠错过 reschedule 时自愈;也是完成检测点 |

**为什么没有 fallback**:额度满 5 min 后通常仍满,fallback 收益低。reschedule + watchdog 已兜底。

**为什么 watchdog 必要**:cc-connect cron 无 catch-up,系统关机 / 睡眠错过一次性 cron 就**永久丢失**(表达式语义是"每年 X 月 Y 日 HH:MM",明年才再触发)。

## 时间窗默认值(可改)

```
工作窗口:    Mon-Fri 11:45 - 21:30  (CST)
budget 上限: util ≤ 95%             (硬 cap)
burn 触发: 0 < remaining_min ≤ 20   (恰好剩 ≤ 20 min 才 burn)
watchdog:   每天 12:00 + 22:00      (最坏 12h 自愈延迟)
单 batch 时长: ≤ 18 min             (留 buffer 防撞 95)
```

所有参数都在 `schedule.py` 顶部和 STATUS.md 全局约束段,改一处。

## 工作目录结构

```
<workspace>/.experiment-state/<task-id>/
  STATUS.md               # 任务结构 + 当前 pointer + 全局约束(deadline/window/budget/cron IDs)
  cron-ids.json           # {main: <id>, reschedule: <id>}
  cron-log.txt            # 每次 cron 触发 append 1 行决策
  burn-output.log         # claude -p 跑 burn 时的 stdout/stderr
  scripts/
    schedule.py           # 调度核心: 算 target 时间 / 删旧 / 加新 / 写 IDs
    burn.sh               # burn 入口(纯 shell skip + claude -p)
    reschedule.sh         # reschedule 入口(单行调用 schedule.py)
  prompts/
    <task>-burn-prompt.md # 调 claude -p 时的任务 prompt
```

## schedule.py 关键逻辑(伪码)

```python
def main():
    old_ids = read(cron-ids.json)

    # 1. 终止信号 - terminated_at 字段 → 删全部 cron + 退出
    if STATUS_md has terminated_at:
        del all old cron + clear ids + halt

    # 2. 完成检测 - 任务表全 ✅ → 自写 terminated_at + 删 + 退出
    done, total = parse_skill_table(STATUS.md)
    if total > 0 and done == total:
        write_terminated_at("all-<N>-skills-evolved")
        del all old cron + clear ids + halt

    # 3. 删旧 cron(idempotent)
    for role in old_ids: cc-connect cron del role_id

    # 4. 算新 target(local time = CST)
    resets_local = budget.fiveHour.resetsAt.astimezone()
    T_main       = resets_local - 20min
    T_reschedule = resets_local + 1min

    # 5. 新增 cron
    if in_work_window(T_main):  # Mon-Fri 11:45-21:30
        ids.main = cc-connect cron add T_main → bash burn.sh main
    ids.reschedule = cc-connect cron add T_reschedule → bash reschedule.sh
    # main 出窗口 → ids.main = null,本周期跳过 burn 等下个

    # 6. 写 cron-ids.json + 日志
```

## burn.sh 关键逻辑(伪码)

```bash
# 0. 终止信号 grep
if grep -q '^\s*-?\s*terminated_at:' STATUS.md:
    cc-connect cron del $self_id
    exit 0

# 1. budget check (pure shell, 0 LLM)
util, remaining = parse(claude-usage --json)

# 2. skip 规则
util > 95         → log skip=safety-cap;      self-delete; exit
remaining > 20    → log skip=too-early;       self-delete; exit
remaining <= 0    → log skip=already-reset;   self-delete; exit

# 3. burn (调 headless claude)
log run util=$util remaining=$remaining
claude -p "$(cat prompts/<task>-burn-prompt.md)" >> burn-output.log 2>&1
log run-done

# 4. self-delete
cc-connect cron del $self_id
```

## burn-prompt.md 必含元素

```md
[<task-id> burn] 你被 cron 在 5h 窗口尾巴的 20 min 内唤起,跑 1 batch <任务>。

## 硬约束
- 5h util 任何时刻 ≤ 95(每完一段子任务自检 1 次,接近 95 立即停手 + commit)
- 本轮工作 ≤ 18 min
- 只跑 1 batch(per STATUS.md 当前 pointer)

## 4 步
1. Read <workspace>/.experiment-state/<task>/STATUS.md → 看当前 pointer
2. 跑 pointer 的"下一步动作"
3. 更新 STATUS pointer(完成的标 ✅,推进到下个)
4. git commit(若 workspace 是 git);写 burn-output.log 终止前一行 summary

## 预算自检
node /Users/falcom/Documents/projects/node-scripts/dist/claude-usage/index.js --json | python3 -c "
import json,sys; print(json.load(sys.stdin)['fiveHour']['utilization'])
" → 输出 ≥ 95 立即停手 + commit + exit
```

## 配 cron 的具体命令(供 bootstrap 用)

```bash
# 1. watchdog(recurring, 一次配好)
cc-connect cron add \
  --cron "0 12,22 * * *" \
  --exec "bash <state-dir>/scripts/reschedule.sh" \
  --desc "<task>-watchdog"

# 2. bootstrap: 跑一次 schedule.py 排出第一组 main + reschedule
python3 <state-dir>/scripts/schedule.py
```

watchdog 配一次永远在,因为它是 recurring。main + reschedule 由 schedule.py 自维护。

## 终止机制(双保险)

| 触发 | 谁写 terminated_at | 谁读 + 停 |
|---|---|---|
| 显式 user 手停 | 用户手写 `echo "- terminated_at: $(date -Iseconds)" >> STATUS.md` | 下次任意 cron 触发即自停 |
| burn agent 检测全 ✅ | agent 写 STATUS.md 终止段 | 同上 |
| schedule.py 检测任务表全 ✅ | schedule.py 自动写(防 agent 漏写) | 当次即 halt |

## Reboot 容灾

| 中断点 | 不容灾后果 | watchdog 容灾后果 |
|---|---|---|
| 系统关机过 reschedule 触发时刻 | 链路死(reschedule 不补 fire,one-shot)| 12:00 / 22:00 watchdog 重建链路 |
| cc-connect daemon 临时挂 | 短暂 miss,launchd 重启后正常 | 同上(自动重建) |
| schedule.py 写 cron-ids.json 半途崩 | 半状态 → 后续无法找到旧 cron | watchdog 跑 schedule.py 会 idempotent 重建 |

**最坏延迟**:12h。

## 当 burn-tail 不适用

- 任务无法切成 ~18 min 独立 batch → 用 `--prompt --session-mode new-per-run` 跑更长 single session
- 任务必须每 N 小时触发(无关 budget)→ 用普通 recurring cron
- 不在乎 budget 抢占,user 同意"全天都可能被打扰" → 用普通 5min poll(老方案)

## 实战来源

darwin-huashu 任务(2026-06-03 设计 + 实战):
- workspace: `~/Documents/projects/skills/.experiment-state/darwin-huashu/`
- 任务结构表 16 skill(hat / meta-skill / experience-summary / 7 flow-* / 5 director-* + flow-cron)
- 每 5h 窗口尾巴 burn 1 round
- 完成预期跨 ~30-60 个工作日,期间不影响用户日常 Claude 使用
