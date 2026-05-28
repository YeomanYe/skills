---
name: flow-project-finish
description: Use when a project's main implementation is done and the user wants a finish bundle that (1) syncs code-level design back into project docs (design system, interaction, PRD, architecture), (2) produces or refreshes the README, (3) builds a landing page via huashu-design + frontend-design when the project itself is not a website, (4) routes through delivery-gate for a pre-delivery review, and (5) closes with clean-commit. Trigger on requests like "项目收尾", "做收尾", "完成项目", "出收尾文档", "准备交付", "交付前整理", "收尾文档加落地页加提交", "wrap up project", "finish project", "finalize project". Do NOT trigger when the user only wants a README, only a landing page, only a doc sync, only a delivery review, or only a commit—those each have their own skill.
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)

# Orchestrating Project Finish

## Overview

编排器,把"主体实现已完成"的项目转成完整的交付包,顺序固定为五阶段加一份报告:

1. **Code → Docs sync** —— 把代码里已经落地的设计、交互、架构变更同步回项目内的设计系统规范、交互文档、PRD、架构文档
2. **README** —— 产出或增量更新一份能让陌生人 30 秒看懂项目的 README
3. **Landing Page(条件)** —— 项目自身**不是网站**时,通过 `huashu-design` 拿设计方向,通过 `frontend-design` 落代码,内容契约固定为「大纲 + 路线图 + 相关链接」,技术栈对齐项目前端栈,无前端栈时回退 `vite + pnpm + react`
4. **Delivery Gate** —— 通过 `delivery-gate` 做交付前审查,判断 must-fix 是否要回流到 Step 1/2/3,以及是否需要补 Playwright 截图/录屏作为视觉证据
5. **Clean Commit** —— 仅当 Step 4 放行后,通过 `clean-commit` 把本次收尾的全部变更提交为干净的 git commit

核心原则:**同步先于补写,补写先于新建,审查先于提交**。先确认项目内已有的文档,再决定哪些需要更新、哪些需要新建、哪些应当显式标"未发现";代码与文档全部就位后由 `delivery-gate` 把关,通过后再交给 `clean-commit` 落盘。本 skill 不替代下游 `huashu-design` / `frontend-design` / `delivery-gate` / `clean-commit`,只负责编排、强制阶段先后,并保护四件用户容易漏掉的事:**已存在文档不被覆写、README 不被翻译/重排破坏、落地页内容契约不被裁剪、提交前必须经过 must-fix 审查**。

## 角色信条

**我是收尾官,不是从零作者;我同步代码到文档,不重写项目历史。**

**收尾最容易死在"AI 觉得应该重写一遍"**——一旦我看到 README 写得"不够规整"就想全推翻,
**用户精心维护半年的 voice 就毁了**。同步先于补写,补写先于新建——**用户原有的文字
是事实,不是初稿**。

我执行任务时心里只问一个问题:**"用户半年后再读这份 README / docs / landing page,
能不能认出'这是我写的'?"** 不能 = 我重写过头,跟它"看起来多规整"、"信息多完整"、
"风格多统一",**一点关系都没有**。

**落地页是产品的脸**。"自身不是网站"的项目对外要露出,landing page 是用户的第一眼——
模糊的渐变 + 通用 SaaS hero + AI 写的副标题 = 用户根本看不到这个项目。
landing 必须走 huashu-design + frontend-design 真做,**不要"先放个简单的占位"**——
占位 push 出去就是终稿。

我最容易翻的车——每一条都是"看起来在做收尾,实际在抹掉项目个性":

- **覆写已有文档** — 看 README 写得"散乱"就重写,**用户的 voice / 半年迭代的取舍
  全没了**。同步先于补写:已有的内容是真相,我只在缺失处补,不在已有处改风格。
- **翻译式重排 README** — "我把中英文统一一下 / 把章节顺序优化一下" = **破坏用户
  原结构** = 半年后用户找不到他记得的那段。翻译 / 重排前先问用户,默认不动。
- **裁剪 landing page 内容契约** — landing page 的内容是按 huashu-design 的 design system
  设计的,我"觉得太长简化一下" = 破坏视觉节奏。**内容契约是 design 的一部分,不是文案稿**。
- **跳 delivery-gate 直接 clean-commit** — "看起来挺好就提交吧" = 把没经审查的产物
  push 出去 = 用户发现问题时 commit 已经在 main 上了。delivery-gate 不是可选步骤,
  是收尾流水线的强制闸门。
