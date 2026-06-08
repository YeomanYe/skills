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

    # 4. 读 budget(graceful degradation 必做)
    try:
        budget = json(claude-usage --json)
        resets_local = budget.fiveHour.resetsAt.astimezone()
    except Exception:
        # 必须 fail-safe!直接 sys.exit(1) 会让链路死(本预设踩过的坑)
        retry_id = cc-connect cron add (now + 5min) → bash reschedule.sh
        ids = {main: None, reschedule: retry_id}  # desc 标记 retry
        write ids + log WARN
        return  # 5 min 后自动再试,不死链

    # 5. 算新 target(local time = CST)
    T_main       = resets_local - 20min
    T_reschedule = resets_local + 1min

    # 6. 新增 cron
    if in_work_window(T_main):  # Mon-Fri 11:45-21:30
        ids.main = cc-connect cron add T_main → bash burn.sh main
    ids.reschedule = cc-connect cron add T_reschedule → bash reschedule.sh
    # main 出窗口 → ids.main = null,本周期跳过 burn 等下个

    # 7. 写 cron-ids.json + 日志
```

**关键 robustness 规则**:budget 读失败时**绝不**直接 abort。必须自动排一个 5 min 后的 retry reschedule,否则一次偶发 API 错误就让链路死。watchdog 是兜底(最坏 12h),但 5 min retry 才是日常该有的容错。

**第二条 robustness 规则**(2026-06-04 + 06-05 各踩一次):cron `--exec` 上下文**既不继承** `CC_PROJECT` **也不继承** `CC_SESSION_KEY`。`cc-connect cron add` 在多项目 + 多会话场景下**必须**显式 `--project <name>` + `--session-key <key>`,否则分别报:
- `Error: project is required (multiple projects configured)`
- `Error: session_key is required: set CC_SESSION_KEY env, pass --session-key, or ensure exactly one active session exists`

两个值都从 `~/.cc-connect/crons/jobs.json` 既有 cron 的同名 field 推断:
```python
def _get_project():    return env.CC_PROJECT     or jobs[0].project     or 'bot2'
def _get_session_key(): return env.CC_SESSION_KEY or jobs[0].session_key or None
```

这条 bug 跟 budget read 失败叠加会**雪崩**:budget 读失败 → 走 retry 路径 → retry 也无法创建 cron(因 project / session_key) → 链彻底死。**先修这两条,再修 budget retry 才有意义**。

**第三条 robustness 规则**(2026-06-04 第 3 坑):**budget API 是 Anthropic 上游**,有 rate limit(实测 5 次连续后 429)。schedule.py 必须做 in-process retry + backoff:
- 第 1 次失败 sleep 5s 重试,第 2 次 15s,第 3 次 30s
- 还失败再走 5-min cron retry(外层)
- 429 窗口可能 1-3 分钟,内层 retry + 外层 5-min retry 叠加吸收

判定 429 的关键字:`429` / `rate_limit`(stderr 含其一)。其他错误不重试,直接走 5-min retry。

**第四条 robustness 规则**(2026-06-05 第 4 坑):`claude -p` headless 模式**默认不能跑 Bash / Edit / Write**(每次会要 interactive approval,cron 里没人按 → 工具调用全失败 → burn agent 在 budget 自检 + STATUS 写状态时全卡住,只能 abort)。burn.sh 调 `claude -p` **必须**带 `--permission-mode bypassPermissions`:
```bash
claude -p "$(cat $BURN_PROMPT)" --permission-mode bypassPermissions
```
controlled prompt(我们自己写的,无外部输入)可安全 bypass。否则 burn 会持续 abort,日志写满"环境阻断"。

**第五条 robustness 规则**(2026-06-06 第 5 坑):budget cmd 失败时**用 `subprocess.run(capture_output=True)` 显式捕获 stderr**,而不是 `check_output`(默认 stderr 直接打到 console 看不到)。否则 CalledProcessError 只带 returncode,根因不明。日志该有一行 `DIAG budget stderr: <前 300 字>`。

**第六条 robustness 规则**(2026-06-06 同时踩):5-min retry 循环必须有**上限**,否则连续失败几小时累积 30+ 个 retry cron 噪音。建议:
- retry 用编号 desc(`darwin-reschedule-retry-N`)
- schedule.py 读 jobs.json 看自己是第几代 retry
- N ≥ 6(≈ 30 min)→ give-up,不再排 retry,等 watchdog 12:00/22:00 救活

这把"瞬时网络抖动"(30 min 内自愈)跟"长期 broken"(等 watchdog)分开,日志不再被淹没。

**第七条 robustness 规则**(2026-06-06 + user 一句话点破根因):**`claude-usage` 用 claude CLI 同一套 auth token,token 会随用户活跃自动续期,但长期 idle(整夜 / 周末)会过期**。过期表现为 stderr 含 `401 / 403 / unauthorized / authentication / token expired`。

这意味着 5-min retry 在 user idle 期间**注定失败**(token 直到 user 跟 claude 对话才会 refresh)。所以 schedule.py 检测到 auth-class 错误关键字时**立即 give-up**,不浪费 retry slot,直接等 watchdog 12:00/22:00。watchdog 触发时 user 通常已醒/在用 → token 已 refresh → 链路自愈。

判定关键字(stderr 全小写匹配):`401` / `403` / `unauthorized` / `authentication` / `token expired`。

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

**关键**:burn agent **必须最大化并发**,串行跑 1 个 sub-agent 浪费 99% 的 5h budget。
设计意图是"把尾巴 burn 干净",所以 prompt 必须强制并发。

```md
[<task-id> burn] 你被 cron 唤起,**立刻最大化并发干活**。

## 硬约束
- shell 已经判过触发条件,你不要二次 skip(util 低不是停手的理由)
- 5h util 任何时刻 ≤ 95(每完一段自检,接近 95 立即停手 + commit)
- 本轮工作 ≤ 18 min
- **最大化并发**:每次 burn 4-6 个 Agent tool 并发 sub-agent(目标 util 从 ~80% 推到 ~93%)

## 3 步
1. Read STATUS + budget cmd 看初始 util
2. **并发 dispatch**:
   - 1 关键路径任务(当前 pointer skill 的当前 round)
   - 3-5 个并行无依赖任务(其他 pending skill 的 Phase 0.5 test-prompts 设计)
   - 同消息内多 Agent tool call → 真并发
3. 收尾:全 done → commit + 更新 STATUS

## 反例补 2 条(本预设独有)
9. ❌ 串行跑 1 个 sub-agent 就收手 → 浪费 5h 尾巴
10. ❌ 多 sub-agent 改同 1 skill 同 1 维 → race + 违反 huashu 规则 5

## 预算自检(每完一段并发批跑 1 次)
node /Users/falcom/Documents/projects/node-scripts/dist/claude-usage/index.js --json | python3 -c "
import json,sys; print(json.load(sys.stdin)['fiveHour']['utilization'])
" → 输出 ≥ 93 立即停手 + commit(留 2% 安全垫到 hard cap 95)
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
