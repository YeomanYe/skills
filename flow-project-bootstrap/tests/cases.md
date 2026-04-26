# 行为测试用例

验证 `flow-project-bootstrap` 的两阶段编排是否正确触发，并产出预期的两阶段交付。

> 2026-04-26 重大重构：从原"三件套"输出（MVP / 规范 / 设计）改为**两阶段产物**——
> - Stage 1 → 总设计文档（MVP + 流程图 + 交互 + 技术栈 + preview 设计 + 设计系统候选 + 部署方案 + 后续规划 + 待锁定决策）
> - Stage 2 → 工程规范 + 项目 logo + 可访问的 preview 页 + 双向链接

## 正例触发（应该触发本 skill）

### T1. 显式完整 kickoff

Prompt：

> 我要做一个面向自由职业者的记账 Web App。帮我从头初始化项目，定 MVP、规范、推荐设计系统，最后给我一个能跑的 preview。

预期：触发本 skill。Stage 1 输出**总设计文档**含 9 节齐全（MVP / ASCII 流程图 / 交互 / 技术栈 / preview 设计 / 候选设计系统 / 部署方案 / 后续规划 / 待锁定决策）；Stage 2 输出工程规范 + ≥2 个 logo 方向 + preview 页 + 双向链接。中间有 user gate。

### T2. 英文 paraphrase 的 kickoff

Prompt：

> I want to bootstrap a small internal tool for QA engineers to triage flaky tests. Give me the full kickoff: MVP, rules, design candidates, logo, and a deployed preview page.

预期：触发本 skill。两阶段全跑通，logo + preview 都要落地。

### T3. 三选二 + 含 kickoff 意图

Prompt：

> 新项目启动：一个团队周报生成器。定下 MVP 范围和要配的视觉风格候选。

预期：触发本 skill（含 kickoff 意图，自动补齐缺的两件）。skill 应在 Stage 1 总设计文档里齐全输出，并触发 user gate；进入 Stage 2 后产 logo + preview。

## 反例触发（不应触发）

### N1. 仅规则需求

Prompt：

> 帮我审查当前项目 docs/ 下的规范，看看有没有重复或者层次错位的地方。

预期：不触发。由 `flow-project-rules` 或 `project-rules-design` 直接处理。

### N2. 仅设计需求

Prompt：

> 给我推荐 3 套适合企业 B2B SaaS 仪表板的设计系统。

预期：不触发。由 `ui-ux-pro-max` 直接处理。

### N3. 只要开发前准备

Prompt：

> 我已经知道后面规范和设计要单独做了，现在先帮我把 MVP、主要技术栈和 preview requirement 定下来。

预期：不触发。由 `project-prep` 直接处理。

### N4. 只要 logo

Prompt：

> 给我设计 3 个 logo 方向，项目叫 RoboMail，赛博朋克风。

预期：不触发。由 `huashu-design` 直接处理。

### N5. 只要 preview 页（已有设计文档）

Prompt：

> 我已经有总设计文档了，按里面的 design system 帮我做一个 preview 页就行。

预期：不触发。由 `huashu-design` / `frontend-design` 直接处理。

### N6. 实现中段微调

Prompt：

> 这个项目已经写了一半了，就是想确认一下 checkout section 的设计是不是符合当前规范。

预期：不触发。

## Stage 1 主流程成功

### M1. Happy path: Stage 1

Prompt：同 T1。

预期 Stage 1 行为顺序：

1. 调 `project-prep` 锁定 MVP / 交互 / 技术栈 / preview decision
2. 把核心流转成 ASCII 流程图（嵌入总设计文档第 2 节）
3. 完成 preview 设计（如 Required，必含 Component reuse plan）
4. 调 `ui-ux-pro-max` 拿 ≥2 候选设计
5. 检测仓库可见性（`gh repo view --json visibility -q .visibility` 或 fallback），路由部署目标（public→GH Pages / private→Cloudflare）
6. 写出"后续规划"段落（或显式"本期未讨论"）
7. **触发 user gate**，列出 5 项决策让用户回答

不得出现：

- 没有 ASCII 流程图就交付
- 单方面挑一套设计
- 把 preview 决策推到 Stage 2 再说
- 私有仓库默认走 GitHub Pages
- 没触发 user gate 直接进 Stage 2

## Stage 2 主流程成功

### M2. Happy path: Stage 2（在 Stage 1 已锁定后）

模拟上下文：用户回复 "MVP OK / preview 用方案 1 / 设计系统选第 2 套 / 部署 GitHub Pages / 后续规划 OK"。

预期 Stage 2 行为顺序：

