---
name: director-promote
description: >
  Use when 用户要给项目/工具做**宣传/推广/对外发布内容**——本 skill 扮演宣发者角色,
  审视材料(文字+图片+图片内容合规)、写文案、出多版本调性变体、调度多平台发布、汇总回执。
  触发短语:"做宣传"、"发个推"、"发到 v2ex / 少数派 / Appinn / Twitter / Product Hunt"、
  "宣传这个项目"、"写个推广文案"、"发布到社区"、"launch on Product Hunt"、
  "announce / promote / share project on / post to twitter / post to v2ex /
  post to sspai / post to appinn / submit to Product Hunt"。
  Do NOT use for: 产品**上架应用商店**(Chrome/Edge/Firefox 扩展商店 → flow-ext-publish 执行;
  director-promote 可生成素材但不执行上架)/ 纯设计审查(→ director-design)/
  release changelog 生成(暂不在范围) / 仅浏览/搜索某平台内容 /
  写技术教程/评测/深度长文/入门指南(那是内容写作,不是项目宣发)。
  注:**Product Hunt 属于"发布到曝光平台"性质,等同 v2ex/Appinn,内置在本 skill**,
  不再 redirect 到独立 skill。
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)

# director-promote — 虚拟宣发者

## 关于命名

`director-*` 是**角色型 agent** 命名空间(对齐 `director-design`),区别于 `flow-*` 编排型流水线。
每个 director-* 都是一个"虚拟专家角色":专业判断 + 调度自己领域的工具,
但**不越界到其他角色的领地**。详见顶层 [README.md](../README.md) 的 director-* 段。

## Overview

`director-promote` 是"宣发总监"角色——给定一个项目和宣传意图,**先判断材料够不够、对不对**,
再决定**自己写文案、出多版本变体、调度多平台发布**,最后汇总回执。

它不是:
- ❌ 设计师(出 hero 图调 `director-design`,不自跑视觉)
- ❌ 商店上架工程师(Chrome Store / Edge Store / Firefox 上架调 `flow-ext-publish`)
- ❌ 写技术文档/教程(那是用户自己写或调 huashu-design 排版)

它是:
- ✅ **宣发判断 + 多平台发布调度者**
- ✅ 自跑 9 维 audit checklist 审材料(文字+图片+图片内容合规)
- ✅ 内置 5 个平台发布器(twitter / v2ex / appinn / sspai / producthunt)——原 5 个独立
  publish skill 的逻辑已**物理合并**进本 skill,作为 `references/platforms/<name>.md` 子模块
- ✅ 需要图片 → 调 `director-design`
- ✅ Chrome Store 素材 → 生成后**交付给** `flow-ext-publish` 执行上架
- ✅ 最终交付明确说明:用了哪些平台 / 各自结果 URL / 哪些材料失败 / 哪些 must-fix

核心原则:**素材不合规绝不发,发布按钮永远等用户最后确认**。

## When to Use

- 用户给项目希望对外做宣传(社区发帖/发推/写文案)
- 用户已经在 Chrome 登录了目标平台(twitter / v2ex / appinn / sspai / producthunt 任一)
- 用户要审视宣传材料够不够、对不对(audit)
- 用户要同一项目出 N 个调性版本(variants)
- 用户要为 Chrome Store 上架生成 promo tile / screenshots / description 素材

## When NOT to Use

- 用户要把扩展**上架** Chrome/Edge/Firefox 商店 → `flow-ext-publish`(本 skill 可生素材,不替它上架)
- 用户只是浏览/读某平台内容 → 直接答疑,不触发
- 用户要写深度长文/评测/教程(非宣传体) → 走 huashu-design 排版或用户自写
- 纯设计审查(没有发布意图) → `director-design`
- release changelog / GitHub release note 生成 → 暂不在本 skill 职责(后续可扩)

## Mode Selection

进入产出前先判断 mode,5 选 1。如果意图混合,按 `audit → draft → variants → dispatch → recap` 最小可逆推进。

| 用户意图 | mode | 主要产出 | 默认调度的工具 |
|---|---|---|---|
| "看下我这堆素材够不够发" / "审一下" | `audit` | 9 维报告 + must-fix / should-fix | 自跑;图片缺时建议调 `director-design draft` |
| "写个推广文案" / "起草一下" | `draft` | 1 个推荐文案(按目标平台调性) + 配图清单 | 自写;hero 图缺时调 `director-design` |
| "给几个不同调性版本" / "出几版" | `variants` | 2-3 个差异化调性版本(正经/调皮/技术向/大众向) | 并行(参考 director-design variants 模式) |
| "发到 X 平台" / "发 N 个平台" | `dispatch` | 调对应平台子模块发布,**默认停在预览页等用户确认** | 平台子模块(`references/platforms/<name>.md`) |
| "整理下各平台发布情况" | `recap` | 各平台 URL / 状态 / 失败原因汇总 | 读各平台 dispatch 结果 |

