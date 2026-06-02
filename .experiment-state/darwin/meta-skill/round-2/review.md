# meta-skill round 2 review

**Baseline**: r1 winner (v4-m4-enforcement,已 cp 到 `skills/meta-skill/SKILL.md`,241 行)
**Variant**: v1-hybrid (285 行,+18% volume)
**Reviewer**: darwin (single)
**Date**: 2026-06-03

## Per-dim 评分

| 维度 | 权重 | baseline | v1-hybrid | Δ | 备注 |
|---|---|---|---|---|---|
| triggerability | 0.20 | 0.85 | 0.85 | 0 | description 完全一致(自动激活信号 / 显式触发 / 上游 / Do NOT 4 段全保留) |
| actionability | 0.30 | 0.82 | 0.90 | +0.08 | hybrid 新增 Step 1.0 边界判定(project root / submodule / monorepo / nested)+ Step 2.5 monorepo 分叉 + Step 3 corrupt 处理 + Step 7 7-天冷却复审 + inline JSON Schema(从 reference 拉进 SKILL.md)+ ASCII end-to-end flow,让 agent 不用跳文件即可执行 |
| integration | 0.20 | 0.72 | 0.92 | +0.20 | **最大提升**:hybrid 增了独立 "Integration with skillshare" 段含 4-command 契约(list-available / enable / disable / list-enabled,scope+cwd 参数化)+ exp-sum signal schema(trigger / from / to / evidence / confidence 字段,< 0.6 触发更谨慎 gate)+ flow-skill-research 调用契约(输入/输出 schema + 仍走 user gate);baseline 只在 prose 里提到这些 skill 但无 schema |
| enforcement | 0.20 | 0.88 | 0.91 | +0.03 | hybrid 保留 baseline 所有 8 高风险动作 + 5Q self-check + 8 Rationalizations;Red Flags 从 12 → 15(+3:corrupt 静默覆盖 / monorepo root 违反子优先 / submodule 继承宿主 stage);自检步骤、 rationalization 表一字未减 |
| volume_efficiency | 0.10 | 0.80 | 0.75 | -0.05 | 241 → 285 行(+18%)。新增的 inline schema(~30 行)+ ASCII flow(~15 行)+ Step 1.0/2.5/7(~25 行)+ 3 新 Red Flags + Integration 段(~25 行)。每行价值高,但还是有体积代价 |

## 加权 aggregate

- **baseline**:0.85×0.20 + 0.82×0.30 + 0.72×0.20 + 0.88×0.20 + 0.80×0.10 = 0.170 + 0.246 + 0.144 + 0.176 + 0.080 = **0.816**
- **v1-hybrid**:0.85×0.20 + 0.90×0.30 + 0.92×0.20 + 0.91×0.20 + 0.75×0.10 = 0.170 + 0.270 + 0.184 + 0.182 + 0.075 = **0.881**
- **delta**: +0.065

## 判定

`improved`(delta ≥ +0.05)。

## Rationale

1. **Integration 大幅提升(+0.20)**是 hybrid 的最大价值:r1 winner 把 enforcement 拉满但 integration 维度一直偏弱(只在 prose 提及 skillshare / exp-sum,没有 schema)。hybrid 补齐了 4-command skillshare 契约 + exp-sum 信号 schema + flow-skill-research 调用契约,直接让"跨 skill 边界"从口头约定变成可机检契约。
2. **Actionability 提升(+0.08)**来自边界处理具象化:Step 1.0 / 2.5 / 7 把 monorepo / submodule / corrupt manifest / opt-out / 7 天冷却这 5 个 edge case 从"模糊兜底"变成"显式分支",inline JSON Schema 让 agent 不用跳 reference 文件就能写出合规 manifest。
3. **Enforcement 微涨(+0.03)**:baseline 已经很强(12 Red Flags + 8 Rationalizations + 5Q + 8 高风险 gate),hybrid 只加了 3 个针对新边界的 Red Flag(corrupt 静默覆盖 / monorepo 子优先违反 / submodule 继承宿主)— 没掉 baseline 任何护栏。
4. **Volume 代价合理**:+44 行换 +0.20 Integration,每行边际价值高;0.10 权重下 volume_efficiency 扣 -0.05 只贡献 -0.005 aggregate 损失,远小于其他维度收益。

建议 **commit hybrid 为 round 2 winner**,cp 到 `skills/meta-skill/SKILL.md`。

## 风险提示(不影响判定)

- inline JSON Schema 跟 `references/manifest-schema.md` 有重复风险;若后续 schema 演化需 dual-update,长期维护成本会上升。建议在 reference 里放 canonical 完整 schema,SKILL.md 里只保留 inline "摘要+约束"(hybrid 当前实现已经是这样,继续保持即可)。
- Step 7 7-天冷却需要 `experience-summary` 配合上报 mtime / 项目状态变化信号,exp-sum 那边的演化要保持兼容 hybrid 的 signal schema(`trigger` / `from` / `to` / `evidence` / `confidence`)。
