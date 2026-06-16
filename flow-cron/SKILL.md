---
name: flow-cron
description: >
  Use when a task is too long to fit in a single agent context window and must
  be sliced across multiple wake-ups gated by budget / deadline. 编排"创建带 STATUS 文件
  的长跑任务 + 配 cron 定时唤醒 + 每次唤醒按 budget+deadline gate 判停 + 任务全完后
  自删 cron + 通知 user"全套。
  显式触发:"长跑任务" / "跨数小时分批跑" / "额度不够分时执行" / "cron 唤醒续作" /
  "5h budget gate" / "deadline 自停" / "halt + resume" / "把任务挂着自己跑" /
  "schedule wake up" / "long-running task with budget gating" / "incremental work via cron"。
  Do NOT use for:一次性 cron 提醒(直接 cc-connect cron add)/ 不需要续作业的纯定时
  任务 / 跨设备分布式编排 / 实时回调 / 短任务(< 1 个 context window 能完)。
---

> 本 skill 受 `../_shared/constitution.md` 约束(always-follow,身份 / 安全 / 高风险动作 gate)

# flow-cron — 长跑任务定时续作业编排

## Overview

一个 agent context window 装不下的任务(几小时到几天),不靠 daemon 而靠 **cron 定时
唤醒 + 磁盘状态文件 + budget/deadline gate** 续作业。

本 skill 编排:
1. 跟用户对齐任务可拆分性 + deadline + budget threshold + cron 频率
2. 落地 `<workspace>/.experiment-state/<task>/STATUS.md`(canonical 状态)
3. 配 cron 任务(用 cc-connect cron / system crontab)+ prompt 含 4 步协议
4. **Smoke test**:1-2 分钟内验证 cron 真能唤醒 + 真能读 STATUS + 真能写日志
5. 启动第一批工作 → halt → 等下次 cron 唤醒
6. 每次唤醒按"Read STATUS → check budget → judge stop → do work → update STATUS"4 步走
7. 终止条件命中(任务完成 / deadline 到 / hard error)→ 自删 cron + 通知 user

**核心信念**:
- 长跑任务**不依赖对话上下文记忆**,依赖**磁盘状态文件**
- cron prompt 必须**自包含**所有续作业指令(不能假设 wake 上下文还在)
- budget threshold 必须**实时检测**而非"我觉得还有"
- **Smoke test 必跑**,否则配错 cron 等于挂了个空炮
- 任务结束必须**自删 cron**,否则后台静悄悄无效唤醒污染额度

## When to Use

- 任务预估时间 ≥ 1 个 5h budget 窗口 / ≥ 2 小时 wall-clock
- 任务能切成 **N 个独立批次**,每批次 30-40 min 工作量,有持久化产物
- 有明确的 **deadline**(任务必须在某时间前完成 / 自停)
- 有明确的 **budget 上限**(Claude 5h 额度 / 调用 API quota / 其他可读阈值)
- 用户期望"挂着自己跑,我去做别的"

## When NOT to Use

- 任务能在当前 context 窗口内做完 → 直接做,不用 cron
- 一次性提醒("每天早上 6 点发 GitHub trending")→ 直接 `cc-connect cron add --prompt`
- 实时回调任务(webhook / event-driven)→ 用 daemon 不用 cron
- 任务**不能持久化中间状态**(必须保留 context 才能续)→ cron 续不起来,本 skill 没用
- 跨设备分布式(超出范围,需要专门的调度器)

## High-Risk Actions — 必经 User Gate

下面任一动作触发前都必须先跟用户确认,不能跳过、不能合并、不能"顺手"做掉:

1. **配 cron**(`cc-connect cron add` / `crontab -e`)— 改 user 的定时任务表
2. **删 cron**(自停触发时)— 必须先在通知里告诉 user "我自删了 cron <id>"
3. **覆盖已有 STATUS.md**(必须先 backup 为 `STATUS.md.bak.YYYYMMDD-HHMM`)
4. **续作业写 user 已手改过的 STATUS.md 字段**(检测到 user 注释 / 手加字段 → 停)
5. **deadline 改为更长**(user 没说"延期"前不能擅自延)
6. **budget threshold 调高**(默认 95%,user 没说"放宽到 99%" 前不能改)
7. **跨任务复用同 cron job**(必须 1 任务 1 cron,避免互相干扰)

read-only 动作(ls / cat STATUS / `claude-usage --json` / `date`)不算 high-risk,可直接做。

## Required Workflow

### Phase 0 — 用户对齐(必须先做)

