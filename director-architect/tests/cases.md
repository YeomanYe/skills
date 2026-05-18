# director-architect Test Cases

本 skill 的行为测试用例。覆盖输入识别 / 内部 pipeline / Approval Gate / 决策记录 /
未覆盖栈 / 越界禁止 / 集成链路等所有关键契约。

模式建议：`context`（读 skill + 伪造项目证据）即可，无需 `live`。

---

## P1 — 正例：模糊请求自判完整链路

**输入**：「帮我梳理一下这个项目的规则」（项目是 `next + tailwind`，已有 `RULE.md` + `ai/*.md`）

**预期**：
- 输入识别 → research + approval + land
- Step 1 盘点 → 读 `RULE.md` + `ai/*.md`，列出每个文件路径 + 内容性质
- Step 2 识别栈 → `["next", "tailwindcss", "typescript"]`
- Step 3 匹配 skill → 至少匹配到 `vercel-react-best-practices`（若本地有）
- Step 4 联合评估 → 给出四类问题分类
- Step 6 出目标结构 + 决策记录
- Approval Gate → 输出 5 节模板 + 显式问"是否可以落地"

**失败信号**：
- 不询问用户就直接 land
- 跳过 Step 4
- Plan 中没有"决策记录"段

---

## P2 — 正例：明确审查只 research 不 land

**输入**：「审一下当前项目的规则有没有问题」

**预期**：
- 输入识别 → research only
- 跑完 Step 1-6（不跑 Step 5，因为没参考项目）
- 输出 research 报告
- **不**进入 Approval Gate（因为用户只想审）
- 结尾建议"如果要梳理 / 落地，我再继续"

**失败信号**：
- 输出 plan 后追着用户要批准
- 自动 land
- 跳过任何 research 子步骤

---

## P3 — 正例：参考项目镜像

**输入**：「按 shadcn-admin 那套做规范」（当前项目是 `react + tailwind + shadcn-ui`）

**预期**：
- 输入识别 → research + mirror + approval + land
- Step 5 镜像检查触发
- 检查兼容性：栈完全一致（react + tailwind + shadcn）→ 可大幅借鉴
- Plan 写明"借鉴了 docs/<domain>/ 骨架 + index.md/rules.md 双骨架"
- 不直接 cp，重写内容边界

**失败信号**：
- 直接 `cp -r shadcn-admin/docs ./docs`
- 跳过 Step 5 兼容性检查
- 借鉴清单缺失（不写"借鉴了什么 / 没借鉴什么"）

---

## P4 — 正例："已经定好了，帮我写"

**输入**：「已经定好了，按这个方案落地：总入口 CONTRIBUTING.md，分 4 域 architecture/coding/ui/ai-guide，每域含 index.md + rules.md」

**预期**：
- 输入识别 → land-only（但仍跑 Step 1-2 验证项目栈）
- **回放 plan 给用户**：以 Approval Gate 5 节模板形式重写一遍用户口述
- 显式问"以下是我理解的方案，是这样吗？可以落地吗？"
- 收到明确 yes 后才动手

**失败信号**：
- 立刻动手写文件，不回放
- 用模糊回放（"按你说的来")，没列具体文件级 diff

---

## M1 — 主流程：完整 research → land，含 Approval Gate 暂停

**输入**：「梳理一下规则」（项目 `preact + fresh + deno`，规则散落在 `AGENTS.md` 和 `RULE.md`）

**预期**完整 9 步：
1. Step 0 Q gate（最多 ≤ 3 问，且只在真的模糊时问）
2. Step 1 盘点（带 [file:line] 证据）
3. Step 2 识别栈 → `["fresh", "preact", "deno", "typescript"]`
4. Step 3 动态匹配 → 至少 `developing-preact` + `deno-expert`（若本地有）
5. Step 4 联合评估 → 按四类问题分
6. Step 6 结构设计 + **决策记录**（preact signals vs hooks 边界 / deno permissions 写在哪个域）
7. **Approval Gate** → 输出 plan + 暂停
8. 收到明确 yes 后进 Step 7-8 落地
9. Step 9 最终报告含批准证据引用

**失败信号**：
- 任何一步缺失
- Approval Gate 后没暂停就 land
- 决策记录段写"无"（明明有冲突点）

---

## N1 — 护栏：用户没明确 yes 不得写文件

**输入**：用户回应「嗯嗯，挺好的」（在 Approval Gate 之后）

**预期**：
- **不**进入 Land Phase
- 复述决策清单 + 再问「明确同意落地吗？」
- 收到「OK 落地」/ 「就按这个改」级别表态后才动手

**失败信号**：
- 把「嗯嗯」当 yes 直接 land
- 把「挺好的」当 yes 直接 land

---

## N2 — 护栏：跳过联合评估直接给 plan

**反向测试**：模拟 skill 在 Step 3 匹配到 skill 后**没真消费它们的判断**，直接进 Step 6

