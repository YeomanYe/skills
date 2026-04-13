---
name: skill-integration-testing
description: Use when testing whether multiple skills work correctly as a chain, especially when you need to verify routing decisions, context handoff, redundant user questions, or downstream execution readiness across a multi-skill workflow.
---

# Skill Integration Testing

## 概览

这个 skill 用于测试多个 skill 串联后的整体链路是否按预期工作。

它关注的不是单个 skill 自己是否合规，而是：

- skill 之间是否正确流转
- 上下文与约束是否完整传递
- 下游 skill 是否重复追问本可从上下文推断的信息
- 链路最终是否进入预期阶段

这个 skill 默认做集成测试，不替代单个 skill 的行为测试。

## 适用时机

- 你已经有 2 个或以上会串联使用的 skill
- 你想验证某条 skill 链是否会丢失上下文、错误流转或重复提问
- 你想确认某个 skill 的输出是否足够让下游 skill 直接接手
- 你要测试类似 `delivery-gate -> writing-plans -> subagent-driven-development` 这样的链路

以下情况不要使用：

- 你只测试单个 skill 的触发与行为
- 你只是想人工阅读多个 skill，而不验证链路效果

## 测试模式

始终先确定模式，再执行测试。

### `auto`

默认模式。先读取整条 skill 链，再自动选择：

- 规则型、规划型、流转型链路：优先 `context`
- 明显依赖真实页面、真实命令、真实录屏证据的链路：升级为 `live`
- 只做极快回归、只验证流转逻辑时：可降为 `mock`

### `mock`

只做文本级链路模拟。

- 不改代码
- 不跑命令
- 不启动服务
- 不打开浏览器

适合测：

- skill 链是否应当触发
- 流转顺序是否正确
- 是否出现明显多余追问

### `context`

允许读取 skill、本地规则、测试 case、handoff、plan 和伪证据，但不做真实外部交互。

- 可以读取每个目标 skill 的 `SKILL.md`
- 可以读取 skill references 和 tests
- 可以读取相关仓库规则、handoff、plan、伪验证记录
- 不启动浏览器
- 不启动服务

适合测：

- skill 链能否在现有上下文下顺畅衔接
- 下游 skill 是否还会重复向用户提问
- 上游输出是否足以支撑下游执行

### `live`

允许真实工具与最小必要外部交互。

- 可以读文件
- 可以跑命令
- 可以打开浏览器
- 可以访问页面

仅在链路明确依赖真实证据时启用，例如：

- 上游需要 Playwright 事实发现
- 中间节点需要真实录屏或真实联调端口
- 下游执行准备依赖真实环境状态

## 必要输入

测试前至少明确：

- 目标 skill 链
- 测试目标
- 测试模式：`mock` / `context` / `live` / `auto`

若用户未指定模式，默认使用 `auto`。

## 测试资产放置约定

测试时区分两类资产：

- 固定测试用例定义
- 每次执行结果

固定测试用例定义优先放在：

- 主导 skill 的 `tests/`
- 或单独的链路测试 skill 目录下的 `tests/`

建议命名：

- `tests/cases.md`
- `tests/chain-*.md`

这里放：

- skill 链定义
- 输入场景
- 预期流转
- 预期禁止行为
- 断言项

每次执行结果不要写回 skill 正文，应放在目标仓库中被 Git 忽略的临时目录。

## 核心流程

### 1. 读取整条 skill 链

按顺序读取每个 skill 的：

- 触发条件
- 输出要求
- 常见错误
- 下游衔接点

同时读取链路相关的：

- 固定测试用例
- handoff 模板
- 计划模板
- 仓库规则

提炼 5 类信息：

- 链路入口条件
- 每一步必须交出的产物
- 每一步禁止行为
- 下游接手所需的最小输入
- 链路完成判定

### 2. 识别链路断点

每次至少检查：

- 上游是否真的产出下游需要的输入
- 下游是否仍然要求用户重复说明已知信息
- 流转时是否丢失关键字段、约束或风险
- 链路是否错误回退到用户澄清
- 链路是否提前宣称完成

特别关注：

- `delivery-gate -> writing-plans`
- `writing-plans -> subagent-driven-development`
- 任意链路中的“已有足够上下文却仍继续追问”

### 3. 生成集成测试矩阵

每次至少覆盖以下 4 类用例：

- 正常流转：上游输出足够，下游应直接接手
- 反例流转：上游输出不足，下游应指出缺口，而不是假装继续
- 冗余追问：上下文已足够，下游不应继续问用户
- 字段保真：关键约束、todo、风险、验证要求是否完整传递

复杂链路再加：

- 分支流转：根据条件走不同 skill
- 回归场景：专门覆盖最近修复过的链路问题

### 4. 生成测试提示词

每个用例都输出：

- 测试名称
- skill 链
- 输入场景
- 建议 prompt
- 预期流转
- 失败信号

如果是 `mock` 或 `context`，prompt 中应明确加入：

- 不要修改代码
- 不要启动服务
- 只根据我提供的假设信息模拟整条 skill 链

如果是 `live`，则明确说明允许：

- 打开浏览器
- 读取页面
- 运行必要命令

### 5. 执行快速集成测试

默认执行快速测试，而不是完整真实回归。

- `mock`：只测流转逻辑
- `context`：测规则、handoff、plan 与执行准备是否能衔接
- `live`：只做最小必要真实检查，不扩展到完整实现

### 6. 输出集成测试报告

必须明确区分：

- 通过
- 失败
- 未覆盖
- 需要真实抽检

## 输出结构

使用以下结构：

```md
## Skill Integration Test Report

### Chain
- Skills:
- Mode:
- Goal:

### Extracted Contract
- Entry conditions:
- Required handoff artifacts:
- Forbidden chain behaviors:
- Completion contract:

### Integration Test Matrix
- Case 1:
- Case 2:
- Case 3:

### Suggested Prompts
- Prompt 1:
- Prompt 2:

### Quick Results
- Passed:
- Failed:
- Not covered:

### Findings
- Finding 1:
- Finding 2:

### Recommendation
- Ready:
- Needs revision:
- Recommend live check:
```

## 判定规则

如果链路出现以下任一问题，应判定为失败：

- 上游输出不足以下游接手，却仍强行流转
- 下游重复询问已在上下文、handoff、plan 或规则中明确给出的信息
- 关键字段在流转中丢失，例如：
  - must-fix / should-fix
  - todo
  - 风险
  - 录屏要求
  - 端口约束
  - 数据安全约束
- 链路顺序错误
- 中途错误宣称完成

## 特别规则：关于用户提问

集成测试时，必须专门判断“是否出现不必要的向用户提问”。

以下情况应判定为冗余追问：

- 上游 handoff 已提供足够信息
- 仓库规则已明确约束
- todo 已具体到可拆解或可执行
- skill 之间只是没有认真消费已有上下文

以下情况允许向用户提问：

- 关键事实缺失且无法从本地上下文推断
- 目标本身存在多解且风险较高
- 上游产物明确标记了未决假设，且这些假设会阻断后续工作

## 建议工作方式

优先顺序：

1. 先用 `context` 跑链路模拟
2. 找出是否存在冗余追问与上下文丢失
3. 只有当链路依赖真实外部证据时，再补少量 `live` 抽检

如果某条链路失败，优先回答：

- 是哪个 skill 的输出不够
- 是哪个 skill 没有消费已有输入
- 是链路设计问题，还是单个 skill 自身问题
