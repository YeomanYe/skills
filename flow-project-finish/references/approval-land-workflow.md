# Approval + Land Workflow — Step 3 落地页 / Step 3.3.5 部署切换 / Step 4 交付审查 详细流程

> 本文件抽离自 SKILL.md,管 flow-project-finish 最厚的三段决策树:
> **landing page 三阶段(分流 → 设计 → 落码)** + **部署切换** + **delivery-gate 路由**。
> SKILL.md 主体只保留 stage 简介,所有 if/else 细节、派工 prompt、回流规则在此。

## Step 3 —— 条件落地页

### 进入条件
- Step 0 探测出 `Already a website: no`
- 用户没有显式跳过(说"先不做落地页"则跳过本步)

### 跳过条件(任一即跳过)
- 项目自身就是网站(Next.js / Nuxt / Astro / Vite SPA 等真实 web 应用)
- 项目无对外公开意图(纯内部工具)且用户未要求

### 3.0 既存落地页分流(refresh / rebuild / skip)

**前置区分:landing ≠ preview**

进入分流前,先看 Step 0 的 `Existing landing page` 与 `Existing web preview` 两个字段。为什么必须区分:preview 是开发期"让人试用产物"的资产,landing 是收尾期"介绍产物 + Roadmap + Links"的对外门面;前者经常被同一个 deploy 通道临时顶替,但两者的代码、内容、目录都不应混淆。把 preview 当 landing 来 refresh,会破坏掉一份仍有用的开发资产。

| 探测结果 | 处理 |
|---|---|
| `landing = none`, `preview = none` | 全新生成,跳过分流,正常走 3.1~3.3 |
| `landing = none`, `preview ≠ none` | **不进分流**,按"无既存落地页"处理,落地页生成到与 preview **平行的目录**(默认 `landing/` 或 `website/landing/`)。严禁把 preview 当成"既存落地页"来 refresh/rebuild,也严禁覆盖、改名、移动 preview 目录 —— preview 是平行资产 |
| `landing ≠ none` | 进下方三选一,与 preview 无关(preview 仍按"平行资产"保留) |

如果 Step 0 探测到 `Existing landing page: <path>`(非 none),不要直接走完整生成路径。先把三个选项摆给用户:

| 选项 | 适用 | 行为 |
|------|------|------|
| **refresh** | 既存落地页结构基本可用,只是内容/路线图/链接落后 | 跳过 huashu-design,直接进 3.3 用 frontend-design 在原位 patch:更新功能清单、roadmap、links;尽量不动整体设计语言 |
| **rebuild** | 用户对既存落地页设计本身不满意,愿意重做 | 走完整 3.2 + 3.3,新代码生成到原路径(注意备份提示) |
| **skip** | 用户决定本期不动落地页 | 收尾报告 Step 3 节标"既存落地页保留,本期不更新",列入开放决策让用户后续处理 |

默认推荐 **refresh**(最小破坏),但**永远不替用户选**;选项必须显式呈现。

### 3.1 收集落地页输入

整理传给下游 skill 的紧凑包(~8 bullets):

- 项目名 + 一句话定位(来自 Step 2 的 README)
- 核心功能清单(来自 Step 2)
- 技术栈(决定落地页技术栈对齐策略)
- **路线图来源**:从 `TODO.md` / `ROADMAP.md` / `progress.md` 取,作为落地页的"待办工作"区
- **相关链接**:GitHub repo / Demo / Docs / Discord / 商店地址等(只列真实存在的)
- 项目调性(从 README/品牌色推断,作为给 huashu-design 的输入)
- 是否对外发布(决定是否需要 SEO meta / OG image)

### 3.2 设计方向 + 落地页 Mockup —— 两阶段 director-design 调度（v5.1）

**v5.1 升级**:从"3 路自决定方向"改为"两阶段 director-design 编排",与 flow-project-bootstrap Stage 1.3 完全一致。

理由:差异化由 director-design variants 这个设计专家裁决,比 3 路独立 subagent 各自瞎猜更专业,且保证发散有度(不会三路风格南辕北辙让用户挑不出)。

#### 3.2a — 派 1 个 director-design (variants) 出 3 方向卡（规划阶段,~2 min）

