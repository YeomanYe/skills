# Cron Prompt 模板

## 用途

cron 唤醒后没有对话上下文,prompt 必须**自包含**所有续作业指令。本模板是 cron prompt 的标准结构,Phase 2 配 cron 时直接用。

## 模板(填充 `<...>` 占位即可)

```text
[<task-id>-cron] 续作业。

第一步:Read <STATUS.md 绝对路径,如 /Users/xx/proj/.experiment-state/<task>/STATUS.md> 看当前 skill / round / pointer。

第二步:跑 budget 检测命令 → 取 utilization:
  <budget command 绝对路径>
  e.g. cd ~/Documents/projects/node-scripts && node dist/claude-usage/index.js --json
  解析: jq .fiveHour.utilization 或 python3 -c "import json,sys;print(json.load(sys.stdin)['fiveHour']['utilization'])"
  若命令失败或无 stdout → **当作 100% 跳过本轮**(不能猜)

第三步:判停 ——
  - 当前时间 ≥ <deadline ISO-8601> → 自删 cron + cc-connect 通知 user 终止 + halt
  - 5h utilization > <budget threshold,默认 95>% → skip 本轮回复 'skipped' 不动手
  - STATUS.md 显示所有阶段 ✅ → 自删 cron + 通知 + halt
  - 否则进 step 4

第四步:做事 30-40 min 工作量 ——
  - 跑当前 pointer 的"下一步动作"(STATUS 里有写)
  - 完成后更新 STATUS pointer(✅ 当前阶段 / 推进到下个阶段)
  - 若 workspace 是 git:`git add . && git commit -m "<task-id>: <step> done"`
  - 不超出当前阶段做无关事

第五步:halt(让 cron 下次再来,不要循环)

环境变量已设(cc-connect 场景):CC_PROJECT / CC_SESSION_KEY → 通知 user 用
  cc-connect send --message "<内容>"

failure mode:
  - budget 命令报错 → 当 100% 跳过(不是 0%)
  - STATUS.md 不存在 / 字段缺失 → 自删 cron + 通知 user 排查 + halt
  - cron 自删命令失败 → 在通知里告诉 user 手动 cc-connect cron del <id>
```

## 必含元素 checklist

| 元素 | 必须有? | 失败后果 |
|---|---|---|
| STATUS.md 绝对路径 | ✓ | cron 上下文 `~/` 可能不展开,读不到 STATUS |
| budget 检测命令绝对路径 | ✓ | cron PATH 通常很窄,相对路径会失败 |
| budget 解析方法 | ✓ | 命令出 JSON,不写解析就不知道怎么取数字 |
| deadline ISO 时间 | ✓ | 跑过头无人停 |
| budget threshold 数字 | ✓ | 不写就没法判 |
| skip 关键词("skipped") | ✓ | user 看 cron log 能识别"这轮被 budget 拦了" |
| 自删 cron 命令 | ✓ | 任务完成 / deadline 到必须真删 |
| 通知 user 的命令 | ✓ | cc-connect send 或等价 |
| failure mode(budget 命令失败时的行为)| ✓ | 不写 = 猜,猜错就 burn 额度 |
| halt 协议 | ✓ | 不 halt 会循环跑撞死 |

## 反例(不能这么写)

❌ "续作业,看 STATUS.md 接着干"
  → 缺路径 / 判停规则 / failure mode,等于没说

❌ "Read ~/.../STATUS.md → check budget → keep going"
  → `~/` 在 cron 不一定展开;"keep going" 太模糊;没说 budget 阈值

❌ "如果额度够就继续"
  → 不写阈值 / 不写如何检测 / 不写命令失败怎么办 = 全靠运气

## 同 Smoke Test prompt 区别

Phase 3 smoke test 的 cron prompt **不是**本模板,而是临时的 1-3 行:
```text
[smoke] 把 <STATUS.md path> 里 sentinel: smoke_pending 改成 sentinel: smoke_ok
```

Smoke 通过后**立即**用本模板替换 cron prompt。
