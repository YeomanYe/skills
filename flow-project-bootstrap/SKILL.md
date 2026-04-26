---
name: flow-project-bootstrap
description: Use when a user wants a full project kickoff bundle that combines project prep, engineering rules, and design options in one chain. Trigger on requests like "bootstrap this project", "项目初始化", "帮我定 MVP 和规范和设计", "从需求到 kickoff", or any ask that combines MVP scoping, main interaction design, preview requirement decisions, engineering setup, and design direction. Use this orchestrator when the user wants the whole package, not just prep, rules, or design alone.
---

# Orchestrating Project Bootstrap

## Overview

编排器，把原始产品需求转成**两阶段产物**，由用户在第一阶段末尾做关键选择后再进入第二阶段。

- **Stage 1 · 总设计文档（Discovery & Direction）**
  把 MVP、主流程、主交互、预览设计、设计系统候选、部署方案统一汇总成**一份总设计文档**。用户在该阶段末做四件锁定：选 MVP 切片、选 preview 策略、选一套设计系统、确认部署目标。
- **Stage 2 · 工程化产出（Build Scaffold）**
  基于 Stage 1 已锁定决策，产出工程规范、项目 logo、可访问的 preview 页（落地实现 Stage 1 描述的预览设计）。preview 页与总设计文档之间必须有双向链接。

核心原则：
- Stage 1 不写代码，不出工程脚手架；只产出设计文档
- Stage 2 以 Stage 1 的 written choices 为唯一输入；如果 Stage 1 决策未锁定，Stage 2 不得开始
- 两阶段间必须有显式 user gate，不允许从 Stage 1 直接连贯写到 Stage 2

本 skill 不替代下游 skill，它负责编排顺序、强制阶段门、保护用户容易漏提的属性（显式交互设计、preview decision、≥2 套候选设计、部署方案、logo、预览实现）。

## When to Use

- 用户描述一个产品或项目需求并希望拿到完整 kickoff 包
- 用户要求 "MVP / 规范 / 设计 / preview / logo / 部署" 中至少两件 + 含 kickoff 意图
- Greenfield 或近 greenfield（大型重做、品牌重塑属此类）

## When NOT to Use

- 只要开发前准备（MVP / 主技术栈 / preview requirement）—— 直接用 `project-prep`
- 只要 MVP —— 直接写，不要编排
- 只要工程规范 —— 直接用 `project-rules-architecture` 或 `flow-project-rules`
- 只要设计系统建议 —— 直接用 `ui-ux-pro-max`
- 只要 logo 或 preview 页 —— 直接用 `huashu-design` / `frontend-design`
- 项目已进入实现中段，只想调整单一维度

---

## Stage 1 · Discovery & Direction

### 1.1 项目前置准备（调 `project-prep`）

调用 `project-prep` 锁定：

- **MVP 范围**（in scope / out of scope / non-goals）
- **目标用户**与**核心流**（happy path 3-7 步）
- **主交互设计**（屏幕清单 + 关键动作 + 状态流转 + 决策点）
- **主要技术栈**（运行面 + 框架 + 主语言）
- **Preview decision**：`Required` / `Not needed` / `Already satisfied`

### 1.2 主要流程 ASCII 图（必出）

把核心流转化成可读的 ASCII 流程图，至少表达入口 → 关键决策 → 出口。**不允许**只用文字描述代替。

最小可接受形式：

```
[Entry] → (Action) → ⟨Decision?⟩ ─yes→ [State A]
                            └─no──→ [State B] → (Action) → [Exit]
```

复杂流可拆分子图（一图表达不超过 7 个节点）。流程图直接嵌进总设计文档第 2 节。

### 1.3 预览功能设计（必出，遵循 Component reuse 硬性要求）

按 `project-prep` 的 Preview decision 处理：

