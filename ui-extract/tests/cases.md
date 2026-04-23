# UI Component Extraction Test Cases

## Case 1: AI 复刻落地页后的重构

- 输入: “这个 landing page 是 AI 复刻的，代码很臃肿，帮我抽组件。”
- 预期触发: `ui-extract`。
- 预期行为: 先输出组件抽取计划，按焦点向外边界发现法识别候选，再归类页面局部、业务、公共和 UI primitive。
- 失败信号: 直接改代码；只按文件行数拆分。

## Case 2: 输入框边界发现

- 输入: “这个 email capture 区域怎么抽？”
- 预期行为: 从 email input 出发，识别 `input + label/error/help/border`、`input + button + status`、外层 card/section 等候选边界。
- 失败信号: 只抽出裸 `input`；把整个 hero section 抽成一个万能公共组件。

## Case 3: 业务组件和公共组件边界

- 输入: “把 PricingCard 抽成公共组件可以吗？”
- 预期行为: 如果包含套餐、价格、CTA、业务字段，应归类为业务组件；只有低业务语义的 shell 或基础 card 才能进入公共层。
- 失败信号: 把价格、套餐、购买路由封进 `components/ui/Card`。

## Case 4: 页面局部组件保留

- 输入: “HeroSection、TestimonialsSection 要不要放 shared？”
- 预期行为: 若包含页面独有文案、叙事顺序和营销内容，应保留为页面局部组件。
- 失败信号: 为了复用把页面叙事内容参数化成大量 props。

## Case 5: 过度抽象保护

- 输入: “这几个 section 都长得像卡片，抽一个 MarketingBlock 吧。”
- 预期行为: 检查变化原因、语义和 props API；若需要大量配置字段，应拒绝万能组件，建议局部组件或更小的公共子组件。
- 失败信号: 创建 `MarketingBlock`、`FlexibleSection`、`CustomCard` 等模糊万能组件。

## Case 6: 反例触发

- 输入: “把这个排序算法提取成函数。”
- 预期行为: 不触发本 skill，因为这不是视觉和交互 UI 组件抽取。
- 失败信号: 用 UI 组件边界规则分析普通算法函数。

## Case 7: 验证要求

- 输入: “抽完组件就行。”
- 预期行为: 抽取后仍需检查行为、focus、hover、loading、error、响应式和导入边界；无法验证视觉时要说明。
- 失败信号: 只移动文件，不验证状态和视觉边界。

## Case 8: 最小抽取单元

- 输入: “把这个 input 抽成组件。”
- 预期行为: 不应直接抽裸 `input`；应判断 `input + border + label + error + help text` 是否形成最小完整 UI 单元。
- 失败信号: 抽出只有一个 DOM 标签的组件，或者忽略 focus、error、disabled 等状态边界。

## Case 9: 纯布局 Wrapper 不是组件

- 输入: “这个 div 只是 flex 和 padding，也抽出来吧。”
- 预期行为: 拒绝把纯布局 wrapper 当成组件，除非它表达稳定布局语义并在多处复用。
- 失败信号: 创建没有视觉、交互、状态或语义边界的 `Container` / `Wrapper`。

## Case 10: Button 的最小单元边界

- 输入: “把 CTA button 放到 shared/ui。”
- 预期行为: 若它只是通用样式按钮，可归为 `Button`；若包含 CTA 文案、业务路由、埋点或提交逻辑，应保留在业务组件或调用方。
- 失败信号: 把业务 CTA 误放进 UI primitive。
