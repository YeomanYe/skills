---
name: microscope
description: >
  [callable-only · 不自主触发,显式点名或被编排调用才用] Use when 用户要"在某个视角下快速看懂一块内容"。
  两种模式:① **设计文档模式**——给有内部复杂度的组件/模块写"产品和工程师都能看懂"的技术设计文档/讲解
  (输入→输出主流程 + 内部为各 case 做的适配);② **改动讲解模式**——改完代码(修 bug/解冲突/接受 review)后
  出"用户视角"讲解(症状场景/根因/现在的行为,≤200 字,不写 file:line/不用技术 jargon)。
  触发短语:"用 microscope"、"写设计文档"、"写技术文档"、"讲清这个组件内部怎么实现"、"各视角讲讲"、
  "讲一下刚改了啥"、"用户视角讲讲"、"recap 这次改动"、"解释下这次修复"、
  "explain how this component works internally"、"explain the fix"、"user-facing recap"。
  **不自主触发**——只在用户显式点名、或被 flow-dev-task 等编排调用时使用,**不要按场景关键词自动触发**。
  Do NOT use for: API 参考 / README / 用户手册 / changelog / commit message / 新 feature 的 release notes。
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)

# microscope —— 把一块内容放到合适视角,讲到对应读者看得懂

## Overview

**核心心智:先在显微镜下看清,再翻译给对应视角的读者。** 一块有内部复杂度的内容(一个组件、一次改动),直接讲最容易写成"贴 API / 贴函数名 / 贴 git diff",结果只有原作者看得懂。microscope 强制:**先吃透,再按目标读者的视角分层翻译**,并在交付前做一次"换位读者"可懂性校验。

按要讲的对象,分两种模式:

| 模式 | 讲什么 | 典型触发 |
|---|---|---|
| **设计文档模式** | 一个有内部 case 处理的**组件/模块**:输入→输出主流程 + 内部为各 case 做的适配 | "写设计文档"、"讲清这个组件内部怎么实现"、"用 microscope" |
| **改动讲解模式** | 一次**代码改动**(修 bug/解冲突/接受 review)对用户意味着什么:症状/根因/现在的行为 | "讲一下刚改了啥"、"recap 这次改动"、被 flow-dev-task 编排调 |

## When to Use / NOT

**用**:别人(PM / 新人 / 跨栈同事 / 终端用户)要"快速看懂"——某个组件是干嘛的+内部为何这么实现(设计文档模式);或这次改动对用户意味着什么(改动讲解模式)。

**不用**:API 参考、README、用户手册、changelog、commit message、新 feature 的 release notes——那些不是"讲内部因果"或"讲单次改动的用户影响"。组件很简单/纯展示(如一个 Button)、内部没 case 处理时也不必用。

**触发纪律**:本 skill **不按关键词自主触发**。只在用户显式点名("用 microscope" / "讲一下刚改了啥"等),或被 `flow-dev-task` 等编排显式调用时启动。

## 模式 A:设计文档

### Required Workflow(A)

按顺序执行,**第 5 步(persona 复审)不是可选项**:

1. **先吃透源码**。读出"输入→输出主流程",以及内部**为每个 case 做了什么适配、按什么顺序**。读不透不动笔——猜着写出来的因果会误导读者。
2. **按固定结构写**(见《文档结构》)。
3. **分层表达**。功能效果用大白话/用户视角;§1/§3/核心改动给工程师,但**每条都带"为什么 / 否则会怎样"的因果**,不只罗列"做了什么"。
4. **画效果图**。有合适绘图工具就用工具;布局/层叠/冻结这类像素效果用 **ASCII 等宽代码块**(mermaid 画不了表格布局,ASCII 在 markdown/Lark 代码块里能保等宽对齐)。
5. **persona 可懂性复审闭环**。派一个 subagent 扮演"**只懂该领域(如表格/电子表格)、完全不懂这个技术栈(如 antd/React/CSS)**"的读者,**只读文档、不读源码**,逐节标出看不懂的术语 / 绕的表述 / ASCII 图歧义;按反馈改,必要时再审一轮,直到该读者能从头顺到尾。**复审 subagent 必须用能力较弱的模型(如 haiku)**——弱模型才暴露得出文档"讲不清"的地方;强模型即使不懂技术栈也会脑补补上、把问题盖住,复审就失真了(见《关键约束》)。

### 文档结构(A)

| 段 | 写什么 | 给谁看 |
|---|---|---|
| **术语表** | 领域读者会反复遇到的词;**同名不同义必须消歧**(例:"锁排序" vs "锁列") | 所有人 |
| **§1 总览** | 为处理这些 case 写了哪些逻辑、**先后顺序**(前一步是后一步的输入) | 工程师 |
| **§2 各 case** | 每个 case = **功能效果**(用户视角,看得见摸得着,配 ASCII 图)+ **核心改动**(技术实现,带因果) | 功能效果给所有人;核心改动给工程师 |
| **§3 依赖顺序** | **互相独立的效果叠在同一处时,谁必须先判断 / 谁压谁,否则冲突** | 工程师 |

