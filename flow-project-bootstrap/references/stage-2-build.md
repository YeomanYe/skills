# Stage 2 · Build Scaffold — 详细流程

> 主体 SKILL.md 只列每个 stage 的 5-10 行简介；具体派工、字段、部署细节在本文件。

进入 Stage 2 的硬前置：

- Stage 1 总设计文档已落盘
- **用户已挑选 1 个 preview mockup**（不能"3 个混"未拍板）
- 部署目标已确认

## Stage 2 并行编排

**2.1 / 2.2 / 2.3 三路完全独立**（写不同目录，仅共享 Stage 1 总设计文档只读），按 `references/parallelization-template.md` 派 3 个 subagent 并行：

| Slot | Subagent 任务 | 写入目录 | 必须调用的 skill |
|---|---|---|---|
| `engineering-rules` | 调 `director-architect` 生成规范脚手架 | `CONTRIBUTING.md` / `AGENTS.md` / `docs/<domain>/` | `director-architect`（必须显式）|
| `logo-design` | 调 `huashu-design` 出 ≥2 个 logo 方向 | `assets/logos/` 或 `branding/` | `huashu-design`（必须显式）|
| `preview-impl` | 基于 Stage 1.3 已挑选的 preview-mockup-N 落地 | `preview/` 或项目内 preview 路由 | `frontend-design`（A 模式必须显式）/ 直接 cp（B 模式）|

**派工 prompt 必填字段集**遵循 `references/dispatcher-template.md`。每个 subagent prompt 必含：
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

## 2.1 工程规范脚手架（调 `director-architect`）

把已锁定的技术栈 + 业务域 + greenfield/adjacent 状态传给 `director-architect`。

handoff payload 必须含 `approval_inherited_from_orchestrator: true` 字段（因为 Stage 1 user gate
已批准 bootstrap 全流程，Stage 2.1 不再走独立 Approval Gate）。

原样接收产出；不要改述。

> **Codex 派工兼容**：如果 `director-architect` 产出涉及大量样板配置文件（≥ 30 行 / ≥ 2 文件），可按项目 Codex 派工政策路由（详见 `flow-dev-task` 的 Codex Delegation Hook）。规则文档本身（CONTRIBUTING.md / AGENTS.md 等）由 Claude 自己写，不派 Codex。

## 2.2 项目 Logo 设计（调 `huashu-design`）

调用 `huashu-design`，请求至少 2 个 logo 方向：

- 输入上下文：项目名 / 一句话目标 / 已选设计系统的配色与字体
- 要求：每个方向出 SVG + PNG（透明底）+ 简短风格说明
- **不允许**直接套通用 emoji 或纯文字 logo（除非用户明说"先用文字 logo 占位"）

输出落到 `assets/logos/` 或项目 `branding/` 目录，并在总设计文档里加引用。

## 2.3 预览页实现（**v5：直接用 Stage 1.3 已挑选的 mockup 落地**）

**v5 简化**：Stage 1.3 已经派过 3 路 mockup 并让用户挑了一个，本步直接拿来落生产代码（不再重派 director-design mockup）。

**按项目栈智能选实现模式**（同 flow-project-finish v5）：

| 项目栈情况 | 模式 | 行为 |
|---|---|---|
| 有前端栈（react/vue/svelte 等） | **A** frontend-design 重写 | 把 `.agent/jobs/preview-mockup-N/` 作为视觉基准，frontend-design 转成对应栈组件 |
| 无前端栈（纯 CLI / lib / extension） | **B** 直接拷 | `cp -r .agent/jobs/preview-mockup-N/ preview/`（清掉 screenshots / meta.json） |

### A 模式（frontend-design）

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

### B 模式（直接拷）

```bash
cp -r ".agent/jobs/preview-mockup-N/" "preview/"
rm -rf "preview/screenshots" "preview/meta.json"  # 清过程产物
```

### 处理被挑后剩余 mockup

默认保留 `.agent/jobs/preview-mockup-{X,Y}/`（用户可参考 / 对比）。
Stage 2 收尾报告标注"可清理"。**不要在 2.3 主动删**。

### 触发条件兼容

- **Required + 有 UI 组件**：A 模式（套已选设计系统的 token + 复用真实组件 + 适配器层）
- **Required + 零代码阶段**：B 模式（直接拷 mockup 当占位 preview，标注切回 deadline）
- **Not needed / Already satisfied**：本节产物 = 总设计文档里的引用，不重复造

### 双向链接（硬性要求）

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

## 2.4 部署接线（**v5.1 升级：自动 wrangler 部署**）

按 Stage 1 第 6 节锁定的目标接线。**凭据应该已在 1.5.2 配齐**，本步直接跑：

### GitHub Pages
- 建 `.github/workflows/deploy-website.yml`，触发路径限定为 preview 页所在目录
- `git push` 后 GitHub Actions 自动构建
- URL: `https://<owner>.github.io/<repo>/` 或自定义 domain

### Cloudflare Pages（**自动 wrangler 部署**）

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

### Vercel / Netlify（同模式）

| 部署目标 | CLI | 凭据校验 |
|---|---|---|
| Vercel | `vercel --prod --token "$VERCEL_TOKEN"` | `[[ -n "$VERCEL_TOKEN" ]]` |
| Netlify | `netlify deploy --prod --auth "$NETLIFY_AUTH_TOKEN" --site=<id> --dir=dist/` | `[[ -n "$NETLIFY_AUTH_TOKEN" ]]` |

### 其他目标 / 自托管
参考用户指定流程，输出 setup 命令。

### 部署后回写

部署完成后**必须**把真实 URL 回写到总设计文档：
- 第 5 节"预览页地址"占位
- preview 页头部"返回总设计文档"链接

> **Codex 派工兼容**：workflow YAML、Cloudflare config、其他部署样板文件（≥ 30 行）可按项目 Codex 派工政策路由。"接哪个平台"的决策由 Claude 自己定，"具体写哪些 YAML 字段"可派 Codex。详见 `flow-dev-task` 的 Codex Delegation Hook。
