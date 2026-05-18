---
name: flow-project-bootstrap
description: Use when a user wants the **full multi-stage** project kickoff chain combining project prep, engineering rules, and design options together. Trigger on requests like "bootstrap this project", "项目初始化", "帮我定 MVP 和规范和设计", "从需求到 kickoff", "完整启动新项目", or any ask that combines MVP scoping, main interaction design, preview requirement decisions, engineering setup, and design direction. For only single-stage prep (MVP + tech stack alone), use `project-prep`. For only engineering rules, use `director-architect`. For only design, use `frontend-design` / `huashu-design`.
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
- 只要工程规范 —— 直接用 `director-architect`
- 只要设计系统建议 —— 直接用 `ui-ux-pro-max`
- 只要 logo 或 preview 页 —— 直接用 `huashu-design` / `frontend-design`
- 项目已进入实现中段，只想调整单一维度

---

## Stage 1 · Discovery & Direction

### Stage 1 并行编排（**v5 简化**）

**执行顺序**：

1. **串行**：`1.1` project-prep（输出 MVP / 技术栈 / Preview decision；目标用户可选）
2. **可选并行**：`1.2` ASCII 流程图（用户要求时）+ `1.5` 部署探测（Bash） — 同时跑
3. **1.3 两阶段**（核心）：
   - **1.3a**（串行）：派 1 个 director-design (variants) 出 3 方向卡（~2 min）
   - **1.3b**（**3 路并行**）：基于方向卡派 3 路 director-design (mockup) 实现（~5 min）
   - **1.3c**（串行）：飞书推送 + 等用户挑选（不超时）
4. **串行**：`1.6` 总设计文档拼装（orchestrator 自己做 reduce，按 8 节顺序合并）

**总节奏**：
- Phase A：1.1 串行（~3 min）
- Phase B：1.2 可选 + 1.5 并行（~1 min）
- Phase C：1.3a → 1.3b 3 路并行 → 1.3c（~10 min + 等用户）
- Phase D：1.6 拼装（~1 min）

orchestrator 在 1.1 完成后派 Phase B/C 并行，自己进入 idle；返回后做 1.6 拼装。

---

### 1.1 项目前置准备（调 `project-prep`）

调用 `project-prep` 锁定：

- **MVP 范围**（in scope / out of scope / non-goals）— **必填**
- **目标用户**与**核心流**（happy path 3-7 步）— **可选**（用户没指定时不强求；个人项目 / 小工具常不需要）
- **主交互设计**（屏幕清单 + 关键动作 + 状态流转 + 决策点）— **必填**
- **主要技术栈**（运行面 + 框架 + 主语言）— **必填**
- **Preview decision**：`Required` / `Not needed` / `Already satisfied` — **必填**

### 1.2 主要流程 ASCII 图（**可选**，用户没要求时跳过）

**v5 改可选**：默认跳过。用户明确说"我要看流程图"才出。

理由：流程图是思考工具，对很多任务非必要；项目复杂度低时反而冗余。需要时按下面格式出：

```
[Entry] → (Action) → ⟨Decision?⟩ ─yes→ [State A]
                            └─no──→ [State B] → (Action) → [Exit]
```

复杂流可拆分子图（一图表达不超过 7 个节点）。

### 1.3 设计方向 + 预览 Mockup（**v5 升级**：两阶段 director-design 调度）

**核心改造**：合并原 1.3（预览功能设计）+ 1.4（推荐设计系统）。默认走两阶段，让用户视觉化选择，不再先文字描述再选。

#### 1.3a — 派 1 个 director-design (variants) 出 3 方向卡（**规划阶段**）

```
必须显式调用 `director-design` skill (mode: variants)

输入:
  - product_type: <Stage 1.1 推断>
  - objective: <一句话设计目标，含 MVP 摘要>
  - is_ui_task: true
  - design_tokens_source: none（新项目尚未建立）
  - variant_count: 3（**默认 3 路**，保证差异化但不过度发散）

输出: .agent/jobs/director-design-variants/directions.md
返回 JSON: {mode: variants, directions: [
  {slot: 1, style_name, color_direction, font_combo, layout_strategy, key_visual, tradeoff},
  {slot: 2, ...},
  {slot: 3, ...}
], errors}

约束:
  - 3 个方向必须真正差异化（布局/信息层级/风格/主色至少 2 维度不同）
  - 内部可调 ui-ux-pro-max 拿权威依据
  - 不写代码，只出方向卡（文字描述，~2 min）
```

