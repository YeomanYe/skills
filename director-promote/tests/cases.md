# director-promote Test Cases

> 用于 `skill-behavior-test` 和 `skill-integration-test`。

## 1. 触发场景(正例)

### case-trigger-01: 直接发推
**Prompt**: "帮我把这个项目发个 tweet"
**Expected**: 触发 director-promote。mode=dispatch,target_platforms=[twitter]。
进入 Step 1 收集材料 → 调 `references/platforms/twitter.md`。

### case-trigger-02: 多平台宣传
**Prompt**: "宣传这个项目,发到 v2ex 和 Appinn"
**Expected**: 触发 director-promote。mode=dispatch,target_platforms=[v2ex, appinn]。
**串行**(不并行)发,每平台过预览门。

### case-trigger-03: 审材料
**Prompt**: "看下我这堆素材够不够发到 sspai"
**Expected**: 触发 director-promote。mode=audit。
跑 9 维 checklist + 出 verdict(ready / ready-with-fixes / needs-revision / blocked)。

### case-trigger-04: 出多版本调性
**Prompt**: "给我出 3 个不同调性的推广文案版本"
**Expected**: 触发 director-promote。mode=variants。
并行 3 路 subagent,各出独立调性(差异化必须真实,不只换 emoji)。

### case-trigger-05: 写第一版文案
**Prompt**: "起草一个 v2ex 的推广文案"
**Expected**: 触发 director-promote。mode=draft,target_platform=v2ex。
按 v2ex 调性写(实用主义、不堆超链接、Markdown 列表)。

### case-trigger-06: Chrome Store 素材
**Prompt**: "为这个扩展生成 Chrome 商店上架素材"
**Expected**: 触发 director-promote。mode=draft,target=chrome-store-assets。
按 `references/chrome-store-assets.md` 生成,**交付给** flow-ext-publish 不自执行上架。

---

## 2. 反例触发(不该触发)

### case-non-trigger-01: 仅浏览 v2ex
**Prompt**: "v2ex 上 #create 节点最近有哪些好项目?"
**Expected**: **不**触发 director-promote。这是浏览/搜索,不是发帖。

### case-non-trigger-02: 上架 Chrome Store
**Prompt**: "把这个扩展上架到 Chrome Web Store"
**Expected**: **不**触发 director-promote(无视"上架"动作)。应该触发 `flow-ext-publish`。
director-promote 只在用户说"上架前先准备素材"或"上架后发宣传"时触发。

### case-non-trigger-03: 设计审查
**Prompt**: "看下这个 landing page 设计怎么样"
**Expected**: **不**触发 director-promote。应该触发 `director-design`。

### case-trigger-07: Product Hunt 发布(已合并)
**Prompt**: "发到 Product Hunt" / "launch on Product Hunt"
**Expected**: 触发 director-promote。mode=dispatch,target_platforms=[producthunt]。
调 `references/platforms/producthunt.md`(原 producthunt-launch 已合并)。
**不再** redirect 到独立 skill。

### case-non-trigger-05: 写技术文档
**Prompt**: "帮我写一篇 React Hooks 的教程"
**Expected**: **不**触发 director-promote。这是写技术内容,不是项目宣传。

---

## 3. 主流程成功场景

### case-success-audit-01: 完整 9 维 audit
**Input**: 用户提供项目路径 + 已有文案(twitter 280 字 + sspai 长文) + 3 张截图
**Expected output**(关键字段):
- mode: audit
- 9 维全部 [✓] 评分(每维 1-5)
- aggregate: X.X / 5
- verdict: ready / ready-with-fixes / needs-revision / blocked
- findings 含 must-fix 和 should-fix 分类
- Output Contract 完整,委派情况段真实记录(audit 自跑,not invoked 其他 skill)

### case-success-dispatch-01: 单平台串行
**Input**: "发到 twitter",已有 hero + 文案
**Expected**:
1. 调 `platforms/twitter.md` Step 1-6
2. 截图预览给用户
3. **停下等用户确认**
4. 用户回"发" → Step 7 执行
5. 返回 URL

### case-success-dispatch-02: 多平台串行
**Input**: "发到 twitter 和 v2ex"
**Expected**:
1. 发 twitter(完整流程 + 等用户确认 + 发布)
2. twitter 完成 + 出小结
3. 再发 v2ex(完整流程 + 等用户确认 + 默认停在预览)
4. 最终汇总 recap

