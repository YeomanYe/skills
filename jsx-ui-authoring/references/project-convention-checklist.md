# Project Convention Checklist

在编写 JSX UI 前，优先检查这些项目约定：

- 目录结构
  - 是否有 `components/ui`
  - 是否有 `features/*/components`
  - 是否按 route / feature / domain 分层
- API 风格
  - 状态字段用 `open` 还是 `visible`
  - 事件字段用 `onChange`、`onValueChange` 还是自定义命名
  - 是否常见受控/非受控组件
- 样式方案
  - Tailwind / CSS Modules / styled-components / vanilla-extract
  - 是否已有 `cn`、`cva`、`tv`
- 交互实现
  - 是否已在用 Radix、Headless UI、React Aria
  - 是否已有对话框、Popover、Tabs、Command、Combobox 模式
- 代码组织
  - 是否允许一个文件内定义多个小组件
  - 是否倾向 hooks 与 UI 分离
  - 是否已有状态建模方式

评估结论：

- `strong`: 同类组件写法稳定且可复用
- `medium`: 有模式但存在分裂
- `weak`: 几乎没有明确规范，或同类组件风格冲突明显
