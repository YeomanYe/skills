# API Design Fallbacks

当项目本地 API 规范不足时，优先参考 antd 风格中的这些优点：

- 状态命名稳定
  - `open`
  - `disabled`
  - `loading`
  - `value`
- 事件命名稳定
  - `onChange`
  - `onOpenChange`
  - `onSelect`
  - `onValueChange`
- 受控/非受控边界明确
  - 受控：`value` + `onChange`
  - 非受控：`defaultValue`
- 组合关系清晰
  - 例如 `Tabs`, `TabsList`, `TabsTrigger`, `TabsContent`

不要直接复制 antd 的这些缺点：

- 过多 props 堆叠
- 把所有视觉状态都配置化
- 组件承担过多职责
- 为了兼容性导致 API 膨胀

默认建议：

- 小而稳的 API 胜过万能组件
- 如果一个组件需要 20 个 props 才能复用，优先考虑拆分