- **Not needed**（纯 web 项目）→ 写"主工程 dev server 即 preview"，本节结束
- **Already satisfied** → 描述现有 preview 面，本节结束
- **Required** → 必须输出**完整的 preview 设计**，包含：
  - 页面布局与分页策略（单页 vs 多页 / 路由切分逻辑）
  - Mock 数据丰富度（条数、字段多样性、关联分布）
  - 状态切换控制器（至少 normal / empty / loading / error，列出切换方式：DevBar / URL query / 设置面板）
  - **Component reuse plan**：
    - 列出真实组件路径（如 `src/popup/Popup.tsx`）
    - 适配器层切点（storage / platform API / network 在哪一层抽象）
    - 显式禁止：另起 `_preview/MockX.tsx`、把 `if (PREVIEW_MODE)` 写进真实组件
    - 零代码阶段允许临时占位但要写明切回 deadline

**对非 web 站项目（extension / native / widget / 嵌入式）这是硬性要求**，缺任一项 Stage 1 不算完成。

### 1.4 推荐的设计系统（调 `ui-ux-pro-max`，候选 ≥2 套）

调用 `ui-ux-pro-max`，请求原话："Return candidates for user selection with tradeoffs. Do NOT implement or commit to a single direction."

每套候选保留：style 名、配色方向、字体组合、布局密度思路、与其他候选的核心 tradeoff。

### 1.5 部署方案选择

按当前仓库可见性决定部署目标：

| 仓库类型 | 默认部署目标 | 备注 |
|---|---|---|
| **Public**（开源 / 无敏感数据） | **GitHub Pages** | 通过 `.github/workflows/deploy-website.yml` 自动构建 |
| **Private**（闭源 / 含敏感配置 / 商业项目） | **Cloudflare Pages** | Cloudflare 直连 private repo + 不暴露 build 日志 |

判定方式：
1. 优先用 `gh repo view --json visibility -q .visibility`（需要 gh 已登录）
2. 退而其次：`git remote -v` + 用户自述
3. 都拿不到 → 在总设计文档"开放决策"里列为待用户回答

如果用户主动指定其他目标（Vercel / Netlify / 自托管 / 不部署）→ 按用户指示，但仍要在总设计文档记录**为什么偏离默认**。

### 1.6 输出物：一份总设计文档

Stage 1 末尾交付**单一文档**（建议路径：`docs/design.md` 或 `DESIGN.md`），按以下顺序：

```md
# {项目名} · 总设计文档

## 1. MVP & 用户
（in scope / out of scope / non-goals / 目标用户 / 核心流）

## 2. 主流程图
（ASCII 流程图）

## 3. 主交互设计
（屏幕清单 / 关键动作 / 状态流转 / 决策点）

## 4. 主要技术栈
（运行面 / 框架 / 主语言）

## 5. 预览功能设计
- Status: Required / Not needed / Already satisfied
- Why:
- Surface:
- Layout & pagination plan:
- Mock data richness:
- State controller:
- Component reuse plan:（Required + 项目有 UI 组件时必填）
- 预览页地址（占位）: `<PREVIEW_URL>`（Stage 2 完成后回填）

## 6. 候选设计系统（≥2 套）
（每套：style 名 / 配色 / 字体 / 布局 / tradeoff）

## 7. 部署方案
- Repo visibility: public / private
- 部署目标: GitHub Pages / Cloudflare Pages / 用户指定
- 偏离默认的理由（如有）:

## 8. 后续规划（post-MVP roadmap）
（暂缓事项 / 扩展点 / 规模预期；无则明写"本期未讨论"）

## 9. Stage 1 待用户锁定的决策
- [ ] 接受 MVP 切片
- [ ] 选定 preview 策略
- [ ] 选一套设计系统：候选 1 / 2 / 3 / 自混
- [ ] 确认部署方案
- [ ] 确认后续规划方向
```

---

## Stage 1 / Stage 2 之间的 User Gate

Stage 2 不得自动启动。必须显式问用户：

> Stage 1 总设计文档已就绪。请确认以下决策后我再进入 Stage 2：
> 1. MVP 切片 OK 吗？
> 2. preview 策略采纳哪一套？
> 3. 设计系统选哪一套？（编号或自混）
> 4. 部署目标确认？
> 5. 后续规划方向 OK 吗？

