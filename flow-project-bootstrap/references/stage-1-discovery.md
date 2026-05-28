# Stage 1 · Discovery & Direction — 详细流程

> 主体 SKILL.md 只列每个 stage 的 5-10 行简介；具体派工、字段、降级路径在本文件。

## Stage 1 并行编排（v5 简化）

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

## 1.1 项目前置准备（调 `project-prep`）

调用 `project-prep` 锁定：

- **MVP 范围**（in scope / out of scope / non-goals）— **必填**
- **目标用户**与**核心流**（happy path 3-7 步）— **可选**（用户没指定时不强求；个人项目 / 小工具常不需要）
- **主交互设计**（屏幕清单 + 关键动作 + 状态流转 + 决策点）— **必填**
- **主要技术栈**（运行面 + 框架 + 主语言）— **必填**
- **Preview decision**：`Required` / `Not needed` / `Already satisfied` — **必填**

## 1.2 主要流程 ASCII 图（**可选**，用户没要求时跳过）

**v5 改可选**：默认跳过。用户明确说"我要看流程图"才出。

理由：流程图是思考工具，对很多任务非必要；项目复杂度低时反而冗余。需要时按下面格式出：

```
[Entry] → (Action) → ⟨Decision?⟩ ─yes→ [State A]
                            └─no──→ [State B] → (Action) → [Exit]
```

复杂流可拆分子图（一图表达不超过 7 个节点）。

## 1.3 设计方向 + 预览 Mockup（**v5 升级**：两阶段 director-design 调度）

**核心改造**：合并原 1.3（预览功能设计）+ 1.4（推荐设计系统）。默认走两阶段，让用户视觉化选择，不再先文字描述再选。

### 1.3a — 派 1 个 director-design (variants) 出 3 方向卡（**规划阶段**）

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

### 1.3b — 基于 3 方向卡，派 3 路 director-design (mockup) 并行（**实现阶段**）

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

### 1.3c — 飞书自动推送 + 用户挑选（**不超时**）

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

### 1.3 降级路径

- director-design 不可用 → 退回直调 `ui-ux-pro-max` + `huashu-design`（同样 3 路并行）
- cc-connect 不可用 → 跳过飞书推送，orchestrator 在对话里贴 3 个 mockup 路径

### 1.3 重做版本命名（硬规则）

| 场景 | 输出路径 |
|---|---|
| 初始 3 路 | `.agent/jobs/preview-mockup-{1,2,3}/` |
| "都不行 重做"（全部新派） | `-v2` / `-v3` 递增 |
| "方向 2 改 X"（单路微调） | `.agent/jobs/preview-mockup-2-v2/`（其他不动） |

**禁止**覆盖原目录（用户可能要对比 v1 / v2）。

## 1.5 部署方案选择 + 凭据前置检测（**v5.1**）

### 1.5.1 仓库可见性 → 部署目标

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

### 1.5.2 部署凭据前置检测（**关键**：Stage 1 就问，不要拖到 Stage 2.4 才卡）

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

**安全硬规则**（同时写入 `failure-modes.md` 的 Red Flags 段）：
- ❌ token 绝不进 git（任何 commit / README / docs）
- ❌ token 不在 prompt / 对话 / log 里裸传（agent 引用要用 `${CLOUDFLARE_API_TOKEN}` 而不是明文）
- ✅ 走 shell 启动文件（全局） / direnv `.envrc`（项目级，含 `.gitignore`）/ keychain（macOS `security add-generic-password`）

**总设计文档第 6 节**记录凭据就绪状态（不记录 token 值本身），见 `output-contract-template.md`。

## 1.6 输出物：一份总设计文档

模板见 `references/output-contract-template.md`。
