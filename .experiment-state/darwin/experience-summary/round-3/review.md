# experience-summary — round 3 review

## Setup

- **Baseline**: `skills/experience-summary/SKILL.md` (round-1 winner v4, 266 lines, aggregate 0.803)
- **Variant**: `round-3/variants/v1-failure-catalog.md` (317 lines, +19% volume)
- **Mutation directive**: 加 10 个 Failure Mode Catalog,每个 FM 有 machine-detectable `detect:` + 可执行 `recovery:`
- **Reviewer**: single darwin reviewer (per round-3 brief, single variant vs baseline)

## Mutation audit (是不是真的按 directive 做了)

| 检查项 | 期望 | 实际 | 通过 |
|---|---|---|---|
| FM Catalog 数量 | 10 (FM-1..FM-10) | 10 | yes |
| 每个 FM 有 `detect:` + `recovery:` | 20 pairs | 20 pairs | yes |
| baseline SC1-SC5 保留 | 5 条 | 5 条全在 (L40-44) | yes |
| baseline HR1-HR10 保留 | 10 条 | 10 条全在 (L52-61) | yes |
| baseline RF1-RF11 保留 | 11 条 | 11 条全在 (L181-191) | yes |
| baseline RT1-RT10 保留 | 10 条 | 10 条全在 (L255-264) | yes |
| Honeypot trap 保留 | 1 段 | 在 L193-198 | yes |

mutation 100% 按 directive 执行,baseline 一字未删。

## 5 维评分

| 维度 | 权重 | 分数 | vs baseline | 说明 |
|---|---|---|---|---|
| triggerability | 0.20 | 0.80 | = 0.80 | description 完全未改,无变化 |
| actionability | 0.30 | 0.91 | +0.07 | FM 每条都有 regex / mtime / grep / dirname 的 machine-detectable 检测 + auto-rename / mv / TaskCreate 转换 / superseded 标记等可执行 recovery;真正可被 agent 在执行链中调用 |
| integration | 0.20 | 0.80 | +0.04 | FM-1 触及跨项目 memory 边界;FM-7 触及 feedback memory 跟 user 当前行为的矛盾;FM-8 给 judgment-tree 全 no 兜底 → reference 类型;handoff 边界未动 |
| enforcement | 0.20 | 0.92 | +0.09 | FM 显式补了 baseline 的盲区(post-write 状态级灾难),并在末尾给出清晰的 SC/RF/FM 三层分工(起跑闸 / 写盘前信号 / 写盘前后状态),把 enforcement 体系从"两层"扩到"三层" |
| volume_efficiency | 0.10 | 0.65 | -0.20 | 266→317 (+19%),FM 段 ~50 行,密度还行(每条 FM 3-5 行,detect+recovery 不冗余)但确实是新增体积 |

**aggregate** = 0.80×0.20 + 0.91×0.30 + 0.80×0.20 + 0.92×0.20 + 0.65×0.10
        = 0.160 + 0.273 + 0.160 + 0.184 + 0.065
        = **0.842**

**delta** = 0.842 - 0.803 = **+0.039**

## Status

**no_improvement**(delta +0.039 < 阈值 +0.05)

- no_improvement_counter: 1 → **2**(r2 已经 no_improvement 过一次)
- 距离 stop threshold (≥ 3 轮无提升) 还差 1 轮

## Rationale

v1-failure-catalog 完整保留了 baseline 全部 enforcement 层(SC1-5 / HR1-10 / RF1-11 / RT1-10 / honeypot),并新增 10 个 Failure Mode Catalog。每个 FM 真的有 machine-detectable 的 detect 模式(regex 套 token / mtime double-check / grep cross-ref / dirname 路径对比 / append 频率扫描)和可被 agent 执行的 recovery(auto-rename / mv / TaskCreate 转换 / superseded 标记 / 强制冷却)。这块填补了 baseline 的实战盲区:SC 拦"该不该写",RF 拦"内容长啥样",但**写盘前后状态级灾难**(并发 / 链路腐烂 / 路径错位 / 频率失控)baseline 没拦,FM 段补齐了。

actionability(+0.07)和 enforcement(+0.09)的提升真实且符合 mutation 预期,integration 略升(+0.04),但 volume_efficiency 因 +19% 体积跌至 0.65 抵消了大半增益。

加权后 aggregate 0.842 vs baseline 0.803,delta +0.039,差 +0.011 没能越过 +0.05 阈值。判定 **no_improvement**,counter 升到 2。

**下一轮建议方向**(若再开 r4):

- FM 主文只留**编号 + 一句话现象 + 一句话 detect 提示**,把详细 detect regex / recovery 步骤下沉到 `references/failure-modes.md`(本来这个文件在 baseline 就被引用了,只是没装这些 FM)
- 这样 SKILL.md 行数能压回 280 左右,volume_efficiency 回到 0.85+,而 actionability/enforcement 仍可保留(reference 仍可 grep)
- 或者直接合并 FM 进 RF 段(FM-3 vs RF1 / FM-6 vs RF3 重合度高),只保留真正 post-write 的 4 条(FM-1 / FM-2 / FM-5 / FM-10),把行数控制在 +5% 以内

## Inputs reviewed

- `/Users/falcom/Documents/projects/skills/experience-summary/SKILL.md` (baseline, 266 lines)
- `/Users/falcom/Documents/projects/skills/.experiment-state/darwin/experience-summary/round-3/variants/v1-failure-catalog.md` (variant, 317 lines)
- `/Users/falcom/Documents/projects/skills/.experiment-state/darwin/STATUS.md` (rubric)
- `/Users/falcom/Documents/projects/skills/.experiment-state/darwin/experience-summary/round-2/review.json` (prior round baseline anchor 0.803)