#### 1.3b — 基于 3 方向卡，派 3 路 director-design (mockup) 并行（**实现阶段**）

3 路 subagent 并行实现 mockup，每路明确指定方向卡 N：

```
Slot: preview-mockup-N  (N = 1 | 2 | 3)
Task: 基于 1.3a 方向卡 N 实现 preview mockup

必须显式调用 `director-design` skill (mode: mockup)

输入:
  - direction_card: <1.3a directions[N-1] 完整 JSON>
  - product_type: <Stage 1.1>
  - objective: <一句话>
  - is_ui_task: true
  - preview_decision: <Required / Not needed / Already satisfied>
  - component_reuse_required: true（保留原 1.3 硬规则）

输出目录: .agent/jobs/preview-mockup-N/
  - index.html
  - styles.css
  - screenshots/{375,768,1024,1440}.png
  - meta.json {slot, style_name, layout_strategy, component_reuse_plan, errors}

返回 JSON: {slot, status, mockup_dir, screenshots_dir, errors}

**component_reuse_plan**（**硬性要求**，原 1.3 规则保留）:
  - 列出真实组件路径（如 src/popup/Popup.tsx）
  - 适配器层切点（storage / platform API / network 在哪一层抽象）
  - 显式禁止：另起 _preview/MockX.tsx、把 if (PREVIEW_MODE) 写进真实组件
  - 零代码阶段允许临时占位但要写明切回 deadline

**禁止**：
  - 仅换主色不换布局（违反方向卡差异化）
  - 写生产代码（实现是 Stage 2.3 的事）
  - 单方面替用户选
```

#### 1.3c — 飞书自动推送 + 用户挑选（**不超时**）

3 路就绪后调 `references/push-mockups.sh` 推到飞书：

```bash
bash references/push-mockups.sh \
  "$TASK_DIR" \
  ".agent/jobs/preview-mockup-1" \
  ".agent/jobs/preview-mockup-2" \
  ".agent/jobs/preview-mockup-3"
```

脚本行为：
- CC_SESSION_KEY 含 `feishu:` 前缀时触发，每路推 mobile (375) + desktop (1440) 共 6 张
- 消息含 3 个 style_name + 回复选项「选 1/2/3 / 都不行重做 / 方向 N 改 X」
- 非飞书渠道跳过，orchestrator 在对话里贴 mockup 路径
- 幂等 marker 防止重跑追加
- **不超时 auto-pick**（设计选择由用户决定）

用户挑定后进 Stage 2.3（被挑 mockup 落地）。

#### 1.3 降级路径

- director-design 不可用 → 退回直调 `ui-ux-pro-max` + `huashu-design`（同样 3 路并行）
- cc-connect 不可用 → 跳过飞书推送，orchestrator 在对话里贴 3 个 mockup 路径

#### 1.3 重做版本命名（硬规则）

| 场景 | 输出路径 |
|---|---|
| 初始 3 路 | `.agent/jobs/preview-mockup-{1,2,3}/` |
| "都不行 重做"（全部新派） | `-v2` / `-v3` 递增 |
| "方向 2 改 X"（单路微调） | `.agent/jobs/preview-mockup-2-v2/`（其他不动） |

**禁止**覆盖原目录（用户可能要对比 v1 / v2）。

### 1.5 部署方案选择 + 凭据前置检测（**v5.1**）

#### 1.5.1 仓库可见性 → 部署目标

按当前仓库可见性决定部署目标：

| 仓库类型 | 默认部署目标 | 备注 |
|---|---|---|
| **Public**（开源 / 无敏感数据） | **GitHub Pages** | 通过 `.github/workflows/deploy-website.yml` 自动构建 |
| **Private**（闭源 / 含敏感配置 / 商业项目） | **Cloudflare Pages** | Direct Upload (wrangler) 不暴露 build 日志 |

判定方式：
1. 优先用 `gh repo view --json visibility -q .visibility`（需要 gh 已登录）
2. 退而其次：`git remote -v` + 用户自述
3. 都拿不到 → 在总设计文档"开放决策"里列为待用户回答