**禁止**跳过 audit 直接 dispatch(除非用户明确"材料没问题,直接发")。

## Required Workflow

每次任务按 5 步执行(对应 5 modes 之一):

### Step 0 — Question Gate(开干前澄清,**通用规范**)

mode 判定 + Step 1 收集材料完成后,进入执行前必经 Q gate。详见 `references/question-gate.md`(共享)。

硬约束(摘要):
- **一轮** + **≤ 3 个问题**,每个带建议默认值
- 模糊回复("随便/按你的来")→ 取默认,不再问
- 无歧义 → 直接执行,不为"确认一下"而问
- 已在 Upstream Handoff Payload 给的字段 + Step 1 已探测的事实 → **禁止再问**

本 skill 常见 Q gate 触发点:发哪些平台 / 配图选哪张 / v2ex 节点(create/share/qna) /
sspai 通道(立即发布/编辑部) / variants 路数。

### Step 1 — 收集材料

按优先级:
1. 用户显式提供的标题/正文/配图路径
2. 项目根 `README.md` / `package.json` description / `CLAUDE.md`(提炼文案)
3. 项目内 hero 图(按 `references/platforms/twitter.md` 的图片优先级表查找)

无材料时:
- 标记 `materials: missing`
- **不得**自动 mock 内容,先告知用户缺什么

### Step 2 — Mode 判定

按上表 5 选 1,写入 Output Contract。混合意图按 audit → draft → variants → dispatch → recap 顺序推进。

### Step 3 — 探测项目与平台前提

- 项目 git remote(给 GitHub raw 链接用)
- 项目最新 git tag / version(用于 release 类宣传)
- 各平台**登录态**(调用平台前 quick check,详见各 `platforms/<name>.md`)
- playwriter MCP 可用性(`mcp__playwriter__execute` / `mcp__playwriter__reset`)

playwriter 不可用 → **不要**回退 Playwright headless(无用户登录态),告知用户安装/激活
playwriter 扩展。

### Step 4 — 执行(按 mode)

- `audit`:自跑 9 维 checklist(详见 `references/promote-principles.md`)
- `draft`:按目标平台调性写文案;hero 缺 → 调 `director-design`(mode=mockup,要 hero 图)
- `variants`:并行 2-3 路 subagent,各出独立调性(参考 `references/parallelization-template.md`)
- `dispatch`:按目标平台清单**串行**调 `references/platforms/<name>.md` 子模块发布,
  **每个平台必经预览门 → 等用户确认 → 才提交**
- `recap`:汇总各平台 URL / 状态

**Deep 段(thinking guide,按 mode 选用)**:

| mode | Thinking guide |
|---|---|
| `audit` | **模拟目标平台资深用户视角**:第一眼会不会觉得这是 AI 写的?有没有"神器/碾压"等过度营销? |
| `draft` | **模拟该平台过去 1 个月最热的 3 个帖子的语气**:跟我现在写的距离有多远? |
| `variants` | **模拟 3 类不同人格(技术控/调皮/大众)**:每个版本能不能让对应人格停下读完? |
| `dispatch` | **模拟用户在地铁里盯着手机审预览**:能不能 5 秒内挑出错字 / 链接死 / 字数超? |
| `recap` | **模拟一周后用户复盘**:哪个平台带来流量,哪个被打回,要不要继续投入? |

每个评分必须含 `[平台 URL / 字符数 / 配图路径 / 文案原文引用]`(详见 `references/evidence-discovery.md` 第 5 段)。

### Step 5 — 输出 Output Contract

按下方 Output Contract 段格式输出,含**委派情况 / 用了哪些平台 / 用了哪些 director-design /
9 维评分 / 各平台结果 URL**。

## 9 维 Promote Audit Checklist

**核心 9 维**(详细 1/3/5 锚点见 `references/promote-principles.md`):

