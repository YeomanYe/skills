# 行为测试用例

验证 `project-prep` 是否能在项目开发前正确产出 MVP、主技术栈与 preview 决策。

## 正例触发

### T1. 新项目开工前准备

Prompt：

> 我要做一个 AI 面试助手，先帮我定 MVP、主要技术栈，以及要不要单独做 preview。

预期：触发本 skill。输出包含主交互设计、主技术栈、preview decision。

### T2. 浏览器扩展需要 preview 判断

Prompt：

> 我想做一个浏览器扩展，把当前页面高亮内容收集起来再生成摘要。先别写代码，帮我整理开工前准备，尤其看看要不要加一个 web preview。

预期：触发本 skill。通常给出 `Preview decision: Required`，并说明可先做 mock web preview 走查 UI，再回到真实浏览器测试。

### T3. 已有 preview 配置

Prompt：

> 我们要启动一个桌面应用项目，但仓库里已经有一套 demo route 和 mock fixture。帮我定 MVP、主要技术栈，并判断 preview requirement 还要不要再加。

预期：触发本 skill。若现有 demo 覆盖核心流，应判为 `Already satisfied`，而不是重复加要求。

## 反例触发

### N1. 只要工程规范

Prompt：

> 帮我给这个项目补一套 CONTRIBUTING 和 docs 规则结构。

预期：不触发本 skill。应路由到项目规范相关 skill。

### N2. 只要设计方向

Prompt：

> 给我推荐几套适合内容产品的设计系统。

预期：不触发本 skill。

### N3. 已经在实现中段

Prompt：

> 这个扩展已经开发到一半了，我只想补一下 popup 的一个 loading 态。

预期：不触发本 skill。

## 主流程成功

### M1. Happy path

Prompt：同 T2。

预期行为顺序：

1. 先锁定 MVP 与主交互设计
2. 再给出主要技术栈
3. 再判断 preview 是否需要新增
4. 最终给出可执行的 prep brief

不得出现：

- 只给功能列表，不写交互
- 因为是 extension 就机械要求完整 web 复制品
- 不检查现有 preview 就新增第二套 preview

## 护栏

### G1. 需求过于含糊

Prompt：

> 我要做个 AI 产品，先把前置准备都帮我定了。

预期：skill 应停下并追问用户、核心流、主要界面，而不是直接编故事。

### G2. 普通 web 项目不应强加 preview

Prompt：

> 我要做一个普通的 SaaS 管理后台，前后端都在同一个 web 工程里。帮我定一下开工前准备。

预期：若主工程本身就支持 mock 驱动走查，应倾向 `Not needed`，并说明原因。

### G3. 用户试图用 preview 替代真实测试

Prompt：

> 我们做个浏览器扩展，只要补一个 web preview 就行，真实浏览器测试就先不做了。

预期：skill 必须明确拒绝把 preview 当真实测试替代，并给出“preview 先走查，真实环境后验证”的顺序。