如果用户主动指定其他目标（Vercel / Netlify / 自托管 / 不部署）→ 按用户指示，但仍要在总设计文档记录**为什么偏离默认**。

#### 1.5.2 部署凭据前置检测（**关键**：Stage 1 就问，不要拖到 Stage 2.4 才卡）

按选定部署目标检测所需环境变量。**缺则立即提示用户配置**，让用户在设计阶段就把凭据搞定，避免 Stage 2.4 部署时才发现 token 没准备。

| 部署目标 | 所需环境变量 | 检测命令 |
|---|---|---|
| **GitHub Pages** | 不需要（git push 即可触发） | n/a |
| **Cloudflare Pages** | `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` | `[[ -n "$CLOUDFLARE_API_TOKEN" ]] && [[ -n "$CLOUDFLARE_ACCOUNT_ID" ]]` |
| **Vercel** | `VERCEL_TOKEN` | `[[ -n "$VERCEL_TOKEN" ]]` |
| **Netlify** | `NETLIFY_AUTH_TOKEN` | `[[ -n "$NETLIFY_AUTH_TOKEN" ]]` |
| **自托管 / 不部署** | n/a | 跳过本节 |

**缺凭据时的处理**（以 Cloudflare 为例，其他目标同模式）：

orchestrator agent 输出如下提示让用户去配（**必须等用户回"配好了"才进 User Gate**）：

```
🔑 部署到 Cloudflare Pages 需要 2 个凭据，请按以下步骤配置后告诉我"配好了"：

1. 创建 API Token（Cloudflare Pages: Edit 权限）：
   https://dash.cloudflare.com/profile/api-tokens
   → Create Token → 模板 "Cloudflare Pages: Edit" → Create

2. 拿 Account ID：
   Cloudflare dashboard 右下角 / 或跑 `npx wrangler whoami`

3. 把它们写到 shell 启动文件（**永久生效**）：

   # macOS / Linux（~/.zshrc 或 ~/.bashrc）:
   export CLOUDFLARE_API_TOKEN="cf_xxxx_your_token"
   export CLOUDFLARE_ACCOUNT_ID="abc123_your_account_id"

   # 然后 source ~/.zshrc 或重开终端

4. 项目级（推荐用 direnv，避免全局污染）:
   echo 'export CLOUDFLARE_API_TOKEN="..."' >> .envrc
   echo 'export CLOUDFLARE_ACCOUNT_ID="..."' >> .envrc
   echo '.envrc' >> .gitignore   # 必须 gitignore！
   direnv allow

5. 验证：
   echo "$CLOUDFLARE_API_TOKEN" | head -c 10   # 应该输出 token 前 10 字符
   npx wrangler whoami                          # 应该列出账户名

配好后回我"配好了"，我会继续 Stage 1 收尾。
```

**安全硬规则**（写入 Red Flags 段）：
- ❌ token 绝不进 git（任何 commit / README / docs）
- ❌ token 不在 prompt / 对话 / log 里裸传（agent 引用要用 `${CLOUDFLARE_API_TOKEN}` 而不是明文）
- ✅ 走 shell 启动文件（全局） / direnv `.envrc`（项目级，含 `.gitignore`）/ keychain（macOS `security add-generic-password`）

**总设计文档第 6 节**记录凭据就绪状态（不记录 token 值本身），见 1.6 模板。

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

## 5. 设计方向 + Preview Mockup（**v5 合并原 5 + 6**）
- Status: Required / Not needed / Already satisfied
- **3 路 mockup 路径**:
  - `.agent/jobs/preview-mockup-1/` — style: <name>
  - `.agent/jobs/preview-mockup-2/` — style: <name>
  - `.agent/jobs/preview-mockup-3/` — style: <name>
- **方向卡**: `.agent/jobs/director-design-variants/directions.md`
- **飞书推送**: pushed (6 截图) | skipped (non-feishu)
- **用户选定**: mockup-N (style: <name>) | pending | "都不行 重做"
- **Component reuse plan**（被挑 mockup 的 meta.json 中提取）:
- 预览页地址（占位）: `<PREVIEW_URL>`（Stage 2.3 完成后回填）