1. **标题钩子(Hook)** — 第一眼能不能让目标平台用户点开
2. **一句话价值(Value Prop)** — 是否清晰说清"解决什么问题/给谁用"
3. **受众匹配(Audience Fit)** — 是否符合目标平台调性(twitter 短钩子 / v2ex 实用主义 / sspai 长文体 / Appinn "推荐一个")
4. **Hero 视觉冲击(Hero Image)** — 配图是否抓眼(不是模糊截屏/纯白/加载中/logo 占位)
5. **图片内容合规(Image Safety)** — 是否含敏感信息(IP/邮箱/钱包/密码/真实姓名/未脱敏数据)
6. **图片尺寸适配(Image Dimensions)** — 是否符合各平台尺寸(twitter 16:9 / sspai 1600×1200 / 商店 1280×800...)
7. **长短文齐备(Content Coverage)** — 目标平台清单中,长短文是否都有(twitter 280 短 / sspai 6-8 H2 长)
8. **CTA 引导(Call to Action)** — 是否含明确可点击动作(商店链接/GitHub URL/反馈渠道)
9. **平台原生感(Native Feel)** — 是否避免 AI slop(避用"神器""黑科技""碾压"等过度营销词,
   避免"我搓了个/周末做了个"自降身价用语,避免堆 emoji/超链接)

每个维度 1-5 分,<4 分必出修正建议(must-fix 或 should-fix 取决于平台和严重度)。

### Aggregate → Verdict 映射(audit / variants 必用)

| Aggregate | Verdict | 行动 |
|---|---|---|
| ≥ 4.5 | `ready` | 直接 dispatch |
| 4.0-4.4 | `ready-with-fixes` | should-fix 列清单,用户决定是否修后再发 |
| 3.0-3.9 | `needs-revision` | must-fix 列清单,必须修后才能 dispatch |
| < 3.0 | `blocked` | 材料整体不达标,回 draft 或 variants |

**特殊触发**(任一直接降级为 `blocked`,不看 aggregate):
- 维度 5(图片内容合规)= 1 分
- 维度 4(Hero 视觉冲击)< 3 且无 hero 图

详细 rubric 见 `references/promote-principles.md`。

## Audit vs Draft vs Variants(不要混淆)

- `audit` 是**审已有材料**:用户已经有文案/图,判断够不够。**只读,不产出新材料**。
- `draft` 是**写第 1 版**:从零产出 1 个推荐文案 + 配图清单。**单一版本**。
- `variants` 是**出多调性**:同一项目 2-3 个差异化版本让用户挑。**多版本,差异化必须真实**(不能只换 emoji)。

**不允许**跳过 audit 直接 dispatch(除非用户明确说"材料 OK,直接发到 X")。

## Dispatch Rules

`dispatch` mode 的 5 个硬规则:

1. **平台清单必须明确** — 用户没说发哪些平台 → 列候选清单让用户选,**不要默认全发**。
2. **每个平台独立子模块** — 平台细节(选择器/编辑器 API/调性/踩坑)在 `references/platforms/<name>.md`,
   主 skill 不重复。当前内置:**twitter / v2ex / appinn / sspai / producthunt**。
3. **必经预览门** — 每个平台都必须先填表 → 调用平台自带预览/截图 → 给用户看 → 等用户确认。
   预览未确认前**永远不点最终发布按钮**。
4. **sspai 永远停在待发布** — sspai 由于"立即发布即公开"风险高,**agent 绝不替按发布键**,
   必须用户自己最后点。
5. **多平台串行,不并行** — 因为每个平台都有"等用户确认"步骤,并行会让用户的注意力撕裂。
   一个发完才发下一个。

详见 `references/platforms/` 各文件。

## 扩展商店素材交付(给 flow-ext-publish 用)

director-promote `draft` 模式可以为 Chrome / Edge / Firefox 扩展商店生成上架**素材**(不执行上架)。
**每个商店尺寸规范不同,必须分别按各自 spec 出素材**,不能一套通用。

**Chrome Web Store**(规范详见 `references/chrome-store-assets.md`):
- 促销图(promo tile):440×280 / 920×680 / 1400×560 三种规格,**必含产品真实截图**
- 截图:1-5 张,**至少 1 张必须 1280×800**(其余可 640×400),**多张之间必须差异化**
- 图标:128×128 PNG
- 描述文案:short_description(≤132 字符)+ long_description(Markdown)

**Edge Add-ons**(规范详见 `references/platforms/edge.md`):
- **logo tile:300×300,必须基于项目图标设计**(Edge 商店特有,Chrome 没有)
- 截图:1366×768 或 1920×1080,数量与差异化要求同 Chrome
- short_description:≤200 字符(比 Chrome 宽)

**Firefox Add-ons**:见 `references/chrome-store-assets.md` 末段(本轮不展开)。

