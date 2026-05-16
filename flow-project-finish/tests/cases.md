# 行为测试用例

验证 `flow-project-finish` 是否正确触发,并产出预期的五阶段收尾交付(同步 / README / 条件落地页 / delivery-gate 审查 / clean-commit 提交)。

## 正例触发(应该触发本 skill)

### T1. 显式收尾意图

Prompt:

> 我的浏览器扩展 ext-helper 主功能已经写完了,准备做收尾:把代码里的设计同步到设计系统、出一个 README、再做个落地页,完事记得提交。

预期:触发本 skill。输出按 Step 0 → 1 → 2 → 3 → 4(delivery-gate) → 5(clean-commit) → 6(报告) 全程跑完。报告 7 节齐全,delivery-gate 状态为 `all clear`,clean-commit 产出真实 hash。

### T2. 英文 paraphrase

Prompt:

> The CLI we've been building is feature-complete. Time to finish: sync code design into our docs, refresh the README, build a landing page, run a delivery review, and commit.

预期:触发本 skill。同样产出 7 节报告。CLI 命中"非网站",触发 Step 3。Step 4 / 5 都按规走。

### T3. 多件 + 收尾意图

Prompt:

> 项目要交付了,帮我把 README 出一下,顺便补一下落地页,然后审查一下提交了。

预期:触发本 skill(收尾意图明确,两件以上)。Step 1 文档同步若无目标文档,要在报告中显式标"未发现",**不得**默默跳过这一阶段或主动新建占位。Step 4 / 5 必跑。

## 反例触发(不应触发)

### N1. 仅出 README

Prompt:

> 帮我写个 README,这个项目没 README。

预期:不触发本 skill。直接写。

### N2. 仅做落地页

Prompt:

> 给我的工具做个落地页。

预期:不触发本 skill。直接 `huashu-design` + `frontend-design`。

### N3. 仅同步设计系统

Prompt:

> 我代码里改了一波颜色和字号,帮我同步到 design tokens 文档。

预期:不触发本 skill。直接处理。

### N4. 仅准备 commit / push(不带其他收尾意图)

Prompt:

> 帮我把工作区里的改动提交一下。

预期:不触发本 skill。路由到 `clean-commit`。本 skill 的 commit 阶段是收尾的尾巴,不是单独入口。

### N4.1. 仅做交付审查

Prompt:

> 这堆改动你帮我审查一下能不能交付了。

预期:不触发本 skill。路由到 `delivery-gate`。

### N5. 主体仍在开发

Prompt:

> 这功能还差几个 bug,你看看怎么修。

预期:不触发本 skill。路由到 `flow-dev-task`。

### N6. 项目本身是 Next.js 网站,只想出 README

Prompt:

> 我的 Next.js 站点要发布了,帮我出 README。

预期:不触发本 skill(单一意图)。直接写 README。

## 主流程成功(含 skill 时)

### M1. Happy path 端到端(浏览器扩展)

Prompt:同 T1。

预期行为顺序:

1. Agent 先做 Step 0 探测,写下 8 个字段(类型 / 前端栈 / 是否网站 / 既存落地页 / 现存文档 / 设计源 / 路线图源 / git state)
2. Agent 进入 Step 1,逐类文档 detect → diff → patch;找不到的类别显式标"未发现"
3. Agent 进入 Step 2,判定 README 是否存在,增量更新或从零新建,命令以 `package.json scripts` 为准
4. Agent 进入 Step 3,识别"非网站",调 `huashu-design` 要 3 套方向,等用户挑选,再调 `frontend-design` 产出代码;落地页内容三段(Outline/Roadmap/Links)齐全;3.4 在 4 个断点截图
5. Agent 进入 Step 4,把 Step 1~3 全部产出递交给 `delivery-gate`;判定 all clear 才往下
6. Agent 进入 Step 5,调 `clean-commit` 把本次收尾的全部变更提交为一个干净 commit
7. Agent 产出 7 节收尾报告

不得出现:

- 跳过 Step 0 直接进 Step 1
- 主动新建占位的 PRD/架构文档
- 把现有 README 整体重写
- huashu-design 只拿 1 套方向就接 frontend-design
- 落地页放在项目源码目录污染主构建
- 跳过 delivery-gate 直接 commit
- delivery-gate must-fix 没消化就 commit
- clean-commit 把无关改动一起夹带进来
- 收尾报告省略某节

### M2. Happy path 端到端(Next.js 网站)

Prompt:

> 我的 Next.js 产品站要交付了,做收尾:同步设计系统到 docs,更新 README,落地页就是网站本身,不用再做。

预期:

1. Step 0 探测出 `Already a website: yes`
2. Step 1 / Step 2 正常执行
3. Step 3 显式跳过,跳过原因记为"项目自身即网站,落地页与产品合并"
4. 收尾报告 Step 3 节存在但内容是跳过说明,不是省略

## 护栏(压力测试)

### G1. 用户施压跳过 Step 0 探测

Prompt:

> 别探测了,我告诉你这是个 React 项目,直接出文档。

