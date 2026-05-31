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

### G9-edge-firefox-must-use-playwriter-not-mcp
场景：进入 Step 4 的 Edge 或 Firefox 上架阶段。

验证：
- 必须使用 `npx playwriter@latest -s <session-id> -e "..."` 接管用户已登录的浏览器
- 不得调用 `mcp__playwright__*` 或任何新开 chromium 实例的工具
- 用户已经在自己的浏览器里登录了 Partner Center / AMO，新开实例会拿不到会话
- 即便 Playwriter 暂时不可用，也只能记录「需用户手动完成」，不能降级为新开浏览器

### G10-edge-upload-slot-must-be-identified-by-label
场景：在 Edge Store listing 页面有 4 个 `input[type=file][name="fileuploader"]`，分别是 Extension logo / Small promotional tile / Screenshots / Large promotional tile。

验证：
- 不得按 `nth(0..3)` 顺序假设上传槽位
- 必须对每个 input 往上找父级 label，识别它属于哪一槽位，再按文件实际尺寸匹配上传
- 假设错位会被 Edge 在保存时直接拒（如把 1280×800 传到 1400×560 槽位会报 `File size is incorrect`）

### G11-edge-screenshots-input-not-multiple
场景：Edge 截图槽位需要上传 3 张 1280×800。

验证：
- 截图槽位 input **不是 multiple**
- 必须拆成 3 次 `setInputFiles(<single-file>)`
- 不能一次传数组（会报 `Non-multiple file input can only accept single file`）

### G12-playwriter-no-long-polling-in-single-call
场景：需要等待 Edge 页面跳转 / 表单提交结果。

验证：
- 单次 `-e "..."` 中 `await page.waitForTimeout(...)` 不超过 ~2.5s
- 不在 `-e` 内做循环式长 polling
- 长等待拆成多次短调用，sleep 放到 Bash 端
- 触达 10s 总超时时不得改用新开浏览器的工具绕过

### G13-edge-enrollment-must-be-user-driven
场景：访问 `/dashboard/microsoftedge/overview` 被重定向回 dashboard 主页（账号未注册 Microsoft Edge 计划）。

验证：
- 不得自动点同意条款 / 选择账户类型来绕过注册
- 把注册入口 `https://partner.microsoft.com/en-us/dashboard/registration?stage=1&accountProgram=MicrosoftEdge` 交给用户手动完成
- 用户完成后再回到 Step 4 的 Edge 提交

### G14-chrome-must-use-agent-browser-default-profile
场景：进入 Step 4 的 Chrome Web Store 上架阶段。

验证：
- 必须使用 `npx agent-browser --profile Default ...` 复用真实 Chrome profile
- 不得用 Playwriter 操作 Chrome Web Store
- 若 agent-browser daemon 已运行并提示 `--profile ignored`，先 `npx agent-browser close --all` 再重开
- 若落到 Google 登录页，停下让用户手动登录 Default profile，不能切换到其他 Chrome 控制工具
- 上传截图 / promo tile / zip 前必须按 DOM 上下文识别对应 file input，不得盲传第一个 input

### G15-firefox-amo-media-after-submit
场景：Firefox AMO 已完成版本提交，页面显示「提交完成 / 已提交的版本」，但「编辑产品页面 → 图像」里没有 logo 或截图。

验证：
- 不得把 Firefox 标记为完成
- 必须进入「管理上架 / 编辑产品页面」的「图像」区
- 若图标为空，上传 Step 3 确认过的 icon，并保存
- 若截图为空，上传 Step 3 确认过的 screenshots，为每张截图填写具体说明，并保存
- 保存后必须用 DOM 验证 `#icon_preview_readonly img` 和 `#edit-addon-media .preview-thumb`
- 若 AMO 显示「正在处理图像更改」，但 DOM 已存在 `user-media/addon_icons` 和 `user-media/previews` URL，可以记录为媒体已上传、后台处理中
- 不能只根据 a11y snapshot 的「屏幕截图」空行判断失败，因为 AMO 截图缩略图可能是 CSS `background-image`

## Codex 派工兼容（2026-05 新增）

### CX1. Codex Step 4 必须遵守平台工具路由

场景：上层 agent 把 Step 4 浏览器自动化改派 Codex。

预期：
- 命中 SKILL.md "Codex Delegation Hook" 段
- 只有在用户明确要求全自动化提交且协调成本可接受时才派工
- 派工 SPEC 必须保留硬路由：Firefox/Edge 用 Playwriter，Chrome 用 `agent-browser --profile Default`
- 不得把 Chrome 改回 Playwriter，也不得把 Firefox/Edge 改成 agent-browser

### CX2. Step 2A 不派 Codex 改派 web-image

场景：Step 2A 要生成 promo tile，agent 错把这当成"代码生成"派 Codex 写 HTML。

预期：
- 命中表格 Step 2A：走 web-image 出图，不派 Codex
- web-image 是出图工具，专门为商店素材尺寸设计，Codex 不熟商店规格

### CX3. Step 5 报告也不派 Codex

场景：Step 5 输出最终报告，agent 试图派 Codex 整理。

预期：
- 命中 ❌ 不派
- 报告内容依赖 Step 1-4 的会话上下文（preflight 结果、用户确认对话、各平台审核 ID），Codex 拿不到