得到至少 2 / 3 / 4 三项明确回答前不进入 Stage 2。1 与 5 可以推断默认。

---

## Stage 2 · Build Scaffold

进入 Stage 2 的硬前置：

- Stage 1 总设计文档已落盘
- 用户已选定**一套**设计系统（不能"几套混"未拍板）
- 部署目标已确认

### 2.1 工程规范脚手架（调 `project-rules-architecture`）

把已锁定的技术栈 + 业务域 + greenfield/adjacent 状态传给 `project-rules-architecture`。

原样接收产出；不要改述。

### 2.2 项目 Logo 设计（调 `huashu-design`）

调用 `huashu-design`，请求至少 2 个 logo 方向：

- 输入上下文：项目名 / 一句话目标 / 已选设计系统的配色与字体
- 要求：每个方向出 SVG + PNG（透明底）+ 简短风格说明
- **不允许**直接套通用 emoji 或纯文字 logo（除非用户明说"先用文字 logo 占位"）

输出落到 `assets/logos/` 或项目 `branding/` 目录，并在总设计文档里加引用。

### 2.3 预览页实现（基于已选设计系统）

实现 Stage 1 第 5 节描述的 preview 设计：

- **Required + 有 UI 组件**：套已选设计系统的 token，复用真实组件 + 适配器层
- **Required + 零代码阶段**：用 `huashu-design` / `frontend-design` 出占位 preview 页，标注切回 deadline
- **Not needed / Already satisfied**：本节产物 = 总设计文档里的引用，不重复造

**双向链接**（硬性要求）：

1. **Preview 页 → 总设计文档**：preview 页头部或角落必须有"返回总设计文档"链接（指向 `docs/design.md` 的 GitHub / Cloudflare URL）
2. **总设计文档 → Preview 页**：Stage 1 第 5 节的 `预览页地址` 占位**必须回填真实 URL**

链接形式建议：

```html
<!-- preview 页头部 -->
<a href="{DESIGN_DOC_URL}" class="design-doc-link">
  ← 总设计文档
</a>
```

```md
<!-- 总设计文档第 5 节 -->
- 预览页地址: https://yeomanye.github.io/myproject/preview/
```

### 2.4 部署接线

按 Stage 1 第 7 节锁定的目标接线：

- **GitHub Pages**：建 `.github/workflows/deploy-website.yml`，触发路径限定为 preview 页所在目录
- **Cloudflare Pages**：通过 Cloudflare Dashboard 接 private repo（手工配置部分由用户做，本 skill 给操作步骤）
- **其他目标**：参考用户指定流程，输出 setup 命令

部署完成后**必须**把真实 URL 回写到总设计文档的"预览页地址"和"返回总设计文档"链接两处。

---

## Handoff Contract

路由给下游 skill 时：

- 传**紧凑版**前置准备摘要（~6 bullets），不是完整文档
- 明确请求："为 X 产出规则脚手架"、"为 Y 提出 N 套候选设计"、"为 Z 出 2 个 logo 方向"
- 带上用户声明的硬约束
- **用户声明的数值约束覆盖默认值**（候选数、设计候选数、logo 方向数）
- 不要重复追问 Stage 1 已确认的信息——下游 skill 应继承上下文

不要把下游 skill 的内部文档复制到本 skill 输出里；让它们自己说话并注明出处。

## Output Contract

最终交付（两阶段累计）必须包含：

### Stage 1 产物
1. **总设计文档**（单一文件），覆盖 9 个章节（MVP、流程图、交互、技术栈、preview 设计、候选设计系统、部署方案、后续规划、待锁定决策）
2. ASCII 流程图（嵌在总设计文档第 2 节）
3. ≥ 2 套设计系统候选（嵌在第 6 节，全量保留）

### Stage 2 产物
4. 工程规范脚手架（或 patch）
5. 项目 logo（≥ 2 个方向；用户选定后归档到 `assets/logos/`）
6. **可访问的 preview 页**（如 Stage 1 判 `Required`），并已部署到目标平台
7. **双向链接已建立**（preview 页 ↔ 总设计文档，URL 已回填）

