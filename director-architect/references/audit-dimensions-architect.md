# director-architect — Audit 自定义维度 / 红线 / Verdict 映射

> 本文件是 `audit-rubric.md` §7 骨架的具体实例化。
> 主文档 "N 维 Audit Checklist" 段只保留骨架，详细定义在此。

## 本 skill 1/3/5 锚点重定义（基线维度领域特化）

- **维度 1**（基线: scope/探测充分性）→ 本 skill: 1=只看主入口 1 文件 / 3=核心 3-5 文件 / 5=全规则体系扫齐 + 引用 ≥ 10 处 [file:line]
- **维度 3**（基线: 决策证据强度）→ 本 skill: 1=无 [file:line] 引用 / 3=部分有 / 5=每个决策都含具体引用 + 反例
- **维度 4**（基线: 方案可执行性）→ 本 skill: 1=只方向描述 / 3=列文件 / 5=每个 add/modify/delete 含理由 + diff 预览
- 其余维度沿用基线

## 本 skill 自定义增维度（基线 7 维 + 以下）

- **维度 8 — 联合评估广度**: 1=未调任何 best-practice skill / 3=调 1-2 个 / 5=覆盖目标栈所有相关 skill，有冲突仲裁
- **维度 9 — 参考项目对齐度**: 1=未对照 mirroring-checklist / 3=部分对照 / 5=完整对照 + 偏离项有明示理由
- **维度 10 — 与现有规则一致性**: 1=与现规则冲突未识别 / 3=识别但未解决 / 5=识别 + 给出迁移/合并方案
- **维度 11 — 工程化约束/自动化覆盖度**: 1=只看规则文档，完全没评估门禁机制（hook/lint-staged/发布门禁/聚合 check）与便捷自动化 / 3=点到约束层但没区分"有牙齿 vs 形同虚设"、未对照 stack-checklist 工程化节 / 5=约束（pre-commit/commit-msg/prepublishOnly/聚合 check/依赖分层）与便捷（auto-install）逐条对照目标项目，缺口按四类问题归类 + 判断每条机制对该项目是否真有收益（不照搬 exemplar）

## 本 skill 红线触发（§3 通用之外）

- 维度 3（决策证据）= 1 且关键决策无 [file:line] 引用 → `blocked`
- 维度 8（联合评估）= 1（完全未调任一 best-practice skill 且未显式标"未覆盖"）→ `blocked`
- 维度 10（与现规则一致）= 1 且与现规则有未解决冲突 → `blocked`

## Aggregate → Verdict 映射（本 skill 自命名标签）

| Aggregate | Verdict | 行动 |
|---|---|---|
| ≥ 4.5 | `ready-to-land` | 可直接进 Approval Gate → land |
| 4.0-4.4 | `ready-with-refinement` | should-fix 列清单，用户决定补研究还是直接 land |
| 3.0-3.9 | `needs-refinement` | must-fix 列清单，Approval Gate 会拦，必须补研究 |
| < 3.0 | `blocked` | 方案整体不可行，回 Research Phase 从头跑 |
