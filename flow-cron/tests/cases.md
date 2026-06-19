# flow-cron — 行为测试用例

四类:正例触发 / 反例触发 / 主流程成功 / 护栏负例。每条标注预期行为、判定标准、可观察产物。

## 1. 正例触发(应当激活本 skill)

### T1.1 — 用户说"长跑任务,挂上 cron 自己跑"
**输入**:"我要演化 16 个 skill,可能跨 6 小时,你挂上 cron 跑,deadline 13:30 之前完事"
**预期**:
- agent 识别 → 触发本 skill
- 进 Phase 0 一次性问清:任务可拆?deadline(已给:13:30)?threshold?cron 频率?
- 进 Phase 1 写 STATUS.md
- 进 Phase 2 配 cron(`cc-connect cron add`)
- 进 Phase 3 跑 smoke test
- 进 Phase 4 启动第一批
**判定**:实跑后 `cc-connect cron list` 能看到新 cron job + `<workspace>/.experiment-state/<task>/STATUS.md` 存在 + smoke test 留下 `smoke_ok` 痕迹

### T1.2 — 英文触发词
**输入**:"This will take 4 hours and might hit the 5h limit, set up a scheduled wake-up with budget gating"
**预期**:同 T1.1,description 必须 match 英文触发

### T1.3 — 跨多个 5h budget 窗口
**输入**:"darwin 演化所有 skill,一个 5h 窗口跑不完,自己排时间"
**预期**:正确触发 + 在 Phase 0 提醒"5h 窗口约 ~3.5h 工作时间,deadline 给得开会跨多个窗口"

### T1.4 — 用户主动提到 cron 续作业
**输入**:"配定时器,每次额度恢复继续"
**预期**:触发 + 默认 threshold=95% / 频率=每整点 :55 / deadline 问 user

## 2. 反例触发(不应当激活本 skill)

### T2.1 — 一次性提醒
**输入**:"每天早上 6 点发我 GitHub trending"
**预期**:**不**触发本 skill;agent 应建议直接 `cc-connect cron add --prompt "Fetch GitHub trending and send"`,因为不需要 STATUS / budget gate / 续作业

### T2.2 — 短任务
**输入**:"修一下这个 bug,加 unit test"
**预期**:**不**触发,直接做(单次 context 能搞定)

### T2.3 — 实时回调
**输入**:"webhook 触发跑这段脚本"
**预期**:**不**触发(daemon 场景,不是 cron)

### T2.4 — 跨设备分布式
**输入**:"在 3 台 worker 上跑分布式训练"
**预期**:**不**触发(超出本 skill 范围,需专门调度器)

### T2.5 — 任务不能持久化中间状态
**输入**:"分析这次会话上下文,需要全程 context 在场"
**预期**:**不**触发(cron 唤醒后 context 不在,本 skill 没用);提示用户考虑别的方式

## 3. 主流程成功

### T3.1 — 端到端跑通(模拟 30 min 任务)
**输入**:简单 mock 任务"每 2 分钟 wake,每次 echo 一行到 log,5 次后自停"
**步骤**:
1. Phase 0 问 4 项(可选用默认)
2. Phase 1 写 STATUS.md(任务结构 5 行,每行 1 阶段)
3. Phase 2 `cc-connect cron add --cron "*/2 * * * *" --prompt <prompt-file>`
4. Phase 3 smoke test(1 分钟内验证 cron 唤醒)
5. Phase 4 first batch(echo 第一行)
6. 等 8 分钟,验证 cron 触发 4 次,每次 echo 一行
7. 第 5 次触发 → 任务全 ✅ → 走 halt 协议 → 自删 cron + 通知

**判定**:
- `<workspace>/.experiment-state/<task>/cron-log.txt` 有 5 行 echo
- `cc-connect cron list` 不再看到该任务的 cron
- IM 通道收到 "<task-id> 任务全完" 消息

### T3.2 — Budget 卡顶 skip 一次后继续
**输入**:T3.1 同时 stub 让 budget 第 2 次唤醒返回 96%
**预期**:
- 第 2 次唤醒判停 step 3 → skip + 回复 `skipped`
- cron-log.txt 第 2 行记 `skipped` 不是 `executed`
- 第 3 次唤醒(budget 恢复)正常做事
- STATUS.md "连续 skip 计数" 应 0 → 1 → 0(skip 后归零)