任一缺失视为未完成。

---

## Red Flags —— STOP 并重新考虑

- Stage 1 没出 ASCII 流程图就进 Stage 2 → 停下，先补流程图
- Stage 1 preview 设计标 Required 但没写 Component reuse plan（项目有 UI 组件时） → 停下，按 project-prep 第 4 条硬要求补全
- 用户还没在 5 项决策里至少明确 2/3/4 三项 → 停下，触发 user gate 问完再说
- Stage 2 用户还没"一套"设计系统选定就开始出 logo / preview → 停下，等用户决策
- Stage 2 部署后没回填总设计文档的 URL → 停下，回填两处
- 把私有仓库默认部署到 GitHub Pages → 停下，公开仓库泄露风险
- 把公开仓库默认走 Cloudflare（用户没要求） → 停下，过度复杂
- 整体走完没列开放决策 → 停下，补 Stage 1 第 9 节

## Rationalizations to Reject

| 说辞 | 现实 |
|------|------|
| "ASCII 流程图用文字描述代替更省事" | 流程图的价值是"一眼看到决策点"，文字段落看不出来。该画就画 |
| "preview 设计可以挪到 Stage 2 再说" | preview 是 Stage 1 锁定项之一；Stage 2 实施它需要 Stage 1 先描述清楚 |
| "用户口头说 OK 了就直接进 Stage 2" | user gate 必须显式列出决策清单让用户回答；口头模糊的"OK"不算锁定 |
| "私有仓库也用 GitHub Pages 算了" | GitHub Pages 公开访问 = 私有项目内容暴露；闭源项目必须 Cloudflare 或其他闭源友好平台 |
| "logo 用 emoji 或纯文字省事" | logo 是品牌识别度；emoji / 纯文字是占位思路，不是 logo 设计。必须出 ≥ 2 方向 |
| "preview 页和设计文档放一起就行，不用双向链接" | 双向链接保证两份资产长期对齐：改了 preview 找得到出处，看了文档点得开 preview |
| "Stage 1 全量候选可以删掉用户没选的" | 全量候选是文档的一部分；保留未选的方便日后回看 tradeoff |
| "用户已经走过 project-prep 了，可以跳 Stage 1" | Stage 1 不只是 project-prep，还含 ASCII 流程图 / 设计系统候选 / 部署方案，必须完整跑 |

## Common Mistakes

- 把 MVP 当成范围裁剪而不是交互承诺
- Stage 1 没出 ASCII 流程图就交付
- Stage 1 给了候选设计但没让用户选就进 Stage 2
- Stage 2 出 logo 但只出一个方向
- Stage 2 preview 页部署后忘记回填总设计文档的 URL
- 私有仓库默认部署到 GitHub Pages 暴露内容
- 把下游 skill 的内容用自己的 voice 改述

## Delivery Check

宣称 bootstrap 完成前，核对：

### Stage 1
- 总设计文档已落盘（路径：`docs/design.md` 或等价）
- 9 节齐全（MVP / 流程图 / 交互 / 技术栈 / preview 设计 / 候选设计系统 / 部署方案 / 后续规划 / 待锁定决策）
- ASCII 流程图存在
- preview 设计满足 project-prep 的 4 条硬性要求（含 Component reuse plan，若项目有 UI 组件）
- 候选设计系统 ≥ 2 套且全量保留
- 部署目标根据仓库可见性正确路由（public → GitHub Pages / private → Cloudflare）
- "后续规划"段落存在或显式写"本期未讨论"
- 触发了 user gate 询问 5 项决策

### Stage 2
- 工程规范脚手架已落盘
- 项目 logo ≥ 2 方向，文件已归档
- preview 页（如 Required）已实现并部署
- **双向链接已建立**：preview 页有"返回总设计文档"链接 + 总设计文档"预览页地址"已回填真实 URL
- 部署 workflow / 配置文件已落地

## Reuse

本 skill 的测试场景保留在 `tests/cases.md`。未来修订本 skill 时以这些用例为基线。