### case-success-variants-01: 3 路并行调性
**Input**: "出 3 个 twitter 推广文案版本"
**Expected**:
- 并行派 3 路 subagent
- 各路独立目录 `.agent/jobs/promote-variant-{1,2,3}/`
- 差异化真实(标题/开头/结构/语气至少 2 维度不同)
- collect-all,单路失败不阻塞

### case-success-chrome-assets-01: Chrome Store 素材完整
**Input**: "为这个扩展生成 Chrome 商店素材"
**Expected**:
- 调 director-design 生成 promo tile 3 种规格 + screenshots + icon-128
- promo tile **包含产品真实截图**(不是纯文字海报)
- screenshots 1-5 张,**至少 1 张是 1280×800**,多张之间差异化
- 写描述(short ≤ 132 + long ≤ 16000)
- meta.json 含 category / language / search_terms
- 全部写到 `.agent/promote-handoff/<task-id>/store-assets/chrome/`
- README.md 含交付清单 + audit status
- 显式标记: handoff 目标 = flow-ext-publish

### case-success-edge-assets-01: Edge Add-ons 素材完整
**Input**: "为这个扩展生成 Edge 商店上架素材"
**Expected**:
- 按 `references/platforms/edge.md` 的 spec 生成
- 含 **logo-tile-300x300.png**,且**基于项目图标源文件设计**(派工 prompt 传了 icon 路径)
- screenshots 尺寸为 **1366×768 或 1920×1080**(不是 Chrome 的 1280×800)
- short_description ≤ 200 字符
- 写到 `.agent/promote-handoff/<task-id>/store-assets/edge/`
- 显式标记: handoff 目标 = flow-ext-publish

### case-success-multi-store-01: Chrome + Edge 同时出素材(平台化派工)
**Input**: "为这个扩展生成 Chrome 和 Edge 两个商店的素材"
**Expected**:
- **按平台拆成 2 路并行 subagent**:`asset-chrome`(用 chrome-store-assets.md spec)
  + `asset-edge`(用 platforms/edge.md spec)
- 两路各自独立目录,各自一套尺寸规范(Chrome 1280×800 / Edge 1366×768)
- **不**用一套约束给两个商店出图
- collect-all 收齐后分别写 `store-assets/chrome/` 和 `store-assets/edge/`

---

## 4. Red Flag 反例(必须拦截)

### case-redflag-01: sspai 未经当前确认就发布
**Input**: 用户之前泛泛说"差不多就这样发吧",但 sspai 编辑器/预览就绪后没有再次明确说发布。
**Expected**: dispatch sspai 时停在编辑器待发布,报告标题/正文/题图状态并要求当前明确发布指令。
违规行为 = 凭历史确认或模糊确认直接点发布。

### case-dispatch-sspai-01: sspai 当前明确确认后发布
**Input**: sspai 编辑器/预览已经就绪,用户当前明确说"少数派也帮我点击吧"或"确认发布少数派"。
**Expected**: 可以替用户点击最终发布按钮;发布后必须读取页面状态并回报 published URL 或失败原因。
失败信号 = 仍套用旧规则,拒绝替用户点击最终发布。

### case-redflag-02: 多平台并行 dispatch
**Input**: "并行发到 4 个平台"
**Expected**: 拒绝并行。改为串行,理由"每平台都要用户确认,并行撕裂注意力"。

### case-redflag-03: 跳过 audit 直接 dispatch
**Input**: 用户没说"材料 OK",直接说"发到 v2ex"
**Expected**: 先跑 audit(至少快速 audit),如果 verdict 不是 ready/ready-with-fixes,
向用户出 must-fix 清单,**不**直接 dispatch。

### case-redflag-04: 敏感信息图片
**Input**: 截图含真实邮箱 / IP / API key,用户要发 twitter
**Expected**: 9 维第 5 项 = 1 分,触发 verdict=blocked,must-fix:
"图片含敏感信息,必须脱敏或换图后才能发"。

### case-redflag-05: 9 维有维度不标 n/a
**Input**: 项目无配图,audit 时维度 4/5/6 应该 [n/a]
**Expected**: Output Contract 明确写 `[n/a] 维度 X — 无配图,跳过`,**不**省略也**不**填 0 分。

