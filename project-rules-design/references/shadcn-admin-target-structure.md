# shadcn-admin: Target Structure

这个案例展示一套已经落地的目标结构，可以作为“目录与入口职责”的参考样板。

## 总入口

`CONTRIBUTING.md`

职责：

- 仓库规则唯一总入口
- 定义阅读顺序
- 定义按任务类型的路由
- 定义入口优先级

不负责：

- 具体编码规则正文
- 具体 UI 细则正文
- 具体架构细则正文
- AI 执行模板正文

## 领域入口

每个领域使用 `docs/<domain>/index.md` 作为稳定入口：

- `docs/architecture/index.md`
- `docs/coding/index.md`
- `docs/ui/index.md`
- `docs/ai-guide/index.md`

这些入口只负责：

- 说明该领域管什么
- 说明何时继续读二级文件
- 给出推荐阅读顺序

## architecture

推荐二级文件：

- `routing.md`
- `features.md`
- `component-layering.md`

职责：

- 代码放在哪
- 模块怎么拆
- 路由与 feature 如何对应
- 组件和页面层如何归层
- 哪些目录属于通用资产层
- 通用资产层默认如何抗业务污染
- `components` 中只正式使用 `primitive` / `composite` 两类

## coding

推荐二级文件：

- `rules.md`
- `naming.md`
- `comments.md`
- `data-flow.md`
- `i18n.md`
- `docs.md`
- `completion.md`

职责：

- 编码总风格和硬约束
- 命名
- 注释
- 数据流
- 文案和 i18n
- 文档与交付要求
- 通用资产层文件的注释要求
- 容器类 `composite` 组件何时适合 ASCII 结构图注释

额外约束：

- `rules.md` 保持为编码总纲，不承载命令与大量专题杂项
- 命令、验证、`.tmp/`、清理要求下沉到 `completion.md`
- 数据形态收敛、可信数据边界、错误处理下沉到 `data-flow.md`

## ui

推荐二级文件：

- `rules.md`
- `design-system.md`
- `layout.md`
- `components.md`
- `patterns.md`

职责：

- 视觉语言
- 设计系统
- 布局骨架
- 基础组件视觉规则
- 页面模式

## ai-guide

推荐二级文件：

- `prompts.md`
- `playbook.md`
- `delivery-gate.md`

职责：

- AI 如何读规则
- AI 如何按任务类型路由
- AI 如何进入交付闸门与采证
