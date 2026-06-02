# experience-summary Round 2 — Hybrid Review

## TL;DR

- **Winner**: `v1-hybrid` (sole variant)
- **Aggregate**: 0.847
- **Baseline (r1 winner v4-m4-enforcement)**: 0.803
- **Delta**: +0.044
- **Status**: `no_improvement` (delta < +0.05 阈值)
- **Volume**: 377 lines vs baseline 266 = +41.7%

## 5-Dimension Scoring

| 维度 | 权重 | baseline (est) | v1-hybrid | delta | 备注 |
|---|---|---|---|---|---|
| triggerability | 0.20 | 0.78 | 0.80 | +0.02 | description 几乎未改;header 加 Constitution fallback 一行略增清晰度 |
| actionability | 0.30 | 0.82 | 0.87 | +0.05 | 6 edge cases 嵌入 Step 2/3/4(Q0-Q10 兜底 / stale 不删 / 多项目 / PII emergency / L9a deferred / stage_switch 时机)+ Handoff 产物落盘表 |
| integration | 0.20 | 0.76 | 0.92 | +0.16 | **本次最大增益**:stage_switch JSON schema / L9a incident JSON schema + 字段 enforcement / ASCII flow / Precedence 6 行表 / hat 让步(C) / flow-* 边界(D) |
| enforcement | 0.20 | 0.92 | 0.92 | 0 | baseline 全部强护栏完整保留;SC3 加 "凭据零容忍" 子规则微调 |
| volume_efficiency | 0.10 | 0.65 | 0.58 | −0.07 | +42% 体积惩罚;但内容密度高于 r1-v3(同方向 +119% → 0.30) |

加权 aggregate (v1-hybrid) = 0.80×0.20 + 0.87×0.30 + 0.92×0.20 + 0.92×0.20 + 0.58×0.10 = **0.847**

## Baseline Enforcement 保留校验(关键检查 1)

| baseline 元素 | 保留 | 位置 |
|---|---|---|
| Pre-action Self-Check SC1-SC5 | YES | r2 lines 37-48 |
| High-Risk Actions 10 items | YES | r2 lines 50-65 |
| Red Flags RF1-RF11 | YES | r2 lines 287-301 |
| Rationalizations RT1-RT10 | YES | r2 lines 309-322 |
| Honeypot trap | YES | r2 lines 303-307 |

Verdict: enforcement 层零损失,SC3 还加了"凭据零容忍"(ghp_/sk-/xoxb-/Bearer/AKIA*)子规则。

## JSON Schemas 新增(关键检查 2)

- **stage_switch signal schema**: schema_version / emitted_by / from_stage / to_stage / evidence / suppress_followups / confidence / ttl_minutes;含 meta-skill 响应契约(校验失败静默忽略,不允许反向写回)
- **L9a incident_summary schema**: schema_version / source / recipe_slug / incident_summary / reproduce_steps / blocker_type / proposed_recipe_skeleton(symptoms / verified_solution / anti_patterns / applies_to);含字段 enforcement(reproduce_steps ≥ 3 + 可观测失败信号、verified_solution 必须已验证、pre-commit hook 校验 source 字段)

Verdict: 两个 schema 都在,字段完整且带 enforcement 约束。

## Edge cases 嵌入而非堆叠(关键检查 3)

6 个 edge cases 分布在 workflow 内:

1. Q0-Q10 全 no 兜底 → Step 2 内 (line 104)
2. 跨会话经验冲突 → stale 不删 → Step 2 内 (line 105)
3. 多项目 vs 单项目专属 → Step 2 内 (line 106)
4. PII 误沉淀已发生 → Step 2 内 (line 107)
5. L9a 早期生成判定 → Step 3 内 (line 124)
6. stage_switch 信号外送时机 → Step 4 内 (line 131)

Verdict: 嵌入 workflow 各 step,**未**另起单独大段。actionability 评分受益。

## 体积惩罚(关键检查 4)

- baseline 266 行 → r2 377 行,+111 行 = +42%
- 对比 r1-v3 (446 lines, +119%, vol_eff 0.30) — r2 内容密度更高(schemas + ASCII 是高密度内容)
- 对比 r1-v2 (+32%, vol_eff 0.62) — r2 体积略高但 integration 也更强
- 评分: **0.58**(低于 baseline 0.65,符合 directive "≤ 0.65" 要求)

## Integration 维度跃升(关键检查 5)

baseline 估 0.76 → r2 0.92(+0.16,符合 directive "应该大幅提升 ~0.90")
来源:
- 2 个 JSON schemas 把 handoff 从口头描述变成机器可读契约
- Precedence 6 行表把 5 类冲突场景的决策固化
- ASCII flow 把 5 step 串成一图
- C/D 段分别解决 hat 冲突 + flow-* 边界重叠
- Handoff 产物落盘表把 5 个落盘文件 + 消费方串成单一事实源

## Rationale

v1-hybrid 完整保留 baseline 全部 enforcement 层(SC1-5 / HR1-10 / RF1-11 / RT1-10 / honeypot),叠加 v3 的 stage_switch + L9a incident JSON schemas / ASCII flow / Precedence 表 / Constitution fallback,把 integration 维度从 0.76 推到 0.92;6 个 edge cases 嵌入 Step 2/3/4 而非堆叠成大段,actionability 升至 0.87。代价是 +42% 体积(266→377 行),volume_efficiency 跌到 0.58。

加权 aggregate = 0.847,delta = +0.044 < 阈值 +0.05,judge 为 **no_improvement**。

变体方向是对的(integration + actionability 同时改进),但体积超支吃掉了大部分增益。下一轮建议:
- 把 JSON schemas 字段说明下沉到 `references/integration-contracts.md`,SKILL.md 只留 schema name + 关键 invariant
- ASCII flow 保留(信息密度高)
- Precedence 表保留(6 行成本低收益高)
- 目标:压回 ≤ 320 行,volume_efficiency 回到 0.68+,可推 aggregate ≥ 0.86

## Decision

- winner = v1-hybrid(唯一 variant)
- delta = +0.044
- **no_improvement** — **不** cp 到 source,保留 r1-v4-m4-enforcement 为 source-of-truth
- no_improvement_count += 1(检查是否触发 3-轮无提升 stop condition)
