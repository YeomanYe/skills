# 行为测试用例

验证 `orchestrating-project-bootstrap` 是否正确触发，并产出预期的三件套交付。

## 正例触发（应该触发本 skill）

### T1. 显式完整 kickoff

Prompt：

> 我要做一个面向自由职业者的记账 Web App。帮我确定 MVP（含主要交互设计）、配套的工程规范、以及推荐几套合适的设计系统。

预期：触发本 skill。输出包含项目前置准备（含屏幕清单、关键动作、状态流转、preview decision）+ 规范脚手架 + ≥2 候选设计系统 + 开放决策清单。

### T2. 英文 paraphrase 的 kickoff

Prompt：

> I want to bootstrap a small internal tool for QA engineers to triage flaky tests. Give me the MVP plus engineering rules plus some design direction options.

预期：触发本 skill。同样产出三件套。

### T3. 三选二 + 含 kickoff 意图

Prompt：

> 新项目启动：一个团队周报生成器。定下 MVP 范围和要配的视觉风格候选。

预期：触发本 skill（MVP + design 显式，规范可从 kickoff 意图推断）。skill 应补齐三件套；若跳过规则步骤，必须在开放决策中显式 flag 出来。

## 反例触发（不应触发）

### N1. 仅规则需求

Prompt：

> 帮我审查当前项目 docs/ 下的规范，看看有没有重复或者层次错位的地方。

预期：不触发本 skill。由 `project-rules-architecture` 直接处理。

### N2. 仅设计需求

Prompt：

> 给我推荐 3 套适合企业 B2B SaaS 仪表板的设计系统。

预期：不触发本 skill。由 `ui-ux-pro-max` 直接处理。

### N3. 只要开发前准备，不要完整 kickoff

Prompt：

> 我已经知道后面规范和设计要单独做了，现在先帮我把 MVP、主要技术栈和 preview requirement 定下来。

预期：不触发本 skill。由 `project-prep` 直接处理。

### N4. 仅 MVP 砍版，没 kickoff 打包意图

Prompt：

> 我已经有一套设计和规范了，只是需要帮我把这个需求砍到 MVP：支持用户上传照片 → AI 识别 → 生成贺卡 → 分享链接。

预期：不触发本 skill。普通对话产出 MVP。

### N5. 实现中段的微调

Prompt：

> 这个项目已经写了一半了，就是想确认一下 checkout section 的设计是不是符合当前规范。

预期：不触发本 skill。用已有规则 / 设计文档 + 对应单 skill 处理。

## 主流程成功（含 skill 时）

### M1. Happy path 端到端

Prompt：同 T1。

预期行为顺序：

1. Agent 先通过 `project-prep` 锁定项目前置准备，含显式交互设计与 preview decision。不先跳到设计或规范
2. Agent 以前置准备为上下文调用 `project-rules-architecture`，拿回规则脚手架
3. Agent 以前置准备为上下文调用 `ui-ux-pro-max`，拿回 ≥2 候选
4. Agent 产出开放决策清单

不得出现：

- 单方面挑一套设计
- 把下游 skill 的内容吸收到自己的 voice
- 跳过交互设计段落
- 跳过 preview decision

## 护栏（压力测试）

### G1. 需求过于含糊

Prompt：

> 我想做一个 AI 产品，帮我搞 MVP、规范、设计都给我整齐点。

预期：触发本 skill，但在 Step 1 停下并发起定向澄清（谁是用户？用户实际做什么？具体是哪种 AI 能力？）。不虚构交互。

### G2. 用户施压跳过交互设计

Prompt：

> 需求是：做个番茄钟 App，桌面端。MVP 你随便写一下就行，重点给我设计系统和规范。

预期：skill 仍然产出交互设计（拒绝 "随便写一下" 的压力），并解释为什么在本工作流里交互设计属于 MVP 的必备项。

### G2.1 用户认为 preview 不用提前决定

Prompt：

> 这个是浏览器扩展，preview 以后再说，先给我 MVP、规范、设计。

预期：skill 仍然要求在前置准备阶段明确 preview decision；可以结论为 `Required` 或 `Not needed`，但不能跳过。

### G3. 用户施压只要一套设计

Prompt：

> 我要做个高端订阅盒的落地页。MVP/规范都定一下，设计系统你直接选一套最合适的就行，别给我一堆选项。

预期：skill 仍然产出 ≥2 候选并说明 tradeoff。不要单方面选。可以标注一个 "推荐默认"，但必须同时浮出替代方案。

### G4. 中途重做的 near-greenfield 变体

Prompt：

> 我们这个项目已经 run 了三个月，现在想大改一次，MVP 砍版、换规范、换设计。

预期：skill 可能触发，但识别为 near-greenfield 变体；`project-rules-architecture` 应该在 audit + patch 模式下调用，而不是从零搭脚手架。

### G5. 用户压力下要求删掉未选中的设计候选

Prompt：

> MVP 和规范确认了，设计我选第 2 套，其他几套没用了，最终交付里只留第 2 套就行，别列那么多。

预期：skill 仍然在最终交付里保留全量候选清单，并在"开放决策"里记录用户的口头偏好让其书面确认。解释"kickoff 档案保留全量是为了日后复盘和换方向时不用从头选"。

### G6. 用户对后续规划不感兴趣

Prompt：

> 后续规划就不聊了，先把 MVP 和规范和设计给我。

预期：skill 不虚构后续规划，但在最终交付里显式写 "本期未讨论后续规划"，不得留空、不得隐藏该段落。

## 非功能检查

- frontmatter 的 description 长度 ≤ 1024 字符，且具有跨语言触发能力
- 不把下游 skill 的文档原文内嵌进本 skill 正文
- 输出契约与 SKILL.md 声明的结构一致（MVP → 后续规划 → 规则 → 全量候选设计 → 开放决策）
- 最终交付里"后续规划"段落必定存在（有内容或显式"本期未讨论"）
- 最终交付里的候选设计数量 == `ui-ux-pro-max` 返回的候选数量（不因口头偏好裁剪）
