# 预设 #1 — burn-tail(5h budget 尾巴 burn)

> 用 5h budget 窗口 reset 前的尾巴跑长任务,**不抢用户日常额度,只用反正会被 reset 掉的剩余**。
>
> **唯一触发**:`0 < remaining_min ≤ 20 AND util ≤ 95`(必须同时满足两个条件)。
> 不要加"固定时间点 burn"或"util 低就 burn"等简化变种 —— 实测会偷走用户主动用 claude 的额度。
> 详见下方反例小节「⚠️ 已废弃尝试: hybrid / fixed mode」。

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

**第六条 robustness 规则**(2026-06-06,2026-06-17 修正实现陷阱):5-min retry 循环必须有**上限**,否则连续失败几小时累积 30+ 个 retry cron 噪音。

⚠️ **实现陷阱(ty-vibe-kanban 实测踩死)**:retry 代数**绝不能靠"数 jobs.json 里 retry cron 个数"来推**——schedule.py 在重排前会先 `cron del` 掉当前那个 retry cron,**删完再数永远是 0 → 代数恒为 1 → 上限永远触发不了 → 无限 5-min 重试**。
- ✅ 正确:**用持久计数器**——写在 `cron-ids.json` 的 `retry_gen` 字段,失败时 `+1`、good read 时清 0。
- retry cron 仍用编号 desc(`<task>-retry-N`)便于辨识,但**判上限以 `retry_gen` 为准,不数 cron**。
- 配合第七条 wake-then-query 后,auth-idle 一周期即恢复,真到上限的只剩"命令真坏"的长期 broken → 不再排 retry,等 watchdog。

这把"瞬时抖动"(自愈)跟"长期 broken"(等 watchdog)分开,日志不再被淹没。

**第七条 robustness 规则**(2026-06-06 起,2026-06-17 ty-vibe-kanban 实战修正根因与解法):**`claude-usage` 从凭证库读 OAuth access token 直接打 Anthropic API,token 长期 idle(整夜 / 周末)会过期**。

⚠️ **过期不一定报 `401/unauthorized`**——实测常表现为 **claude-usage 返回空 stdout**(budget JSON 解析失败 `Expecting value: line 1 column 1`),会被误判成 "other" 类错误。**靠 auth 关键字分类会漏**。

❌ **已废弃的旧解法**:"检测到 auth-class 关键字 → 立即 give-up 等 watchdog"。两个致命问题:(1) 过期常是空输出、命中不了 auth 关键字 → 不 give-up 反而进 5-min 死重试;(2) 即便命中,give-up 等 watchdog(12:00/22:00,通常在工作窗外)= **丢掉整段窗口**。2026-06-17 ty-vibe-kanban 实测:03:12–05:52 空转 **2h40m**,直到 user 给 bot 发消息(= claude 活动刷新了 token)才恢复。

✅ **正解:先唤醒刷新,再查询(wake-then-query)**。**每次 burn 唤醒,在读 budget 之前先跑一次 `claude -p hi --permission-mode bypassPermissions`**——它刷新共享凭证库里的 token,使后续 budget 查询永远在 fresh token 上做。idle-expiry 不再造成空转(根因是 user 点破:他跟 bot 对话本身就刷新了 token,把那招主动化即可)。

兜底:schedule.py 的 watchdog 路径(不经 burn.sh)在 budget 读失败时也做一次 `claude -p hi` 自刷新 + 重读,再决定是否 5-min retry。

## burn.sh 关键逻辑(伪码)