- **越界做设计判断 / 写代码 / 审 PR** — 我管收尾编排 + 阶段顺序 + 4 件用户易漏的事;
  **设计审查找 director-design,UI 改造找 frontend-design,代码 review 找 requesting-code-review,
  commit 安全找 clean-commit**。越界 = 假装自己什么都懂 = 让每个下游环节都做半吊子。

## When to Use

- 项目主体功能已实现,用户想要一份"交付前的整理"
- 用户提到 README + 文档 + 落地页 + 提交 中的至少**两件**,且语气是收尾
- 内部工具/Lib/CLI/扩展/移动应用 等"自身不是网站"的项目准备对外公开

## When NOT to Use

- 仅出 README —— 直接写,不要编排
- 仅做落地页 —— 直接调用 `huashu-design` + `frontend-design`
- 仅同步设计系统 —— 直接处理,无需本 skill
- 仅做交付审查 —— 直接用 `delivery-gate`
- 仅做提交 —— 直接用 `clean-commit`
- 主体功能仍在开发中 —— 用 `flow-dev-task`
- 准备发布到浏览器商店 —— 用 `flow-ext-publish`
- 项目本身就是网站(Next.js/Nuxt/Astro/Vite App 等)且用户没说要补设计/PRD/架构文档 —— 不需要本 skill

## Mandatory Workflow

### Step 0 —— 探测项目状态

调用任何下游 skill 之前,必须先扫描以下信号,并把扫描结果作为后续阶段的唯一前置:

- **包管理器与前端栈**:`package.json` 里的 framework(react / vue / svelte / next / nuxt / astro / solid)、构建工具(vite / webpack / rsbuild / turbopack)、包管理器(pnpm / npm / yarn / bun)
- **项目类型**:CLI / library / browser-extension / desktop / mobile / website / fullstack
- **是否已是网站**:存在 `next.config.*` / `nuxt.config.*` / `astro.config.*`,或 `package.json scripts` 含明确的 web build,或根目录 `index.html` 是真实落地页(不是 popup 入口)
- **既存落地页子目录**:扫 `website/` / `landing/` / `marketing/` / `docs/landing/` / `site/`,有则记录路径与最后构建时间;这是与"项目本身是网站"不同维度的信号
- **既存 web 预览(preview/demo)**:扫 `preview/` / `demo/` / `playground/` / `examples/` / `sandbox/`,以及 `package.json scripts` 里有 `preview`/`demo`/`dev:preview` 一类目标的子目录。**为什么单独列**:preview 是"让人试用产物",landing 是"介绍产物 + Roadmap + Links",两者职能不同,前期常被同一个 deploy 通道顶替,但收尾时必须区分对待。检测到 preview 必须单独记录,不能并入"既存落地页"
- **部署配置**:扫 `vercel.json` / `netlify.toml` / `.github/workflows/*pages*.y*ml` / `wrangler.toml` / `firebase.json` / `package.json` 的 `homepage` 字段,记录:配置文件路径 + 当前指向的构建产物路径(如 `vercel.json` 的 `outputDirectory`、GH Pages workflow 的 publish dir)。多文件时**全部列出**,标注哪一个是"主要部署"(优先级: vercel/netlify > gh-pages > 其他)。**为什么扫部署配置**:收尾会切换公开门面(preview → landing),不读现状就无法切换。**如果文件层面一无所获**:再扫 `README.md` / `package.json` / `docs/**` 是否出现 `deployed at` / `vercel.app` / `netlify.app` / `.pages.dev` / `*.workers.dev` / `*.fly.dev` / `github.io` 等公开域名关键词。**为什么补这一步**:Vercel/Netlify/Cloudflare 都允许仅在平台后台 UI 配置部署,toml/yml 此时不存在,文件层面与"项目从未部署"无法区分;落地后会丢失关键信息(用户其实是 Netlify 部署,但 skill 误判为无部署、不提示切换)。命中则标记为 `Deployment config: [platform-only:<inferred-platform>:primary]`,后续在 Step 3.3.5 走平台后台分支
- **现存文档清单**:遍历 `docs/` / `README*` / `CONTRIBUTING*` / `ARCHITECTURE*` / `PRD*` / `INTERACTION*` / `DESIGN*`(包括子目录),记录每份文档的最后更新时间与覆盖的主题
- **设计系统线索**:Tailwind config / design tokens 文件 / `theme.*` / `tokens.*` / `styles/` 下的 css variables / Storybook
- **路线图线索**:`TODO.md` / `ROADMAP.md` / `progress.md` / `task_plan.md` / GitHub issues 标题(若可读)
- **git 状态**:工作区是否已有未提交改动、当前分支、远端配置(为 Step 5 clean-commit 准备)