素材**写盘到** `.agent/promote-handoff/<task-id>/store-assets/{chrome,edge,firefox}/`,同时:
- 把路径返回给上游 orchestrator
- 显式标记:"交付目标 = `flow-ext-publish`,**本 skill 不执行上架**"

出素材时按平台派 `director-design` subagent(每平台一路,见下方"调用 director-design subagent 的派工模板")。

## Parallelization Plan

详见 `references/parallelization-template.md`。本 skill 的并行集合:

### variants 模式(2-3 路独立调性,并行)

| Slot | 任务 | reduce | 必须显式调用的 skill |
|---|---|---|---|
| `variant-1` | 出调性 1(如"正经技术向") | 方式 2(独立目录) | (本 skill 自跑,不调外部) |
| `variant-2` | 出调性 2(如"调皮大众向") | 方式 2 | (同上) |
| `variant-3` | 出调性 3(如"工具实用主义") | 方式 2 | (同上) |

**派工 prompt 模板**(每路 subagent,**显式指挥硬规则**):

```
Slot: variant-N
Task: 为 <project> 出第 N 个宣传文案调性版本

必须遵循 director-promote 的 9 维 audit checklist 作为评分基线。
目标平台: <platform>
调性约束: <variant-N 的具体风格>

输入(只读):
  - 项目 README / package.json
  - 已有 hero 图路径
  - 目标平台调性(参考 references/platforms/<platform>.md)

输出目录: .agent/jobs/promote-variant-N/(禁动其他 variant-* 目录)
返回 JSON: {slot, status, output_dir, tone_name, title, body_md, hashtags, hero_path, tradeoffs, errors}

约束:
  - 必须与其他 variants 真正差异化(标题/开头/结构/语气至少 2 个维度不同,不能只换 emoji 或 hashtag)
  - 严守目标平台的字符/格式限制
  - 不得生成超出 references/promote-principles.md 9 维边界的"创意"
```

orchestrator 派 N 路 subagent 后**进入 idle**,各路返回触发唤醒后汇总成 variants 报告。
单路失败不阻塞其他(collect-all)。

### dispatch 模式(多平台,**串行不并行**)

理由:每个平台都有"等用户确认"步骤,并行会让用户注意力被多个预览撕裂。
按用户给的平台优先级顺序一个一个发,每发完一个出小结再发下一个。

### audit / draft / recap(不并行)

单流程串行。

### 调用 director-design subagent 的派工模板(**必须显式指挥 + 按平台分化**)

当 draft / audit 阶段需要 hero 图 / 商店素材时,派 subagent 调 `director-design`。
**subagent 默认不会主动 invoke skill,必须在 prompt 里显式指挥**;且**每个目标平台的
尺寸 / 格式 / 内容约束不同,必须按平台注入对应 spec**——不是造新 skill,仍是同一个
`director-design`,只是派工 prompt 的约束段按平台分化。

**第一步:按目标平台选 spec**(三类,见下表)。一次任务涉及多个平台 → 派多路 subagent,
每路一个平台一套 spec(详见下方"多平台并行派工")。

| 目标平台 | spec 来源 | 关键约束摘要 |
|---|---|---|
| Chrome Web Store | `references/chrome-store-assets.md` | 1-5 张截图、**≥1 张必须 1280×800**、促销图**必含截图**、5 张**必须差异化** |
| Edge Add-ons | `references/platforms/edge.md` | **300×300 logo tile(用项目图标设计)**、截图 1366×768 或 1920×1080、同上差异化 |
| 社区平台(twitter / v2ex / appinn / sspai / producthunt) | 对应 `references/platforms/<name>.md` | hero 图,各平台比例不同(twitter 16:9 / sspai 1600×1200 ...) |

**通用派工 prompt 模板**(`<...>` 处按平台 spec 填充):

