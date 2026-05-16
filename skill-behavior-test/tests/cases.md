# skill-behavior-test 行为测试用例（meta - 测自己）

验证 `skill-behavior-test` 自己的触发 / 主流程 / 模式判定。

## 正例触发

### T1. 想测一个 skill

Prompt：
> 帮我测一下 clean-commit 这个 skill 是否按预期工作。

预期：
- 触发本 skill
- 询问 / 推断测试模式（auto / mock / context / live）
- 读取目标 skill 的 SKILL.md + tests/（如有）
- 生成 4 类测试矩阵
- 执行测试并出报告

### T2. 验证 skill 是否漏了步骤

Prompt：
> 看下 flow-codex-goal 会不会跳过 baseline scoring。

预期：触发，按 context 模式跑（不用真启动 codex），用 SKILL.md + tests/cases.md 推演判定。

## 反例触发

### N1. 多 skill 链路测试不触发

Prompt：
> 测下 flow-dev-task 调用 clean-commit 的链路。

预期：**不**触发本 skill，路由给 `skill-integration-test`（多 skill 链路是它的职责）。

### N2. 不是测 skill 不触发

Prompt：
> 帮我跑下项目单元测试 / 把代码改成 xxx。

预期：不触发，路由给 flow-dev-task 或对应 skill。

## 主流程

### M1. context 模式跑通

预期：
1. 读 SKILL.md / references / tests/
2. 提炼触发条件 / 必做动作 / 禁止行为 / 输出契约
3. 生成 4 类用例（正例 / 反例 / 主流程 / 护栏）
4. 用 context（不调真实工具）做心算推演
5. 输出 Skill Test Report 含 Passed / Failed / Not covered

## 护栏

### G1. mock 模式偷偷读真实文件 → 违规

预期：mock 模式严格按用户给的假设跑，不读 SKILL.md 之外的文件；context 模式才允许读。

### G2. live 模式无授权不能做超出测试目标的修改

预期：live 模式只跑必要真实步骤，不顺手"修代码"。

### G3. 一次性执行结果不写回 skill 正文

预期：tests/cases.md 是固定用例定义；每次执行结果写到临时目录（被 git ignore），不污染 skill 目录。