```
必须显式调用 `director-design` skill (mode: variants)

输入:
  - product_type: landing-page
  - objective: <项目名> 的产品落地页
  - is_ui_task: true
  - design_tokens_source: <Step 0 项目品牌色路径,若无填 none>
  - content_contract: <Step 3.1 收集的 8 bullets>
  - variant_count: 3（默认 3 路,保证差异化但不过度发散）

输出: .agent/jobs/director-design-variants/directions.md
返回 JSON: {mode: variants, directions: [
  {slot: 1, style_name, color_direction, font_combo, layout_strategy, key_visual, tradeoff},
  {slot: 2, ...},
  {slot: 3, ...}
], errors}

约束:
  - 3 方向必须真正差异化(布局/信息层级/风格/主色至少 2 维度不同)
  - 内部可调 ui-ux-pro-max 拿权威依据
  - 不写代码,只出方向卡(文字描述)
```

#### 3.2b — 基于 3 方向卡,派 3 路 director-design (mockup) 并行（实现阶段,~5 min）

3 路 subagent 并行实现 mockup,每路明确指定方向卡 N:

```
Slot: landing-mockup-N  (N = 1 | 2 | 3)
Task: 基于 3.2a 方向卡 N 实现落地页 mockup

必须显式调用 `director-design` skill (mode: mockup)

输入:
  - direction_card: <3.2a directions[N-1] 完整 JSON>
  - product_type: landing-page
  - objective: <项目名> 的产品落地页
  - is_ui_task: true
  - design_tokens_source: <Step 0 项目品牌色路径,若无填 none>
  - content_contract: <Step 3.1 收集的 8 bullets>

输出目录: .agent/jobs/landing-mockup-N/
  - index.html        HTML mockup(轻量 100-200 行)
  - styles.css
  - assets/           如有
  - screenshots/      4 断点截图
    - 375.png         mobile (375×667)
    - 768.png         tablet (768×1024)
    - 1024.png        small desktop
    - 1440.png        desktop (1440×900)
  - meta.json         {slot, style_name, layout_strategy, component_reuse_plan, errors}

返回 JSON: {slot, status, mockup_dir, screenshots_dir, style_name, errors}

禁止:
  - 偏离方向卡 N(方向卡是约束,不是建议)
  - 复用其他 slot 的整体结构
  - 写生产代码(实现是 3.3 的事)
  - 单方面替用户选
```

orchestrator 派 3 路 subagent 后**进入 idle**,收齐后做 3.2.5 推送。

#### 3.2.5 飞书自动推送（CC_SESSION_KEY 含 `feishu:` 时强制）

3 路 mockup 全部就绪后:

```bash
bash references/push-mockups.sh \
  "$TASK_DIR" \
  ".agent/jobs/landing-mockup-1" \
  ".agent/jobs/landing-mockup-2" \
  ".agent/jobs/landing-mockup-3"
```

脚本会:
1. 每路取 `375.png` + `1440.png` 共 6 张
2. 用 cc-connect 发到飞书会话
3. 消息文案:
   ```
   落地页 3 路独立 mockup 已就绪(mobile + desktop):

   方向 1: <style_name 1>
   方向 2: <style_name 2>
   方向 3: <style_name 3>

   请回复:
   - "选 1" / "选 2" / "选 3"  → 选定方向进入实现
   - "都不行 重做"             → 派新一轮 3 路
   - "方向 N 改 X"             → 派该路微调
   ```

**非飞书渠道**:跳过推送,orchestrator 把 3 个 mockup 路径回报给用户,等用户回复选哪个。

#### 3.2.6 等用户挑选（不超时）

用户没回时:
- 写到 STATUS.md `## Pending Decision` 段:`等用户从 3 路 mockup 中挑选(mockup 路径 + 截图路径)`
- **不超时** auto-pick(设计选择是重要决策,不应代替用户)
- 用户可能在飞书外(手机 / 出门 / 第二天)回复,flow 不应推进

收到回复后才进 Step 3.3。

#### orchestrator 唤醒条件（用户回复后怎么触发）

push-mockups.sh 写入 STATUS.md `## Pending Decision` 段(含 `<!-- pending-decision-mockup-v1 -->` marker 做幂等去重)。orchestrator 监听方式:
- **IM 渠道**:watcher 周期 poll cc-connect inbox,用户回 "选 N" / "都不行 重做" / "方向 N 改 X" 时,watcher 把回复追加到 STATUS.md `## Human Feedback` 段,orchestrator 下次被 ping 时读到 → 进 Step 3.3 或重派
- **非 IM**:用户在对话里回复 → orchestrator 当场识别 → 进 Step 3.3 或重派
- **手动**:用户编辑 STATUS.md,把 `## Pending Decision` 改成 `## Decision: 选 N` → orchestrator 下次唤醒时识别