### 关键约束(A,最容易写歪的五处)

- **§3"依赖顺序"≠ 数据流顺序**。不是"先算 A 才能算 B"那种自然先后(那归 §1),而是**两个本来不相关的效果落在同一格 / 同一像素 / 同一次点击上,必须按特定顺序或优先级判断谁压谁,否则视觉穿帮或交互打架**(典型:z-index 层叠、点击事件抢占、样式优先级)。每条都写清"判错会出什么问题"。
- **功能效果必须是用户视角**,不是技术动作。写"拖动列右边线,这列实时变宽、其他列不动",不是"mousedown 记 offsetWidth 再 clamp"。
- **核心改动必须带因果**,不能只列"做了 X、Y、Z";每条接一句"为了…… / 否则会……"。
- **persona 复审必跑**。自己觉得清楚 ≠ 外行看得懂;不跑复审等于没做完。
- **persona 复审必须用弱模型**(如 haiku)。用默认/强模型当评审员等于没校验——它会替你脑补看懂,放过该改的地方。

### 最小范例(A,节选)

```markdown
### Case A:拖一列改宽

**功能效果**:鼠标移到两列之间的竖线上,光标变成左右拖拽样式;按住拖动,这一列宽度
实时跟手,**其他列不动、表格整体宽度随之变化**;松手定宽。

  拖前 │Name│Age│City│   ──►   拖后 │Name      │Age│City│   (只有 Name 变宽)

**核心改动**:① 列宽存成组件自己的状态,拖动就改它;② 用样式把表格总宽钉死、关掉浏览器
自动分配列宽——**否则拖一列会按比例牵动其他列**;③ 起算宽用"连内边距的真实宽",否则手柄
会越拖越落在鼠标后面。
```

(功能效果零术语 + ASCII 图;核心改动逐条带"否则会……"。)

## 模式 B:改动讲解(recap)

**核心心智:同传**。开发者改完代码 / agent 解完冲突 / 按 review 改完——但用户(终端用户 / PM / QA)看不懂技术 commit / git diff。本模式把改动**翻译成用户视角**:**症状场景 + 根因(口语化) + 现在的行为**。

**3 类适用场景**:① bugfix(刚修了 bug);② merge-resolve(刚解了冲突);③ accept-review-feedback(按 reviewer / delivery-gate must-fix 改完)。

**不适用**:新加 feature(那是 release notes)、纯 UI 调整(那是 director-design + 截图)、代码解读(那是教学)。

### 受众可配(`--audience end-user|pm|dev`)

| 受众 | 默认 | 语气 / 字典 |
|---|---|---|
| **end-user** | ★ 默认 | 全去技术,用业务术语("登录"/"支付"/"搜索"),不许出现框架名 / 变量名 |
| **pm** | | 可含一点业务模块名 + 影响范围,仍口语化;避免代码细节 |
| **dev** | | 允许提到模块名 + 行为变化(如"timer 触发时机改了"),仍不写 file:line |

CLI 用 `--audience pm|dev` 切换;flow-dev-task 编排调时透传。

### Required Workflow(B)

1. **收集输入**(必读):`git diff <base>...HEAD --stat`(改了多少/哪几类文件)、`git diff <base>...HEAD`(具体改了啥)、当前分支名 + 最近 1-3 个 commit message。可选:spec 路径、agent 自报"我刚做了 X"、task_type、audience。**不收集 diff 就开始写 = 编故事**。
2. **非 UI 边界探测**:`git diff <base>...HEAD --name-only | grep -E '\.(tsx|jsx|vue|svelte|css|scss|less|html)$'`。全是 UI 文件 + 仅视觉调整 → 输出降级提示「建议改用 director-design + 截图更直观,是否继续?」,用户回"继续"才往下;逻辑文件占主/混合 → 正常往下。
3. **生成 3 段讲解**(按 audience 选语气):
   - **症状场景**:1-3 行,用户做什么操作时遇到的问题 / 两边分支冲突的业务场景 / reviewer 提的具体问题。
   - **根因**:1-2 行,**不写 file:line / 变量名 / 框架名**,用业务术语。
   - **现在的行为**:1-3 行,改后用户做同样操作会看到什么。
