---
name: orchestrating-skill-development
description: Use when creating or substantially updating a skill and you need a structured workflow for scoping, authoring, testing, and reporting the result
---

# Orchestrating Skill Development

## Overview

这个 skill 用于编排完整的 skill 开发流程。

它不替代 `skill-creator`、`writing-skills`、`skill-behavior-testing` 或 `skill-integration-testing`。
它的职责是决定何时调用这些 skill、强制执行顺序，并要求真实落盘、真实测试和最终输出报告。

默认行为是执行，不是只给流程建议。

## When to Use

以下情况使用本 skill：

- 新建一个 skill
- 对已有 skill 做实质性流程变更
- 修改 skill 的触发条件、输出契约、路由行为或 handoff 行为
- 准备把 skill 交付为可复用能力，并希望补齐测试与交付报告

以下情况通常不要使用本 skill：

- 只修正文案、错别字
- 只补充不影响行为的 reference 内容
- 只改很小的 metadata，且不影响触发和流程

## Execution Default

当本 skill 被触发时，默认直接推进到可交付产物，除非缺少关键上下文。

默认应执行到以下终点：

- 真实创建或修改目标 skill 文件
- 真实创建或修改目标 `tests/` 用例
- 真实执行行为测试
- 命中 gate 时真实执行集成测试
- 当目标 skill 需要进入全局复用范围时，调用 `sync-skill-to-center`
- 输出最终报告

不要停留在：

- 只给流程建议
- 只给 `SKILL.md` 草稿
- 只给测试思路，不实际补用例
- 只说“建议运行测试”，但没有实际执行

只有在以下情况下才应暂停并向用户说明：

- 缺少目标 skill 名称或目标位置，且无法合理推断
- 本次请求的职责边界本身不清，继续写会导致 skill 定义错误
- 工作区存在直接冲突，无法安全落盘

## Required Workflow

必须严格按以下顺序执行：

1. 先判定本次工作类型
2. 调用 `skill-creator` 理清范围与契约
3. 调用 `writing-skills` 编写或修订 skill
4. 运行 `skill-behavior-testing`
5. 判定是否需要 `skill-integration-testing`
6. 若需要，则运行 `skill-integration-testing`
7. 判定是否需要调用 `sync-skill-to-center`
8. 输出最终报告

在最终报告完成前，不得宣称该 skill 已准备就绪。
除非命中暂停条件，否则不要在中途停下来等待用户二次确认。

## Step 1: Classify the Work

先判断本次请求属于哪一类：

- `new-skill`
- `substantial-update`
- `minor-update`

若改动涉及以下任一项，应视为 `substantial-update`：

- 触发条件
- 必要流程
- 禁止行为
- 输出契约
- handoff 契约
- 上下游路由行为

如果只是 `minor-update`，通常不必使用这个 orchestrator。

## Step 2: Scope With `skill-creator`

在编写或修订 skill 之前，必须先用 `skill-creator` 理清：

- 这个 skill 负责什么
- 什么情况应该触发
- 什么情况不该触发
- 它是单体能力还是多-skill 链路中的一环
- 是否需要额外资源

此步骤结束后，必须提炼并记录：

- skill 名称
- 触发条件
- 边界
- 所需资源
- 预期输出或 handoff 产物

如果这些信息已经能从当前请求和上下文中可靠推断，应直接整理并继续，不要为已知信息重复追问用户。

## Step 3: Author With `writing-skills`

使用 `writing-skills` 编写或修订 skill 正文。

如果当前环境中的 `writing-skills` 明确要求先满足某个前置 skill 或前置方法论，也必须先补齐该前置条件，再继续进入编写阶段。

这一阶段必须产生真实文件变更，而不是只输出建议文本。

执行时强制遵守以下规则：

- **语言约定**：SKILL.md 正文、`tests/` 用例、`references/` 等附加资产默认使用中文；技术术语、工具名、命令、配置键、文件路径、代码、frontmatter 字段名保持英文原文不翻译
- **description 语言**：frontmatter 的 `description` 允许中英文并存——可以纯中文、纯英文或中英混合列出触发短语，目的是提升跨语言召回（例如同时写 "项目初始化" 与 "bootstrap this project"）
- frontmatter 的 description 只写触发条件，不要摘要化流程
- 正文保持简洁、偏流程化
- 不要把下游测试 skill 的完整内容复制进来
- 如果可复用测试场景有价值，应补充 `tests/` 资产
- 尽量写成明确 gate，不要写模糊建议

至少应创建或更新：

- 目标 skill 的 `SKILL.md`
- 必要时的 `tests/cases.md` 或等价测试用例文件

## Step 4: Run Behavior Testing

在宣称 skill 已可用之前，必须运行 `skill-behavior-testing`。

行为测试至少覆盖：

- 一个正例触发场景
- 一个反例触发场景
- 一个主流程成功场景
- 一个负例或护栏场景

如果 skill 目录下已经有可复用的 `tests/`，必须优先复用。
不要只生成测试提示词而不执行测试。

## Step 5: Decide Whether Integration Testing Is Required

集成测试是“条件必跑”，不是一律必跑。

若满足以下任一条件，必须运行 `skill-integration-testing`：

- 该 skill 会参与多-skill 工作流
- 该 skill 会将工作 handoff 给其他 skill
- 该 skill 依赖上游 skill 提供 plan、handoff、evidence 或 contract 输入
- 该 skill 本身就是 orchestrator、router、gate 或 workflow coordinator
- 本次改动影响路由、handoff 字段、上下文传递或“禁止重复追问”策略