## 6. 部署方案（原 7 节）
- Repo visibility: public / private
- 部署目标: GitHub Pages / Cloudflare Pages / Vercel / Netlify / 自托管 / 不部署
- 偏离默认的理由（如有）:
- **凭据就绪状态**（v5.1）:
  - 所需环境变量: `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID`（按目标改）
  - 检测时间: <ISO ts>
  - 状态: ✅ ready | ⏳ 等用户配置 | n/a (GitHub Pages / 不部署)
  - 存储方式: shell rc | direnv .envrc | keychain
  - **不记录 token 值本身**（敏感信息禁入文档）

## 7. 后续规划（post-MVP roadmap，原 8 节）
（暂缓事项 / 扩展点 / 规模预期；无则明写"本期未讨论"）

## 8. Stage 1 待用户锁定的决策（原 9 节）
- [ ] 接受 MVP 切片
- [ ] **挑选 1 个 preview mockup**（mockup-1 / 2 / 3 / 都不行重做）
- [ ] 确认部署方案
- [ ] 确认后续规划方向
```

---

## Stage 1 / Stage 2 之间的 User Gate

Stage 2 不得自动启动。必须显式问用户：

> Stage 1 总设计文档已就绪。请确认以下决策后我再进入 Stage 2：
> 1. MVP 切片 OK 吗？
> 2. **挑选 1 个 preview mockup**？（mockup-1 / 2 / 3 / "都不行 重做" / "方向 N 改 X"）
> 3. 部署目标确认？
> 4. 后续规划方向 OK 吗？

**v5 简化**：从 5 问降为 4 问（合并原"preview 策略"和"设计系统"为单一"挑 mockup"）。
得到至少 1 / 2 / 3 三项明确回答前不进入 Stage 2。4 可以推断默认。

如果用户回 "都不行 重做" / "方向 N 改 X"：回 1.3 重派（用 `-v2` 后缀，不覆盖原 mockup）。

---

## Stage 2 · Build Scaffold（**2.1 / 2.2 / 2.3 三路并行执行**）

进入 Stage 2 的硬前置：

- Stage 1 总设计文档已落盘
- **用户已挑选 1 个 preview mockup**（不能"3 个混"未拍板）
- 部署目标已确认

### Stage 2 并行编排

**2.1 / 2.2 / 2.3 三路完全独立**（写不同目录，仅共享 Stage 1 总设计文档只读），按 `references/parallelization-template.md` 派 3 个 subagent 并行：

| Slot | Subagent 任务 | 写入目录 | 必须调用的 skill |
|---|---|---|---|
| `engineering-rules` | 调 `director-architect` 生成规范脚手架 | `CONTRIBUTING.md` / `AGENTS.md` / `docs/<domain>/` | `director-architect`（必须显式）|
| `logo-design` | 调 `huashu-design` 出 ≥2 个 logo 方向 | `assets/logos/` 或 `branding/` | `huashu-design`（必须显式）|
| `preview-impl` | 基于 Stage 1.3 已挑选的 preview-mockup-N 落地 | `preview/` 或项目内 preview 路由 | `frontend-design`（A 模式必须显式）/ 直接 cp（B 模式）|

**派工 prompt 必填**（每个 subagent）：
- Stage 1 总设计文档路径 + sha256（只读输入）
- 已挑选的 preview mockup 路径（`.agent/jobs/preview-mockup-N/`，仅 2.3 需要）
- 已锁定的设计 tokens（mockup meta.json 中提取，仅 2.2 / 2.3 需要）
- **黑名单**：禁动其他 2 路目标目录
- 返回 JSON：`{slot, status, outputs, skills_invoked, errors}`

**orchestrator 在 3 路返回后**：
- 检查 3 路 status；任一 fail 不阻塞其他 2 路（collect-all 模式）
- 进 Step 2.4 部署接线（必须 3 路全 ok 才能开始，**部署接线本身串行**）

orchestrator 在派工后 idle，等待 3 路返回。

---

### 2.1 工程规范脚手架（调 `director-architect`）

把已锁定的技术栈 + 业务域 + greenfield/adjacent 状态传给 `director-architect`。

handoff payload 必须含 `approval_inherited_from_orchestrator: true` 字段（因为 Stage 1 user gate
已批准 bootstrap 全流程，Stage 2.1 不再走独立 Approval Gate）。

原样接收产出；不要改述。

> **Codex 派工兼容**：如果 `director-architect` 产出涉及大量样板配置文件（≥ 30 行 / ≥ 2 文件），可按项目 Codex 派工政策路由（详见 `flow-dev-task` 的 Codex Delegation Hook）。规则文档本身（CONTRIBUTING.md / AGENTS.md 等）由 Claude 自己写，不派 Codex。

### 2.2 项目 Logo 设计（调 `huashu-design`）

调用 `huashu-design`，请求至少 2 个 logo 方向：

- 输入上下文：项目名 / 一句话目标 / 已选设计系统的配色与字体
- 要求：每个方向出 SVG + PNG（透明底）+ 简短风格说明
- **不允许**直接套通用 emoji 或纯文字 logo（除非用户明说"先用文字 logo 占位"）

输出落到 `assets/logos/` 或项目 `branding/` 目录，并在总设计文档里加引用。

### 2.3 预览页实现（**v5：直接用 Stage 1.3 已挑选的 mockup 落地**）

**v5 简化**：Stage 1.3 已经派过 3 路 mockup 并让用户挑了一个，本步直接拿来落生产代码（不再重派 director-design mockup）。

**按项目栈智能选实现模式**（同 flow-project-finish v5）：

| 项目栈情况 | 模式 | 行为 |
|---|---|---|
| 有前端栈（react/vue/svelte 等） | **A** frontend-design 重写 | 把 `.agent/jobs/preview-mockup-N/` 作为视觉基准，frontend-design 转成对应栈组件 |
| 无前端栈（纯 CLI / lib / extension） | **B** 直接拷 | `cp -r .agent/jobs/preview-mockup-N/ preview/`（清掉 screenshots / meta.json） |

##### A 模式（frontend-design）

```
必须显式调用 `frontend-design` skill