跟用户问清以下 4 项(Question Budget = 4,**一次性批量问**,不能挤牙膏):

1. **任务可拆性**:能切成 N 批,每批 ~30-40 min?如果不能 → **本 skill 不适用**,直接告诉 user。
2. **Deadline**:任务必须在何时前完成 / 自停?(ISO 时间或相对描述,转为绝对时间存档)
3. **Budget threshold**:5h 额度跑到多少 % 就 skip 本轮?(默认 95%,user 可改 80/90/99)
4. **Cron 频率**:多久唤醒一次?(默认每整点 :55,可改 `*/30 * * * *` 等)

收到 4 项答复 → 进 Phase 1。任一缺 → 用合理默认推断(deadline=今天 23:59 / threshold=95% / 频率=`55 * * * *`),并在 Phase 1 报告里**显式标注**默认值的来源。

### Phase 1 — STATUS.md 落地

写到 `<workspace>/.experiment-state/<task-id>/STATUS.md`,canonical 状态文件。

**STATUS.md 必含字段**(模板见 `references/status-md-template.md`):

```md
# <task-id> — STATUS

> Cron 唤醒后**第一件事:Read 本文件 → 决定续作业从哪开始**

## 全局约束
- **截止时间**: <ISO-8601 deadline>(超过 → 自停 + 删 cron + 通知)
- **Budget 阈值**: 5h utilization > <X>% → skip 本轮回复 'skipped'
- **预算检测命令**: `<absolute path to budget query>`
- **工作目录**: <abs path>
- **任务分支**(若 git): <branch-name>

## 任务结构(全部步骤)
| 阶段 | 状态 | 产物 | 备注 |
|---|---|---|---|
| 1. <step> | ⏳ pending | <expected-output> | |
| 2. <step> | pending | | |
| ... | | | |

## 当前 pointer
- 当前阶段: <N>
- 当前 round / batch(若有): <round>
- 下一步动作: <具体命令 / 文件路径>

## Cron 唤醒协议(prompt 已经包含,这里复述以便审查)
1. Read 本 STATUS.md → 看当前 pointer
2. 跑 budget 检测命令 → 取 utilization
3. 判停:
   - 时间 ≥ deadline → 自删 cron + cc-connect 通知 + halt
   - budget > threshold → skip 本轮回复 'skipped' 不动手
   - 否则进 step 4
4. 做事 30-40 min:跑当前阶段的"下一步动作",done 后更新 pointer
5. 写状态 → halt(等下次 cron)

## Halt 协议(任一命中即触发)
- 所有阶段都 ✅ → 自删 cron + cc-connect 通知"任务全完"
- 时间 ≥ deadline → 自删 cron + cc-connect 通知"deadline 强停"
- 连续 N 轮 skip(budget 一直过线)→ ping user "budget 长期卡顶,要不要调整 threshold"
- 检测到 STATUS.md 损坏 / 缺字段 → 自删 cron + ping user

## 反例黑名单(本 skill 自己不要做的事)
- ❌ 不读 STATUS 直接动手("我大概记得做到哪了")
- ❌ budget 检测命令报错就当 0%(应当当 100% 跳过)
- ❌ 跑超 40 min 不写状态(下次唤醒 pointer 不对)
- ❌ user 没说就改 threshold / deadline
```

写完后 `git add` + commit(若 workspace 是 git repo)+ 在报告里给 user 看完整路径。

### Phase 2 — Cron 配置

```bash
# 选项 A: cc-connect cron(IM 会话场景首选)
cc-connect cron add \
  --cron "<频率,如 55 * * * *>" \
  --prompt "$(cat <path-to-cron-prompt.md>)" \
  --desc "<task-id>-cron"

# 选项 B: system crontab(无 IM 会话场景)
crontab -l > /tmp/crontab.bak
(crontab -l; echo "<频率> <绝对命令路径>") | crontab -
```

**cron prompt 必须自包含**(因为唤醒后没有对话历史)— 完整模板见 `references/cron-prompt-template.md`,要包含:

1. **第一步指令**:Read `<STATUS.md 绝对路径>` 看当前 pointer
2. **第二步指令**:跑 budget 检测命令(STATUS 里的)→ 取 utilization
3. **第三步指令**:判停规则(deadline / budget / halt 条件)
4. **第四步指令**:做事 30-40 min
5. **环境变量提示**:CC_PROJECT / CC_SESSION_KEY 已设(若 cc-connect)
6. **失败兜底**:budget 检测命令失败 → 当作 100% 跳过(不动手)

