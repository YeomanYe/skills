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

## 当前状态(2026-06-03 07:50)
- 5h: 84%(下一轮可能撞 95% 警戒线 → 等 10:50 重置)
- 重置: 06-03 10:50 CST
- 截止: 06-03 13:30 CST

### 进度
| skill | round | 状态 | 当前 baseline |
|---|---|---|---|
| ✅ hat | r1-r4 | **STOPPED** counter=3 | r1 winner(score ~0.87,278 行) |
| meta-skill | r1-r4 | counter=1 等 r4 reviewer | r2 winner(score 0.881,285 行) |
| experience-summary | r1-r3 | counter=1 等 r3 reviewer | r1 winner(score 0.803,266 行) |
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

### 在飞 agent(07:50)
- meta-skill r4 reviewer(scenarios variant 已落盘 330 行)
- exp-sum r3 reviewer(failure-catalog variant 已落盘 317 行)

### 下一步(cron 续作业)
1. 若 meta r4 / exp-sum r3 still no_improvement → counter+=1(都到 2)
2. 重置后(10:50)起 meta r5 / exp-sum r4(最后机会触发 stop)
3. 若都 stopped → 进 flow-* 演化(7 个 skill,可考虑只跑 r1 单轮看趋势,因为 hat 模式表明 enforcement mutation 几乎稳赢)
4. 若时间够 → director-* 同样套路

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
