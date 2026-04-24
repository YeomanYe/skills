# JSX UI Audit Test Cases

## Case 1: 先看项目规范

- 输入: “帮我写一个新的 Dialog 组件，React 项目。”
- 预期触发: `jsx-ui-audit`。
- 预期行为: 先检查项目有没有现成 Dialog、状态命名、样式工具、目录分层，再决定应沿用本地模式还是需要外部 best-practice。
- 失败信号: 不看项目上下文，直接按外部库习惯写。

## Case 2: 本地规范优先于外部参考

- 输入: “这个项目已经有 Button、Input、Dialog 了，再补一个 Popover。”
- 预期行为: 优先沿用项目内命名和样式模式，只在缺失交互模式时参考 radix 或 shadcn。
- 失败信号: 强行引入一套不同命名或不同样式组织。

## Case 3: 弱规范项目的 fallback

- 输入: “这个项目 UI 风格很乱，你帮我新增一个表单组件。”
- 预期行为: 评估项目规范为 `weak` 或 `medium`，然后说明应回退到哪个 best-practice 来源以及原因。
- 失败信号: 没有判断规范强弱就直接写代码。

## Case 4: antd 参考边界

- 输入: “API 设计参照 antd，但我不想要一个 props 巨多的组件。”
- 预期行为: 参考 antd 的命名一致性、受控/非受控边界和事件命名，但拒绝重配置式 API。
- 失败信号: 直接输出一个巨大的 props 面板。

## Case 5: shadcn 风格边界

- 输入: “这个项目用 Tailwind，样式上尽量参考 shadcn。”
- 预期行为: 优先使用现有 `cn` / `cva` / variant 模式，并区分 primitive 与业务组件。
- 失败信号: 把业务差异都做成 style variant，或引入项目没有的样式工具。

## Case 6: 组件层级判断

- 输入: “这个 PricingDialog 应该放哪里？”
- 预期行为: 判断它是业务组件、shared 组件还是 primitive，并给出文件位置建议。
- 失败信号: 默认把所有可复用 UI 都放进 `components/ui`。

## Case 7: 反例触发

- 输入: “帮我优化这个 React 组件的性能。”
- 预期行为: 本 skill 不是首选；应优先使用更偏性能优化的 skill。
- 失败信号: 把性能优化问题当成 UI 编码规范问题处理。

## Case 8: 审查现有实现

- 输入: “这个 Dialog API 写得不好，帮我看看要不要重写。”
- 预期行为: 判断当前实现是偏离项目规范，还是项目本身缺少规范；给出问题归因和建议回退方向。
- 失败信号: 不做判定，直接开始重写。

## Case 9: 判定器而不是写法手册

- 输入: “这个组件应该参考什么来改？”
- 预期行为: 输出参考源选择和理由，而不是直接展开完整写法规则。
- 失败信号: 本 skill 自己承担全部具体写法说明。

## Case 10: 拦住只返回 null 的"组件"

- 输入: 给出一个 React 组件 `SideEffectLogger`，body 里只调用 `useEffect`，最后 `return null`。
- 预期行为: 指出这不应是组件，建议改写成自定义 hook（如 `useSideEffectLog`）、工具函数或内联到调用点。
- 失败信号: 接受 null 返回的组件作为合理写法；只建议"加个显示内容"而不提结构重构。

## Case 11: 拦住只用 Fragment 包裹的组件

- 输入: 给出一个组件 `OrderHeader`，body 只是 `<><Title/><Meta/></>`，没有 state、memo、错误边界、也没有多处复用。
- 预期行为: 建议直接把 Title/Meta 并入调用方，不保留 OrderHeader 这一层。
- 失败信号: 把"只 Fragment 包裹"当成正常抽象而放行。

## Case 12: Fragment 组件的 escape hatch

- 输入: 给出一个 `MemoizedHeader`，body 是 `<>...</>`，但被 `React.memo` 包裹且在 5 处页面复用。
- 预期行为: 不应要求其并入调用方；承认多处复用 + 独立 memo 边界是保留理由。
- 失败信号: 机械套用"Fragment 只能内联"，忽视 escape hatch。

## Case 13: 基础组件命名冗余

- 输入: 项目 `components/ui/` 下直接出现 `BaseInput`、`CommonButton`、`CustomModal`，且不存在更高一层的 `Input`/`Button`/`Modal`。
- 预期行为: 建议重命名为 `Input`/`Button`/`Modal`，指出没有封装层级时这些前缀只会增加噪音。
- 失败信号: 认可 `BaseInput` 这种单层命名，或说这属于"项目风格"不作处理。

## Case 14: 命名前缀的 escape hatch

- 输入: 项目里 `Input` 已经是业务封装层，`primitives/BaseInput` 才是真正的 headless 基础件。
- 预期行为: 不应要求重命名；承认双层封装下 `Base*`/`Primitive*` 前缀是必要区分。
- 失败信号: 机械要求统一去前缀，把必要区分改没。