记录返回的 cron job ID 到 STATUS.md `cron_job_id` 字段(后续自删用)。

### Phase 3 — Smoke Test(必跑,不能跳)

配完 cron **不能直接挂主任务**。先验证 cron 真能唤醒,5 步:

```bash
# 1. 在 STATUS.md 加 sentinel 字段(初始 "smoke_pending")
# 2. 改 cron prompt 临时加一行 "把 STATUS.md 里 smoke_pending 改成 smoke_ok"
# 3. 把 cron 频率临时改为 1 分钟后即触发(如当前 06:00 → 配 "01 06 * * *")
# 4. 等 1-2 分钟,检查 STATUS.md 是否被改写成 smoke_ok
# 5. 验证通过 → 改回 cron prompt 真实指令 + 改回真实频率
```

Smoke test 失败 → **不能进 Phase 4**,先排查:
- cron job ID 是否真的生效(`cc-connect cron list` / `crontab -l`)
- cron prompt 路径是否正确(绝对路径,不能用 ~)
- 环境变量是否在 cron 上下文里能拿到

Smoke test 通过 → 删除 sentinel 字段 + 恢复真实 cron prompt 与频率,进 Phase 4。

### Phase 4 — 第一批工作 + Halt

跑当前 STATUS 里第一阶段的"下一步动作",目标 30-40 min 工作量:
- 用 Agent 并发派工 / 直接做工 / 其他
- 工作完成后更新 STATUS.md(当前阶段 ✅ / 推进 pointer)
- git commit 状态(若 workspace 是 git repo)
- 给 user 报告"第一批做完,后续 cron 接管,下次唤醒 <时间>"

### Phase 5 — 每次 cron 唤醒的 4 步(已写进 cron prompt)

agent 被 cron 唤醒后,**只做这 4 步**,不超出范围:

1. **Read STATUS.md** → 看当前 pointer
2. **跑 budget 检测命令** → 取 utilization
3. **判停**:
   - 时间 ≥ deadline → 走 Phase 6 自删 cron + 通知
   - budget > threshold → 回复 `skipped` 不动手(也不写日志,降低噪音)
   - 否则进 step 4
4. **做事 30-40 min** → 更新 STATUS pointer → halt(让 cron 下次再来)

不在唤醒上下文里做超出当前 pointer 的事。

### Phase 6 — 终止协议

任一触发即终止:
- 所有阶段 ✅ → 自删 cron(`cc-connect cron del <id>` / `crontab -r`)+ `cc-connect send --message "<task-id> 任务全完"`
- 时间 ≥ deadline → 自删 cron + `cc-connect send --message "<task-id> deadline 强停,完成 N/M 阶段"`
- 连续 K 轮(默认 5)skip → ping user "budget 卡顶 K 次,要不要调 threshold"(**不**自停,等 user)
- STATUS.md 损坏 → 自删 cron + 通知 user 排查

**自删 cron 必须**:
1. 先在通知里告诉 user "我自删了 cron `<job-id>`"
2. 然后真删
3. 删完再写 STATUS.md 加 `terminated_at` 字段

## Output Contract

- 详细输出契约见 `../_shared/output-contract-schema.md`
- **本 skill 落盘产物**:
  - `<workspace>/.experiment-state/<task>/STATUS.md`(canonical)
  - `<workspace>/.experiment-state/<task>/cron-log.txt`(每次唤醒记一行:时间 + 决策)
  - cron job ID(记录在 STATUS.md `cron_job_id` 字段)
- **对话响应**(给 user 看):
  - Phase 0 后:确认 4 项配置 + 推断的默认值
  - Phase 1-3 完成:STATUS 路径 + cron job ID + smoke test 结果
  - Phase 4 完成:第一批产物 + "已挂上 cron,下次唤醒 <时间>"
  - Phase 6 触发:终止原因 + 完成 N/M 阶段 + 自删的 cron ID

## Red Flags — STOP

每条都是 **machine-detectable / 可在 commit/PR review 时 grep 出来**:

- **不跑 Phase 3 smoke test 就挂主任务** — cron 没真接上等于挂了空炮(grep `phase 3 skipped` / 找 `smoke_ok` 是否真出现)
- **cron prompt 路径含 `~/` 而非绝对路径** — cron 上下文里 `~` 不一定展开(`grep -E '\\b~/' <prompt-file>`)
- **STATUS.md 缺 `deadline` 字段** — 任务跑过头无人停(`grep -L 'deadline' STATUS.md`)
- **STATUS.md 缺 `budget threshold` 字段** — 撞 hard limit 触发 lockout
- **cron prompt 没含"判停"指令** — 唤醒后 burn 额度不停
- **任务全完 / deadline 到了不自删 cron** — 后台僵尸 cron 持续无效唤醒
- **续作业改了 user 手改过的 STATUS 字段**(user 加了 `pinned: true` / 注释 → 必须保留)
- **同一任务配 ≥ 2 个 cron job** — 互相干扰,可能并发动同一文件
- **budget 检测命令失败时当 0%**(应当当 100% 跳过)— 命令没输出 ≠ 没用 budget
- **smoke test 改 cron 频率为 1 分钟后忘了改回来** — 后续真任务被高频骚扰

## Rationalizations — 这些是借口,不是理由

- "smoke test 太麻烦,我觉得 cron 配对了" → NO。配错 cron 等于挂空炮,2 分钟 smoke 是必要成本
- "deadline 还远着呢不用写" → NO。STATUS.md 不写 deadline = 跑过头无人停
- "budget 检测命令偶尔失败,我跳过这次" → NO。命令失败必须当满额跳过,不能"觉得还有就跑"
- "任务做完了 cron 留着没事" → NO。僵尸 cron 每次唤醒消耗少量但持续 burn
- "user 没明说要 95% 我用 80% 保守点" → NO。default 95% 是本 skill 契约,user 没改你不能改
- "我自删 cron 不用通知 user 反正他不在乎" → NO。删 user 的 cron 是 high-risk action,必通知

## 预设(Presets) — 现成可挑的编排方案

落地长跑任务时,直接挑现成预设比从零编排省事。每个预设是 SKILL.md Required Workflow 的**具体实例化**:固定 cron 模式 + 默认参数 + 实战范例。在 Phase 0 跟 user 对齐时,先问"是否用预设"。

### #1 — `burn-tail`(5h budget 尾巴 burn)

**最适合**:长跑任务(几天到几周)+ 任务可切 ~18 min batch + 不能影响 user 日常额度。

**核心机制**: 动态一次性 cron 两件套 + watchdog:
- **main** @ `resetsAt - 20min`(burn 触发,仅工作窗内)
- **reschedule** @ `resetsAt + 1min`(查新 resetsAt + 排下一组,链心脏)
- **watchdog** @ daily 12:00 + 22:00(reboot 后自愈,完成检测点)

**默认参数**(均可改):
- 工作窗口:Mon-Fri 11:45-21:30(CST)
- budget 上限:util ≤ 95%
- burn 触发:`0 < remaining_min ≤ 20`
- 单 batch:≤ 18 min
- watchdog:每天 12:00 / 22:00,最坏 12h 自愈

**何时**不用**此预设**:
- 任务无法切成独立 batch(每 batch 必须 < 18 min 自包含)→ 改 `--prompt --session-mode new-per-run` 跑更长 single session
- 必须每 N 小时定时触发(无关 budget)→ 用普通 recurring cron
- 用户允许"任何时候打扰" → 用每 5 min poll(老式 polling 方案)

**完整实现**(schedule.py / burn.sh / reschedule.sh / 工作目录结构 / cron prompt 模板 / 实战参数 / reboot 容灾)见 [`references/preset-burn-tail.md`](references/preset-burn-tail.md)。

**实战**:`~/Documents/projects/skills/.experiment-state/darwin-huashu/`(本 skill 来源,2026-06-03 编排)。

### #2 — `window-burn`(指定时间窗整段 burn)

**最适合**:长跑任务(几天到几周)+ 任务可切 ~50 min batch + user 划定一段"随便烧"的时段(典型:夜间),窗内要**尽量用光额度**。与 #1 相反:#1 只 burn 尾巴、不碰白天额度;#2 在指定窗内**整段连烧到 cap**。

**核心机制**: 动态一次性 cron 自排程(由 `resetsAt` 算下次)+ watchdog:
- **burn** @ 窗内 util<cap → +~50min 续烧本窗;当前窗烧满 → `resetsAt+1min` 等下一窗;出窗 → 下个窗起点
- **每次唤醒先 `claude -p hi` 刷 token、再查 budget**(wake-then-query,见 preset-burn-tail robustness 第七条——idle 过期的 token 直接查必败)
- **watchdog** @ daily 12:00 + 22:00(reboot 自愈)