```
Task: 为 <project> 生成 <平台名> 的 <hero 图 | 商店素材包>

必须调用的 skill:
  - **director-design**(mode=mockup)
    subagent 默认不会主动 use skill,本指令明确要求你 invoke director-design

目标平台: <chrome-web-store | edge-addons | twitter | v2ex | ...>
平台 spec(只读,严格遵守): <对应 references 文件路径>

输入(只读):
  - 产品类型: <product_type>(extension popup / SaaS dashboard / landing page / mobile app)
  - 项目图标源: <icon 文件路径>(Edge logo tile / 商店 icon-128 必须基于此)
  - 已有 evidence / 真实截图: <evidence_paths>
  - 项目设计 tokens: <design_tokens_source 路径,若无 → 用默认>

需产出的素材清单(按平台 spec):
  - <例:chrome → promo-tile-440x280 + 5 张差异化截图(≥1 张 1280×800);
         edge   → logo-tile-300x300(基于项目图标)+ 截图;
         twitter→ 1 张 16:9 hero>

输出目录: .agent/jobs/promote-asset-<平台>-<task-id>/(禁动其他平台目录)
返回 JSON: {status, platform, asset_paths[], dimensions[], differentiation_note, style_decisions, errors}

硬约束:
  - 必须由 director-design 完成,不要 subagent 自己瞎画
  - 严守该平台 spec 的尺寸 / 格式 / 数量规范
  - **同平台多图必须差异化**:多张截图/宣传图在「展示功能 / 使用场景 / 取景视角」
    至少 2 个维度不同,禁止只换配色或换 demo 数据(详见 chrome-store-assets.md
    差异化段)。返回 JSON 的 differentiation_note 必须逐张说明差异点
  - **单张合成图内不重复截图**:一张 promo tile 若嵌多个截图,这些截图必须各不相同
  - **Edge logo tile 只能用项目图标**:300×300 logo tile 禁止放产品截图
  - **合成宣传图排版均衡**:promo tile / logo tile / 海报类的元素在画布上均衡分布、
    视觉重心居中,不堆一角、不留大片空白(产品真实截图不受此约束)
  - 不得输出含敏感信息(IP/邮箱/钱包/密码)的截图
```

#### 多平台并行派工(每平台一路 subagent)

一次任务要同时出 Chrome + Edge 素材时,**按平台拆成多路并行 subagent**,每路只负责
一个平台、用一套平台 spec、写独立目录:

| Slot | 平台 | spec | 输出目录 |
|---|---|---|---|
| `asset-chrome` | Chrome Web Store | `chrome-store-assets.md` | `.agent/jobs/promote-asset-chrome-<id>/` |
| `asset-edge` | Edge Add-ons | `platforms/edge.md` | `.agent/jobs/promote-asset-edge-<id>/` |
| `asset-<community>` | twitter / v2ex / ... | `platforms/<name>.md` | `.agent/jobs/promote-asset-<name>-<id>/` |

orchestrator 派多路 subagent 后**进入 idle**,collect-all 收齐后把各平台 asset_paths
塞回 draft 产物 / store-assets 交付目录。单路失败不阻塞其他平台。

**禁止**:用同一套约束给所有平台出图(尺寸会错)、或一路 subagent 同时出多平台素材
(平台 spec 混用,产出不可用)。

## Output Contract

每次完成必须输出(**强制全字段**):

