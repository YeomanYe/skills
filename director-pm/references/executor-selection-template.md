# Executor & Model-Tier Selection — 跨 skill 通用执行者选择规范

> 历史上各 flow-* / director-* 在 SKILL.md 末段写"Codex Delegation Hook",核心是"什么时候把活派给 Codex"。
> 2026-06 改版:**默认不再走 Codex 重委派**,改成更轻、harness 原生支持的"按模型档位选执行者"。
> Codex 降级为**可选的重路径**(见 §4),只在少数真划算的场景用。各 skill 引用本文件即可,不再内联私有 ROI 表。

## 1. 默认:orchestrator agent 自写

绝大多数研发/编排工作,**默认就是当前 agent(Claude)自己写**。不要为"省 token"主动外派——
外派(无论 subagent 还是 Codex)都有协调成本,小活外派几乎一定负 ROI。

## 2. 省钱手段:大体量样板 → 便宜档模型

**真正能省的不是"换个 agent",而是"换个更便宜的模型档"。** 命中以下**全部**时,把这部分活
派一个**便宜档 subagent**(`Agent`/`Workflow` 指定 `model: haiku` 或 `sonnet`)或开 fast 模式去跑:

- 改动**大体量**(≳ 数百行 / 多文件) **且**
- 工作性质是**纯样板**:CRUD、UI scaffolding、测试夹具、配置、格式转换、批量重命名、同结构复制

收益来源是**模型单价**(haiku/sonnet ≪ opus),不是并行,也不需要 SPEC/review 往返——
直接把任务描述给便宜档 subagent,产出回来由 orchestrator 验收即可。

## 3. 🔴 必须当前 agent 自写(不下放任何执行者)

任一命中 → 不外派(既不派便宜档 subagent,也不派 Codex):

| 场景 | 理由 |
|---|---|
| 改动 < 30 行 或 < 2 文件 | 协调成本 > 节省 |
| 高风险代码:auth / 支付 / 加密 / 输入校验 / 数据访问层 | 安全约束,不可豁免 |
| 强依赖会话上下文(未落地的设计、推断的状态) | 迁移到别的执行者要把上下文解释一遍,等于做两遍 |
| 决策 / 路由 / 仲裁 / 评分 / 整理报告 | judgment-heavy,SPEC 压缩比 ≈ 1(描述跟产出一样大) |
| 写 / 改 skill SKILL.md、audit 报告、PRD/AC | 同上,SPEC ≈ 输出 |

## 4. 可选重路径:Codex 委派(默认不走)

Codex 是**对等 agent**,能力强但**协调开销重**(写 SPEC + 跨进程派工 + 收 JSON 报告 + review 返工 + 错误分类)。
默认**不用**。只有同时满足才考虑:

- 任务 **≥ 2 小时**长跑(固定开销摊薄) **且**
- 有**清晰验收标准**(Codex 能独立判停,不烧飞 quota) **且**
- 可拆并行 / 跨工程批量 / 需要"生成端 vs 评分端"隔离(另一 Codex 当 LLM-judge)

命中且确实想走时,具体 SPEC / 派工 prompt / review checklist / 错误分类见各 skill 的
`references/codex-*.md`(可选,不进主文档)。**长跑 Codex 任务的元方法是 `flow-codex-goal`**——
那才是 Codex 的主场。

## 5. 例外 skill:flow-codex-goal

`flow-codex-goal` 是 Codex 派工的**元方法**(整个长任务就是驱动 Codex),**不适用**本文件的"默认不派"。
它在自己的 SKILL.md 明示"本 skill 是 Codex 重委派的承载者,不走通用选择判断"。

## 6. 各 skill 统一写法

各 skill 的 `## Executor Selection` 段**不再内联 ROI 表**,统一:

```md
## Executor Selection

执行者选择遵循 `../_shared/executor-selection-template.md`:默认当前 agent 自写;
大体量纯样板派便宜档 subagent(haiku/sonnet)/ fast;高风险/决策/强上下文不下放。

本 skill 特例(如有,写;无可略):
- <场景 X 因为 Y 的特殊处理>
```

## 7. 自检 checklist

- [ ] 没内联复述选择表(应引本文件)
- [ ] 没把"决策 / 整理 / 评分"类工作外派
- [ ] 外派只发生在"大体量纯样板",且用**便宜档模型**而非默认 opus
- [ ] 没把小改动(<30 行 / <2 文件)外派
- [ ] 走 Codex 重路径前确认 ≥2h + 清晰验收 + 可并行/批量三条都中
