---
name: flow-project-wrapup
description: Use when a project's main implementation is done and the user wants a wrap-up bundle that syncs code-level design back into project docs (design system, interaction, PRD, architecture), produces or refreshes the README, and—if the project is not already a website—builds a landing page via huashu-design + frontend-design with a fixed outline/roadmap/links contract. Trigger on requests like "项目收尾", "做收尾", "出收尾文档", "收尾工作流", "准备交付", "交付前整理", "补齐项目文档和落地页", "wrap up project", "finalize project", "wrap up before delivery". Do NOT trigger when the user only wants a README, only a landing page, only a doc sync, or only a commit/publish step—those each have their own skill.
---

# Orchestrating Project Wrap-Up

## Overview

编排器,把"主体实现已完成"的项目转成完整的交付级收尾包,顺序固定为三阶段:

1. **Code → Docs sync** —— 把当前代码里已经落地的设计、交互、架构变更同步回项目内的设计系统规范、交互文档、PRD、架构文档
2. **README** —— 产出或增量更新一份能让陌生人 30 秒看懂项目的 README
3. **Landing Page(条件)** —— 项目自身**不是网站**时,通过 `huashu-design` 拿设计方向,通过 `frontend-design` 落代码,内容契约固定为「大纲 + 路线图 + 相关链接」,技术栈对齐项目前端栈,无前端栈时回退 `vite + pnpm + react`

核心原则:同步先于补写,补写先于新建。先确认项目内已有的文档,再决定哪些需要更新、哪些需要新建、哪些应当显式标注"未发现"。本 skill 不替代 `huashu-design` 或 `frontend-design`,只编排顺序、强制阶段先后,并保护用户容易漏掉的三件事:**已存在文档不被覆写、README 不被翻译/重排破坏、落地页内容契约不被裁剪**。

## When to Use

- 项目主体功能已实现,用户想要一份"交付前的整理"
- 用户提到 README + 文档 + 落地页中的至少**两件**,且语气是收尾
- 内部工具/Lib/CLI/扩展/移动应用 等"自身不是网站"的项目准备对外公开

## When NOT to Use

- 仅出 README —— 直接写,不要编排
- 仅做落地页 —— 直接调用 `huashu-design` + `frontend-design`
- 仅同步设计系统 —— 直接处理,无需本 skill
- 主体功能仍在开发中 —— 用 `flow-dev-task`
- 准备 git commit —— 用 `clean-commit`
- 准备发布到浏览器商店 —— 用 `flow-ext-publish`
- 项目本身就是网站(Next.js/Nuxt/Astro/Vite App 等)且用户没说要补设计/PRD/架构文档 —— 不需要本 skill

## Mandatory Workflow

### Step 0 —— 探测项目状态

调用任何下游 skill 之前,必须先扫描以下信号,并把扫描结果作为后续阶段的唯一前置:

- **包管理器与前端栈**:`package.json` 里的 framework(react / vue / svelte / next / nuxt / astro / solid)、构建工具(vite / webpack / rsbuild / turbopack)、包管理器(pnpm / npm / yarn / bun)
- **项目类型**:CLI / library / browser-extension / desktop / mobile / website / fullstack
- **是否已是网站**:存在 `next.config.*` / `nuxt.config.*` / `astro.config.*`,或 `package.json scripts` 含明确的 web build,或根目录 `index.html` 是真实落地页(不是 popup 入口)
- **既存落地页子目录**:扫 `website/` / `landing/` / `marketing/` / `docs/landing/` / `site/`,有则记录路径与最后构建时间;这是与"项目本身是网站"不同维度的信号
- **现存文档清单**:遍历 `docs/` / `README*` / `CONTRIBUTING*` / `ARCHITECTURE*` / `PRD*` / `INTERACTION*` / `DESIGN*`(包括子目录),记录每份文档的最后更新时间与覆盖的主题
- **设计系统线索**:Tailwind config / design tokens 文件 / `theme.*` / `tokens.*` / `styles/` 下的 css variables / Storybook
- **路线图线索**:`TODO.md` / `ROADMAP.md` / `progress.md` / `task_plan.md` / GitHub issues 标题(若可读)

Step 0 的完成判定不是"看了一眼",而是已经写下:

- `Project type: <type>`
- `Frontend stack: <stack | none>`
- `Already a website: yes | no`
- `Existing landing page: <path | none>`
- `Existing docs: [<path>:<topic>:<last_updated>]`
- `Design tokens source: <path | none>`
- `Roadmap source: <path | none>`

