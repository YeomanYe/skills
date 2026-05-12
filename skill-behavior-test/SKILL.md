---
name: skill-behavior-test
description: Use when testing whether a single skill actually triggers and behaves correctly, especially when you need fast mock/context simulations or a live browser-backed check for skills that depend on external evidence.
---

# Skill Behavior Testing

## 概览

这个 skill 用于测试单个 skill 是否真的按预期工作。

它的目标不是“复述 skill 文档”，而是验证：

- 该触发时会不会触发
- 不该触发时会不会误触发
- 行为是否符合 skill 规定
- 输出是否符合 skill 约束
- 是否能拦住 skill 明确禁止的行为

这个 skill 默认做单元测试，不负责多个 skill 的组合联动测试。

## 适用时机

- 你刚创建或修改了一个 skill，想快速验证它是否有效
- 你怀疑某个 skill 的触发条件写得不对
- 你想确认 skill 会不会漏掉关键步骤、错误流转或偷懒跳步
- 你想在不跑完整真实流程的情况下，快速做 skill 回归测试

以下情况不要使用：

- 你要验证多个 skill 串联后的整体工作流
- 你只是想人工阅读一个 skill，而不做行为测试

## 测试模式

始终先选择模式，再开始测试。

### `auto`

默认模式。先读目标 skill，再自动选择：

- 纯流程型、输出型、规则型 skill：优先 `context`
- 明显依赖浏览器、页面交互、截图、录屏、网络行为证据的 skill：升级为 `live`
- 只需极快回归、无需读取真实上下文时：可降为 `mock`

### `mock`

只做文本模拟。

- 不改代码
- 不跑命令
- 不启动服务
- 不打开浏览器

适合测：

- 触发条件
- 输出结构
- must/should 判定
- 流程是否跳步

### `context`

允许读取目标 skill、本地文件、引用文档和伪证据，但不进入真实外部交互。

- 可以读取 `SKILL.md`
- 可以读取 skill references
- 可以读取相关规则、diff、handoff、伪验证记录
- 不启动浏览器
- 不启动服务

适合测：

- skill 是否能基于真实上下文做判断
- skill 是否会正确引用规则
- skill 是否能从证据中发现问题

### `live`

允许使用真实工具与外部证据。

- 可以读文件
- 可以跑命令
- 可以打开浏览器
- 可以访问页面

仅在目标 skill 明确依赖真实交互证据时启用，例如：

- Playwright 探索
- 页面行为发现
- 录屏要求
- 网络请求观察

## 必要输入

测试前至少明确：

- 目标 skill 名称或路径
- 测试目标
- 测试模式：`mock` / `context` / `live` / `auto`

若用户未指定模式，默认使用 `auto`。

## 测试资产放置约定

测试时区分两类资产：

- 固定测试用例定义
- 每次执行结果

固定测试用例定义应优先放在目标 skill 目录下，例如：

- `<skill>/tests/cases.md`
- `<skill>/tests/case-01-*.md`

这里放：

- 测试 case
- prompt 模板
- expected
- assertion

每次执行结果不要写回 skill 正文，应放在目标仓库中“被 Git 忽略的临时目录”。

优先级：

1. 如果目标仓库已有明确约定的 Git 忽略临时目录，就使用该目录
2. 如果目标 skill 已有现成 `tests/` 目录，优先复用其中的测试 case
3. 若两者都不存在，再临时生成测试模板

执行结果目录中放：

- 实际输出
- 临时日志
- 截图或录屏
- 一次性测试报告

不要把一次性执行结果直接沉入 skill 目录。

## 核心流程

### 1. 读取目标 skill

读取目标 skill 的：

- frontmatter
- 适用时机
- 必要流程
- 输出要求
- 常见错误
- 相关 reference 文件（按需）

如果目标 skill 目录下存在 `tests/`，必须优先读取并复用其中已有的测试用例，而不是从头重新发明测试场景。

提炼出 5 类信息：

- 触发条件
- 必做动作
- 禁止行为
- 输出结构
- 判定门槛

### 2. 生成测试矩阵

每次至少覆盖以下 4 类用例：

- 正例触发：应该触发 skill
- 反例触发：不应该触发 skill
- 主流程：skill 在理想输入下是否按规定工作
- 负例场景：skill 是否能拦住违反规则的情况

如目标 skill 比较复杂，再加：

- 边界场景：信息不完整、证据缺失、要求冲突
- 回归场景：专门覆盖最近修复过的问题

### 3. 生成测试提示词

每个用例都输出：

- 测试名称
- 输入场景
- 建议 prompt
- 预期行为
- 失败信号

如果是 `mock` 或 `context`，prompt 中应明确加入：

- 不要修改代码
- 不要启动服务
- 只根据我提供的假设信息模拟执行

如果是 `live`，则明确说明允许：

- 打开浏览器
- 读取页面
- 运行必要命令

### 4. 执行快速测试

默认执行快速测试，而不是完整真实回归。

- `mock`：直接用文本场景测试
- `context`：使用文件与伪证据测试
- `live`：只执行最小必要的真实步骤，不做无关扩展

### 5. 输出测试报告

必须明确区分：

- 通过
- 失败
- 未覆盖
- 需要真实抽检

## 输出结构

使用以下结构：

```md
## Skill Test Report

### Target
- Skill:
- Mode:
- Goal:

### Extracted Contract
- Trigger conditions:
- Required actions:
- Forbidden behaviors:
- Output contract:

### Test Matrix
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

如果目标 skill 出现以下任一问题，应判定为失败：

- 该触发时未触发
- 不该触发时误触发
- 漏掉 skill 中的关键步骤
- 输出结构偏离 skill 明确要求
- 放过了 skill 本应拦住的问题
- 把 skill 明确禁止的行为合理化

若只是表述风格不同，但行为与结论仍满足 skill 要求，可判定为通过。

## 模式选择启发式

- 规则审查、流程分流、写作 handoff、计划拆解类 skill：优先 `context`
- 依赖页面观察、交互录制、网络证据的 skill：优先 `live`
- 只想快速验证触发与输出格式：优先 `mock`

## 常见错误

- 把 skill 测试当成普通摘要任务
- 只检查“能不能复述规则”，不检查“会不会按规则行动”
- 一上来就跑完整真实场景，导致成本过高
- 用组合工作流去测试单个 skill，导致失败原因无法定位
- 在 `mock` 模式下偷偷引入真实外部证据，污染测试边界
- 在 `live` 模式下做超出测试目标的实现工作
