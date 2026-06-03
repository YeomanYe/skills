# Budget Gate — 预算检测与阈值

## 设计原则

1. **必须实时检测**,不靠"我觉得还有"
2. **命令失败时按 100% 处理**(最保守),不能按 0% 也不能跳过检测
3. **threshold 由 user 决定**,本 skill default 95%,**不替 user 改**
4. **每次唤醒必跑**,不能"上次跑过没多久应该差不多"

## Claude 5h budget 检测(主要场景)

```bash
node ~/Documents/projects/node-scripts/dist/claude-usage/index.js --json
```

输出 JSON 结构:
```json
{
  "fiveHour": {
    "utilization": 87,
    "remaining_minutes": 38,
    "resets_at": "2026-06-03T10:50:00Z"
  },
  "weekly": { ... }
}
```

**解析方法**:
```bash
# 用 jq
util=$(node <path>/claude-usage/index.js --json | jq -r '.fiveHour.utilization')

# 或 python3
util=$(node <path>/claude-usage/index.js --json | python3 -c "import json,sys;print(json.load(sys.stdin)['fiveHour']['utilization'])")
```

**判停**:
```bash
if [ -z "$util" ] || ! [[ "$util" =~ ^[0-9]+$ ]]; then
  echo "budget cmd failed → treat as 100, skip" >&2
  exit_skip
fi
if [ "$util" -gt "$THRESHOLD" ]; then
  echo "budget $util% > threshold $THRESHOLD% → skip"
  exit_skip
fi
```

## 其他 LLM 场景

| LLM | 检测命令 | 解析路径 |
|---|---|---|
| OpenAI API | 自己写一段 `openai usage --json`(需 OPENAI_API_KEY) | `.usage.daily.dollars` / configured budget |
| Anthropic API quota | 公开 API 没 quota endpoint,用 cost tracker(如 `claude-cost --json`) | 自定义 |
| Gemini | `gcloud ai-platform quota --json` | `.usage.percent` |
| Codex CLI | 没有 quota,fallback wall-clock | N/A |

**通用包装规则**:命令必须输出**单一数字**或**含 `utilization` 字段的 JSON**。
不要让 cron 唤醒去解析多家不同输出,**Phase 0 锁定一个**,后续不变。

## Fallback:无 budget API → wall-clock 限速

若用户场景**真的没有** budget 检测命令(自托管 LLM / 离线模型),退化为:
```bash
WALL_START=$(stat -c %Y .agent/wall-start 2>/dev/null || date +%s)
NOW=$(date +%s)
ELAPSED=$(( (NOW - WALL_START) / 60 ))  # 分钟

if [ "$ELAPSED" -gt "$WALL_THRESHOLD" ]; then
  exit_skip
fi
```

**报告里必须 flag**:"无 budget 检测,降级用 wall-clock,可能不准"

## 阈值推荐

| 场景 | threshold | 理由 |
|---|---|---|
| 长期跑(数天)| 80% | 留余量给紧急任务 |
| 通宵跑(<12h)| 90% | 平衡 throughput 和余量 |
| 抢额度跑(deadline 紧)| 95%(default) | 最大化使用,但留 5% 缓冲防 hard limit |
| 用户明确 "burn 到底" | 99% | 极限模式,可能触发 hard lockout 风险 |
| **绝对不要** | 100% | 撞 hard limit 会触发 cooldown lockout,后续 5h 完全无法跑 |

## Skip 行为细节

判停命中 budget 超线时:
1. **不动手做任何事**(不写 STATUS / 不跑 agent / 不发通知)
2. **回复 `skipped`**(单一字符串,让 cron log 易识别)
3. **更新 STATUS.md 的"连续 skip 计数"+= 1**(轻量更新,这一步算例外,因为不更新计数器就没法触发 budget-jam ping)
4. **不**发 cc-connect message(skip 是日常,不打扰 user)

## 连续 skip 累计的处理(避免静默死锁)

参考 `halt-protocol.md` 的 `budget-jam-ping-only` reason:
- 连续 ≥ K(default 5)轮 skip → 发一次 ping
- 自然脱离 jam(下轮 budget < threshold,正常做事)→ skip 计数器清零
- user 回复 ack → 计数器清零 + 写 ack 字段

## 反例

❌ **命令失败当 0%**:budget 没了但命令失败,继续跑 → 撞 hard limit
  → 正确:失败必须当 100% / 至少跳过本轮

❌ **取上次的 cached 值**:"5 min 前查过 80% 应该差不多"
  → 正确:每次唤醒必查实时,绝不 cache

❌ **threshold 写死在 prompt**:user 想改要改 prompt 文本
  → 正确:threshold 字段在 STATUS.md,prompt 引用 STATUS

❌ **判停时四舍五入**:`if [ "$util" -ge 95 ]`(95.0 算超线但 94.5 不算)→ 边缘 race
  → 正确:整数比较,jq 输出已经 round,不再二次 round

❌ **threshold 默认设 100%**:跑到撞死才停
  → 正确:default 95% 留 5% 缓冲;user 可放宽到 99% 但必须显式说
