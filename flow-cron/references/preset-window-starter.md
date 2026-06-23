# 预设 #3 — window-starter(5h 窗口提前撞开,极低成本)

> 跟 #1/#2 **方向相反**:#1 `burn-tail`、#2 `window-burn` 是**烧**额度的长跑任务;
> #3 `window-starter` 是**撞开**——每天固定时间发一句最便宜的 "hi",让 5h 滚动窗口
> 在你开工前就已经开启,这样你真正坐下来干活时窗口已经在走、不必现等。
>
> 它不是长跑任务,没有 STATUS.md / budget-gate / 自排程那套机械。本质是一条
> **普通 recurring cron**,但 prompt/命令经过逐项裁剪,把 token 成本压到最低。

## 适用场景

- 固定作息:每天某时段开始用 Claude / Codex,想让 5h 窗口卡着作息起点开
- 多个 agent(Claude 订阅 + Codex 订阅)各自有独立 5h 窗口,都要提前撞开
- 只要"开窗",不要它干活——所以越便宜越好,别加载 MCP / skill / hook

## 不适用(别用本预设)

- 要在窗内**用光额度**做长跑任务 → 用 #2 `window-burn`
- 只捡每个窗口尾巴 burn、不碰白天 → 用 #1 `burn-tail`
- 要它真做事(总结 / 巡检)→ 那是普通 `cc-connect cron add --prompt`,不是 window-starter

## 核心约束(最关键,别踩)

**撞窗口必须用订阅的 OAuth 会话**——开的是订阅那条 5h 窗口。任何让 CLI 改走
API key 计费的 flag 都会**偏离目标**(开错窗口 / 走计费),即使它"更省"也不能用。

- **Claude `--bare` 禁用**:官方 headless 文档明确
  *"Bare mode skips OAuth and keychain reads. Anthropic authentication must come
  from `ANTHROPIC_API_KEY` or an `apiKeyHelper`."* —— `--bare` 虽然能跳过
  hooks/skills/plugins/MCP/memory/CLAUDE.md 全部,但它**不读 OAuth/keychain**,
  对订阅用户会直接 "Not logged in"。所以 window-starter **不能用 `--bare`**,
  只能用"保 OAuth 的逐项裁剪"。
- **Codex `--ignore-user-config` 安全**:官方 reference 明确
  *"Do not load `$CODEX_HOME/config.toml`. Authentication still uses CODEX_HOME."*
  —— 跳过 config.toml(MCP server 都在里面)但 auth 仍走 CODEX_HOME,撞窗口不受影响。

## 落地命令(已实测,2026-06-19)

### Claude

```bash
sleep $(( (RANDOM % 40 + 1) * 60 )); \
/Users/falcom/.local/bin/claude -p "hi" \
  --permission-mode bypassPermissions \
  --strict-mcp-config \
  --settings /Users/falcom/.cc-connect/claude-minimal-settings.json \
  > /dev/null 2>&1
```

- `--strict-mcp-config` → 只用 `--mcp-config` 提供的 server;一个都不给 = **不加载任何 MCP**。
- `--settings <空 hooks 文件>` → 该文件内容 `{"hooks":{}}`,把 SessionStart hook 覆盖为空,
  **干掉 superpowers 注入**(token 大头)。落成文件而非内联 JSON,避免 cron exec 里引号转义。
- **保 OAuth**(没用 `--bare`)→ 订阅窗口正常开。
- 残留:CLAUDE.md + MEMORY.md(很小)。想再剥只能 `--bare`,但那破坏 OAuth → 不剥。
- 绝对路径 `/Users/falcom/.local/bin/claude`(cron 的 PATH 不含它,裸 `claude` 会 127 退出)。

空 hooks settings 文件(一次性建好):

```bash
echo '{"hooks":{}}' > /Users/falcom/.cc-connect/claude-minimal-settings.json
```

### Codex

```bash
sleep $(( (RANDOM % 40 + 1) * 60 )); \
/opt/homebrew/bin/codex exec \
  --ignore-user-config \
  --ephemeral \
  --skip-git-repo-check \
  --sandbox read-only \
  --cd /tmp \
  "hi" < /dev/null > /dev/null 2>&1
```

- `--ignore-user-config` → 不读 config.toml = **不加载 MCP**(context7/playwright/brave/
  chrome-devtools/fetch 等);auth 仍走 CODEX_HOME。token 38.5K → 25.4K。
