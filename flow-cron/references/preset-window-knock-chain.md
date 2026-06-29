# 预设 #4 — window-knock-chain(动态自排程敲窗链)

> #3 `window-starter` 的**动态变体**。#3 是**固定时钟**(如 `50 5 * * *`)每天敲一次,不跟踪真实滚动 `resetsAt`;
> #4 是**单个自编辑 cron**:每次在 5h 窗口重置后敲开新窗口,再读真实 `resetsAt` 把**自己**重排到下一次重置,
> 无限循环——**精确跟随真实滚动窗口、每个重置都敲、自适应漂移**。
>
> 和 #3 一样:它不是长跑任务,没有 STATUS.md / budget-gate,只用一句最便宜的 "hi" **撞开窗口**。

## 适用场景

- 想让 5h 滚动窗口在**每个重置点之后立刻被敲开**,而不是每天固定时刻敲一次。
- 真实 `resetsAt` 会随使用漂移(不锚定整点),要定时器**自动跟随**,不想手工对齐时钟。
- 单 agent(Claude)的窗口保活;Codex 同理另起一条(各自独立窗口,别合并)。

## #4 vs #3 怎么选

| | #4 window-knock-chain | #3 window-starter |
|---|---|---|
| 触发时机 | **每个真实 `resetsAt + 1min`**(动态自排程) | 固定时钟(如每天 05:50) |
| 跟随滚动窗口 | ✅ 每次读真实 resetsAt 重排 | ❌ 时钟固定,窗口漂了就错位 |
| 敲的频率 | 每个 5h 重置都敲(一天约 5 次) | 每天 N 次固定点 |
| 复杂度 | 略高(自编辑 cron + 解析 resetsAt) | 低(一条普通 recurring cron) |
| 选它 | 要精确跟随、每个重置都敲 | 只要每天固定点敲一次、够用且简单 |

## 何时**不用**此预设

- 要在窗内**用光额度**做长跑 → #2 `window-burn`;只捡窗口尾巴 burn → #1 `burn-tail`。
- 只要"每天固定点敲一次" → #3 `window-starter`(更简单)。
- 无 budget / resetsAt 概念的纯定时(总结 / 巡检)→ 普通 `cc-connect cron add --prompt`。

## 核心约束:保 OAuth(与 #3 共用)

撞窗口**必须用订阅的 OAuth 会话**,不能让 CLI 改走 API key 计费。Claude 用
`--permission-mode bypassPermissions --strict-mcp-config --settings <空 hooks 文件>`,
**绝不用 `--bare`**(`--bare` 跳过 OAuth/keychain → 订阅用户 "Not logged in")。
完整 flag 裁剪依据见同目录 `preset-window-starter.md` 的「核心约束」段,这里不重抄。

## 核心机制

**一个自编辑 cron**(desc 固定,如 `claude-window-knock-chain`),exec 跑下面的脚本。每次唤醒三步:

1. **敲开窗口**:`claude -p "hi"`(上面的保 OAuth flag),不带 sleep(要正好在重置后敲)。
2. **查真实 resetsAt**:跑 budget 命令读 `fiveHour.resetsAt`。
3. **自排程**:算 `resetsAt + 1min` 的 cron 字段(**本地时区**),按 desc 找到自己的 cron id,
   `cc-connect cron edit <id> cron_expr "<M H D Mon *>"` 把**自己**重排到下次重置。