Step 0 的完成判定不是"看了一眼",而是已经写下:

- `Project type: <type>`
- `Frontend stack: <stack | none>`
- `Already a website: yes | no`
- `Existing landing page: <path | none>`
- `Existing web preview: <path | none>` (preview/demo/playground/examples,与 landing 平行的另一资产)
- `Deployment config: [<file>:<current_target_path>:<primary|secondary>]` (空则 none)
- `Existing docs: [<path>:<topic>:<last_updated>]`
- `Design tokens source: <path | none>`
- `Roadmap source: <path | none>`
- `Git state: <clean | dirty>:<branch>`

如果项目根本没有可识别的项目结构(空目录、没有 manifest、没有源码),停下并发起澄清,不要进入下一阶段。

**项目快照在收尾全程是唯一的事实源**。后续阶段中用户主动补充的信息(如"对了 tokens 在 X 路径"),应合并 / 更新进入此快照,**不要重启 Step 0 探测**,也不要忽略。

### Step 1 —— Code → Docs Sync（并行 4 路 subagent）

4 类文档同步彼此独立（各写不同文件,仅共享 Step 0 快照只读）,按 `references/parallelization-template.md` 派 4 个 subagent 并行,派工 prompt 字段集遵循 `references/dispatcher-template.md`:

| Slot | 任务 | 写入目标 |
|---|---|---|
| `design-sync` | 代码 tokens → 设计系统规范 | `docs/design-system.md` 或既有路径 |
| `interaction-sync` | 代码状态机 → 交互文档 | `docs/interaction.md` 或既有路径 |
| `prd-sync` | 实现 vs PRD 偏差汇总 | `docs/PRD.md` 或既有路径 |
| `architecture-sync` | 模块边界 / 数据流 / 依赖 | `docs/architecture.md` 或既有路径 |

**派工 prompt 关键字段**:Step 0 快照路径 + sha256(只读) / 目标文档现有路径 + voice 样本 / 黑名单(禁动源码、禁碰其他 3 类文档) / 输出到独立 `.agent/jobs/<slot>/output.patch` / 返回 JSON `{slot, status, patch_path, evidence_file_lines, errors}`。

**Reduce**:orchestrator 收集 4 patch → 按 `design → interaction → prd → architecture` 顺序 `patch -p1` apply。任一 patch fail → 记录但不阻塞其他 3 路(collect-all 模式)。orchestrator 派工后 idle,subagent 返回触发唤醒。**类别不存在的 slot 直接 skip**(不派 subagent,也不默认新建)。

以下规则适用于每个 subagent 的内部执行(写入派工 prompt)。以 Step 0 的扫描结果为输入,对每一类目标文档执行 **detect → diff → patch** 三步,而不是直接重写:

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

**进入条件**:Step 0 探测出 `Already a website: no`,且用户没说"先不做落地页"。
**跳过条件**(任一即跳过):项目本身就是网站(Next.js/Nuxt/Astro/Vite SPA);或纯内部工具且用户未要求对外。

子阶段编排:

- **3.0 既存落地页分流**:`Existing landing page` 非 none 时,显式呈现 refresh / rebuild / skip 三选一,默认推荐 refresh,**永远不替用户选**。`preview ≠ none` 不进分流(preview 是平行资产)
- **3.1 收集落地页输入**:整理 ~8 bullets(项目名 / 功能 / 技术栈 / 路线图源 / 链接 / 调性 / 是否外发)传下游
- **3.2 设计方向 + Mockup**(两阶段 director-design):3.2a 派 1 个 `director-design (variants)` 出 3 方向卡 → 3.2b 派 3 路 `director-design (mockup)` 并行实现 mockup(每路独立目录 `.agent/jobs/landing-mockup-{1,2,3}/`,含 4 断点截图)→ 3.2.5 飞书自动推送 6 张截图(CC_SESSION_KEY 含 `feishu:` 时强制)→ 3.2.6 等用户挑选**不超时**
- **3.3 落地页实现**(按项目栈智能选):有前端栈 → A 模式调 `frontend-design` 以选中 mockup 为视觉基准重写;无前端栈 → B 模式直接 `cp -r` mockup 到 `website/`。内容契约三段齐全:Outline / Roadmap / Links
- **3.3.5 部署目标切换**(落地页落码后必做):primary 部署配置 Claude 改,secondary 必须用户确认;preview 代码留、公开下线、子路径迁移交给用户。带 `Deployment switched` / `Preview retained at` 证据进 Step 4
- **3.4 响应式截图**(并行 4 路 subagent):375/768/1024/1440 四断点,必须显式调 `agent-browser`,按 `references/parallelization-template.md` 派工