1. 调 `project-rules-architecture` 出工程规范（带上 Stage 1 锁定的技术栈）
2. 调 `huashu-design` 出 ≥ 2 个 logo 方向（用 Stage 1 选定设计系统的配色 + 字体）
3. 实现 preview 页（套已选设计系统 token + 真实组件复用 / 占位组件 + 切回 deadline）
4. 部署 preview 页到目标平台（GitHub Pages / Cloudflare）
5. **回填总设计文档**第 5 节的"预览页地址"为真实 URL
6. **在 preview 页头部加"返回总设计文档"链接**

不得出现：

- 用户还没选定一套设计系统就开始出 logo
- logo 只出 1 个方向
- preview 部署后忘记回填总设计文档 URL
- preview 页没有返回总设计文档的链接
- 跳过工程规范

## 护栏（压力测试）

### G1. 需求过于含糊

Prompt：

> 我想做一个 AI 产品，从初始化到 preview 都给我搞定。

预期：触发本 skill，但在 Stage 1 项目前置准备阶段停下并发起定向澄清（谁是用户？用户实际做什么？具体是哪种 AI 能力？）。不虚构交互，不直接进入流程图绘制。

### G2. 用户施压跳过 ASCII 流程图

Prompt：

> 流程图就别画了，文字描述够清楚的。给我 MVP、设计、preview 方案就行。

预期：skill 仍然要求出 ASCII 流程图（拒绝"文字代替"），并解释流程图的作用是"让决策点一眼可见"。

### G3. 用户施压跳过 preview 设计的 Component reuse plan

Prompt：

> 这是浏览器扩展。preview 我打算单独写一份 MockPopup 复制一份组件，反正以后再说。

预期：skill 拒绝"另起 mock 组件"路径（命中 project-prep 反模式），要求写出真实组件路径 + 适配器层切点；提供"零代码阶段"占位的有条件接受路径。

### G4. 用户施压只要一套设计

Prompt：

> 设计系统直接给我选最合适的就行，别给我候选。

预期：skill 仍然产出 ≥2 候选并说明 tradeoff；可以标"推荐默认"，但不得删掉替代候选。

### G5. 用户施压跳 user gate

Prompt：

> 你直接 Stage 1 + Stage 2 一起跑完就行，别问我那些问题。

预期：skill 仍然触发 user gate，理由是"设计系统选哪一套必须用户决定，logo 和 preview 的视觉一致性依赖该选择"。可以接受用户提前在同一条消息里回答全部 5 项决策；但不得自己拍板设计系统。

### G6. 私有仓库被默认推到 GitHub Pages

Prompt：

> 我这个是公司内部项目，仓库是 private 的。bootstrap 完整流程。

预期：skill 在 Stage 1 第 7 节明确路由到 **Cloudflare Pages**，不得默认 GitHub Pages（私有仓库走 GH Pages 会暴露内容，本 skill 视为 Red Flag）。

### G7. 公开仓库被过度复杂化为 Cloudflare

Prompt：

> 开源工具站，仓库 public。bootstrap。

预期：skill 默认路由到 GitHub Pages（不要主动推 Cloudflare）；除非用户显式要求其他平台。

### G8. 用户施压用 emoji 当 logo

Prompt：

> logo 你随便选个 emoji 就行，别花时间设计。

预期：skill 拒绝 emoji 占位（除非用户明说"先用文字 logo 占位"），仍要求出 ≥2 个 logo 方向；可以接受"文字 logo 占位 + 标记后续替换"路径。

### G9. Stage 2 没回填 URL 就宣告完成

模拟：preview 页已部署，但总设计文档第 5 节"预览页地址"仍是占位。

预期：skill 视为未完成；Delivery Check 命中"双向链接"项失败，要求回填 URL 后再宣告交付。

### G10. 用户对后续规划不感兴趣

Prompt：

> 后续规划就不聊了，先把当前的 MVP 和规范和设计给我。

预期：skill 不虚构后续规划，但在总设计文档第 8 节显式写"本期未讨论后续规划"，不得留空、不得隐藏该段落。

## 非功能检查

- frontmatter 的 description 长度 ≤ 1024 字符，且具有跨语言触发能力
- 不把下游 skill 的文档原文内嵌进本 skill 正文
- 总设计文档结构与 SKILL.md 声明的 9 节一致
- Stage 1 不写代码 / 不出工程脚手架（顺序门禁）
- Stage 2 必须有 user gate 接收过 Stage 1 用户决策才启动
- Stage 1 / Stage 2 产物拼起来是上述 7 项产物（总设计文档 + 流程图嵌入 + 候选设计 + 工程规范 + logo + preview 页 + 双向链接）
- 私有仓库不能默认 GitHub Pages；公开仓库不能默认 Cloudflare
