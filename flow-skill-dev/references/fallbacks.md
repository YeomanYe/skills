# Missing Dependency Fallbacks

如果目标环境缺少某个依赖 skill，不要直接中断；应退化为最小可执行流程，并在最终报告中明确说明。

## `skill-creator` 缺失

如果 `skill-creator` 不可用，至少要手工补齐以下设计输入后，才能继续编写：

- skill 名称
- 触发条件
- 不应触发的场景
- 核心职责
- 边界
- 是否属于多-skill 链路
- 预期输出或 handoff 产物

若以上信息仍不完整，不应继续进入编写阶段。

## `writing-skills` 缺失

如果 `writing-skills` 不可用，按以下最小写法手工完成：

1. 先写正反触发场景
2. 再写最小可用的 `SKILL.md`
3. 明确禁止行为与完成判定
4. 补充可复用的 `tests/` 用例骨架
5. 再进入行为测试

不要因为 `writing-skills` 缺失就跳过测试或直接宣称完成。

## `skill-behavior-test` 缺失

如果 `skill-behavior-test` 不可用，至少手工完成以下四类检查，并记录到最终报告：

- 正例触发
- 反例触发
- 主流程成功场景
- 护栏或负例场景

手工验证不等于免测，只是降级执行。

## `skill-integration-test` 缺失

如果 `skill-integration-test` 不可用，但当前 skill 命中了集成测试 gate，至少手工检查：

- 上游输入是否足够让下游接手
- handoff 字段是否完整
- 是否会重复向用户追问已知信息
- 是否会过早宣称完成

这种情况不得标记为"完整通过的集成测试"，只能标记为"手工链路检查已完成"。