### T3.3 — Deadline 强停
**输入**:T3.1 但 deadline 设为 cron 第 3 次唤醒前
**预期**:
- 第 3 次唤醒 step 3 检测到时间 ≥ deadline → 走 halt
- 通知里说"deadline 强停,完成 2/5 阶段"
- cron 自删

## 4. 护栏 / 负例

### T4.1 — 不跑 smoke test 应被阻止
**操作**:agent 跳过 Phase 3 直接 Phase 4
**预期**:本 skill SKILL.md Red Flags 明确禁止;最终报告 Step 9 必须有 "Phase 3 跑过" 字段;跳过 → 报告不完整 → 不算 done

### T4.2 — cron prompt 含 `~/` 不绝对路径
**操作**:agent 写 cron prompt 时用 `~/.experiment-state/...`
**预期**:被 Red Flags 拦下(grep `\\b~/` 命中);改为绝对路径 `/Users/.../experiment-state/...`

### T4.3 — STATUS.md 缺 deadline 字段
**操作**:agent 写 STATUS.md 忘了 deadline
**预期**:Phase 1 输出后,Pre-action self-check 必须 grep `deadline` STATUS.md;缺则回 Phase 1 补

### T4.4 — Budget 命令失败当 0%
**操作**:mock budget 命令 exit 1 / 无 stdout
**预期**:cron prompt 内 failure mode 触发 → 当 100% → skip;**不能**继续做事

### T4.5 — 任务全完忘自删 cron
**操作**:Halt 协议 step 3 跳过
**预期**:halt-protocol.md 明确"先通知再删 cron"+ verify;跳过 → cron-log.txt 后续仍有唤醒记录 → user 抱怨"你说完事了怎么还在 ping"

### T4.6 — Budget jam ping 多次重复(spam)
**操作**:连续 K=5 轮 skip 后已 ping;接下来又连续 5 轮 skip
**预期**:同一 jam 期只 ping 一次;**不**再次 ping;直到自然脱离(skip 计数器归零)后下次又达 K 才允许重 ping

### T4.7 — 同 STATUS 配 2 个 cron
**操作**:agent 误以为"加冗余 cron 保险点",配第 2 个 cron prompt 指向同一 STATUS
**预期**:Red Flags 明确禁止"同一任务配 ≥ 2 个 cron";agent 拒绝执行 + 警告 user

### T4.8 — 续作业改 user 手改字段
**操作**:user 在 STATUS.md 加 `# user comment: 注意这里` 注释;cron 唤醒 update 时把 comment 删了
**预期**:Update STATUS 规范:atomic write 必须保留 user 注释 / 不在已知 schema 字段范围内的内容;实测一次

## 5. 预设 #3 window-starter

### T5.1 — 正例:撞开 5h 窗口路由到 #3
**操作**:user 说"每天早上提前把 5h 窗口撞开 / 给 claude 和 codex 各配个唤醒定时"
**预期**:触发 flow-cron,选 **预设 #3 window-starter**(不是 #1/#2 burn,也不当成 ❌ 纯定时);产出 claude `--strict-mcp-config --settings <空hooks>` + codex `--ignore-user-config --ephemeral` 两条 cron

### T5.2 — 护栏:claude 禁用 `--bare`
**操作**:agent 想"`--bare` 跳过最多东西最省,用它"
**预期**:preset #3 核心约束拦截——`--bare` 跳 OAuth/keychain、强制 API key,对订阅用户 "Not logged in";撞窗口必须保 OAuth → 拒用 `--bare`,改 `--strict-mcp-config + --settings 空hooks`

### T5.3 — 护栏:codex skill 残留不硬剥
**操作**:agent 见 codex 仍加载 hat skill,想换 `CODEX_HOME` 指空目录硬剥
**预期**:preset #3 说明 `auth.json` 在 CODEX_HOME,换了破坏 auth;无按次禁 skill 的 flag(`--ignore-rules` 跳 rules 非 skill,实测更贵)→ 接受残留,不动认证

## 测试执行方法

行为测试 skill 不可用时,手工跑:
1. 真起 STATUS.md + cron(用 `cc-connect cron add --cron "*/1 * * * *"` 高频触发便于观察)
2. 等 5-10 分钟看 cron-log.txt + STATUS.md + cron list 变化
3. 检查产物 vs 预期
4. 测完跑 `cc-connect cron del <id>` 清理

集成测试场景(本 skill 是 orchestrator,必跑):
- 真起一个 demo 长跑任务(如"echo 10 行,每 1 min 一行"),走全流程到自动 halt
- 验证 IM 通道 user 端真收到通知
- 验证 budget 跳 sequence 真生效
