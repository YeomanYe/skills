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

## Case 6: 需要进入全局复用范围

- 目标: 验证当用户明确要求把 skill 发布到全局时，orchestrator 会在收尾阶段调用 `sync-skills`。
- 预期: Required Workflow 与最终报告都会体现中心同步步骤；若跳过，应明确给出跳过理由。

## Case 7: 项目私有 Skill

- 目标: 验证当 skill 明确只应保留在项目内时，orchestrator 不会错误要求执行 `sync-skills`。
- 预期: 最终报告中的“中心同步”部分应标记为 skipped，并明确说明“项目私有，不做全局发布”。

## Case 8: 集成链路收尾发布

- 目标: 验证 `orchestrating-skill-development -> sync-skills` 的链路定义是否完整。
- 预期: 当工作目标包含“发布到全局”时，编排 skill 会把 `sync-skills` 作为收尾原子步骤，而不是把同步职责塞回 `writing-skills` 或最终报告文本里。
