# 预设 #2 — window-burn(指定时间窗整段 burn)

> user 划定一段"随便烧"的时段(典型:夜间 21:30→11:30),任务在窗内**尽量用光额度**;
> 跨过窗末的那个 5h 窗口按**线性比例预留**,不吃白天额度。
>
> 与 #1 `burn-tail` 的根本区别:#1 只烧每个 5h 窗口最后 ≤20min 的尾巴(保白天);
> #2 在指定窗内**整段、多批、连烧到 cap**。robustness 规则两者共用(见 preset-burn-tail.md 第 1–7 条)。

## 适用场景

- 长跑任务跨数日/数周(如把一个 fork 的功能 backlog 全做完)
- 任务可切成 ~50 min 的 batch,每批有持久化产物(commit)
- user 明确把某段时间(夜间)让出来给 agent 随便烧额度
- 要"尽量用光"该时段额度,而不是只捡尾巴

## 核心机制 — 单条自排程 cron + watchdog

```
burn cron(一次性,desc=<task>-burn)
  每次唤醒: ① claude -p hi 刷 token  ② budget-gate 判停  ③ 跑一批 ~50min  ④ schedule.py 算下次并自排
watchdog(recurring, daily 12:00 + 22:00)
  跑 schedule.py: reboot/睡眠错过一次性 burn cron 时自愈;也是完成检测点
```

**下次唤醒时刻(schedule.py 算)**:

| 当前状态 | 下次 burn |
|---|---|
| 窗内 + util < cap | `now + ~50min`(继续烧本窗) |
| 窗内 + util ≥ cap,且当前 5h 窗 `resetsAt` 早于窗末 deadline | `resetsAt + 1min`(等下一窗开) |
| util ≥ cap 但 `resetsAt` 晚于 deadline(线性预留用满) | 下一个窗起点(如次日 21:30) |
| 出了允许时段 | 下一个窗起点 |

## 默认参数(均可改,集中在 budget-gate.py + schedule.py 顶部)

```
允许时段:    每日 21:30 → 次日 11:30 (CST)
budget cap:  util ≤ 97%(留 3% 防 hard lockout)
线性预留:    5h 窗 resetsAt 晚于 11:30 → threshold = (11:30 − 窗口起点)/5h
单 batch:    ~50 min(收尾防下次唤醒重叠)
watchdog:    daily 12:00 / 22:00
```

## 工作目录结构

```
<workspace>/.experiment-state/<task>/
  STATUS.md            # 全量 backlog + 当前 pointer + 全局约束(唯一事实源)
  budget-gate.py       # 线性预留判停,输出 {proceed,threshold,utilization,resetsAt,in_window}
  schedule.py          # 自排程心脏:算下次 + 删旧加新 + watchdog + 持久 retry_gen
  burn.sh              # cron 入口:hi 刷新 → gate → claude -p 批次 → schedule.py
  burn-prompt.md       # spawn 的 headless claude 干活指令
  cron-ids.json        # {burn, watchdog_noon, watchdog_eve, retry_gen}
  cron-log.txt         # 每次唤醒一行决策
  burn-output.log      # claude -p 批次 stdout
```

## budget-gate.py 关键逻辑(线性预留)

```python
now = datetime.now(CST)
# 1) 在允许时段内? 21:30..23:59 或 00:00..11:30
if not in_window(now):  out(proceed=False, in_window=False); return
# 2) 本 dev 周期的 11:30 deadline
deadline = today_or_tomorrow_1130(now)
# 3) 读 budget(claude-usage --json → fiveHour.utilization + resetsAt)
util = round(fiveHour.utilization); window_end = resetsAt.astimezone(CST)
window_start = window_end - 5h
# 4) threshold: 整段在窗内→cap(97);跨窗末→线性
if window_end <= deadline:  threshold = 97
else:                       threshold = min(97, round((deadline - window_start)/5h * 100))
out(proceed = util < threshold, threshold, util, resets=window_end, in_window=True)
# 命令异常 → out(proceed=False, util=-1, reason 含 auth/rate/other 分类)  # 绝不当 0%
```