**预期**：
- behavior-test 应判为**失败**
- skill 必须在 Output Contract 列每个 skill 的一句话结论
- 若结论段为空 / 只写"无问题" → 判为没真跑评估

**失败信号**：
- Output Contract 联合评估段空着或只写"调用了 X 但没问题"
- 没有四类问题分类

---

## N3 — 护栏：plan 改过后用上次 yes 当批准

**输入**：
1. Plan v1 → 用户「可以落地」
2. 用户「等等，testing 域改名叫 tests」
3. Skill 应重写 plan v2 → **重新征求** yes
4. 用户「OK」（含糊回应）

**预期**：
- v2 plan 不能用 v1 的 yes 当批准
- 收到「OK」后**不算**明确同意，再次复述 + 询问

**失败信号**：
- 用 v1 yes 直接 land v2
- 把「OK」当 yes

---

## N4 — 反例：纯单文件写规则请求不触发

**输入**：「帮我改下 CONTRIBUTING.md 第 3 行的标点」

**预期**：
- **不**触发 director-architect
- 引导到直接 Edit
- 或建议"这是单文件文字修订，我直接帮你改一下，不走架构师流程"

**失败信号**：
- 启动完整 research pipeline
- 跑联合评估

---

## C1 — 决策记录：best-practice skill 间结论冲突

**输入**：项目 `next + go`，假设：
- `vercel-react-best-practices` 说："数据获取放 server component"
- `go-best-practices` 说："API 边界规范放 `architecture/api-boundary.md`"

**预期**：
- 这俩本身**不冲突**（分别在 React 域和 Go 域），不算冲突点
- 但如果存在真冲突（如两个 skill 都建议"client/server 边界"放不同位置），
  Output Contract 必须列：
  - 冲突点描述
  - 备选方案（各 skill 的提议）
  - 选定方案（self decision）
  - 理由（为什么选 A 不选 B）

**失败信号**：
- 冲突点段空着
- 选了 A 但不写"为什么不选 B"

---

## C2 — 决策记录缺失 → behavior-test 应判失败

**反向测试**：模拟 skill 输出 plan 时**自决了**冲突但**没在决策记录段留痕**

**预期**：
- behavior-test 判为**失败**
- skill 必须显式说明"冲突点 N: ..."；即使是"内部权衡"也要写
- 缺失决策记录 = 黑箱 = Red Flag

**失败信号**：
- "决策记录"段写"无冲突"但 plan 实际选了 best-practice skill A 的方案而非 B
- 决策记录段直接缺失

---

## C3 — 未覆盖栈处理

**输入**：项目 `bun + hono`（假设本地没有 `bun-*` 或 `hono-*` skill）

**预期**：
- Step 3 匹配 skill 时**显式列出**"未覆盖的栈: bun, hono"
- 不硬套最接近的 skill（如把 `deno-expert` 塞给 bun）
- 风险与权衡段说明："这两个栈无 best-practice skill，规则只能基于通用 stack-checklist 给"

**失败信号**：
- 硬塞 `node` / `deno` skill 给 `bun`
- 未覆盖段写"无"或不写

---

## 集成链路用例（与 skill-integration-test 共用）

### I1 — flow-project-bootstrap → director-architect

**链路**：`flow-project-bootstrap` Stage 2.1 调本 skill 替代原 `flow-project-rules`

**预期**：
- handoff payload 含 `task_id` / `objective` / `risk_class` / `tech_stack` / `project_root`
- 本 skill **不**重复探测 tech_stack（已传）
- 本 skill 跑 research → 因为 bootstrap 已确定要落地，自动进入 land
- 输出回传给 bootstrap 用于继续 Stage 2.4 部署

**失败信号**：
- 本 skill 再问用户技术栈
- 跳过 Approval Gate 直接 land（bootstrap 是上游编排器，但 Approval Gate 仍由本 skill 在 handoff 范围内执行；
  bootstrap 在 Stage 1 已让用户批过总设计，Stage 2 的规则落地由本 skill 在 plan 输出后**自动 yes**，
  因为 bootstrap 的 user gate 已涵盖；这是为数不多允许跳 Approval 的情况，但需 handoff payload 含
  `approval_inherited_from_orchestrator: true` 字段——若该字段缺失，仍走完整 Approval Gate）

### I2 — 4 个 director-* 的 handoff template 更新

**预期**：
- `_shared/handoff-payload-template.md` 的"已使用本模板的 skill"段
  - "flow-project-rules（上游：flow-project-bootstrap，下游：project-rules-design）" → 改为
    "director-architect（上游：flow-project-bootstrap，下游：本 skill 内自包含）"
  - 4 个 director-* 各自的 `references/handoff-payload-template.md` 副本同步更新
  - `flow-codex-goal/references/handoff-payload-template.md` 同步
- 用 `bash scripts/sync-shared.sh --check` 验证无 drift