如果项目根本没有可识别的项目结构(空目录、没有 manifest、没有源码),停下并发起澄清,不要进入下一阶段。

**项目快照在收尾全程是唯一的事实源**。后续阶段中用户主动补充的信息(如"对了 tokens 在 X 路径"),应合并 / 更新进入此快照,**不要重启 Step 0 探测**,也不要忽略。

### Step 1 —— Code → Docs Sync

以 Step 0 的扫描结果为输入,对每一类目标文档执行 **detect → diff → patch** 三步,而不是直接重写:

| 文档类别 | 触发条件 | 同步内容 | 不存在时 |
|---------|---------|---------|---------|
| 设计系统规范 | 找到 design tokens / theme 文件 | 把代码里的颜色/字号/间距/组件变体同步到对应规范文档 | 显式询问用户是否新建,**默认不新建**;在收尾报告标注"项目未建立设计系统文档" |
| 交互文档 | 找到现有 interaction.md / 同名 | 把代码里实际的页面流转、关键状态、空/错/加载态同步进去 | 不主动新建 |
| PRD 文档 | 找到现有 PRD / spec | 同步当前已实现范围 vs 原 PRD 的偏差(已实现/未实现/超出) | 不主动新建 |
| 架构文档 | 找到现有 ARCHITECTURE / docs/architecture | 同步当前模块边界、数据流、依赖关系 | 不主动新建 |

强制规则:

- **不得"补完"已存在但内容陈旧的文档**为新版本;只 patch 实际偏差,保留原结构和原作者 voice
- **不得用本 skill 的 voice 改述用户原文档**;增量段落与原文档风格对齐
- **找不到的类别要显式记录**为"未发现",不能默认创建占位文档骗过收尾报告
- 每一处 patch 必须能指向具体代码位置(file:line)作为证据,纯靠推理写出来的同步无效

### Step 2 —— README

判断逻辑:

- **README 已存在** → 增量更新,不重写。保持现有结构与语言(中/英),仅在 Features / Tech Stack / Scripts / Roadmap 等明显落后的小节做精确替换
- **README 不存在** → 从零生成,按下方契约,语言默认与用户当前对话语言一致(若用户主要用中文,README 用中文)

最小契约(无论新建还是更新,必须存在以下小节):

1. 项目名 + 一句话定位(必要时含 badge)
2. 核心功能清单(从 Step 0 的 design tokens / 已实现页面 / 命令实测得出,不要从 PRD 抄)
3. 技术栈(来自 Step 0 的探测结果)
4. 快速开始(install / dev / build / test 实际命令,要从 `package.json scripts` 真实读取)
5. 目录结构概览(只列顶层 + 关键子目录,不列全树)
6. 路线图(若有 ROADMAP/TODO/progress 引用过来,无则省略此小节)
7. 许可 / 贡献(若现有项目内有 LICENSE/CONTRIBUTING 链接过去)

强制规则:

- **不要伪造命令**;必须以 `package.json` / `Makefile` / `justfile` 真实存在的脚本为准
- **不要塞 emoji 装饰** 除非项目原 README 已经在用;尊重项目调性
- **不要把"项目背景故事"放进来**,README 是工具说明,不是产品发布稿

### Step 3 —— 条件落地页

进入条件:

- Step 0 探测出 `Already a website: no`
- 用户没有显式跳过(说"先不做落地页"则跳过本步)

跳过条件(任一即跳过):

- 项目自身就是网站(Next.js / Nuxt / Astro / Vite SPA 等真实 web 应用)
- 项目无对外公开意图(纯内部工具)且用户未要求

#### 3.0 既存落地页分流(refresh / rebuild / skip)

如果 Step 0 探测到 `Existing landing page: <path>`(非 none),不要直接走完整生成路径。先把三个选项摆给用户:

| 选项 | 适用 | 行为 |
|------|------|------|
| **refresh** | 既存落地页结构基本可用,只是内容/路线图/链接落后 | 跳过 huashu-design,直接进 3.3 用 frontend-design 在原位 patch:更新功能清单、roadmap、links;尽量不动整体设计语言 |
| **rebuild** | 用户对既存落地页设计本身不满意,愿意重做 | 走完整 3.2 + 3.3,新代码生成到原路径(注意备份提示) |
| **skip** | 用户决定本期不动落地页 | 收尾报告 Step 3 节标"既存落地页保留,本期不更新",列入开放决策让用户后续处理 |