**默认参数**(均可改):
- 工作窗口:每日 21:30 → 次日 11:30(CST)夜间
- budget 上限:util ≤ 97%(尽量用光,留 3% 防 hard lockout)
- **线性预留**:5h 窗口结束**晚于**窗末(11:30)时,只用落在窗内的比例 = (11:30−窗口起点)/5h(例窗口 07:30→12:30 = 用 80%、留 20% 给白天)
- 单 batch:~50 min(收尾防下次唤醒重叠);窗内多批连烧
- watchdog:每天 12:00 / 22:00

**何时**不用**此预设**:
- 不能影响 user 白天额度(只能用反正要 reset 的尾巴)→ 用 #1 `burn-tail`
- 任务无法切成 ~50min 独立 batch → 改 `--prompt --session-mode new-per-run` 跑更长 single session
- 无 budget 概念的纯定时 → 普通 recurring cron

**完整实现**(budget-gate.py 线性预留 / schedule.py 自排程 / burn.sh wake-then-query / burn-prompt / 工作目录)见 [`references/preset-window-burn.md`](references/preset-window-burn.md)。robustness 规则与 #1 共用(见 preset-burn-tail.md 第 1–7 条)。

**实战**:`~/Documents/projects/.experiment-state/ty-vibe-kanban-build/`(本预设来源,2026-06-17 编排)。

## Boundaries(本 skill 不做的事)

- **不实现 cron 引擎本身**(dep:cc-connect cron / system crontab)
- **不实现 budget 检测 API**(dep:node-scripts/claude-usage 等;可配置)
- **不替你写主任务逻辑**(只编排定时机制;主任务靠你自己的 skill / 直接做工)
- **不做 cross-device / distributed** 任务(超出范围,需要专门调度器)
- **不做实时回调 / event-driven** 任务(那是 daemon 的活)

## Dependencies(本 skill 的前提)

- **cron 引擎**(任选其一):
  - `cc-connect cron add/list/del`(IM 会话场景首选;CC_PROJECT/CC_SESSION_KEY 已注入)
  - `crontab -e`(无 IM 会话场景;agent 必须能跑 shell)
- **Budget 检测命令**(可选,但强烈建议):
  - Claude 场景:`node ~/Documents/projects/node-scripts/dist/claude-usage/index.js --json`,解析 `fiveHour.utilization`
  - 其他 LLM:用对应 SDK 的 quota API,wrap 成 `--json` 输出
  - 都没有:用 wall-clock fallback("跑超 X 分钟就 skip"),但**报告里必须 flag** "无 budget 检测,降级用 wall-clock"
- **持久化磁盘**(写 STATUS.md / cron-log.txt)
- **可选**:git repo(状态文件 commit 留 trace)/ cc-connect send(通知 user)

## 示例触发(给 agent 看)

✅ "这个任务跨 4 小时,我中午有事,你挂上 cron 自己跑"
✅ "演化所有 skill,可能撞限额,配定时器,每次额度恢复继续"
✅ "scheduled run, halt if budget exceeds 90%, resume at next wake"
✅ "deadline 23:30 之前跑完,过点自停"

❌ "每天早上发 GitHub trending"(直接 `cc-connect cron add`,不需要 STATUS / budget gate)
❌ "5 分钟内做完这个 commit"(短任务,不需要 cron)
❌ "我在多设备上跑分布式 worker"(超出范围)

## 设计灵感

本 skill 抽自 darwin-skill 长跑实验(2026-06-03)实战:
- skill 中心库 16+ skill 演化,跨 6+ 小时 + 多个 5h budget 窗口
- cron `be758bdc` 每 :55 唤醒,2 次 5h budget 撞顶后 skip,1 次 smoke test 验证唤醒链路
- STATUS.md 是续作业的唯一 ground truth,跨 cron 唤醒不丢
- 任务完成后自删 cron 协议(避免僵尸唤醒)

参考:
- `references/preset-burn-tail.md` — **预设 #1 burn-tail** 完整实现(schedule.py / burn.sh / 工作目录 / 实战参数 + 第 1–7 条共用 robustness 规则)
- `references/preset-window-burn.md` — **预设 #2 window-burn** 完整实现(指定夜间窗整段 burn / 线性预留 / wake-then-query / resetsAt 自排程)
- `references/cron-prompt-template.md` — cron prompt 套话
- `references/status-md-template.md` — STATUS.md 结构 + 字段说明
- `references/halt-protocol.md` — 自删 + 通知协议
- `references/budget-gate.md` — budget 检测命令 / 阈值 / fallback
- `tests/cases.md` — 4 类行为测试用例