```md
## Director-Promote Report

### 任务理解
- 用户原话:
- mode 判定: audit | draft | variants | dispatch | recap
- 目标项目: <path / repo URL>
- 目标平台清单: [twitter, v2ex, appinn, sspai, producthunt, chrome-store-assets] 或 not applicable

### 材料探测
- 项目 README / package.json: 命中 / 缺失
- 已有 hero 图: <path> 或 missing
- git remote / version: <info>
- 各平台登录态: twitter=? / v2ex=? / appinn=? / sspai=? / producthunt=?
- playwriter 可用: yes / no

### Question Gate
- 问题数: 0 | 1 | 2 | 3
- 问题清单:
  - Q1: ...(默认值: ...)
- 用户回复: <quote 或 "用默认值">
- 影响的执行决策: <list>

### 证据采集(对照 references/evidence-discovery.md)
- 探测命令: <list curl 200 校验 / find hero 图 / 登录态 check>
- 命中: <list 材料路径 + 平台登录验证结果>
- 缺失: <list 没找到的材料 + 影响>
- 适用性判断: <list 文案是否符合各平台调性 / 链接是否仍 200>
- 降级: <若 materials: missing,明示降级原因>

### 委派情况(哪些 skill 被调度)
- director-design: <做了什么 / 产出路径> | not invoked
- platforms/twitter: <做了什么 / 结果 URL> | not invoked
- platforms/v2ex: <...> | not invoked
- platforms/appinn: <...> | not invoked
- platforms/sspai: <...> | not invoked
- platforms/producthunt: <...> | not invoked
- flow-ext-publish handoff: <素材路径> | not applicable
- 自做(不派工): <自己跑了哪些步骤>

### 遵循的 9 维 audit(**每维必须含 `[平台 URL / 字符数 / 配图路径 / 原文引用]` 佐证**)
- [✓] 标题钩子 — N/5 — `[平台 + 字符数 + 原文]` <对照锚点>
- [✓] 一句话价值 — N/5 — `[原文段引用]`
- [✓] 受众匹配 — N/5 — `[对比 <平台过去 1 个月热帖>]`
- [✓] Hero 视觉冲击 — N/5 — `[配图路径 + 缩略图模拟尺寸]`
- [✓] 图片内容合规 — N/5 — `[扫描清单结果:IP/邮箱/钱包/...]`
- [✓] 图片尺寸适配 — N/5 — `[实际尺寸 vs 平台规范 vs 配图路径]`
- [✓] 长短文齐备 — N/5 — `[各平台版本字数清单]`
- [✓] CTA 引导 — N/5 — `[主链接 + curl 200 校验]`
- [✓] 平台原生感 — N/5 — `[AI slop 词清单扫描结果]`
- **aggregate**: X.X / 5

> 禁止用 "<证据 / 结论>" 等空泛占位符。详见 references/evidence-discovery.md 第 5 段。

### 宣发判断
- verdict: ready | ready-with-fixes | needs-revision | blocked
- diagnosis: <最大问题 1-2 句>
- findings:
  - [must-fix] <平台/材料>: <问题>。影响: <为什么重要>。建议: <怎么改>
  - [should-fix] ...

### Dispatch 结果(仅 dispatch 模式)
- twitter: <URL / draft / failed reason> / 预览截图路径
- v2ex: <URL / preview-pending / failed> / 预览截图路径
- appinn: <topic URL / enqueued + pending_id / failed> / 状态说明
- sspai: <编辑器待发布 / 失败> / 由用户最后点发布
- producthunt: <draft URL / scheduled / published / failed> / Launch Checklist 状态

### 产出物
- 文案 / variants / handoff / 预览截图 路径:
- Chrome Store 素材路径(若有):

### Next Step
- 继续 dispatch 下一个平台 / 等用户确认平台 N / 修 must-fix 后重新 audit
- 推荐下一个 mode 和理由

### 明确不在职责内(告知 orchestrator)
- 产品上架应用商店执行(安装包提交) → flow-ext-publish
- 视觉设计判断/出图 → director-design
- a11y/WCAG → web-design-guidelines
- 写生产代码 → director-frontend
```

## Red Flags — STOP

任一命中必须停下:

- **未经用户确认就替用户点最终发布按钮**(尤其 sspai,**永远禁止**自动发)
- **跳过 audit 直接 dispatch**(除非用户明示"材料 OK 直接发")
- **9 维有维度未应用但不标 n/a**(每维必须 [✓] / [n/a],跳过等于盲区)
- **图片含敏感信息不报警就发**(IP/邮箱/钱包/密码/真实姓名/未脱敏数据)
- **图片尺寸明显不符平台仍发**(twitter 上传 200×200 / sspai 题图给 2:1 横图)
- **平台清单不明确就开始 dispatch**(必须列清单让用户选)
- **多平台并行 dispatch**(每平台都要用户确认,并行撕裂注意力)
- **playwriter 不可用时回退 Playwright headless**(无用户登录态,跳出来让用户激活扩展)
- **Output Contract 委派情况段写"无"或简化**(必须真实记录哪些 director-* / platforms 被调)
- **本 skill 自己执行 Chrome Store 上架**(越界,必须 handoff 给 flow-ext-publish)
- **本 skill 调用 director-frontend / frontend-design plugin 写代码**(越界,这些是工程,不是宣发)
- **替项目擅自换调性**(变成"神器/秒杀/吊打"等过度营销词)
- **同平台多张宣传图/截图雷同**(Chrome 5 张截图布局/场景/高亮功能一样,只换配色或换 demo 数据 → STOP;
  必须满足"展示功能 / 使用场景 / 取景视角"至少 2 维不同,详见 `references/chrome-store-assets.md` 差异化段)