**健壮性**:
- 敲失败(claude 非 0)仍继续查 + 重排——链不断。
- budget 查不到 → **fallback** `now + 5h + 1min`,链不断。
- 全程只动**这一个** cron(自编辑,不滋生新任务)。
- cron_expr 用**本地时区**(cc-connect cron 按系统本地时间解释,与 #1/#2/#3 一致)。
- **绝对路径**:cron 的 PATH 极简,脚本里 `export PATH` 含 node / claude / cc-connect 所在目录,python 用 `/usr/bin/python3`。
- `resetsAt` 是带时区的 ISO(`...+00:00`),用 `datetime.fromisoformat(...).astimezone()` 转本地再 +1min。

## 脚本(实测可用,2026-06-28)

落到稳定路径,如 `~/.cc-connect/scripts/claude-window-knock.sh`(占位用绝对路径,按本机实际替换):

```bash
#!/usr/bin/env bash
# claude-window-knock-chain —— 5h 重置后敲开新窗口,再把自己(同名 cron)重排到下一个 resetsAt+1min。
set -uo pipefail
# cron PATH 极简:补 node(nvs)/ claude / cc-connect 所在目录(按本机实际路径改)
export PATH="$HOME/.nvs/node/<ver>/<arch>/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

DESC="claude-window-knock-chain"
LOG="$HOME/.cc-connect/scripts/claude-window-knock.log"
USAGE="$HOME/Documents/projects/node-scripts/dist/claude-usage/index.js"   # budget 命令(--json,含 fiveHour.resetsAt)
SETTINGS="$HOME/.cc-connect/claude-minimal-settings.json"                  # 内容 {"hooks":{}}
PY=/usr/bin/python3
ts(){ date "+%Y-%m-%d %H:%M:%S"; }

# 1) 敲开窗口:最便宜的 hi,保 OAuth(--strict-mcp-config + 空 hooks settings;绝不用 --bare)
claude -p "hi" --permission-mode bypassPermissions --strict-mcp-config --settings "$SETTINGS" >/dev/null 2>&1
knock_rc=$?

# 2) 查下个窗口 resetsAt → 算下次 fire(resetsAt + 1min)的 cron 字段(本地时区)
NEXT=$(node "$USAGE" --json 2>/dev/null | "$PY" -c "
import json,sys,datetime
try:
    d=json.load(sys.stdin)['fiveHour']['resetsAt']
    dt=datetime.datetime.fromisoformat(d).astimezone()+datetime.timedelta(minutes=1)
    print(f'{dt.minute} {dt.hour} {dt.day} {dt.month} *')
except Exception:
    pass
")

# 3) fallback:查不到额度 → now+5h+1min,保证链不断
if [ -z "${NEXT:-}" ]; then
  NEXT=$("$PY" -c "import datetime; dt=datetime.datetime.now().astimezone()+datetime.timedelta(hours=5,minutes=1); print(f'{dt.minute} {dt.hour} {dt.day} {dt.month} *')")
  echo "$(ts) knock_rc=$knock_rc budget-query-failed → fallback next='$NEXT'" >> "$LOG"
else
  echo "$(ts) knock_rc=$knock_rc next='$NEXT'" >> "$LOG"
fi

# 4) 自排程:按 desc 找自己的 cron id,把 cron_expr 改到下次 fire
ID=$(cc-connect cron list 2>/dev/null | grep -F "$DESC" | awk '{print $2}' | head -1)
if [ -n "${ID:-}" ] && [ -n "${NEXT:-}" ]; then
  cc-connect cron edit "$ID" cron_expr "$NEXT" >/dev/null 2>&1 \
    && echo "$(ts) rescheduled id=$ID → '$NEXT'" >> "$LOG" \
    || echo "$(ts) WARN edit failed id=$ID next='$NEXT'" >> "$LOG"
else
  echo "$(ts) WARN cannot self-reschedule (id='${ID:-}' next='${NEXT:-}')" >> "$LOG"
fi
```

空 hooks settings 文件(一次性建好,与 #3 共用):

```bash
echo '{"hooks":{}}' > ~/.cc-connect/claude-minimal-settings.json
```

## 落地(cc-connect 场景)

```bash
# 1) 先查当前窗口 resetsAt,把初始 cron 排到"下个重置 + 1min"(下面演示用 python 现算)
INIT=$(node ~/Documents/projects/node-scripts/dist/claude-usage/index.js --json \
  | /usr/bin/python3 -c "import json,sys,datetime;d=json.load(sys.stdin)['fiveHour']['resetsAt'];dt=datetime.datetime.fromisoformat(d).astimezone()+datetime.timedelta(minutes=1);print(f'{dt.minute} {dt.hour} {dt.day} {dt.month} *')")

# 2) 建自编辑 cron(desc 必须与脚本里的 DESC 一致,自排程靠它找自己)
cc-connect cron add --cron "$INIT" \
  --exec "bash $HOME/.cc-connect/scripts/claude-window-knock.sh" \
  --desc "claude-window-knock-chain" \
  --timeout-mins 10

# 3) 自检:手动跑一次脚本,看 log + cron_expr 是否被自排程改写成下个 resetsAt+1min
bash $HOME/.cc-connect/scripts/claude-window-knock.sh
cc-connect cron info <id> cron_expr     # 应 = 下个 resetsAt+1min
```

> **手动自检的妙处**:若当前窗口已开(util>0),手动跑时的 "hi" 是**窗口内空敲**(不重锚 resetsAt),
> 于是脚本读到的还是当前 resetsAt、把 cron 重排到它+1min——正好把链 bootstrap 到正确的下个重置点,
> 同时一次性验证了「敲 + 查 + 自排程」全链路。

## 实战

`~/.cc-connect/scripts/claude-window-knock.sh` + cron desc `claude-window-knock-chain`(2026-06-28 实测:knock_rc=0、自排程把 cron_expr 改到 `resetsAt+1min` 成功)。
