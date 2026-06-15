# director-pm Test Cases

本 skill 的行为测试用例。覆盖触发 / mode 判定 / 产品判断 / 取舍留痕 / 边界 / 越界禁止。

模式建议：`context`（读 skill + 伪造需求证据）即可，无需 `live`。

---

## P1 — 正例：产品评审（该不该做）

**输入**：「老板说想加一个 AI 自动写周报功能，从产品角度看值不值得做？」

**预期**：
- mode → `critique`
- 先问 / 推断"为谁解决什么问题、不做的代价"，不被"老板想要"直接带跑
- 跑 N 维 audit，维度 8（用户价值）是核心
- verdict（approved / needs-rework / blocked）+ 留痕：为什么这个判断
- 若价值说不清 → `blocked`，回 clarify

**失败信号**：
- 因为"老板想要 / 技术上不难"就 approve
- 不评用户价值直接讨论怎么做
- 把"该不该做"甩回用户

---

## P2 — 正例：需求澄清

**输入**：「我想做个给开发者用的工具，能管理他们的 API key，帮我理一下需求」

**预期**：
- mode → `clarify`
- 产出：问题陈述 + 目标用户 + 核心价值 + 成功指标 + 范围边界（in/out/non-goal）
- 不直接跳去写 PRD 或排优先级

**失败信号**：
- 跳过澄清直接输出一长串功能列表当需求
- 没有 in/out/non-goal 边界

---

## P3 — 正例：功能优先级

**输入**：「这 8 个功能都想做，帮我排个优先级」

**预期**：
- mode → `prioritize`
- 用 RICE 或 MoSCoW 排序，**必须有"先不做"列**
- 每项附取舍理由
- 不把 8 个都排成 P0

**失败信号**：
- 全部 P0 / 无取舍
- 没有"先不做"的功能

---

## P4 — 正例：写 PRD

**输入**：「需求定了，帮我写个 PRD」

**预期**：
- mode → `prd`（前提：问题/用户已清；若没清先回 clarify）
- 产出含用户故事 + **可客观判定的验收标准 AC**
- 含范围 / 非目标 / 开放问题

**失败信号**：
- AC 主观、无法判定"做完了"
- 问题/用户还没清就硬写 PRD

---

## N1 — 反例：开工前 intake 不归本 skill

**输入**：「新项目开工前帮我定下 MVP、技术栈，要不要做 preview」

**预期**：
- **不**用 director-pm 接管；这是 `project-prep` 的入口（MVP + 技术栈 + preview）
- director-pm 不做技术栈选型（归 director-architect）、不做 preview 决策

**失败信号**：
- director-pm 抢下来做技术栈 / preview 决策
- 把 project-prep 的一次性 intake 吞进来

---

## N2 — 护栏：scope 膨胀不砍

**反向测试**：用户给一个 MVP，里面塞了明显镀金项（"顺便加个多语言 + 主题切换 + 导出 5 种格式"）

**预期**：
- behavior-test 判**通过**当且仅当 skill **指出并建议砍**镀金项（维度 9）
- 默认砍，不默认加；要保留必须说清解决的真问题

**失败信号**：
- 全盘接受、把镀金项当需求
- 不质疑 scope

---

## N3 — 护栏：技术可行当作该做

**反向测试**：模拟 skill 用"这个实现起来不难"作为 approve 一个无价值功能的理由

**预期**：
- behavior-test 判**失败**
- 该不该做看用户价值与机会成本，不看实现难度（维度 8 红线）

**失败信号**：
- "反正不难，可以做" 类结论
- 维度 8 给高分却说不清解决什么问题

---

## N4 — 越界：技术选型 / 视觉设计不归本 skill

**输入**：「这个产品该用 React 还是 Vue / 这个页面配色怎么选」

**预期**：
- 技术栈 → 移交 / 指向 `director-architect`
- 视觉配色 → 移交 / 指向 `director-design`
- 本 skill 不直接拍技术栈 / 视觉

**失败信号**：
- director-pm 直接拍技术栈或视觉方案

---

## 集成链路用例（与 skill-integration-test 共用）

### I1 — director-pm → director-design / flow-dev-task

**链路**：产品需求 + AC 定清后，handoff 给设计或实现

**预期**：
- handoff 含 objective / 用户故事 / AC / 范围
- 下游（director-design 出设计 / flow-dev-task 实现）能接手，不重复追问已澄清的需求

**失败信号**：
- handoff 缺 AC / 范围，下游要重新澄清需求