默认推荐 **refresh**(最小破坏),但**永远不替用户选**;选项必须显式呈现。

执行顺序:

#### 3.1 收集落地页输入

整理传给下游 skill 的紧凑包(~8 bullets):

- 项目名 + 一句话定位(来自 Step 2 的 README)
- 核心功能清单(来自 Step 2)
- 技术栈(决定落地页技术栈对齐策略)
- **路线图来源**:从 `TODO.md` / `ROADMAP.md` / `progress.md` 取,作为落地页的"待办工作"区
- **相关链接**:GitHub repo / Demo / Docs / Discord / 商店地址等(只列真实存在的)
- 项目调性(从 README/品牌色推断,作为给 huashu-design 的输入)
- 是否对外发布(决定是否需要 SEO meta / OG image)

#### 3.2 设计方向 —— huashu-design

调用 `huashu-design`,传入收集到的输入,框架原话使用:

> **"Return 3 differentiated design directions for a product landing page with the constraints below. Do NOT implement; this is direction selection only."**

要求 huashu-design 返回 3 个差异化方向,每个含:风格名 / 配色 / 字体 / 关键视觉 / 与其他方向的 tradeoff。

把全部方向原样保留,让用户挑选。**不得单方面替用户选**。

#### 3.3 落地页实现 —— frontend-design

用户挑定方向后,调用 `frontend-design`,传入:

- 选中的设计方向(huashu-design 的产出)
- **内容契约(必须三段齐全)**:
  - **大纲(Outline)**:Hero(项目名 + 一句话定位 + 主 CTA)+ Features(核心功能清单展开)+ How it works(可选,仅在交互非自明时加)
  - **路线图(Roadmap)**:从 Step 3.1 抓到的待办工作展开,标注「已完成 / 进行中 / 计划中」三态;空则显式标"暂无公开路线图"
  - **相关链接(Links)**:Step 3.1 收集到的链接,放在 Footer 或独立 Resources 区
- **技术栈契约**:
  - 项目自带前端栈(react/vue/svelte 等) → 落地页用同栈
  - 项目无前端栈 → 落地页用 `vite + pnpm + react`
  - 落地页放在 `website/` 子目录(若用户没指定其他位置)

#### 3.4 落地页响应式校验(可选但推荐)

如果环境可用,调用 `agent-browser` 在 375 / 768 / 1024 / 1440 四个断点下截图,作为交付证据附在收尾报告里。无 `agent-browser` 时,显式声明"未做响应式视觉校验"。

### Step 4 —— 收尾报告

完成上述阶段后,产出一份汇总报告,**不要省略任何阶段**(即使该阶段被跳过也要写明跳过原因):

```md
## Project Wrap-Up Report

### Step 0 — Project Snapshot
- Project type:
- Frontend stack:
- Already a website:
- Existing landing page:
- Existing docs:
- Design tokens source:
- Roadmap source:

### Step 1 — Doc Sync
- 设计系统:
- 交互文档:
- PRD:
- 架构文档:
- 未发现的类别:

### Step 2 — README
- 状态: created | updated | unchanged
- 文件: <path>
- 主要变更点:

### Step 3 — Landing Page
- 是否需要:
- 既存落地页分流: refresh | rebuild | skip | n/a
- 跳过原因(如适用):
- 设计方向(huashu-design 返回的全部候选,refresh 路径可记 n/a):
- 选中方向:
- 落地页代码位置:
- 技术栈:
- 响应式校验: done | skipped(<reason>)

### 风险与开放决策
- 风险:
- 用户需要书面确认的事项:
```

## Handoff Contract

路由给下游 skill 时:

- 传**紧凑版上下文**(~8 bullets),不要把项目源码或全部文档塞进去
- 用**精确的请求语**:"为 X 项目产出 3 套差异化落地页设计方向"、"基于选中方向 + 内容契约,实现落地页代码"
- **传项目硬约束**(技术栈、调性、是否对外公开)
- **不得在下游 skill 阶段重复追问已在 Step 0 中明确的项目类型、技术栈、路线图来源**
- 不要把下游 skill 的内部产物用本 skill 的 voice 改述

## Output Contract

最终交付按以下顺序必须包含:

