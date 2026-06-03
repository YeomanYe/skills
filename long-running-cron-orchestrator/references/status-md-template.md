# STATUS.md 模板

## 路径约定

`<workspace>/.experiment-state/<task-id>/STATUS.md`

- `<workspace>`:当前 cwd 或 user 指定的项目根
- `<task-id>`:任务唯一名(kebab-case,如 `darwin-skill-evolve` / `monthly-backup-run`)

## 完整模板(复制 + 替换 `<...>`)

```md
# <task-id> — STATUS

> Cron 唤醒后**第一件事:Read 本文件 → 决定续作业从哪开始**

## 全局约束
- **截止时间**: <ISO-8601,如 2026-06-03T13:30+0800>(超过 → 自停 + 删 cron + 通知 user)
- **Budget 阈值**: 5h utilization > <X,默认 95>% → skip 本轮
- **预算检测命令**: <绝对路径 + 解析方法>
  e.g. `cd ~/Documents/projects/node-scripts && node dist/claude-usage/index.js --json | jq .fiveHour.utilization`
- **工作目录**: <abs path>
- **任务分支**(若 git): <branch-name>
- **cron job ID**: <id-from-cron-add-output>  ← 自删时用
- **cron 频率**: <如 55 * * * *>

## 任务结构(全部步骤)
| # | 阶段 | 状态 | 产物 / 验收 | 备注 |
|---|---|---|---|---|
| 1 | <step name> | ⏳ pending | <file path / commit hash / 测试通过> | |
| 2 | <step name> | pending | | |
| 3 | <step name> | pending | | |

状态枚举:`pending` / `in_progress` / `✅ done` / `❌ failed` / `⏭ skipped`

## 当前 pointer
- 当前阶段: <N>
- 当前 round / batch(若有): <round>
- 下一步动作(cron 唤醒后跑的命令 / 派工指令): <具体命令 / 文件路径 / agent prompt>
- 已工作时长: <累积 wall-clock>
- 上次更新: <ISO ts>
- 连续 skip 计数: <K>(达到 <连续 skip 阈值,默认 5> 时 ping user)

## Cron 唤醒协议(已写进 cron prompt,这里复述备审)
1. Read 本 STATUS.md → 看当前 pointer
2. 跑 budget 检测命令 → 取 utilization(命令失败 → 当 100%)
3. 判停:
   - 时间 ≥ deadline → 自删 cron + 通知 + halt
   - budget > threshold → skip 本轮回复 'skipped'
   - 所有阶段 ✅ → 自删 cron + 通知 + halt
   - 否则进 step 4
4. 做事 30-40 min:跑"下一步动作",done 后更新 pointer
5. 写状态 → halt

## Halt 协议
- 所有阶段都 ✅ → 自删 cron + cc-connect 通知 "任务全完"
- 时间 ≥ deadline → 自删 cron + 通知 "deadline 强停,完成 N/M 阶段"
- 连续 ≥ <连续 skip 阈值> 轮 skip → ping user "budget 长期卡顶,要不要调 threshold"(**不**自停)
- STATUS.md 检测异常 → 自删 cron + ping user 排查

## 反例黑名单(自我护栏)
- ❌ 不读 STATUS 直接动手("我大概记得做到哪了")
- ❌ budget 命令报错就当 0%(应当当 100% 跳过)
- ❌ 跑超 40 min 不写状态(下次 pointer 不对)
- ❌ user 没说就改 threshold / deadline / 频率
- ❌ 同时启动 ≥ 2 个 cron 改同 STATUS.md(并发写文件冲突)
- ❌ 任务全完不自删 cron(僵尸唤醒污染额度)

## 历史日志(可选,append-only)
- <ISO ts> phase=<N> action=<wake|skip|halt|complete|error> note=<one-liner>
```

## 字段必含 / 选填表

| 字段 | 必含? | 缺失后果 |
|---|---|---|
| `截止时间` | ✓ | 跑过头无人停 |
| `Budget 阈值` | ✓ | 撞 hard limit |
| `预算检测命令` | ✓ | 判停没法执行 |
| `工作目录` | ✓ | cron 上下文 cwd 不对会动错文件 |
| `cron job ID` | ✓ | 自删时找不到 cron |
| `cron 频率` | ✓ | 审查时无法判断"多久来一次" |
| `任务结构表` | ✓ | 续作业不知道做哪一步 |
| `当前 pointer` | ✓ | 续作业不知道做哪一步 |
| `连续 skip 计数` | ✓ | 不写 → 一直 skip 不知道何时该 ping user |
| `任务分支` | 选 | 仅 git workspace 必填 |
| `历史日志` | 选 | 仅长任务建议留 trace |

## 损坏 / 异常恢复

cron 唤醒检测到以下任一情况 → **不做事**,自删 cron + 通知 user 排查:
- STATUS.md 不存在
- 缺必含字段
- `截止时间`字段不是合法 ISO-8601
- `cron job ID`与当前唤醒的 cron 不匹配(可能多任务串台)
- `任务结构表`所有阶段同时 in_progress(状态机非法)

## 更新规范

每次 cron 做完事后必须 update 的字段:
- 当前 pointer.下一步动作
- 当前 pointer.上次更新(ISO ts)
- 当前 pointer.已工作时长
- 任务结构表对应行状态
- 连续 skip 计数(skip 时 += 1,做事时清零)

写文件用 atomic write(临时文件 → rename),避免 cron 中断时半写损坏:
```bash
cp STATUS.md STATUS.md.tmp && \
  <edit STATUS.md.tmp> && \
  mv STATUS.md.tmp STATUS.md
```
