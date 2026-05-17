# Style Fallbacks

当项目没有明确样式规范，且当前技术栈是 Tailwind 或类似原子类方案时，可参考 shadcn/ui 风格：

- primitive 与业务组件分层
- 使用有限、可预测的 variant
- 用 `cn` / `cva` 组织 className
- 避免在调用方传入大量样式细节
- 保持 className 可读，不写成一长串难以维护的拼接逻辑

当项目需要交互与可访问性 fallback 时，可参考 radix：

- trigger / content / overlay / portal 的关系
- 焦点管理
- 键盘行为
- ARIA 语义

不要这样做：

- 见到 Tailwind 就把所有业务差异都塞进 variant
- 项目本身不用 Tailwind，却硬套 shadcn 写法
- 只复制样式，不复制交互边界和可访问性规则
- 在一个项目里混合多套 primitive 命名体系