4. **长度自检(硬约束)**:总字符数 ≤ 200(不含 markdown 标记/段标题);三段各 1-3 行。**end-user 受众**扫一遍,出现以下任一即重写:扩展名(.ts/.tsx/...)、框架名(React/Vue/FastAPI/...)、API/Hook 名(useEffect/useState/Promise/...)、技术 jargon(race condition/debounce/mutex/...)、file:line、任何代码标识符(驼峰/蛇形/含括号)。pm 允许业务模块名;dev 允许模块名+行为,仍不许 file:line。自检失败→当场重写,不许输出"建议你自己理解一下"。
5. **输出**:
   - **用户显式调** → 对话中输出 3 段 + 末尾告知行 `[microscope recap audience=<X>]`。
   - **编排调(flow-dev-task)** → 把 3 段 markdown 返回给编排方,由它决定推 IM / 拼 commit body / 写 spec 头。
   - **IM 推送**(仅编排调时自走 `cc-connect send --message`):**显式调**失败→stop 报警告知用户,不重试;**编排调**失败→**不阻断**主流程,把失败原因塞 Output JSON `im_pushed: "failed (<reason>)"` 让编排方写进报告 `errors[]`;两种都**不重试**。

### 3 段示例(B,end-user)

```md
## 症状场景
在购物车结算时偶尔会卡 3-5 秒。
## 根因
两个步骤抢同一个资源,谁先到谁等。
## 现在的行为
下单结算 1 秒内完成,不再卡顿。
```

(merge-resolve:症状=两边分支冲突的业务场景;accept-review-feedback:症状=reviewer 提的具体问题。)

### Output Contract(B)

```json
{
  "skill": "microscope",
  "mode": "recap",
  "audience": "end-user | pm | dev",
  "task_type": "bugfix | merge-resolve | accept-review-feedback | other",
  "is_ui_change": true,
  "ui_warning_shown": false,
  "recap_markdown": "## 症状场景\\n...\\n\\n## 根因\\n...\\n\\n## 现在的行为\\n...",
  "char_count": 0,
  "self_check": { "no_file_line": true, "no_framework_name": true, "no_tech_jargon": true, "within_length": true },
  "im_pushed": "true | false | skipped (no CC_SESSION_KEY) | failed (<reason>)",
  "next_action": "<下一步建议>"
}
```

## Common Mistakes(两模式通用)

| 写歪的样子 | 改成 |
|---|---|
| (A)功能效果里贴 `mousedown` / `useMemo` / 函数名 | 功能效果只讲"用起来什么样",技术词挪进核心改动 |
| (A)§3 写成 collectLeaf → leafStates 的数据流 | §3 只写"独立效果的判断先后";数据流归 §1 |
| (A)核心改动罗列"做了什么"没因果 | 每条补一句"否则会怎样" |
| (A)persona 复审用默认/强模型 | 换弱模型(haiku)当评审员,否则它脑补看懂、放过问题 |
| (B)不收集 git diff 就凭脑补写 recap | 先读 diff,基于真实改动写 |
| (B)end-user 受众输出含 file:line / 框架名 / 变量名 | 全去技术,违反 audience 硬约束就重写 |
| (B)总字符 > 200 / 三段缺一段 | 压到 ≤200、症状/根因/现在的行为三段齐 |
| 同一个词指两件事(如"锁") | 术语表消歧,正文统一用词 |

## Red Flags — 停下来重写

- (A)功能效果段里出现技术术语 / 函数名 → 挪到核心改动。
- (A)§3 里写的是"先算谁后算谁"的自然顺序 → 那是 §1 的料。
- (A)想跳过 persona 复审("我觉得挺清楚的") → 不跑就是没做完。
- (A)persona 复审用了默认/强模型 → 换弱模型(haiku)重审。
- (B)不读 diff 就写 / 把新 feature 当 recap 写 / end-user 输出含 file:line 或框架名 / 改写代码提议改实现 / 编排调时 IM 推失败仍宣告完成。
- **本 skill 被关键词自动触发**(没人显式点名也没编排调)→ 停,本 skill 是 callable-only。

## Rationalizations to Reject(B)

| 说辞 | 现实 |
|---|---|
| "用户应该看懂技术术语" | 受众是 end-user/pm 时就是不能用,违反 audience 契约 |
| "200 字不够说清楚" | 200 字是硬约束;说不清就再想"用户角度其实就这一句话" |
| "顺便把代码也微调一下" | 改代码不归本 skill;只解读不改 |
| "IM 推失败 retry 一次" | 不重试;失败按调用方式 stop / 塞 errors |

## Relationship to Other Skills

- **上游(调用本 skill)**:用户显式点名;`flow-dev-task` Stage 7.5 commit 前 pre-hook(task_type ∈ bugfix/merge-resolve/accept-review-feedback 且 `--auto-recap=true`,走改动讲解模式)。
- **下游**:无 —— 本 skill 是讲解/理解终点,产出(文档 / 3 段 recap)交调用方处理。
- **不调用**:clean-commit(不写 commit)、director-design(UI 类改动让上游切过去)、任何改代码的 skill(只解读不改)。
- **不替代**:commit message(clean-commit 写)、CHANGELOG / release notes(产品全局)。

## Reuse

测试用例在 `tests/cases.md`,后续修订以这些用例为回归基线。