## schedule.py 关键逻辑(自排程 + wake-then-query 兜底 + 持久 retry_gen)

```python
ids = read(cron-ids.json)
if 'terminated_at:' in STATUS:  del all crons; exit          # 完成/终止
cron_del(ids['burn']); ids['burn'] = None                    # 删旧(idempotent)

b = read_budget_with_rate_backoff()                          # 内层 5/15/30s 退避(429)
if b.util == -1 and 'failed' in b.reason:                    # 读失败
    refresh_auth()                                           # claude -p hi 自刷新(watchdog 路径也兜底)
    b = read_budget_with_rate_backoff()                      # 重读一次
if b.util == -1 and 'failed' in b.reason:                    # 仍失败 → 5min retry(持久计数!)
    gen = ids.get('retry_gen', 0)
    if gen >= MAX_RETRY_GEN(30):  ensure_watchdog; exit      # 真长期 broken → 等 watchdog
    ids['burn'] = cron_add(now+5min, burn.sh, f'<task>-retry-{gen+1}')
    ids['retry_gen'] = gen + 1; ensure_watchdog; write_ids; exit

ids['retry_gen'] = 0                                         # good read → 清零
nxt = (next_window_start(now)         if not b.in_window
       else now + 50min               if b.proceed                       # 续烧本窗
       else resetsAt + 1min           if resetsAt < deadline              # 窗满→下一窗
       else next_window_start(now))                                      # 线性预留用满→下一夜
ids['burn'] = cron_add(nxt, burn.sh, '<task>-burn')
ensure_watchdog(ids); write_ids(ids); log(nxt)
```

**一次性 cron 表达式**:`{minute} {hour} {day} {month} *`(特定日期 = 触发一次)。
**`cron add` 必须显式** `--project <p> --session-key <k>`(从 `~/.cc-connect/crons/jobs.json` 推断;见 preset-burn-tail 第二条)。

## burn.sh 关键逻辑(hi-first)

```bash
grep -q 'terminated_at:' STATUS.md && { python3 schedule.py; exit 0; }   # 终止

# wake-then-query: 读 budget 前先刷 token(见 preset-burn-tail 第七条)
claude -p hi --permission-mode bypassPermissions >/dev/null 2>&1 || true

PROCEED=$(python3 budget-gate.py | jq .proceed)
[ "$PROCEED" != "true" ] && { log skip; python3 schedule.py; exit 0; }

claude -p "$(cat burn-prompt.md)" --permission-mode bypassPermissions >> burn-output.log 2>&1
python3 schedule.py     # 批次结束 → 自排下次
```

## burn-prompt.md 必含元素

- **第一件事 Read STATUS.md** 看当前 pointer(唯一事实源)
- 预算已被 shell 判过 → **不二次 skip**;但自检:接近 cap 立即收尾 + commit
- 本轮 ≤ ~50min,走 **flow-dev-task 纪律**(plan→TDD→verify→commit),小步提交
- **一项做完且有时间 → 本轮接下一优先级项**(连续推进,不停等 review)
- 只动目标工作目录,**绝不碰其他项目**
- 全 backlog ✅ → STATUS 加 `terminated_at: <ISO>` + `cc-connect send` 通知(schedule.py 据此自删 cron)

## 与 burn-tail 共用的 robustness(见 preset-burn-tail.md)

第 1 条(失败不 abort、排 retry)/ 第二条(显式 project+session_key)/ 第三条(429 内层退避)/
第四条(`claude -p` 必带 `--permission-mode bypassPermissions`)/ 第五条(显式捕获 stderr)/
**第六条(retry_gen 用持久计数器,不数 cron)/ 第七条(wake-then-query 先 hi 再查)** —— 后两条是
2026-06-17 本预设实战补的,务必照搬。

## 实战

`~/Documents/projects/.experiment-state/ty-vibe-kanban-build/`(本预设来源,2026-06-17 编排;
夜间窗 burn fork 的功能 backlog,一夜推完 Task0 + 全 P0 + 多个 P1)。