#### 重做版本命名（硬规则,避免覆盖旧 mockup）

| 场景 | 输出路径 |
|---|---|
| 初始 3 路 | `.agent/jobs/landing-mockup-{1,2,3}/` |
| "都不行 重做"(全部新派) | `.agent/jobs/landing-mockup-{1,2,3}-v2/` |
| "方向 2 改 X"(单路微调) | `.agent/jobs/landing-mockup-2-v2/`(其他不动) |
| 再次重做 | `-v3` / `-v4` 依次递增 |

**禁止**覆盖原目录(用户可能想对比 v1 / v2)。

#### 3.2 降级

director-design 不可用 → 退回直调 `huashu-design` 3 路并行(同样要求独立性 + 自跑 4 断点截图)。
cc-connect 不可用 → 跳过飞书推送,orchestrator 在对话里贴 mockup 路径。

### 3.3 落地页实现 —— 按项目栈智能选（v5）

用户挑定方向(如"选 2")后,按**项目栈智能选**实现方式:

| 项目栈情况 | 实现方式 | 理由 |
|---|---|---|
| 有前端栈(react/vue/svelte/preact/solid 等) | **A**:调 `frontend-design`,把 mockup-N 作为视觉基准**重写**成对应栈的组件 | 与主项目栈对齐,可复用真实组件 |
| 无前端栈(纯 CLI / 库 / extension 等) | **B**:直接把 `landing-mockup-N/` 拷到 `website/` 当生产代码 | 轻量项目无必要引入框架;mockup 本身就是可用 HTML |

#### A 模式（frontend-design 重写）

传入 frontend-design:
- 选中的 mockup 路径(`.agent/jobs/landing-mockup-N/`)作为**视觉基准**(颜色/字体/布局都对齐 mockup)
- **内容契约(必须三段齐全)**:
  - **大纲(Outline)**:Hero(项目名 + 一句话定位 + 主 CTA)+ Features(核心功能清单展开)+ How it works(可选,仅在交互非自明时加)
  - **路线图(Roadmap)**:从 Step 3.1 抓到的待办工作展开,标注「已完成 / 进行中 / 计划中」三态;空则显式标"暂无公开路线图"
  - **相关链接(Links)**:Step 3.1 收集到的链接,放在 Footer 或独立 Resources 区
- **技术栈契约**:
  - 项目自带前端栈(react/vue/svelte 等) → 落地页用同栈
  - 落地页放在 `website/` 子目录(若用户没指定其他位置)

#### B 模式（直接拷）

```bash
cp -r ".agent/jobs/landing-mockup-N/" "website/"
rm -rf "website/screenshots" "website/meta.json"  # 清掉过程产物
```

把 `website/index.html` 中相对路径 / 链接 / 资产校验一遍。无需 frontend-design 重写。

#### 选完 2 路被淘汰的 mockup

- 默认保留在 `.agent/jobs/landing-mockup-{X,Y}/`(人类可参考)
- 收尾报告标注"可清理"
- 不要在 Step 3.3 时主动删(用户可能想对比再决定)

> **Codex 派工兼容**:用户选定 mockup 后,A 模式 frontend-design 转码代码量较大时(≥ 30 行 / ≥ 2 文件),可按项目 Codex 派工政策路由(详见 `flow-dev-task` 的 Codex Delegation Hook)。**3 路 mockup 选择和内容契约由 Claude 把关**,具体页面实现可派 Codex,但视觉细节(配色、字体、动画感)的最终验收必须由 Step 4.0 director-design audit + Claude 跑过 `agent-browser` 截图验证。B 模式(直接拷 mockup)不涉及代码生成,不派 Codex。

### 3.3.5 部署目标切换 —— 落地页落码后必做

**前提**:Step 0 探测到 `Deployment config ≠ none`,且 Step 3.3 真实产出了落地页代码。`Deployment config` 有三种可能的形态,分别走不同分支:

| Step 0 探测结果 | 本节走法 |
|---|---|
| `none`(文件无 + 公开域名也无) | **跳过本节**,在报告"开放决策"段写"项目无部署配置,落地页部署留给用户后续处理" |
| `[file:<path>:<role>, ...]`(toml/yml 可见) | 走下方"切换规则"主路径 |
| `[platform-only:<platform>:primary]`(文件无,但公开域名暴露了平台) | **跳过自动改文件**,直接走"失败/无法切换的情况"段的"平台后台"分支,在报告里显式列"需在 <platform> 后台改 publish dir 为 <landing path>" |

