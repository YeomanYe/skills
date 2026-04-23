# 链路测试用例

验证 `orchestrating-project-bootstrap -> project-prep -> project-rules-design / ui-ux-pro-max` 的衔接是否完整。

## C1. 正常流转

输入：

> 我要启动一个浏览器扩展项目：抓取当前页面商品信息，做收藏和价格提醒。帮我做完整 kickoff，先定 MVP，再给规范和设计方向。

预期：

- 入口应触发 `orchestrating-project-bootstrap`
- Step 1 应先进入 `project-prep`
- prep 产出里应包含 preview decision
- 后续规则与设计阶段不应重复追问已在 prep 中明确的用户、主流程、技术栈、preview 背景

失败信号：

- bootstrap 直接内嵌写 Step 1，不经过 prep
- 下游还在重复问“要不要 preview”“主要技术栈是什么”
- 最终交付遗漏 preview decision

## C2. 反例流转

输入：

> 这个项目我只需要先定 MVP、主要技术栈、要不要做 preview，规范和设计以后再说。

预期：

- 不应触发 `orchestrating-project-bootstrap`
- 应直接路由到 `project-prep`

失败信号：

- 仍然强行进入完整 kickoff 三件套

## C3. 字段保真

输入：

> 我要做一个桌面端写作工具，先完整 bootstrap。它已经有 demo route 和 mock fixture。

预期：

- prep 阶段应给出 `Preview decision: Already satisfied`
- bootstrap 最终交付里必须保留这一结论，不能丢掉或改写成 `Required`

失败信号：

- 上游给了 `Already satisfied`，下游汇总时丢失
- 最终开放决策里没有 preview 相关确认项