> 完整子流程(分流决策表、director-design 两阶段派工 prompt、push-mockups.sh 调用、重做命名硬规则、部署切换分支表、preview 处理细则、4 路截图 prompt)详见 `references/approval-land-workflow.md`。subagent 派工 prompt 字段集统一遵循 `references/dispatcher-template.md`。

### Step 4 —— Delivery Gate(交付审查)

- **Step 4.0 director-design audit**(v4 新增,UI 改动时必做):派 subagent 调 `director-design (mode: audit)`,audit 的是 **3.3 落地后的生产代码**(不是 3 路 mockup)。verdict=`needs-redesign` 或 `mockup_alignment_score < 4/5` → 回 Step 3.3 重做。非 UI 任务跳过
- **Step 4.1 delivery-gate**:Step 1~3 产物就位后调 `delivery-gate`,一次性递交全部证据(文档 patch + README + 落地页 + 3.4 截图 + 3.3.5 部署切换证据 + 4.0 audit 报告 + Step 0 快照)。**递交前 self-check**:对每条 `Deployment switched: <file>` 跑 `git diff -- <file>` 确认文件真变了

回流路由:

| 判定 | 回流 |
|------|------|
| must-fix on doc patch | 回 Step 1 修复后重跑 |
| must-fix on README | 回 Step 2 修复后重跑 |
| must-fix on landing page | 回 Step 3 修复后重跑(设计方向问题可能回 3.2) |
| need more visual evidence | 跑 agent-browser 补截图/录屏后重跑 |
| all clear | 进入 Step 5 |

强制规则:**不得跳过 delivery-gate 直接 commit**;**不得自己代替 delivery-gate 做轻量审查**;IM 通道时视觉证据由 delivery-gate 回流,本 skill 不重复发送。

> 完整 audit 派工 prompt、回流判定表、证据 self-check 流程详见 `references/approval-land-workflow.md`。

### Step 5 —— Clean Commit(干净提交)

仅当 Step 4 给出 **all clear** 时,调用 `clean-commit`,传入:

- 本次收尾涉及的全部变更范围:
  - Step 1 文档 patch
  - Step 2 README
  - Step 3 落地页代码
  - **Step 3.3.5 改动的部署配置文件**(若有):显式列出文件路径,例如 `vercel.json` / `netlify.toml` / `.github/workflows/*pages*.y*ml` / `wrangler.toml` / `package.json#homepage`。**必须显式列**,否则 clean-commit 的 select-and-commit 模式会把根目录的部署配置当成"与当前任务无关的脏改动"而排除
- 收尾的语义 scope:
  - `docs`(仅文档+README)
  - `docs+landing`(含落地页,无部署切换)
  - **`docs+landing+deploy`**(含落地页 + 切了部署目标)
  - 或 conventional commit 中更合适的类型
- Step 0 探测出的 `Git state`(若 dirty,需要先把无关改动剥离;clean-commit 自带这种判断)

强制规则:

- **不得在 delivery-gate must-fix 未消化时 commit**
- **不得把本次收尾以外的改动夹带进来**;必须让 clean-commit 选择性 staging
- **不要 push**(除非用户显式要求或 IM 来源会话默认要求);clean-commit 默认只 commit 不 push
- 提交信息须能让人三秒看懂"这是一次项目收尾",而不是把每个文件改动罗列出来

### Step 6 —— 收尾报告

完成上述阶段后,产出一份汇总报告,**不要省略任何阶段**(即使该阶段被跳过也要写明跳过原因)。

报告含 7 节(Project Snapshot / Doc Sync / README / Landing Page / Delivery Gate / Clean Commit / 风险与开放决策),按 `references/output-contract-template.md` 的完整 markdown skeleton 产出,字段顺序与命名硬约束在该文件。

## Handoff Contract

路由给下游 skill 时:

- 传**紧凑版上下文**(~8 bullets),不要把项目源码或全部文档塞进去
- 用**精确的请求语**:"为 X 项目产出 3 套差异化落地页设计方向"、"基于选中方向 + 内容契约,实现落地页代码"、"对收尾产物做交付审查,must-fix 回流到对应阶段"、"把本次收尾涉及的变更提交为一个干净 commit"
- **传项目硬约束**(技术栈、调性、是否对外公开、git state)
- **不得在下游 skill 阶段重复追问已在 Step 0 中明确的项目类型、技术栈、路线图来源、git state**
- 不要把下游 skill 的内部产物用本 skill 的 voice 改述

## Output Contract

最终交付按以下顺序必须包含:Step 0 快照 → Step 1 文档同步明细(含"未发现") → Step 2 README 状态与变更 → Step 3 落地页结果或跳过原因 → Step 4 delivery-gate 判定与 must-fix 回流 → Step 5 clean-commit hash 与 message(或跳过原因) → 风险与开放决策清单。**任一缺失即视为未完成**。完整 markdown skeleton + Delivery Check 自查清单见 `references/output-contract-template.md`。

## Failure Modes

本 skill 三段失败模式(Red Flags / Rationalizations to Reject / Common Mistakes)集中在 `references/failure-modes.md`,触发任一红线必须停下重判:

- **覆写已有文档 / 翻译式重排 README** — 同步先于补写,默认不动 voice
- **裁剪 landing page 内容契约** — Outline/Roadmap/Links 三段不可压
- **未派 3 路 mockup / auto-pick 替用户选 / 覆盖旧 mockup 目录** — 3 路 + 不超时 + -v2 命名是 v5 硬规则
- **跳过 3.3.5 部署切换 / 自动改 secondary 配置 / 声明切了但 git diff 为空** — 部署切换证据必须可验证
- **跳过 delivery-gate / must-fix 未消化就 commit / clean-commit 夹带无关改动** — 审查 → 提交是硬闸门
- **把 preview 当 landing / 删除 preview 目录** — preview 是平行资产

完整红线列表 + 21 条合理化驳斥 + Common Mistakes 见 references。

## Codex Delegation Hook

Codex 是对等 agent，能做本 skill 的所有执行工作。是否派工取决于 **ROI**（净收益 = 省 Claude token + 并行性 - SPEC 成本 - 协调成本 - review 成本 - 质量风险）。

### 🟢 高 ROI 推荐派
- **Step 3.3 落地页实现**（含 5+ Section，预估 ≥ 200 行 / ≥ 4 文件）：Claude 把 huashu-design 选定的方向 + 内容契约写进 SPEC，Codex 实施，Claude 跑 agent-browser 截图验收

### 🟡 中 ROI 视情况派
- **Step 1 文档同步**（≥ 20 处 patch 或跨 ≥ 5 个文档）：Claude 把每处 from→to + voice 约束写进 SPEC，Codex 应用 patch，Claude 验收风格未漂移
- **Step 2 README 从零生成**（≥ 80 行）：Claude 列真实命令清单 + 大纲，Codex 生成 markdown，Claude 验收命令真实性
- **Step 3.4 响应式截图**：跨 4 断点截图本质是 4 次独立任务，可派 Codex 跑 agent-browser；但单 skill 调用启动成本 < 派工开销，多数时候 Claude 自跑更快

### 🔴 低 / 负 ROI 不建议派
- **Step 0 项目探测**：全是短 Bash 命令，Claude 自跑 1 秒完成
- **Step 1 小规模 patch**（< 10 处）：SPEC 撰写成本 ≈ 直接写
- **Step 2 README 增量更新**：每处只改几行，需要保留原结构和 voice，SPEC > 输出
- **Step 3.1 收集输入 / Step 3.2 设计方向**：决策类，依赖 Claude 推断
- **Step 4 delivery-gate**：独立 gate skill，自己有完整工作流
- **Step 5 clean-commit**：commit message + scope 选择依赖会话上下文，Codex 拿不到

派工细则（SPEC 模板、prompt 模板、review checklist、错误分类、Red Flags）全部以 `flow-dev-task` 的 "Codex Delegation Hook" 为唯一规范，不在本 skill 重复。

## Reuse

本 skill 的行为测试场景在 `tests/cases.md`。
本 skill 的链路测试场景在 `tests/chain-handoff.md`。
未来修订本 skill 时以这些用例为基线。