**为什么必须切**:项目走到收尾意味着功能成型;之前公开部署的预览(让人试用)在角色上已经被新落地页(介绍 + Roadmap + Links)替代。如果只产出落地页代码却不动部署配置,用户线上看到的还是过期预览,等于这步白做。

**核心原则**:**部署目标切换;preview 代码留;子路径迁移交给用户**。

#### 切换规则

1. **识别 primary 部署配置**:Step 0 标注 `primary` 的那一个
2. **改其 build/publish 路径** 指向落地页产物:
   - `vercel.json` → `outputDirectory` 或 `builds[].config.distDir`
   - `netlify.toml` → `[build] publish = ...`
   - GitHub Pages workflow → `actions/upload-pages-artifact` 的 `path`,或 `gh-pages` action 的 `folder`
   - `wrangler.toml` → `[site] bucket` / `pages_build_output_dir`
   - `package.json` 的 `homepage`(仅 CRA 等老项目用)
3. **secondary 部署配置** —— **不自动改**,列给用户显式确认:
   ```
   检测到以下辅助部署配置:
   - <file>: 当前指向 <path>
   - <file>: 当前指向 <path>
   是否一并切换到 <landing build path>?  (是/否/逐个确认)
   ```
   为什么不替用户改:secondary 配置常承担 staging/internal preview/PR 预览等并行通道,统一切可能破坏用户有意保留的其他场景。用户没回 → **不动**,在收尾报告"开放决策"段挂等用户处理

#### 预览的去向 —— 公开下线,代码保留

- **代码原位不动**:preview/demo 目录作为平行资产继续存在
- **公开部署下线**:旧部署配置不再指向 preview,意味着旧公开 URL 切到落地页后,preview 不再有公开入口
- **不自动迁子路径**(如 `/demo`):为什么不自动迁 —— 子路径部署涉及路由重写、子目录 build 命令、CDN 缓存失效,自动改风险高;由用户在收尾后自行决定
- **落地页 Links 段的处理**:
  - 用户希望 preview 仍被人访问 → 收尾报告"开放决策"段提一句"preview 子路径部署待用户后续手工配置",landing Links 段先不指 preview,等用户配好后手工补
  - preview 仅本地可跑 → Links 段指向**仓库 README 的"Run preview locally"段落**(让感兴趣的人 clone 跑)

#### 失败/无法切换的情况

- 部署配置用了**变量 / 平台后台 secret** 决定路径(如 Vercel/Netlify UI 配置而非 toml) → **不强改**,在收尾报告里**显式列出**"需在 <platform> 后台手动调整 publish dir 为 <landing path>",作为开放决策
- 检测到 deployment config 但 build 路径与已知子目录都不匹配(可能动态生成) → 同上,不强改,显式提示

#### 不要做的事

- 删除/重命名/移动 preview 目录(它是平行资产,删 = 丢开发能力)
- 自动改 secondary 部署配置(必须用户确认)
- 把 preview 内容"合并进"落地页(职能不同;让 Links 指过去即可)
- 跳过本节直接进 3.4 截图(用户线上看到的是过期 preview,不是新落地页)
- 在 landing Links 里直接放旧 preview URL(部署已切,旧 URL 现在指向 landing,等于自指)

#### 写入 delivery-gate 证据包的新字段

本节执行后,需要给 Step 4 delivery-gate 多带两项证据:
- `Deployment switched`: `<file>:<old path> → <new path>` 列表(或 `n/a` 若无部署配置)
- `Preview retained at`: `<path>` + 在线/离线状态

### 3.4 落地页响应式截图（并行执行,4 路 subagent）

**并行编排**:4 断点截图完全独立(写不同文件名),按 `references/parallelization-template.md` 派 4 个 subagent 并行:

| Slot | 断点 | 输出路径 | 必须调用的 skill |
|---|---|---|---|
| `screenshot-375` | 375×667 mobile | `.agent/jobs/screenshot-375/landing.png` | `agent-browser`(必须显式)|
| `screenshot-768` | 768×1024 tablet | `.agent/jobs/screenshot-768/landing.png` | `agent-browser` |
| `screenshot-1024` | 1024×768 small desktop | `.agent/jobs/screenshot-1024/landing.png` | `agent-browser` |
| `screenshot-1440` | 1440×900 desktop | `.agent/jobs/screenshot-1440/landing.png` | `agent-browser` |