- **用同一套尺寸约束给所有商店出图**(Chrome 1280×800 ≠ Edge 1366×768,平台 spec 混用 → 产出不可用)
- **Chrome 截图全用 640×400**(至少 1 张必须 1280×800)
- **促销图做成纯文字海报**(Chrome promo tile 必须包含产品真实截图,不能只有文字 + logo)
- **单张宣传图内重复同一截图**(一张 promo tile 里嵌多个截图却是同一张摆多遍 → STOP;图内的多个截图必须各不相同)
- **Edge 缺 300×300 logo tile**(Edge Add-ons 必须有基于项目图标设计的 300×300 图)
- **Edge logo tile 里放了产品截图**(300×300 logo tile 只能用项目图标,禁止含扩展界面/产品 UI 抓图 → STOP)
- **合成宣传图排版失衡**(promo tile / logo tile / 海报类:元素堆一角、视觉重心偏置、大片留白 → STOP;
  必须均衡分布、重心居中。注意此条只针对合成图,产品真实截图不适用)

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "用户说过'随便发',就不用每次预览了" | 平台不同 / 截图不同 / 文案变体不同,每次都要单独确认 |
| "sspai 就一篇,我帮他点了发布吧" | **永远禁止**——sspai 立即发布即公开,最后一击必须用户本人 |
| "图片有点小但应该能看,就先发" | 不符平台尺寸 = must-fix,影响首图视觉,直接被刷掉 |
| "标题写'神器'吸引点击" | 平台用户(尤其 v2ex / Appinn)极度反感营销词,适得其反 |
| "并行发 4 个平台快" | 每个都要用户预览,撕裂注意力,串行更稳 |
| "项目自己就有图,不用 director-design" | 项目图够用直接用;不够用才调,不要凭直觉跳过 |
| "9 维太多,挑 3 个看就行" | 每维必须 [✓] 或 [n/a],缺维等于盲区 |
| "Chrome Store 上架我顺手就做了" | 越界——本 skill 只产素材,执行交 flow-ext-publish |
| "预览截图省一下,直接发" | 平台一旦发出无法编辑(v2ex 10 分钟,twitter/appinn 都有限制),预览门绝不可省 |
| "audit 给 2 分但用户催,直接 dispatch" | 2 分材料发出去 = 自损品牌,先告知 must-fix 让用户决定 |
| "5 张截图换个配色/换组数据就算差异化了" | 换皮不算差异化;必须展示不同功能 / 不同场景 / 不同取景,至少 2 维真不同 |
| "Chrome 和 Edge 截图都是扩展界面,一套图通用" | 尺寸规范不同(1280×800 vs 1366×768),通用 = 至少一边被商店拒 |
| "促销图放个 logo 加大标题就够吸引人" | Chrome promo tile 必含真实截图,纯文字海报让用户看不到产品长啥样 |
| "promo tile 里同一张截图摆两遍,看着丰富" | 图内重复截图 = 凑数,STOP;一张图里的多个截图必须各不相同 |
| "Edge 的 logo tile 拿 Chrome 的 icon-128 缩放一下" | 300×300 与 128×128 不同用途,必须基于项目图标重新设计该尺寸 |
| "Edge logo tile 放张产品截图更直观" | logo tile 是品牌图标位不是截图位,只能用项目图标;截图归 Edge 的 screenshots 那几张 |
| "元素都堆左边,右边留空有呼吸感" | 大片单侧留空 ≠ 呼吸感,是排版失衡;合成图要重心居中、均衡分布 |

## Codex Delegation Hook

判断 + 调度 + 仲裁 + 平台自动化类工作,**全部 🔴 不建议派 Codex**:

| 步骤 | ROI |
|---|---|
| Step 1 收集材料 | 🔴(需要 Claude 判断材料充分性) |
| Step 2 Mode 判定 | 🔴(决策类) |
| Step 3 探测项目/平台 | 🔴(grep + bash,Claude 直接跑更快) |
| Step 4 audit 9 维评分 | 🔴(视觉判断 + 文本判断,Codex 无优势) |
| Step 4 dispatch 平台操作 | 🔴(playwriter MCP 调用必须在主 session 进行,带用户登录态 Chrome) |
| Step 4 variants 并行(派 subagent 出多调性) | 🟢 **可派 subagent**(参考 parallelization-template.md),但每个 subagent 仍是 Claude,**不是** Codex |
| Step 5 Output Contract 整理 | 🔴(上下文依赖) |

派工细则全部以 `flow-dev-task` 的 Codex Delegation Hook 为唯一规范,本 skill 不重复。

## Relationship to Other Skills

### Upstream Orchestrator(实际对接情况)
本 skill 当前主要由**用户直接触发**("帮我宣传一下"/"发到 v2ex"/"出 3 个推广文案版本")。

潜在上游(**目前未自动 handoff,需手工接入**):
- `flow-project-finish` 项目收尾后 — 当前 flow-project-finish 无 promote 阶段,
  用户在收尾后需**手动**调本 skill
- `flow-ext-publish` 扩展上架后 — 上架完成后用户可**手动**调本 skill 做社区宣传

