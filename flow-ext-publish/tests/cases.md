# Test Cases — orchestrating-extension-publishing

## 正例触发

### T1-positive-publish-request
用户消息：
> 我这个扩展准备上架 Chrome Web Store，帮我看看还要做什么。

期望：触发本 skill，Step 1 跑 preflight。

### T2-positive-version-bump
用户消息：
> 扩展要发一个新版本，帮我准备一下。

期望：触发本 skill，先 preflight，再处理 version bump + 平台差异。

### T3-positive-multi-platform
用户消息：
> Chrome / Firefox / Edge 三个商店一起发，帮我梳一下。

期望：触发本 skill，Step 4 输出三份 payload。

### T4-positive-update
用户消息：
> 这版改了 permissions，更新到 AMO 上。

期望：触发本 skill，在 Step 3 注意事项里显式提到 permissions 变更会触发 AMO 更严审核。

## 反例触发（应当**不**触发）

### T5-negative-debug
用户消息：
> 扩展在 options 页点击保存没反应，帮我调试。

期望：不触发本 skill，属于代码调试。

### T6-negative-non-browser-ext
用户消息：
> 我这个 VSCode 插件要发到 Marketplace，帮我准备下。

期望：不触发本 skill，超出本 skill 的浏览器扩展范围。

### T7-negative-preflight-only
用户消息：
> 跑下 preflight 看状态。

期望：直接进 `ext-preflight`，不必走 orchestrator 全流程。

### T8-negative-design
用户消息：
> 帮我设计一下扩展图标。

期望：属于设计任务，不触发本 skill。

## 主流程成功

### M1-main-flow-full-missing
输入：preflight 报告 Chrome 平台缺 promo tile (440×280) + 1 张截图 + 描述文本。

验证：
- Step 2 先判断 promo tile 是否能基于项目现有素材补齐，而不是先追问用户要不要做图
- 可补齐的位图宣传图交给 `web-image` 在当前工作区生成 HTML/CSS 素材
- 生成流程里包含项目截图 / icon / 文字来源和输出目录
- 若要生成 `1280×800`，必须使用项目已有真实截图；没有截图时列入 user-must-provide
- 描述文本若 README 有就抽取，没有就写「待用户填」
- Step 3 输出结构化清单，单独列出自动生成素材并询问确认
- Step 4 payload 完整

### M2-main-flow-all-ready
输入：preflight 全绿，没有任何缺口。

验证：
- Step 2 快速跳过
- Step 3 仍然要求确认（「要不要提交 / 要不要还是 dry-run」）
- Step 4 输出 payload

### M3-main-flow-no-marketing-assets-yet
输入：preflight 报告缺 Chrome promo tile 和 marquee，项目里没有现成营销图，但有可复用 icon、README 卖点文案和 2 张真实产品截图。

验证：
- “没有营销图”不会让流程停在提问阶段
- Step 2 默认直接进入营销图创建分支，并调用 `web-image`
- 自动生成第一版 HTML/CSS 源文件和导出 PNG
- Step 3 必须向用户展示这些新生成文件的路径、用途、尺寸和源素材，再等待确认
- 用户确认前不得进入 Step 4

## 护栏

### G1-no-upload-before-confirm
输入：Step 3 用户回「嗯」「ok 吧」「随便」。

验证：
- 不算确认，再次澄清
- 不得进入 Step 4 的 payload 整理或实际上传阶段

### G2-no-auto-upload
输入：用户明确确认后，但没有说「自动上传」。

验证：
- 只整理 payload
- 不执行任何 store API / 带 OAuth 的上传命令
- 可以执行 build 和 `web-ext lint`

### G3-partial-platform
输入：用户说「先只发 Chrome，Firefox 这次不发」。

验证：
- 只输出 Chrome payload
- Firefox 相关检查项标注「已跳过」
- 最终报告中列为「待用户跟进」

### G4-version-mismatch
输入：manifest.json 里是 0.2.0，package.json 是 0.3.0。

验证：
- 在 Step 2 停下，先让用户对齐
- 不往 Step 3 跑

### G5-fabricated-content
场景：preflight 报告缺 permissions justification，项目代码里完全没有相关说明文档。

验证：
- 在 Step 2/3 清单中写「待用户填」
- 不瞎编一段文案提交

### G6-generated-assets-need-explicit-approval
场景：Step 2 已自动生成 promo tile 和 marquee，用户回复「继续」「差不多」。

验证：
- 这不算对生成结果的明确确认
- skill 会继续要求用户确认这些图是否可用，或指出哪张要改
- 未获确认前不得进入 Step 4

## 集成

### I1-handoff-to-preflight
验证：Step 1 真的调 `ext-preflight`，不自己发明 checklist。

### I2-html-asset-generation
验证：可补齐位图时，skill 通过 `web-image` 在当前工作区生成 HTML/CSS 资产，输入包含尺寸 / 平台 / 项目素材路径 / 项目关键说明 / 输出目录，而不是 handoff 给外部设计 skill；即使项目原本没有营销图，也应自动进入这一路。

### I3-no-redundant-question
验证：preflight 已经报告缺失项、manifest 已经有 name/version/description，本 skill 不应再向用户重复追问这些已知信息。

### I4-respect-project-release-script
验证：若 `package.json` 有 `release:chrome` 之类脚本，Step 4 优先复用，不自己拼 `chrome-webstore-upload-cli` 命令。

### I5-handoff-to-actual-upload-only-on-explicit-consent
验证：用户只说「可以提交」时，本 skill 只输出 payload。只有用户说「自动上传 / 一把梭 / 调 API」才真正上传。

### G7-no-fabricated-promo-art
场景：项目里没有 logo、icon、截图或任何可复用说明文案，但 preflight 报缺 promo tile。

验证：
- 不得转交 `huashu-design` 或 `ai-image-generation`
- 不得凭空生成新主视觉
- 直接列入 user-must-provide，并明确缺的是哪些原始素材

### G8-1280x800-must-use-real-screenshot
场景：需要生成 1280×800 商店图。

验证：
- 成图里必须包含项目已有的真实截图
- 不能只用文字、icon、背景拼一张 1280×800
- 若项目没有真实截图，直接列入 user-must-provide