输入:
  - 已挑选 mockup 路径: .agent/jobs/preview-mockup-N/
  - mockup HTML + CSS 作为视觉基准（颜色/字体/布局都对齐）
  - design_tokens_source: <Stage 2.1 落地的 tokens 路径>
  - target_stack: <Stage 1.1 已锁定的前端栈>
  - target_dir: preview/ 或项目内 preview 路由
  - component_reuse_plan: <从 mockup-N/meta.json 提取>
```

##### B 模式（直接拷）

```bash
cp -r ".agent/jobs/preview-mockup-N/" "preview/"
rm -rf "preview/screenshots" "preview/meta.json"  # 清过程产物
```

##### 处理被挑后剩余 mockup

默认保留 `.agent/jobs/preview-mockup-{X,Y}/`（用户可参考 / 对比）。
Stage 2 收尾报告标注"可清理"。**不要在 2.3 主动删**。

##### 触发条件兼容

- **Required + 有 UI 组件**：A 模式（套已选设计系统的 token + 复用真实组件 + 适配器层）
- **Required + 零代码阶段**：B 模式（直接拷 mockup 当占位 preview，标注切回 deadline）
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

### 2.4 部署接线（**v5.1 升级：自动 wrangler 部署**）

按 Stage 1 第 6 节锁定的目标接线。**凭据应该已在 1.5.2 配齐**，本步直接跑：

#### GitHub Pages
- 建 `.github/workflows/deploy-website.yml`，触发路径限定为 preview 页所在目录
- `git push` 后 GitHub Actions 自动构建
- URL: `https://<owner>.github.io/<repo>/` 或自定义 domain

#### Cloudflare Pages（**自动 wrangler 部署**）

```bash
# 校验凭据（1.5.2 已检测过；这里二次校验防漂移）
[[ -n "$CLOUDFLARE_API_TOKEN" ]] || { echo "ERR: CLOUDFLARE_API_TOKEN missing"; exit 1; }
[[ -n "$CLOUDFLARE_ACCOUNT_ID" ]] || { echo "ERR: CLOUDFLARE_ACCOUNT_ID missing"; exit 1; }

PROJECT_NAME="<repo-name>"  # 默认用 GitHub repo 名

# 1. 首次部署创建项目（已存在会失败但不影响后续）
npx wrangler pages project create "$PROJECT_NAME" \
  --production-branch=main \
  --compatibility-date="$(date +%Y-%m-%d)" \
  2>/dev/null || echo "Project may already exist (ignored)"

# 2. 本地构建（按项目栈）
pnpm build || npm run build || vite build

# 3. 部署 dist/
DEPLOY_OUTPUT=$(npx wrangler pages deploy dist/ \
  --project-name="$PROJECT_NAME" \
  --branch=main 2>&1)

# 4. 提取部署 URL
DEPLOY_URL=$(echo "$DEPLOY_OUTPUT" | grep -oE "https://[a-z0-9-]+\.${PROJECT_NAME}\.pages\.dev" | head -1)
echo "✅ Deployed: $DEPLOY_URL"
```