预期:skill 仍然做 Step 0 完整探测(可以参考用户的提示加速,但要写下 6 个字段);因为后续每一步都依赖快照。如果用户拒绝提供探测条件且环境无法读取,显式停下报"无法在缺少项目结构信息的情况下产出可信的同步"。

### G2. 用户施压用单一 huashu-design 方向

Prompt:

> 落地页设计你直接选一套最潮的就行,不用给我选项。

预期:skill 仍然要求 huashu-design 返回 3 套方向。可以标注"推荐默认方向",但必须把另外 2 套保留进开放决策。理由:跳过方向选择就把"特色"主动让位给 AI 默认美学。

### G3. 用户施压主动新建未发现的文档

Prompt:

> PRD 没有,你就帮我顺手写一份吧,反正都要交付了。

预期:skill 拒绝在收尾阶段主动新建 PRD;显式说明"PRD 是产品定义文档,应由用户在另一个工作流中产出,本 skill 只负责同步,不负责创造"。在报告里标"未发现 PRD",并把"是否新建 PRD"列入开放决策。

### G4. 用户施压重写陈旧的架构文档

Prompt:

> 这份 ARCHITECTURE.md 已经过时半年了,你给我整个重写下,符合现在的代码。

预期:skill 拒绝整体重写;改为按 detect→diff→patch 三步,只 patch 实际偏差。如果偏差量过大(超过原文 50%),停下并提示"偏差过大,建议作为单独任务而非收尾步骤进行",请用户确认是否进入"重写模式"。

### G5. 用户希望 README 翻译成英文

Prompt:

> 顺便把 README 翻译成英文吧,看起来更专业。

预期:skill 不在收尾阶段做翻译。显式说明"语言转换不是收尾职责";如果用户坚持,把翻译记入开放决策让用户在另一工作流处理。

### G6. 项目无前端栈

Prompt:

> 我的 Rust CLI 主要功能都好了,做收尾,顺便给我个落地页。

预期:落地页技术栈回退到 `vite + pnpm + react`(因为 Rust CLI 无前端栈);明确告知用户"项目本身无前端栈,落地页采用 vite+pnpm+react 默认栈"。

### G7. 用户施压跳过响应式校验

Prompt:

> 落地页就先这样,响应式以后再说。

预期:skill 可以跳过 `agent-browser` 校验,但在收尾报告里显式写"响应式校验:skipped(用户暂缓)",不得隐瞒。

### G8. 用户希望落地页内容契约只留两段

Prompt:

> 落地页路线图不用要,我们 roadmap 还没定。

预期:skill 仍然保留路线图段落,但内容显式写"暂无公开路线图 / 待规划",而不是删除该段。理由:契约固定,空数据用空文案表达,不裁段。

### G9.A. delivery-gate 给了 must-fix,用户要求直接 commit

Prompt:

> 你这个 delivery-gate 报的几个 must-fix 都是吹毛求疵,先 commit 上去再说,后面再修。

预期:skill 拒绝跳过 must-fix;显式拒答 + 引用 SKILL.md 的硬约束 "must-fix 必须消化才能进 Step 5"。把每个 must-fix 路由回对应 Step(1/2/3),修复后重跑 delivery-gate,直到 all clear。

### G9.B. 用户希望 clean-commit 把整个工作区一起提交

Prompt:

> commit 的时候 git add -A 一下吧,我顺手把工作区里其他改动也带上了。

预期:skill 拒绝;clean-commit 必须走选择性 staging,只提交本次收尾涉及的范围。其他无关改动让用户单独决定是否另提一笔 commit。

### G9.C. 用户希望跳过 delivery-gate

Prompt:

> 审查这一步就跳了吧,我自己看过了没问题。

预期:skill 拒绝;delivery-gate 是硬阻断不可绕过。理由:它的判断维度(must-fix/should-fix、视觉证据、IM 回流)是 agent 自己走查覆盖不到的。

### G10. 项目本身不是网站,但已有落地页子目录

Prompt:

> 我的浏览器扩展项目要做收尾,项目里其实已经有个 `website/` 目录是之前做好的落地页,但代码已经跟不上现在的功能了。

预期:

- Step 0 应同时输出 `Already a website: no`(项目主体不是网站)与 `Existing landing page: website/`(已发现既存落地页子目录)
- Step 3 不能直接跳过,也不能粗暴重新生成覆盖
- skill 应在 Step 3 入口提供三选一:**refresh**(基于现有方向 patch 落后内容)/ **rebuild**(走完整 huashu-design + frontend-design 重做)/ **skip**(用户决定不动它)
- 默认推荐 **refresh** 作为最小破坏路径,但把选择权交回用户

失败信号:

- Step 0 漏掉既存落地页信号
- Step 3 直接当成"无落地页"走完整重做,覆盖既有代码
- Step 3 直接当成"项目即网站"跳过,放任落后落地页对外

## 非功能检查

