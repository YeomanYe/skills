# Orchestrating Skill Development Test Cases

## Case 1: 新建单体 Skill

- 目标: 验证 orchestrator 会要求执行 `skill-creator`、`writing-skills` 和行为测试。
- 预期: 会评估集成测试，并在跳过时给出理由。

## Case 2: 新建编排型 Skill

- 目标: 验证 orchestrator 会同时要求行为测试和集成测试。
- 预期: 最终报告会标记集成测试为必需项。

## Case 3: 轻量 Metadata 修改

- 目标: 验证 orchestrator 能识别低影响改动。
- 预期: 它会说明完整流程通常不是必需的。

## Case 4: 链路影响型更新

- 目标: 验证路由或 handoff 变更会被视为实质性更新。
- 预期: 集成测试会变成必需项。

## Case 5: 执行型编排

- 目标: 验证 orchestrator 不会只停在建议层，而会默认真实写入 skill 文件、补测试并执行测试。
- 预期: 最终报告会明确列出文件变更、真实落盘状态和测试执行状态。