只有同时满足以下条件，才可以跳过集成测试：

- 该 skill 是单体能力
- 本次改动不影响触发条件或流程契约
- 本次改动不影响上下游协作

若跳过集成测试，必须在最终报告中说明原因。

## Step 6: Run Integration Testing When Required

当集成测试是必需项时，使用 `skill-integration-testing` 验证：

- 是否正确进入 skill 链路
- 是否正确 handoff 给下游 skill
- 关键约束和产物是否完整保留
- 在上下文已足够时是否避免冗余追问
- 是否避免过早宣称完成

不要把“理论上应该能衔接”当作集成测试通过；至少要完成一次基于真实 skill 文件和测试资产的链路检查。

## Step 7: Sync To Center When Needed

`sync-skill-to-center` 不是一律必跑，而是条件必跑。

若满足以下任一条件，应在收尾阶段调用 `sync-skill-to-center`：

- 用户明确希望该 skill 进入全局复用范围
- 该 skill 不仅用于当前项目，还应在其他上下文中复用
- 本次工作目标明确包含“发布到全局”或“纳入 skillshare source”

若满足以下任一条件，则不要调用：

- 该 skill 明确只应保留在当前项目内
- 当前产物仍是半成品，不应覆盖全局版本
- 用户明确表示本次只做本地迭代，不做全局发布

若调用该 skill，默认只同步到 `~/.config/skillshare/skills/`。
不要把“同步到编辑器或 agent 自己的全局目录”视为该步骤的职责。

若跳过该步骤，必须在最终报告中明确说明原因。

## Missing Dependency Fallbacks

如果目标环境缺少某个依赖 skill，不要直接中断；应退化为最小可执行流程，并在最终报告中明确说明。

### `skill-creator` 缺失

如果 `skill-creator` 不可用，至少要手工补齐以下设计输入后，才能继续编写：

- skill 名称
- 触发条件
- 不应触发的场景
- 核心职责
- 边界
- 是否属于多-skill 链路
- 预期输出或 handoff 产物

若以上信息仍不完整，不应继续进入编写阶段。

### `writing-skills` 缺失

如果 `writing-skills` 不可用，按以下最小写法手工完成：

1. 先写正反触发场景
2. 再写最小可用的 `SKILL.md`
3. 明确禁止行为与完成判定
4. 补充可复用的 `tests/` 用例骨架
5. 再进入行为测试

不要因为 `writing-skills` 缺失就跳过测试或直接宣称完成。

### `skill-behavior-testing` 缺失

如果 `skill-behavior-testing` 不可用，至少手工完成以下四类检查，并记录到最终报告：

- 正例触发
- 反例触发
- 主流程成功场景
- 护栏或负例场景

手工验证不等于免测，只是降级执行。

### `skill-integration-testing` 缺失

如果 `skill-integration-testing` 不可用，但当前 skill 命中了集成测试 gate，至少手工检查：

- 上游输入是否足够让下游接手
- handoff 字段是否完整
- 是否会重复向用户追问已知信息
- 是否会过早宣称完成

这种情况不得标记为“完整通过的集成测试”，只能标记为“手工链路检查已完成”。

## Step 8: Write the Final Report

始终以书面报告收尾，使用以下结构：

```md
## Skill Development Report

### 目标
- Skill:
- 路径:
- 范围:
- 类型: new | update

### 设计摘要
- 触发条件:
- 核心职责:
- 边界:
- 所需资源:

### 编写流程
- skill-creator:
- writing-skills:
- 文件变更:
- 备注:

### 行为测试
- 状态:
- 测试方式: skill | manual
- 关键用例:
- 发现:

### 集成测试
- 是否必需:
- 状态:
- 测试方式: skill | manual | skipped
- 原因:
- 发现:

### 中心同步
- 是否需要:
- 状态:
- 测试方式: sync-skill-to-center | skipped
- 目标路径:
- 原因:

### 风险
- 风险 1:
- 风险 2:

### 结论
- 可交付:
- 需要修订:
- 建议下一步:
```

最终报告还必须包含：

- 本次新增或修改的文件路径
- 是否真实落盘
- 是否真实执行了行为测试
- 是否真实执行了集成测试，或为何跳过
- 是否真实执行了中心同步，或为何跳过

## Completion Rules

如果出现以下任一情况，则该 skill 不应被视为完成：

- 新建 skill 或实质性更新时跳过了 `skill-creator`
- 没有运行 `skill-behavior-testing`
- 集成测试是必需项但没有执行
- 跳过了集成测试但没有给出理由
- 需要进入全局复用范围但没有调用 `sync-skill-to-center`
- 缺少最终报告
- 只输出建议，没有实际创建或修改 skill 文件
- 只写了测试思路，没有实际执行测试

若因依赖缺失而走降级流程，最终报告中还必须额外说明：

- 缺失的是哪个 skill
- 使用了哪种降级方式
- 因降级而残留的风险是什么

## Minimal Operating Principle

这个 orchestrator 的存在，是为了拦住三类常见失败：

- 在触发条件和边界尚未明确时就开始写 skill
- 写完 skill 但还没测试就宣称可用
- 把链路影响型改动误当成单 skill 改动

它默认是一条执行链，而不是一份建议清单。
