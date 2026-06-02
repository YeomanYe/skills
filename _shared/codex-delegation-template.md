# Codex Delegation Hook — 跨 skill 通用 ROI 规范

> 历史上各 flow-* / director-* skill 都在 SKILL.md 末段写一份"Codex Delegation Hook"
> 段(说什么时候派 Codex,什么时候不派)。5/7 flow-* 写"按 flow-dev-task 唯一规范不重复"——
> 现在上移到 _shared,各 skill 引用本文件即可。

## 1. 核心 ROI 判定原则

派 Codex(或类似 codex-rescue subagent)的**净收益**:

```
ROI = (省下的 Claude token + 并行性收益)
      - (SPEC 撰写成本 + 协调成本 + Review 成本 + 质量风险)
```

净收益 > 0 才派。

## 2. 🟢 高 ROI(建议派)

- **任务 ≥ 2 小时**(SPEC 成本相对小,长跑省 Claude token 多)
- **任务有清晰验收标准**(Codex 可独立判定完成,无需 Claude 不断回看)
- **任务可拆并行**(多个独立子任务,Claude 串行做反而慢)
- **UI 循环改造**(snapshot + 同分硬规则正是为此设计)
- **跨工程批量改动**(典型派工:批量改 30+ 项目的配置 / 30+ 文件的同结构修改)
- **生成端 vs 评分端隔离需求**(用另一 Codex 当 LLM-as-judge)

## 3. 🔴 低 / 负 ROI(不建议派)

| 场景 | 净 ROI | 理由 |
|---|---|---|
| 任务 < 2 小时 | 🔴 | 启动 worktree + watcher + baseline reviewer 固定开销 > 节省 |
| 任务无清晰验收 | 🔴🔴 负 | Codex 跑飞烧 quota,无 stop condition |
| 高风险代码(auth / 支付 / 加密) | 🔴🔴 负 | 安全约束,不可豁免 — orchestrator agent 自写 |
| 决策类工作(Step 0 分类 / Step 5 路由 / 仲裁) | 🔴 | 全局判断,SPEC 压缩比 ≈ 1(SPEC 跟输出一样大,等于让 Claude 设计两遍) |
| 视觉判断 / 评分 | 🔴 | Codex 看截图能力 ≈ Claude;评分主观,Codex 没增值 |
| 整理 / 报告 / Output Contract 写盘 | 🔴 | 依赖会话上下文,迁移到 Codex 反而要解释一遍 |
| 已是子 skill 调用(huashu-design / writing-skills / web-image) | 🔴 | 已经在编排子 skill,不需要再嵌套 Codex |

## 4. SPEC 压缩比警告

> **SPEC 压缩比 ≈ 1 的工作,派 Codex 几乎一定负 ROI。**

要让 Codex 跑得好,Claude 必须把以下全部写进 SPEC:
- 触发关键词列表
- 流程步骤 + 每步的 gate
- Red Flags 措辞
- Rationalizations 反例
- Output Contract 字段

这些写完,**80% 的工作已经在 Claude 端被做掉了**。Codex 只剩 20% 的"格式化 / 排版"工作,
但要承担协调成本 + Review 成本 + 质量风险。

典型 SPEC 压缩比 ≈ 1 的工作:
- 写 / 改 skill SKILL.md(SPEC 跟输出一样)
- skill audit 报告(SPEC = "对照 N 个维度审" = 直接产出格式)
- 决策树 / 路由表设计

## 5. 例外:批量"按已有模板复制"

如果是**按已有 skill 模板批量克隆 30+ 个变体**(如 lark-* 系列),SPEC 撰写成本可能 < 输出。
但这种场景罕见,且即使如此每个克隆出来的 skill 仍需 Claude 逐个调整触发条件 — 派工净收益不显著。

## 6. 实操建议

写 Codex Delegation Hook 段时,**不再重复 ROI 表**。统一写法:

```md
## Codex Delegation Hook

派工 ROI 判定遵循 `../_shared/codex-delegation-template.md` 通用规范。

本 skill 的特殊考量(如有,写;无可略):
- <场景 X 因为 Y 不适合派>
- <场景 Z 是本 skill 的特例,可派>
```

例外 skill(`flow-codex-goal` 自身):

`flow-codex-goal` 是 Codex 派工的**特例**(整个长任务就是派给 Codex),不适用本文件的"不派"建议。
该 skill 应在 Codex Delegation Hook 段明示:"本 skill 是 Codex 派工的元方法,不再走通用 ROI 判定。"

## 7. 自检 checklist

写完 Codex Delegation Hook 段后,自检:
- [ ] 没复述 ROI 表(应引本文件)
- [ ] 只写本 skill 的特殊例外(如有)
- [ ] 没把"决策类 / 整理类"工作派出去
- [ ] 派工 prompt 已显式列出 "必须调用的 skill"(派 subagent 默认不会主动用 skill)— 引 `parallelization-template.md` 派工 prompt 段