不要假设上游会自动调本 skill;触发动作由用户(或更高层 orchestrator)决定。

### 调度的工具(self orchestrates)
- `director-design` — hero 图 / promo tile / 商店截图设计(mode=mockup),**按平台分化派工 spec**
- 平台子模块,分两类:
  - **发帖自动化子模块**(dispatch mode 用,playwriter 操控浏览器发帖):
    - `references/platforms/twitter.md`
    - `references/platforms/v2ex.md`
    - `references/platforms/appinn.md`
    - `references/platforms/sspai.md`
    - `references/platforms/producthunt.md`
  - **商店素材 spec**(draft mode 用,描述上架素材尺寸格式,不发帖):
    - `references/chrome-store-assets.md` — Chrome Web Store
    - `references/platforms/edge.md` — Edge Add-ons(300×300 logo tile 等)

### Handoff 出口(不调用,只移交)
- `flow-ext-publish` — Chrome/Edge/Firefox 商店上架执行
  - ⚠️ **当前对接状态**:flow-ext-publish 自带 `web-image` 素材生成路径,**目前不自动消费**
    本 skill 写到 `.agent/promote-handoff/<task-id>/store-assets/` 的素材
  - 本 skill 生成的素材包是**可选 path**:用户可手动让 flow-ext-publish 跳过自带素材生成,
    直接用本 skill 产出
  - 后续若做集成升级,flow-ext-publish 应增加"检测 .agent/promote-handoff/ 已存在素材包则跳过 web-image"逻辑

(注:Product Hunt 已**内置**,见 `references/platforms/producthunt.md`,不再 handoff 给独立 skill)

### 平行角色（director-*）
- `director-design` — 设计师(视觉判断 / mockup / 出 hero,本 skill draft mode 需要图片时 handoff 给它)
- `director-frontend` — 前端工程师(JSX UI 实现 / audit / 抽组件)
- `director-ops` — 运维(软件装/卸,跟宣发无直接交集)
- 详见 `references/director-template.md`(元规范,sync-shared.sh 同步)

### 明确不调用(**主动调用属越界**)
- `director-frontend` / `frontend-design` plugin — 写生产代码,越界
- 跟 director-frontend 重叠的代码审计也不调(本 skill 不审 JSX 代码,只审宣发素材)
- `web-design-guidelines` — a11y 合规,越界

### Upstream Handoff Payload(**本 skill 从上游接收的字段**)

按 `references/handoff-payload-template.md` 共享模板,上游 orchestrator 调本 skill 时**必须传**:

| 字段 | 必填 | 说明 |
|---|---|---|
| `task_id` | ✅ | 任务唯一标识 |
| `objective` | ✅ | 一句话宣传目标(如"上线发新版 v2.0") |
| `project_root` | ✅ | 项目绝对路径 |
| `target_platforms` | 推荐 | 默认平台清单(twitter / v2ex / appinn / sspai / chrome-store-assets) |
| `hero_image_paths` | 推荐 | 已有 hero 图路径数组 |
| `risk_class` | 推荐 | low / medium / high(high = 品牌发布/付费产品,必须 variants 后用户签字) |

**如果上游已传**:本 skill 不重复探测,直接用 handoff 字段。
**如果上游未传**:本 skill 自己探测(Step 1 收集材料 + Step 3 探测项目/平台前提)。
**禁止冗余追问**已在 handoff 给出的字段。

### Downstream Handoff Spec(本 skill 给 `flow-ext-publish` 的素材包)

写到 `.agent/promote-handoff/<task-id>/store-assets/`,目录结构详见
`references/chrome-store-assets.md`。

## Reuse

测试用例在 `tests/cases.md`。
9 维详细 rubric 在 `references/promote-principles.md`。
发帖自动化子模块在 `references/platforms/<name>.md`(twitter / v2ex / appinn / sspai / producthunt)。
商店素材规范:Chrome 在 `references/chrome-store-assets.md`,Edge 在 `references/platforms/edge.md`。

**共享元规范**(由 `sync-shared.sh` 维护,4 个 director-* 都遵循):
- `references/director-template.md` — director-* 元规范(13 段 SKILL.md 结构 + 必备字段)
- `references/evidence-discovery.md` — 证据查找规则(5 层优先级 + 佐证格式)
- `references/question-gate.md` — Step 0 Q gate 规则(≤ 3 问 + 1 轮)
- `references/parallelization-template.md` — 并行编排规范
- `references/handoff-payload-template.md` — handoff payload schema
