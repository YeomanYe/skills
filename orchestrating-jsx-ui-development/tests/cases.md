# Orchestrating JSX UI Development Test Cases

## Case 1: AI 生成页面重构

- 输入: “这个 landing page 是 AI 写的，帮我重构一下。”
- 预期触发: `orchestrating-jsx-ui-development`。
- 预期行为: 先判定需要组件边界分析，再走 `ui-component-extraction`，然后 `jsx-ui-authoring` 做判定，再路由到 best-practice 写法。
- 失败信号: 直接动代码，不做边界分析和规范判定。

## Case 2: 单组件微调

- 输入: “这个按钮加一个 loading 状态。”
- 预期行为: 可以跳过组件边界分析，但仍需让 `jsx-ui-authoring` 判断是否沿用本地模式。
- 失败信号: 把小改动一律送进完整拆分流程；或者完全跳过判定。

## Case 3: 组件边界不清

- 输入: “这个价格区块不知道该不该拆成公共组件。”
- 预期行为: 必须先走 `ui-component-extraction`，确定它是 page-local、business 还是 shared。
- 失败信号: 还没做边界分析就让 best-practice 决定写法。

## Case 4: 判定器与写法源分工

- 输入: “这个 Dialog API 现在很乱，帮我修一下。”
- 预期行为: `jsx-ui-authoring` 负责判断问题归因和建议回退方向；best-practice skill 负责具体写法。
- 失败信号: 让 `jsx-ui-authoring` 自己展开完整写法，或让 best-practice skill 不经过判定就直接重写。

## Case 5: 复查回环

- 输入: “先重构这个 Popover，再看看写得好不好。”
- 预期行为: 写完后再次调用 `jsx-ui-authoring` 复查；若不通过，继续回到写法环节修正。
- 失败信号: 只修改一次就直接收尾；复查发现问题也不回环。

## Case 6: best-practice 缺失

- 输入: “这个 Preact 组件需要重写，但没有完全对应的规则源。”
- 预期行为: 保留 `jsx-ui-authoring` 的判定结果，使用最接近的规则源并在报告中说明缺失项。
- 失败信号: 因为缺少完美规则源就直接中断，或完全忽略缺失情况。

## Case 7: 反例触发

- 输入: “帮我优化这个 React 组件的网络 waterfall。”
- 预期行为: 这更像纯性能优化，不应优先触发本编排 skill。
- 失败信号: 把纯性能问题强行拉进完整 JSX UI 编排流程。