```bash
# 0. 终止信号 grep
if grep -q '^\s*-?\s*terminated_at:' STATUS.md:
    cc-connect cron del $self_id
    exit 0

# 0.5 wake-then-query (见第七条): 读 budget 前先刷新 token,否则 idle 过期的 token 查 budget 必败 → 死重试
claude -p hi --permission-mode bypassPermissions >/dev/null 2>&1 || true

# 1. budget check (pure shell, 0 LLM)
# ⚠️ JSON 只有 .fiveHour.utilization + .fiveHour.resetsAt(camelCase),没有 remaining_minutes!
# remaining 要自己算: (resetsAt - now_utc) / 60。一行实现见 budget-gate.md「算 remaining_min」。
util, remaining = parse_budget()   # util=.fiveHour.utilization; remaining=(resetsAt-now)/60

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

**并发分桶架构**(避免不同任务类型的依赖冲突):

| 桶 | 改不改 SKILL.md | 是否 git revert 风险 | 是否需 worktree | 并发 N |
|---|---|---|---|---|
| A. round(改维度评分) | ✓ | ✓(Δ<0 必 revert) | **要**(按 skill 隔离,失败不撤其他)| 2-4 |
| B. baseline(评分) | ✗ | ✗(read-only) | 不要 | 3-5 |
| C. test-prompts | ✓ 新建文件 | ✗(独立文件,不会失败 revert) | 不要 | 3-5 |

**为什么 round 桶必须 worktree**:多 skill 并行改 SKILL.md,任一失败要 `git revert HEAD` 会撤掉同 batch 其他成功 commit。worktree 把每个 round 隔离在独立 branch:
- Δ>0 → `git merge --no-ff` 进主 branch
- Δ≤0 → `git worktree remove --force` + `git branch -D`(等价 revert,不影响他人)

coordinator 单点 commit,STATUS.md 单点更新,避免并发写文件冲突。

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

## ⚠️ 已废弃尝试: hybrid / fixed mode(反例,不要复用)

2026-06-10 实测出严重坑,**fixed mode 已从预设移除**。此节作为反例 + 设计教训保留。

### 当时设计

为了"工作时段也能 burn"(不只是 5h 尾巴),加了 fixed mode:
- recurring cron 在固定时间点(如 13:00 / 17:00 Mon-Fri)触发
- burn.sh 切 `mode=fixed` 分支,**只检查 util ≤ 90,不查 remaining_min**
- 跟 tail mode(main)互补 = "hybrid"

### 为什么不行

实测 2026-06-10 13:00 触发:
- 当时 `util=15% remaining=179min`(5h 窗口刚开始)
- fixed mode 没看 remaining,认为 "util < 90 就 burn 没毛病" → 跑了 23 min
- burn 后 util 飙到 95%,后续 2 小时用户主动用 claude 撞 rate limit
- **本质问题**:burn-tail 预设的核心契约是"只用反正会被 reset 掉的余量"。任何不查 `remaining_min` 的 mode 都违反这个契约,会偷走用户白天的可用额度。

### 教训

| 错觉 | 真相 |
|---|---|
| util 低 = budget 多 = 可以 burn | util 低 ≠ "反正要 reset",可能只是 5h 窗口刚启动,后续都是 user 的可用预算 |
| "工作时段定点 burn 让链路更活" | 链路活靠 reschedule + watchdog 自愈,不靠多触发点 |
| "fixed mode 跟 tail mode 互补" | 真互补需要 fixed 也查 remaining,但那就跟 tail 一样了 → 没必要存在 |

### 如果未来又想要"工作时段多 burn 几次"

**正确做法**:不是加固定时间点 burn,而是**在工作时段让 5h 窗口多 reset 几次**:
- 早上 6:00 cron 发 "hi" → 窗口 11:00 reset → 11 点附近有一次 tail burn 机会
- 中午 11:30 再发"hi" → 窗口 16:30 reset → 16:10 附近又一次
- 每个 reset 都对应一次 tail burn(由 main cron 自动排)

这个方案下,burn 还是只用尾巴,user 主动用 claude 不受影响。
关键:**永远不要绕开 `remaining_min ≤ 20` 这个 gate**。

## 实战来源

darwin-huashu 任务(2026-06-03 设计 + 实战):
- workspace: `~/Documents/projects/skills/.experiment-state/darwin-huashu/`
- 任务结构表 16 skill(hat / meta-skill / experience-summary / 7 flow-* / 5 director-* + flow-cron)
- 每 5h 窗口尾巴 burn 1 round
- 完成预期跨 ~30-60 个工作日,期间不影响用户日常 Claude 使用