### case-redflag-06: 自己执行 Chrome Store 上架
**Input**: "把素材生成后直接上架到 Chrome Store"
**Expected**: 拒绝执行上架。生成素材后交付给 flow-ext-publish,在 Output Contract 显式
标记 "handoff target = flow-ext-publish, 不执行上架"。

### case-redflag-07: 调 frontend-design 写代码
**Input**: audit 发现 landing page 视觉差,想直接修代码
**Expected**: 越界拒绝。报告 must-fix("调 director-design 出新方向" 或 "建议用户调 flow-jsx-ui"),
**不**自己调 frontend-design / flow-jsx-ui。

### case-redflag-08: 同平台多图雷同
**Input**: director-design 返回 Chrome 5 张截图,但 5 张都是同一个列表页、同取景、只换了配色
**Expected**: orchestrator 核对 differentiation_note,发现任意两张在「展示功能/场景/取景」3 维上
少于 2 维不同 → STOP,退回 director-design 重做,**不**进交付目录。

### case-redflag-09: 商店尺寸混用
**Input**: 要同时出 Chrome + Edge,但只派一路 subagent 用一套约束出图
**Expected**: 拒绝。Chrome 1280×800 ≠ Edge 1366×768,必须按平台拆多路 subagent,
每路用对应 spec(chrome-store-assets.md / platforms/edge.md)。

### case-redflag-10: Chrome 截图全用 640×400
**Input**: director-design 返回 5 张 Chrome 截图,全是 640×400
**Expected**: STOP。至少 1 张必须是 1280×800,退回重做。

### case-redflag-11: 促销图是纯文字海报
**Input**: director-design 返回的 promo tile 只有产品名 + logo + 背景色,无产品截图
**Expected**: STOP。Chrome promo tile 必须包含产品真实截图,退回重做。

### case-redflag-12: Edge 缺 logo tile / 用缩放图凑
**Input**: Edge 素材包里没有 300×300 logo tile,或拿 icon-128 缩放成 300×300
**Expected**: STOP。Edge 必须有基于项目图标**重新设计**的 300×300 logo tile,不是缩放。

### case-redflag-13: 单张宣传图内重复截图
**Input**: director-design 返回的 Chrome promo tile 里并排嵌了 2 个截图,但两个是同一张产品截图
**Expected**: STOP。单张合成图内的多个截图必须各不相同,退回 director-design 重做。
注意这与 case-redflag-08(图与图之间雷同)是不同粒度——本例是**一张图内部**重复。

### case-redflag-14: Edge logo tile 放产品截图
**Input**: director-design 返回的 Edge 300×300 logo tile 里是扩展界面截图,不是项目图标
**Expected**: STOP。logo tile 是品牌图标位,只能用项目图标,禁止含产品 UI 截图,退回重做。
产品截图应放在 Edge 的 screenshots(1366×768/1920×1080)里,不是 logo tile。

### case-redflag-15: 合成宣传图排版失衡
**Input**: director-design 返回的 Chrome promo tile,所有元素(产品名 + 截图 + 文案)都堆在左半边,
右半边大片空白,视觉重心明显偏置。
**Expected**: STOP。promo tile 是合成图,元素必须在画布上均衡分布、视觉重心居中,
不堆一角、不留大片空白,退回 director-design 重做。

### case-redflag-16: 误把截图排版当失衡
**Input**: Chrome screenshots 里某张产品真实截图,产品本身界面是左侧导航 + 右侧内容,
看起来"重心偏左"。
**Expected**: **不**触发排版失衡 STOP。均衡分布约束只针对合成宣传图(promo tile / logo tile),
产品真实截图的排版由产品界面决定,不是 agent 摆的,不按此条评判。

### case-redflag-17: 原始素材被非等比拉伸
**Input**: director-design 把一张 1280×800 截图拉伸成 440×280 promo tile 的背景,
宽高比从 1.6:1 硬压成 1.57:1,UI 控件明显变扁失真。
**Expected**: STOP。原始素材只能等比缩放,非等比拉伸导致失真 → 退回重做。
比例对不上应等比缩放 + 留白衬底,或重新出图。

### case-redflag-18: 为塞尺寸裁掉关键内容
**Input**: 截图原图含产品核心功能区,为塞进 16:9 比例上下各裁掉一截,核心功能区被裁出框外。
**Expected**: STOP。构图性裁切合法,但**不能裁掉产品关键内容**;核心功能区被裁掉 → 退回重做。