- `--ephemeral` → 不落 session rollout 文件,每日 cron 不在 `~/.codex/sessions` 堆垃圾。
- `--skip-git-repo-check` + `--cd /tmp` → 避免 "Not inside a trusted directory" 报错。
- `< /dev/null` → 防 codex 卡在 "Reading additional input from stdin"。
- **残留 hat/superpowers skill** 砍不掉:它来自 `~/.codex/skills/`(CODEX_HOME 默认 skill 目录),
  官方**无按次禁用 skill 发现的 flag**;`--ignore-rules` 跳的是 rules/AGENTS.md 不是 skill,
  实测加了反而更贵。要彻底剥只能换 `CODEX_HOME` 指向空目录,但 `auth.json` 也在 CODEX_HOME,
  换了得拷贝凭证、极脆 → 为这点零头不值得,接受残留。

## cron 配置(cc-connect 场景)

```bash
cc-connect cron add --cron "50 5 * * 1-5" --timeout-mins 50 \
  --desc "claude-5h-window-starter (random 5:51-6:30)" \
  --exec '<上面 Claude 命令单行>'

cc-connect cron add --cron "50 5 * * 1-5" --timeout-mins 50 \
  --desc "codex-5h-window-starter (random 5:51-6:30)" \
  --exec '<上面 Codex 命令单行>'
```

- **`--timeout-mins 50` 必带,别吃默认**:cc-connect cron 不带 `--timeout-mins` 时默认
  **30 分钟**超时,而 exec 里 `sleep` 上限是 **40 分钟**(`RANDOM%40+1`)。随机值落在
  31–40 分钟时,job 会在 sleep 还没睡完就被 30 分钟超时**杀掉**,`claude/codex "hi"`
  **根本没执行到** → 窗口没撞开,只在 `last_error` 留一句 `job timed out after 30m0s`
  (**静默失败、间歇必现**,约 1/4 概率)。`--timeout-mins 50` = sleep 上限 40min +
  冷启动余量 → 彻底盖住。详见下方「Robustness」。
- schedule `50 5 * * 1-5`:工作日 05:50 触发,叠加 `sleep $(( (RANDOM%40+1)*60 ))`
  → 实际 05:51–06:30 随机落点(错峰、避免每天同一秒撞 API)。
- 两个 agent 各一条 cron,**1 任务 1 cron**(别合并,各自独立窗口)。
- 改已存在的 job 用 `cc-connect cron edit <id> <field> <value>`(如
  `cc-connect cron edit <id> timeout_mins 50`);`cron info <id> [field]` 可单独查
  `last_run` / `last_error` / `timeout_mins`,诊断是否撞了超时。

## Robustness — sleep 上限必须 < job 超时(硬不变式)

**不变式**:`exec` 里 `sleep` 的**上限**必须 **< 该 cron job 的超时**(`--timeout-mins`,
不设则默认 **30min**)。睡过超时的那部分,job 必被杀,后面的命令执行不到。

- 本预设 sleep 上限 = `RANDOM%40+1` = **40min** → `--timeout-mins` 必须 **≥ 40 + 冷启动余量**,取 **50**。
- 反向也可:不抬超时,就把 sleep 上限收敛到远小于超时(如 `RANDOM%20+1` = 20min 配默认 30min)。
  但那会压缩错峰窗口(→ 05:51–06:10),错峰变弱 —— 故本预设选"抬超时"而非"压 sleep"。
- 症状签名:`cc-connect cron info <id>` 看到 `last_error: "job timed out after 30m0s"`
  且 `last_run` ≈ 启动时刻 + 超时分钟数 → 就是踩了这个坑,**不是命令本身错**。
- 通用教训:**任何 exec 带长 sleep / 长阻塞的 cron,建命令时就把 `--timeout-mins` 设到
  覆盖最坏阻塞 + 余量**,别依赖默认 30min。

## 设计要点回顾(为什么这么裁)

| | 裁掉了什么 | 用的 flag | 保住了什么 |
|---|---|---|---|
| Claude | MCP + SessionStart hook(superpowers) | `--strict-mcp-config` + `--settings 空hooks` | **OAuth 订阅登录**(没用 `--bare`) |
| Codex | config.toml(MCP servers) + session 文件 | `--ignore-user-config` + `--ephemeral` | **auth**(CODEX_HOME 仍读) |

两者都落到"官方文档支持 + 保住订阅登录"的最优点:大头(claude superpowers、codex MCP)
已砍;零头(CLAUDE.md / hat skill)受"必须保 OAuth/auth"硬线限制,再压得动认证机制,
得不偿失。

## Sources

- Claude Code — Run programmatically(headless / `--bare` 认证要求):
  https://code.claude.com/docs/en/headless
- Codex CLI — Command line options(`--ignore-user-config` / `--ephemeral` 语义):
  https://developers.openai.com/codex/cli/reference

## 实战

`~/.cc-connect/crons/jobs.json` — claude `b3d1f56d` / codex `718383d8`(2026-06-19 落地 + 官方文档核对;
2026-06-23 修复:两个实例 `timeout_mins` 从默认 30 → 50,堵住 `sleep>30min` 必超时漏洞,起因是某早 starter 静默未撞开窗口)。