- frontmatter 的 description 长度 ≤ 1024 字符,且具有跨语言触发能力(中英混合)
- description 只描述触发条件,不复述工作流
- 不把下游 skill (`huashu-design` / `frontend-design` / `delivery-gate` / `clean-commit`)的文档原文内嵌进本 skill 正文
- 输出契约与 SKILL.md 声明的结构一致(Step 0 → Step 1 → README → Landing → Delivery Gate → Clean Commit → 风险与开放决策)
- 跳过的阶段必须有显式跳过段落,不得直接省略
- 落地页内容必定三段齐全(Outline / Roadmap / Links),即使数据为空也要写空文案
- delivery-gate must-fix 必须消化才能进 Step 5,没有任何说辞能绕过
- clean-commit 必须用选择性 staging,不得 git add -A

## Codex 派工兼容（2026-05 新增）

### CX1. Step 3.3 大型落地页可派 Codex

场景：Step 3.3 frontend-design 实现一个含 5 个 Section 的落地页，预估代码 > 200 行 / ≥ 4 文件。

预期：
- 命中 Codex Delegation Hook 表格 Step 3.3 ✅ 可派
- 设计方向（Step 3.2 huashu-design 已选）由 Claude 把关
- 内容契约（Outline / Roadmap / Links）由 Claude 写进 SPEC
- 视觉细节验收必须由 Claude 跑 agent-browser 截图验证

### CX2. Step 1 文档同步必须 Claude 自写

场景：Step 1 同步 PRD，差异约 80 行。

预期：
- Codex Delegation Hook 表格明示 Step 1 ❌ 不派
- 理由：必须保留原作者 voice，Codex 容易改述风格
- Claude 直接写

### CX3. Step 2 README 必须 Claude 自写

场景：README 不存在，要从零生成约 100 行。

预期：
- 命中 ❌ 不派规则
- 理由：涉及命令真实性核对（必须读 package.json scripts），Codex 易瞎编

### CX4. Step 5 commit 不派 Codex

场景：Step 5 进入 clean-commit 阶段。

预期：
- 命中 ❌ 不派规则
- commit message + scope 由 Claude 决定（Codex 不知道收尾上下文）


---

## v5 落地页 3 路 mockup 改造测试

### LM1. 默认 3 路（用户不说话）

Prompt：
> 项目收尾，要做落地页。

预期：
- Step 3.2 **不问** 要几个方向，直接派 3 路 subagent 调 director-design (mode: mockup)
- 3 路独立目录 .agent/jobs/landing-mockup-{1,2,3}/
- 每路自跑 4 断点截图

### LM2. 3 路独立性硬规则

预期：
- 每路 meta.json 含 dimensions_differ_from_others 至少 2 维度
- 维度集合：布局结构 / 信息层级 / 风格调性 / 主色方向
- **禁止**仅换主色（只换 1 维度 → Red Flag）

### LM3. 飞书渠道自动推送

场景：CC_SESSION_KEY = feishu:chat:user

预期：
- 3 路就绪后 push-mockups-to-feishu.sh 触发
- cc-connect 发 6 张截图（每路 mobile + desktop）
- 消息含 3 个 style_name + 选 1/2/3 / 都不行重做 / 方向 N 改 X 提示
- STATUS.md 写 ## Pending Decision 段

### LM4. 非飞书渠道跳过推送

场景：CC_SESSION_KEY = telegram:* 或未设置

预期：
- push 脚本 log skipping feishu push
- orchestrator 在对话里贴 3 个 mockup 路径让用户挑

### LM5. 用户没回不超时

场景：飞书推送后用户 24h 没回。

预期：
- STATUS.md ## Pending Decision 段保持
- **不**auto-pick mockup-1
- orchestrator 下次被 ping 时报告等待用户挑选

### LM6. 用户选 选 2

预期：
- 进 Step 3.3，按项目栈智能选实现模式
- 有 React/Vue/Svelte 等前端栈 → A 模式（frontend-design 重写，mockup-2 作视觉基准）
- 纯 CLI / 库 / extension → B 模式（直接 cp .agent/jobs/landing-mockup-2/ → website/）

### LM7. 用户回 都不行 重做

预期：
- 派新一轮 3 路（不复用旧 mockup）
- 旧 3 路保留在 .agent/jobs/ 供参考
- 新一轮在 .agent/jobs/landing-mockup-{1,2,3}-v2/

### LM8. 用户回 方向 2 改 X

预期：
- 只派 mockup-2 微调（不重派 1 / 3）
- 输出到 .agent/jobs/landing-mockup-2-v2/
- 重新推送（只推 mockup-2 修改后的截图）

### LM9. Step 4.0 audit 含 mockup_alignment_score

场景：用户选 mockup-2，3.3 落代码后。

预期：
- director-design audit prompt 含 selected_mockup_path
- 输出含 mockup_alignment_score（落地代码 vs 选定 mockup 的对齐度）
- alignment < 4/5 → 回 3.3 调整

### LM10. cc-connect 推送失败降级

场景：CC_SESSION_KEY 是 feishu 但 cc-connect 命令失败（网络 / 凭据问题）

预期：
- push 脚本 log 失败
- STATUS.md 写 推送失败，请手动查看 mockup + 路径
- orchestrator 在对话里告知用户
- **不**阻塞流程（用户仍可手动看 mockup 选）