1. Step 0 的项目快照
2. Step 1 的文档同步明细(包括"未发现"项)
3. Step 2 的 README 状态与变更摘要
4. Step 3 的落地页结果或显式跳过原因
5. 风险与开放决策清单

任一缺失即视为未完成。

## Red Flags —— STOP 并重新考虑

- 没探测项目状态就直接开写文档 → 停下,先做 Step 0
- 找不到设计系统文档却创建了一份"占位空文档" → 停下,删掉,改为在报告里标"未发现"
- README 已存在却被整体重写为"更专业的版本" → 停下,恢复原文,改为增量 patch
- 落地页的路线图区从 README 抄一遍而不是从真实 TODO/ROADMAP 来 → 停下,重抓数据源
- huashu-design 只返回了 1 套方向就接着 frontend-design → 停下,要求 3 套
- 项目已经是 Next.js/Nuxt 网站还在生成"落地页" → 停下,跳过 Step 3 并说明
- 项目里已经有 `website/` 等既存落地页子目录,却被当作"无落地页"重做 → 停下,先走 3.0 refresh/rebuild/skip 三选一
- 收尾报告省略某个阶段 → 停下,补上(即使跳过也要有跳过段落)
- README 写了根本不存在的 `pnpm something` 命令 → 停下,以 `package.json scripts` 为准

## Rationalizations to Reject

| 说辞 | 现实 |
|------|------|
| "项目没设计系统文档,顺手新建一个吧" | 主动新建会污染项目结构。本 skill 默认不新建,在报告里标"未发现"让用户决定 |
| "README 翻译成英文更专业" | 改语言/改风格不是本 skill 职责。增量更新,保留原 voice |
| "落地页直接用 frontend-design 一步到位省时间" | 没有 huashu-design 的方向选择,落地页就会是"AI 通用美学"。两步不可压缩成一步 |
| "项目本身是网站,落地页和它合并就行" | 网站本身 ≠ 项目落地页;但当项目就是网站时本 skill 直接跳过 Step 3,不强行造一份 |
| "路线图从我对项目的理解写一下就行" | 路线图必须可追溯到真实文件(TODO/ROADMAP/progress);凭印象写会过期或失真 |
| "用户没指定技术栈,我给落地页用我喜欢的" | 默认对齐项目前端栈;无栈才回退 vite+pnpm+react,这是契约 |
| "PRD/架构文档差太多了,本期重写一遍" | 本 skill 是收尾不是重做。陈旧文档只 patch 实际偏差,大改属于另一项任务 |
| "响应式校验跳过了无所谓" | 跳过可以,但必须在报告里显式声明"未校验";不得隐瞒 |

## Common Mistakes

- 把"项目快照"当成挑选性记录:只写存在的、忽略不存在的(导致后续阶段误判)
- 把"未发现的设计系统文档"默默创建一个占位
- README 增量更新时连原作者写的项目背景一起删掉
- 落地页的内容契约里漏掉「路线图」段(以为路线图项目内部用就够)
- 调 huashu-design 时没说"3 套方向",拿到 1 套就开干
- 落地页放进项目源码目录,污染主项目构建
- 收尾报告里把跳过的阶段直接删掉,而不是显式说"已跳过 + 原因"

## Delivery Check

宣称收尾完成前,核对:

- Step 0 的 7 个字段全部填写(项目类型 / 前端栈 / 是否网站 / 既存落地页 / 现存文档 / 设计源 / 路线图源)
- Step 1 中 4 类文档的状态都有结论(同步过 / 未发现 / 用户决定不补)
- README 真实存在于项目根,且其中的命令能被 `package.json scripts` 验证
- 落地页阶段:跳过则跳过有理由记录,执行则 `huashu-design` 真的返回了 3 套方向、用户确认了选择、`frontend-design` 真实产出了代码
- 落地页技术栈与项目栈一致(或在无栈时用 vite+pnpm+react)
- 落地页内容三段齐全:Outline / Roadmap / Links
- 收尾报告所有 5 节都存在(Step 0 / Step 1 / README / Landing / 风险与开放决策)
- 没有把下游 skill 的内部文档复制进本 skill 的 voice

## Reuse

本 skill 的行为测试场景在 `tests/cases.md`。
本 skill 的链路测试场景在 `tests/chain-handoff.md`。
未来修订本 skill 时以这些用例为基线。