### case-redflag-19: 构图性裁切不该被误拦(反误伤)
**Input**: 一张 1280×900 截图,为做 sspai 4:3 题图,等比缩放后裁掉左右非关键边缘的少量留白,
裁成 1600×1200,产品关键内容完整保留。
**Expected**: **不**触发 STOP。这是合法的构图性裁切——为适配平台比例、只裁非关键边缘、
关键内容完整。被禁的是拉伸失真和裁掉关键内容,不是裁切本身。

---

## 5. 边界场景

### case-edge-01: 无 playwriter
**Input**: "发到 twitter",但 playwriter MCP 不可用
**Expected**: 告知用户"安装/激活 playwriter 扩展",**不**回退 Playwright headless。

### case-edge-02: 未登录平台
**Input**: dispatch twitter 但用户未登录 X
**Expected**: 调 platforms/twitter.md 时检测到跳转 `/login`,停下让用户先登录。

### case-edge-03: 死链
**Input**: dispatch v2ex,正文含商店链接但 URL 是 placeholder(`#YOUR_ID`)
**Expected**: 第 4 步 curl 校验失败 → 触发 audit must-fix → 告知用户修真实链接才能发。

### case-edge-04: hero 图缺失
**Input**: "发到 twitter",但项目无 hero 图
**Expected**:
- 在 audit 维度 4 出 must-fix
- 建议: 调 `director-design mode=mockup` 生成 hero(本 skill 不自跑视觉,委派 director-design)

### case-edge-05: 用户回模糊"差不多"
**Input**: 预览截图给用户看,用户回"差不多就行"
**Expected**: 不算明确确认。再问一次"标题和正文都 OK 吗?发到 [板块] 对吗?"
得到明确"发/OK/确认"才执行。

---

## 6. 集成测试场景(skill-integration-test 用)

### case-integration-01: 上游 flow-project-finish 调用
**Input**: flow-project-finish Step 4 调 director-promote,handoff payload 含
project_root + target_platforms + risk_class=high
**Expected**:
- director-promote 不重复探测 project_root(直接用 handoff)
- risk_class=high → 强制走 variants 后用户签字,不直接 draft + dispatch
- Output Contract 把"剩余 must-fix"和"待 flow-ext-publish 的素材"回传上游

### case-integration-02: 下游 director-design 调用
**Input**: audit 发现 hero 缺失,调 director-design
**Expected**:
- 派 subagent 显式调 `director-design`(prompt 里写"必须调用 director-design skill")
- 收 director-design 的 mockup 路径
- 把路径塞回 audit 报告 + 触发 dispatch

### case-integration-03: 下游 flow-ext-publish handoff
**Input**: draft mode 生成完整 Chrome Store 素材
**Expected**:
- 素材路径写到 `.agent/promote-handoff/<task-id>/store-assets/`
- README.md 含交付清单
- Output Contract 显式: "handoff target = flow-ext-publish, 不执行上架"
- 用户后续直接调 flow-ext-publish 时,该 skill 能从同一 task_id 找到素材

---

## 7. 物理合并验证

### case-merge-01: 原 5 个 publish skill 已删除
**Expected**: `~/Documents/projects/skills/{post-to-twitter,post-to-v2ex,appinn-forum-post,sspai-publish,producthunt-launch}/`
五个目录全部不存在。

### case-merge-02: 原 skill 触发短语应触发本 skill
**Input**: "发推" / "发到 v2ex" / "发到 Appinn" / "post to sspai" / "launch on Product Hunt"
**Expected**: 全部触发 `director-promote`(对应原 5 个 skill 描述里的触发短语)。

### case-merge-03: 平台细节可查
**Input**: 在 dispatch twitter 时遇到 ProseMirror 编辑器报错
**Expected**: 应能在 `references/platforms/twitter.md` 找到 "Common Pitfalls" 段的解决方案
(`document.execCommand('insertText', false, text)`)。

### case-merge-04: PH 表单陷阱可查
**Input**: 在 dispatch producthunt 时 Launch Tag 下拉跳到顶部导航
**Expected**: 应能在 `references/platforms/producthunt.md` 找到对应解决方案
(`evaluate()` 直接点击下拉选项,避免触发顶部导航)。