**派工 prompt 必填**:
- 落地页 URL(本地 dev server / 静态预览)
- 视口尺寸(精确 W×H)
- 输出路径 + 文件名(独立目录避免冲突)
- **必须调用 `agent-browser` skill**(subagent 不会自动用,prompt 里要明示)
- 返回 JSON:`{slot, status, screenshot_path, viewport, errors}`

orchestrator 在派工后 idle,4 路返回后汇总成证据包传给 Step 4 delivery-gate。

**降级**:`agent-browser` 不可用时,orchestrator 显式声明"未做响应式截图"并把缺口告诉 delivery-gate(不强求改用 Claude 自跑——4 个截图串行写也不快)。

## Step 4 —— Delivery Gate(交付审查)

### Step 4.0（v4 新增）—— Director-Design 设计审计（针对已选定的落地代码）

**v5 修正**:3.2 阶段 3 路 mockup 各自有截图,但用户挑了 1 个后 3.3 才落生产代码。
本 step audit 的是**3.3 落地后的真实生产代码**(不是 3 路 mockup)。

进 delivery-gate 之前,**如果有落地页 / UI 改动**,先派 subagent 调 `director-design` 的 `audit` mode:

**派工 prompt 模板**:

```
必须显式调用 `director-design` skill (mode: audit)

输入:
  - evidence_paths: <Step 3.4 落地代码的 4 断点截图路径>
  - selected_mockup_path: <Step 3.2 用户选定的 mockup 目录>
  - product_type: landing-page
  - is_ui_task: true
  - design_tokens_source: <项目品牌 tokens>

输出: 写到 .agent/jobs/director-design-finish-audit/output.md
返回 JSON: {mode: audit, verdict, aggregate, must_fix, should_fix, mockup_alignment_score, errors}

约束:
  - 不修代码,只出 9 维度报告 + 修正建议
  - 特别评估 "mockup 对齐度":落地代码是否忠实还原了用户选定的 mockup(颜色 / 布局 / 间距 / 字体)
  - 偏离 mockup 必须列为 must-fix(除非偏离是因为响应式或框架限制,要明示)
```

**回流规则**:
- verdict = `pass` / `pass-with-fixes` → 进 Step 4 delivery-gate
- verdict = `needs-redesign` → 回 Step 3.3 重做落地代码(带 must-fix 清单)
- mockup_alignment_score < 4/5 → 回 Step 3.3 调整对齐 mockup

非 UI 任务(无落地页改动)跳过 Step 4.0。

### Step 4.1 —— Delivery Gate(交付审查)

Step 1~3 的实际产物全部就位后,调用 `delivery-gate`,把以下证据一次性递交:

- Step 1 的文档同步明细 + 每处 patch 对应的代码位置
- Step 2 的 README 状态 + 命令实测来源
- Step 3 的落地页代码路径 + 3.4 的响应式截图(或缺口声明)
- **Step 3.3.5 部署切换证据**(若执行):`Deployment switched: <file>:<old> → <new>` 列表 + `Preview retained at: <path>` + 在线/离线状态 + 平台后台手动事项(若有)。**递交前 self-check**:对每条声明的 `<file>` 跑 `git diff -- <file>` 确认确实有 publish/output 路径变更,避免"声明切了实际没切"骗过 delivery-gate
- **Step 4.0 director-design audit 报告**(如有)
- Step 0 的项目快照与 git state

`delivery-gate` 的判定回流路由:

| 判定 | 回流 |
|------|------|
| **must-fix on doc patch** | 回 Step 1 修复后重跑 delivery-gate |
| **must-fix on README** | 回 Step 2 修复后重跑 delivery-gate |
| **must-fix on landing page** | 回 Step 3 修复后重跑 delivery-gate(若涉及设计方向问题,可能需要回 3.2 重新挑) |
| **need more visual evidence** | 跑 agent-browser 补截图/录屏后重跑 delivery-gate |
| **all clear** | 进入 Step 5 |

强制规则:

- **不得跳过 delivery-gate 直接 commit**;否则就是用本 skill 旁路了"先审查再提交"的硬约束
- **不得自己代替 delivery-gate 做轻量审查**;它是独立 gate,有自己的 must-fix/should-fix 区分
- 如果当前会话来自 IM 通道,delivery-gate 会自动把视觉证据回流到 IM,本 skill 不要重复发送
