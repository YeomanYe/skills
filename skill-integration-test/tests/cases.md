# skill-integration-test 行为测试用例（meta - 测自己）

验证 `skill-integration-test` 自己的触发 / 主流程 / 与 skill-behavior-test 的边界。

## 正例触发

### T1. 测多 skill 链路

Prompt：
> 测一下 flow-dev-task 调 writing-plans 再调 subagent-driven-development 这条链路。

预期：
- 触发本 skill
- 读所有相关 skill 的 SKILL.md + handoff payload + tests/
- 校验链路衔接、字段传递、是否有冗余追问
- 输出 Skill Integration Test Report

### T2. 验证 handoff 完整性

Prompt：
> 看 flow-codex-goal 接 flow-dev-task 的 handoff 字段是不是齐的。

预期：触发，检查 Upstream Handoff Payload 表，看必填字段在上游 skill 中是否都会生成。

### T3. 验证 router 会不会重复问问题

Prompt：
> 检查 flow-project-bootstrap → project-prep 这条链，project-prep 会不会重复问用户已经在 bootstrap 阶段说过的话。

预期：触发，按"冗余追问"维度审查。

## 反例触发

### N1. 单 skill 测试不触发

Prompt：
> 测下 clean-commit 是否正常触发。

预期：**不**触发本 skill，路由给 `skill-behavior-test`（单 skill 是它的职责）。

### N2. 不是测 skill 链路不触发

Prompt：
> 跑 e2e 测试 / 跑集成测试 / 测下后端 API。

预期：不触发，这些是项目代码测试，路由给 flow-dev-task。

## 主流程

### M1. context 模式跑通

预期：
1. 接受用户指定的 skill 链
2. 读链中每个 skill 的 SKILL.md + references + tests/
3. 校验：流转顺序 / handoff 字段 / 是否冗余追问 / 是否过早完成
4. 至少覆盖 4 类用例（正常 / 反例 / 冗余追问 / 字段保真）
5. 输出报告含 Passed / Failed / Not covered / Findings

## 护栏

### G1. 不能用单 skill 测代替链路测

预期：发现用户其实只关心单个 skill 时，建议改用 skill-behavior-test，不强行做链路测。

### G2. mock 模式不调真实工具

预期：mock 模式不启动浏览器、不跑命令、不修代码——只做文本级链路推演。

### G3. 链路出问题时能精确定位

预期：失败时必须回答"是哪个 skill 的输出不够 / 哪个 skill 没消费已有输入 / 链路设计问题还是单 skill 问题"——不能只说"链路有问题"。
