# Darwin Skill Evolution — STATUS

> Cron 唤醒后第一件事: Read 本文件 → 决定续作业

## 设计(借鉴 SkillClaw 但简化适应 directed-evolution)

不同点: SkillClaw 用 agent session 数据驱动 evolve(我们没有 session)。我们用 **directed mutation + reviewer scoring**:

**每轮**(N=4 variant 并行):
- Mutation directives(4 类,跨 round 复用):
  - M1 — **clarity**: 简化句式 / 去冗余 / 更结构化
  - M2 — **completeness**: 补缺失 edge case / 反例 / 测试用例
  - M3 — **integration**: 强化跨 skill 边界 / handoff schema / precedence rules
  - M4 — **enforcement**: 强化 Red Flags 措辞 / Rationalizations / 自检步骤

**每轮评分(2 reviewer 并行):**
- R1 — **clarity & usability** scorer(对照 director-template / flow-template 元规范打分)
- R2 — **integration & enforcement** scorer(对照 audit 报告 + constitution + 跨 skill 边界打分)

5 维度评分(对齐 SkillClaw 4 维 + 1 维独有):
- `triggerability` 0.20 — description 触发清晰度
- `actionability` 0.30 — workflow steps + gates 可执行度
- `integration` 0.20 — handoff / cross-skill boundaries
- `enforcement` 0.20 — Red Flags + Rationalizations 真护栏
- `volume_efficiency` 0.10 — 体积 vs 价值

aggregate = 加权平均(per reviewer) → 2 reviewer 几何平均 → round score

## Stop Condition
- **3 轮 round score 无提升**(< +0.05) → 停止该 skill 演化
- 5h 额度 > 95% → halt 本轮
- 当前时间 > 06-03 13:30 → 自停 + 删 cron + 通知 user

## 演化顺序
1. ⏳ hat — round 0 (baseline) 已 cp,round 1 待跑
2. meta-skill
3. experience-summary
4. flow-codex-goal
5. flow-dev-task
6. flow-ext-publish
7. flow-project-bootstrap
8. flow-project-finish
9. flow-skill-dev
10. flow-skill-research
11. director-architect
12. director-design
13. director-frontend
14. director-ops
15. director-promote

## 当前状态(2026-06-03 08:00)
- 5h: 88%(已撞警戒边缘 → halt new agent 等 10:50 重置)
- 重置: 06-03 10:50 CST
- 截止: 06-03 13:30 CST
- cron be758bdc 仍 active(每 :55)— 下次 09:55 wake 但 budget 仍高,该轮跳过;10:55 wake budget reset 后可干活

### 进度
| skill | round | 状态 | 当前 baseline |
|---|---|---|---|
| ✅ hat | r1-r4 | **STOPPED** counter=3 | r1 winner(score ~0.87,278 行) |
| meta-skill | r1-r4 | counter=2(差 1 轮 stop) | r2 winner(score 0.881,285 行) |
| experience-summary | r1-r3 | counter=2(差 1 轮 stop) | r1 winner(score 0.803,266 行) |
| flow-codex-goal | r0 | pending | source baseline |
| flow-dev-task | r0 | pending | source baseline |
| flow-ext-publish | r0 | pending | source baseline |
| flow-project-bootstrap | r0 | pending | source baseline |
| flow-project-finish | r0 | pending | source baseline |
| flow-skill-dev | r0 | pending | source baseline |
| flow-skill-research | r0 | pending | source baseline |
| director-architect | r0 | pending | source baseline |
| director-design | r0 | pending | source baseline |
| director-frontend | r0 | pending | source baseline |
| director-ops | r0 | pending | source baseline |
| director-promote | r0 | pending | source baseline |

### 在飞 agent(08:00)
- 无(全部已完成,处于 halt 状态)

### 下一步(cron 续作业)— 决策树

**优先级 1**: 若 budget < 60% → 触发 meta r5(单 variant)+ exp-sum r4(单 variant)并行。两者大概率 no_improvement → stop。

**优先级 2**: 一旦 meta + exp-sum 都 stopped → 进 flow-* 演化(7 个 skill)
  - 考虑只跑 r1 单轮看趋势(hat r1 模式表明 enforcement mutation 几乎稳赢 +0.05+)
  - 每个 flow-* 派 1 个 v4-enforcement-style variant + 1 reviewer = 2 agent
  - 7 × 2 = 14 agent,可分成 2-3 批,每批 5 agent

**优先级 3**: director-* 5 个,同样套路

**Halt 决策**:
  - budget ≥ 90% → 立刻 halt + 写状态 + 等下次 cron
  - 时间 ≥ 13:30 → 立刻 halt + 删 cron + 通知 user
  - 5 个 flow-* + 5 个 director-* 都完成 → 任务结束,通知 user

### Halt 时刻 user 通知
- 用 cc-connect send --message 通知关键里程碑
- 不通知中间小步,只通知:
  1. 演化完 1 个完整 skill(commit + 分数)
  2. 全部 finish
  3. 超 deadline 强停
  4. 重大错误

## 单轮流程(每个 skill 重复直到 stop)

1. Read 当前 SKILL.md(baseline 或上一轮 winner)
2. **派 4 parallel subagent** 各生成一份 variant(M1-M4 mutation directive)
3. 写到 `.experiment-state/darwin/<skill>/round-N/variants/v1.md..v4.md`
4. **派 2 parallel reviewer** 各对 4 variant + baseline 评分
5. 聚合 → pick winner(geo mean 最高)
6. 若 winner 比 baseline +0.05 → cp 到 `<skill>/SKILL.md` + commit
7. 若 < +0.05 → no_improvement_count += 1
8. 若 no_improvement_count ≥ 3 → stop this skill,进下一个
9. 否则 → round += 1,回 step 1

## Cron 协议(下一步配)
- 每整点 :55 唤醒
- 唤醒后: Read 本 STATUS.md → 看当前 skill / round
- 跑 1 轮(可能 30-40 min,看额度)
- 写状态 + halt
- 到 deadline 自停