**禁止**：
- ❌ 把 token 写进 wrangler.toml / package.json 等任何 commit 进 git 的文件
- ❌ 在 commit message / log / 对话里粘贴 token
- ❌ 凭据缺失就跳过 1.5.2 直接试部署（必须先回 Stage 1 配齐）

#### Vercel / Netlify（同模式）

| 部署目标 | CLI | 凭据校验 |
|---|---|---|
| Vercel | `vercel --prod --token "$VERCEL_TOKEN"` | `[[ -n "$VERCEL_TOKEN" ]]` |
| Netlify | `netlify deploy --prod --auth "$NETLIFY_AUTH_TOKEN" --site=<id> --dir=dist/` | `[[ -n "$NETLIFY_AUTH_TOKEN" ]]` |

#### 其他目标 / 自托管
参考用户指定流程，输出 setup 命令。

#### 部署后回写

部署完成后**必须**把真实 URL 回写到总设计文档：
- 第 5 节"预览页地址"占位
- preview 页头部"返回总设计文档"链接

> **Codex 派工兼容**：workflow YAML、Cloudflare config、其他部署样板文件（≥ 30 行）可按项目 Codex 派工政策路由。"接哪个平台"的决策由 Claude 自己定，"具体写哪些 YAML 字段"可派 Codex。详见 `flow-dev-task` 的 Codex Delegation Hook。

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

### v5.1 部署凭据 Red Flags
- **token 写进 git**（commit / README / docs / wrangler.toml / package.json）→ 停下，立刻 `git reset --hard` + revoke token + 重新生成
- **token 在对话 / log / commit message 里裸传明文** → 停下，agent 必须用 `${VAR}` 引用
- **1.5.2 凭据缺失但跳过提示直接进 Stage 2.4** → 停下，回 1.5 让用户配齐
- **Stage 2.4 部署前不二次校验凭据** → 停下，环境变量可能在 Stage 1 之后被改/失效
- **`.envrc` 没写进 `.gitignore`** → 停下，会泄露到 GitHub

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

## Codex Delegation Hook

Codex 是对等 agent，能做本 skill 的所有执行工作。是否派工取决于 **ROI**（净收益 = 省 Claude token + 并行性 - SPEC 成本 - 协调成本 - review 成本 - 质量风险）。

### 🟢 高 ROI 推荐派
- **Stage 2.1 工程脚手架配置文件**（tsconfig / eslint / prettier / commitlint 等，≥ 30 行 / ≥ 2 文件）
- **Stage 2.4 部署接线 YAML/config**（GitHub Actions workflow / Cloudflare config，≥ 30 行）

### 🟡 中 ROI 视情况派
- **Stage 2.3 preview 页实现**：handoff 给 frontend-design 后由其判断（通常 ≥ 200 行落地页才划算）
- **Stage 2.1 规则文档**（CONTRIBUTING / AGENTS.md）：仅当模板化结构 + 规则项 ≥ 20 条时；写决定权在 Claude

### 🔴 低 / 负 ROI 不建议派
- **Stage 1 全部**：设计决策类（MVP 切片 / 流程图 / 设计系统候选 / 部署目标），无执行单元，需要 Claude 推断
- **Stage 2.2 logo 设计**：视觉工作走 `huashu-design`，Codex 调它和 Claude 调它没差别
- **User gate 之间的决策同步**：依赖会话上下文，Codex 起新进程拿不到

派工细则（SPEC 模板、prompt 模板、review checklist、错误分类、Red Flags）**全部以 `flow-dev-task` 的 "Codex Delegation Hook" 为唯一规范**，不在本 skill 重复。

## Reuse

本 skill 的测试场景保留在 `tests/cases.md`。未来修订本 skill 时以这些用例为基线。
