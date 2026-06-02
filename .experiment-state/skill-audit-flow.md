# Flow-* Skill Audit

时间: 2026-06-02
范围: 7 个 flow-* skill (codex-goal / dev-task / ext-publish / project-bootstrap / project-finish / skill-dev / skill-research)
对照: `_shared/{constitution,output-contract-schema,question-gate,handoff-payload-template,parallelization-template,evidence-discovery,dispatcher-template,director-template}.md`

---

## 概览(7 skills 跨 skill 共性问题)

### 共性 P0(必改 — 元规范级 drift)

- **Q gate 0/7 引用 `_shared/question-gate.md`**: 7 skill 里**没一个**显式引用 question-gate 元规范。
  - flow-dev-task 有自己的 "Question Budget"(line 105),自创"≤ 3 问"约定。
  - flow-codex-goal 在 Step 0.1 内联了 "Question Budget = 3 + 1"(line 217)。
  - flow-ext-publish 在 Step 3 自创"含糊回应不算确认"清单(line 277)。
  - flow-project-bootstrap / project-finish / skill-dev / skill-research **完全没有** Q gate 段。
  - question-gate.md 第 5 段明确要求 Output Contract 含 `### Question Gate` 段(问题数 / 清单 / 默认值 / 用户回复 / 影响) — **7 个里 0 个 follow**。
- **`_shared/evidence-discovery.md` 7/7 未引用**: director-* 元规范的 5 段要求"Output Contract 必须含'证据采集'段"。flow-* 自己产物多数也是带证据的报告(diff / 截图 / commit SHA / 部署 URL),但**没一个 flow-* 引用本规范或建对应的"证据采集"段**。
- **Output Contract 引用混乱**: 只有 flow-dev-task 同时引用 schema + template(line 276-277)。flow-codex-goal 用自己的 `task-report-template.md`(line 905) **不引用 schema 基线**;flow-ext-publish / flow-skill-dev / flow-skill-research **完全没有 Output Contract 段或没引 schema**。output-contract-schema.md 第 179 行明确列了 7 个 flow-* 都"必须按本规范出具",**4/7 没做到**。

### 共性 P1(应改 — 结构 drift)

- **handoff-payload-template 引用面 1/7**: 只有 flow-codex-goal line 955 显式引用 `handoff-payload-template.md`。flow-dev-task / flow-ext-publish / flow-project-bootstrap / flow-project-finish / flow-skill-dev / flow-skill-research 都没引,虽然 flow-dev-task 是 codex-goal 的上游、bootstrap 是 dev-task 的上游。handoff-payload-template.md 第 47 行明确要求"各 flow-* skill 在 `## Relationship to Other Skills` 段加引用"。
- **`parallelization-template.md` 引用不一致**:
  - flow-dev-task line 80 / flow-ext-publish line 142 / flow-project-bootstrap line 107 / flow-project-finish line 107,171 都引了 — OK
  - flow-codex-goal 主体没引(只在 Step 2.3.2 line 648 一处提到) — **该 skill 是 parallelization-template 第 229 行明示的"reference design"**,反而主体不引,矛盾
  - flow-skill-dev / flow-skill-research **完全没引**(它们也派 subagent — skill-creator / writing-skills / skill-behavior-test / find-skills,应引)
- **`dispatcher-template.md` 引用不齐**: flow-skill-dev / flow-skill-research **没引** dispatcher-template,但两者都派下游 skill。dispatcher-template.md 第 233 行明示 7 个 flow-* 全是"已使用本模板的 skill",**2/7 没引**。
- **failure-modes.md 拆分不齐**: flow-codex-goal / flow-dev-task / flow-project-bootstrap / flow-project-finish 都把 Red Flags 下沉到 `references/failure-modes.md` — 模式一致 OK。**flow-ext-publish / flow-skill-dev / flow-skill-research 没有 failure-modes.md**(ext-publish 用 line 446 "禁止行为" 长清单内联,skill-dev 用 line 506 Completion Rules,skill-research 用 line 207 "常见错误")。3 套不同命名 + 不同结构 = drift。
- **角色信条段普及不齐**: codex-goal / dev-task / ext-publish / project-bootstrap / project-finish / skill-dev 都加了"## 角色信条"段(对齐 director-template.md 第 4 段),**flow-skill-research 没有角色信条段**。
- **TL;DR 段只 codex-goal 有**: codex-goal line 21 加了 "TL;DR for Orchestrators(30 秒上手)" 段。这是好实践(大 skill 必备),但只此一家 — 没沉淀到元规范,新 flow-* 不知道要不要加。

### 共性 P2(可改 — 内容质量)

- **`director-template.md` 没有 flow-* 平行版本**: shared 里有 director-template,但**没有 `flow-template.md`**。7 个 flow-* 没统一元规范托底,只能横向对齐互抄,drift 是必然结果。
- **Codex Delegation Hook 措辞高度重复**: 5/7 写"派工细则全部以 `flow-dev-task` 的 Codex Delegation Hook 为唯一规范,不在本 skill 重复"(几乎逐字一致)。该段应下沉成 `_shared/codex-delegation-template.md` 或在 dispatcher-template.md 里加 ROI 段。

---

## 逐 skill findings

### flow-codex-goal (992 行, 36 refs — 巨大)

**优**:
- TL;DR 段(line 21-65)做得到位 — 5 phase + 3 翻车点 + References 路由表,**最常翻的车**对应锚点齐全,是大 skill 的最佳实践范本。
- 角色信条段(line 88-110)非常具体(5 条翻车 + 心理测试题),对齐 director-template.md 第 4 段要求。
- Two-Codex Hard Isolation 段(line 723-777)是核心价值,工程细节充分(进程 / 会话 / fs / 网络 / 信息 / 审计 5 重)。
- 引用 `constitution.md` 第 1/3/6 条**用法正确**(line 127 / 405 / 827),是 7 个 flow-* 里**唯一**实际把 constitution 用进决策的。
- Reviewer Plan 确认表(line 282-302)的覆盖性自检 — 维度必须被认领,反 AI slop 设计精到。

**改 P0**(必改):
- [SKILL.md:903-915] **Output Contract 段不引用 `_shared/output-contract-schema.md`**:用了私有 `task-report-template.md`,违反 output-contract-schema.md 第 179 行的强制引用规则。**改法**:Output Contract 段第一行改为 "按 `references/output-contract-schema.md` 基线 + 本 skill 扩展字段(`score_trajectory` / `highest_tag` / `reviewer_pids` 等已在 schema 第 73 行登记)" → 然后再保留 task-report-template.md 作为 markdown 模板。
- [SKILL.md:217 + 整段 Step 0.1] **Q gate 自创不引 `question-gate.md`**:"Question Budget = 3 + 1 项可选维度"是私造 budget。**改法**:整段加 reference 行 "Q gate 规则遵循 `references/question-gate.md`(本 skill 因 Step 0.1 涉及 5 项确认,额外允许 1 项 mode 维度,共 4 问 — 对元规范第 3 段 ≤3 的明示例外)"。
- [SKILL.md:282-302] **Reviewer Plan 段没说"Q gate 应该把它当成几个问题"**:确认表是用户必须回的,但没说是否计入 3-question budget,跟 line 217 矛盾。**改法**:明示 "Reviewer Plan 确认表算 1 个 Q gate 问题(yes/默认/具体调整)" 或 "不算 Q,属确认门"。
- [SKILL.md:872] **文档矛盾自承认未清理**:"统一为 3,旧版有处写 2 是文档矛盾——以本条为准" — 这是已知 drift 但没动手清理。**改法**:全文 grep 把所有 "Review 2 轮 fail" 改为 "Review 3 轮 fail",再删本条免责声明。

**改 P1**(应改):
- [SKILL.md:48-65] References 路由表 8 行,**漏列**了 `failure-modes.md` / `task-report-template.md`(都是 Output Contract / Red Flags 主体下沉的目标)。**改法**:补两行 — "全套 Red Flags + Rationalizations → `failure-modes.md`" / "task report markdown 模板 → `task-report-template.md`"。
- [SKILL.md:646-651] Extra reviewer 段引用了 `references/dispatcher-template.md` + `references/parallelization-template.md`,但**主体 Workflow 段(Phase 1-3)没引** parallelization-template,反而是核心并行场景(extra reviewers 并列启动 / mini-review / 4 路 ui screenshot)。**改法**:Required Workflow 段开头加引用,或单建 "## Parallelization Plan" 段(director-template.md 第 10 段要求,flow-codex-goal 没有这一段)。
- [SKILL.md:113-122] "Codex `/goal` 的硬限制"表 5 行 — **过短**(Codex CLI 0.128.0+ 的状态信息可能在 4-6 个月后过期)。**改法**:下沉到 `references/codex-goal-setup.md`(reference 目录已存在该文件,SKILL.md 主体只留 1 行链接 + 必要警示)。
- [SKILL.md:166-180] Run Modes 4 路表(CLI-YOLO / TMUX-YOLO / CLI-EXEC / SUBAGENT)体积大(15 行表 + 关键纪律段)。**改法**:精简到 "4 mode 速查 → 全表见 `references/run-mode.md`"(reference 已存在),主体只保留"Phase 0 必须先探测 + 落盘 RUN_MODE"。
- [SKILL.md:412-535] Phase 1 含 4 个 Step + 多个 mode 分支启动代码(line 416-460),**主体 Bash 段过多**。**改法**:Step 1.1 各 mode 启动代码下沉到 `references/run-mode.md`,主体只留"按 RUN_MODE 选启动方式,详见 references/run-mode.md"。

**改 P2**(可改):
- [SKILL.md:540-578] Step 2.2 创建 review-readonly worktree 的 25 行 bash 是工程细节,可下沉到 `references/reviewer-arbitration.md`(已存在)。
- [SKILL.md:124-142] "用户判断权优先"段在 When to Use 之前 — **顺序错位**,违反 director-template.md 第 3 段标准结构(角色信条 → When to Use → When NOT to Use → Mode Selection ...)。**改法**:把该段并入 "When to Use" 注脚或下沉到 references。
- [SKILL.md:38-45] TL;DR 里"3 个最常翻的车"和 line 920 Red Flags 主体的"Top 3 翻车点"是双源同步 — drift 风险。**改法**:加一行 "Top 3 与 failure-modes.md 的 Phase 0/隔离/Score 三组首条同步,改一处即改两处"。

**Outdated**:
- [SKILL.md:113] "Codex CLI 0.128.0+" — 是否仍是当前最低门槛?2026-06 时点该信息已半年,建议在 references/codex-goal-setup.md 补 "last verified 日期" 元信息。
- [SKILL.md:872] 上文已述"文档矛盾"自承认未消除。

---

### flow-dev-task (317 行, 9 refs)

**优**:
- 角色信条段(line 31-46)简洁有力 — 1 个心理测试题 + 5 条翻车,完全对齐 director-template.md 第 4 段要求。
- Output Contract 段(line 274-279)是 **唯一一个**同时引用 schema + template 的 flow-*,是标杆。其他 6 个应抄。
- Workflow 表(line 112-130)双链(feature / bugfix)对齐 Stage 编号 — 行业级"统一视图"做法。
- Decision Rules 6 条(Execute Mode / Auto-Recap / TDD Skip / Writing-Plans / Worktree / Brainstorm Skip)全是"硬写死,不询问" — 反"问超 3"设计精到。

**改 P0**(必改):
- [SKILL.md:105-110] **Question Budget 段不引 `_shared/question-gate.md`**:自创"一轮 ≤ 3 个问题",和 question-gate.md 第 3 段完全同义,但**没引用元规范**。**改法**:"Question Budget" 段第一行改 "Q gate 规则遵循 `references/question-gate.md`,以下是本 skill 的具化"。
- [SKILL.md:296-313] Relationship 段**没有 Upstream Handoff Payload 子段**。flow-codex-goal line 955 明确把"上游 flow-dev-task 必须透传字段"列了出来,但 **flow-dev-task 自己**(下游是 codex-goal)的 Relationship 段没回应这套契约。handoff-payload-template.md line 60 列 flow-dev-task 上游为"用户 / flow-project-bootstrap",下游"flow-codex-goal / clean-commit" — 应在本 skill 同时声明上下游 payload。**改法**:加 "### Upstream Handoff Payload"(从 flow-project-bootstrap 接什么)+ "### Downstream Handoff Payload(到 flow-codex-goal)"(透传什么,对齐 codex-goal SKILL.md line 953-971 已声明的字段)。

**改 P1**(应改):
- [SKILL.md:74] Scenario Classification 表第 5 行 "同时命中 / 完全模糊" → "停下追问**一句**" — 问 1 个非 budget 内的问题,但 Q budget 仅声明从 Context Harvest 后开始,**入场分类追问的 1 次没被算进 budget**,边界不清。**改法**:明示 "分类追问不计入 3-question budget(属 mode 判定门,不属 question gate)"。
- [SKILL.md:140-141] Auto-Recap Rule 没说 change-recap **如何拼 commit body**(只说"+ 拼 commit body")。下游 clean-commit 不知道怎么拿这 body。**改法**:补一句 "change-recap 的 recap_markdown 落盘 `.agent/jobs/<task>/recap.md`,Stage 8 clean-commit 读该路径作为 commit body 来源"。
- [SKILL.md:203-230] Stage 5.5 Director-Design Trigger Rule 派工 prompt **没引 dispatcher-template.md**(line 211 引了,但 prompt 字段表自己列了一遍 — 应改成"按 dispatcher-template.md 模板,补这些扩展字段")。**改法**:line 213-220 字段表保留,但加 "字段集对齐 dispatcher-template.md,以下是扩展"。
- [SKILL.md:281-294] Failure Modes 主体 6 条 trip-wire — **缺第 7 条:Auto-Recap 失败但悄悄阻断 Stage 8**(line 160 fallback 说不阻断,但 trip-wire 没列"如果 fallback 没生效 = 翻车信号")。

**改 P2**(可改):
- [SKILL.md:231-272] Codex Delegation Hook 是其他 flow-* 引用的"唯一规范",**应下沉到 `_shared/codex-delegation-template.md`** 让别的 flow-* 真能引用(目前是逐字复制式引用)。

**Outdated**: 无明显死引用。

---

### flow-ext-publish (479 行, 4 refs)

**优**:
- 角色信条(line 31-62)非常具体到平台 quirks(Firefox AMO source review / Edge publisher 验证 / Chrome promo tile 尺寸) — 5 条翻车有平台佐证。
- 平台特定要点(line 345-398)是高浓度知识,几个月内 Edge / AMO UI 改了 agent 也能复用。
- 工具路由表(line 301-309)清晰且禁止 fallback 到 Playwright MCP 明示。

**改 P0**(必改):
- [SKILL.md:整体] **没有 Output Contract 段**!Step 5 最终报告(line 406-432)是个 markdown 模板,但**段名叫"最终报告"不是 Output Contract**,且不引 `_shared/output-contract-schema.md`。output-contract-schema.md line 179 列 flow-ext-publish 为必须遵守。**改法**:重命名 line 405 段为 "## Output Contract",首行加 "按 `references/output-contract-schema.md` 基线 + 本 skill 扩展字段(`platform`(来自 handoff)/ `preflight_verdict` / `submitted_platforms[]` / `review_ids[]` / `skipped_platforms[]`)",保留下方 markdown 模板。
- [SKILL.md:整体] **没有 References 段或 References 路由表** — 4 refs 太少,大段平台细节(Firefox / Chrome / Edge 三段共 ~50 行)**应下沉**到 `references/platform-quirks-{firefox,chrome,edge}.md`,主体只留 "完整步骤详见 references/..."。当前 479 行有 ~150 行是平台 UI 操作细节,SKILL.md 体积过大。
- [SKILL.md:无] **没有 Q gate 段** — Step 3 用户确认是"含糊不算"清单(line 277),但没声明属于 Q gate;没说 Step 2 分流 + Step 3 确认总共问几个问题。**改法**:加 "## Question Gate"(引用 question-gate.md)说明"Step 3 用户确认属 Step 3 阶段门,不是 Q gate 多轮 — Q gate 在 Step 1 preflight 后只允许 1 次澄清"。
- [SKILL.md:无] **没有引用 `_shared/handoff-payload-template.md`** — flow-ext-publish 是 director-promote 的下游(handoff-payload-template.md line 69 显示 director-promote handoff 出口指向 flow-ext-publish)。本 skill 必须声明上游 payload 字段。**改法**:加 "## Relationship to Other Skills" 段,声明上游 director-promote 必传字段(`platform[]` / `version` / `release_notes_path` / `evidence_paths`)。

**改 P1**(应改):
- [SKILL.md:446-466] "禁止行为" 21 条 — 应拆到 `references/failure-modes.md` 与其他 4 个 flow-* 对齐(目前 flow-codex-goal / dev-task / bootstrap / finish 都拆出去)。
- [SKILL.md:142-162] Step 2 并行编排表 引用了 parallelization-template.md(line 142 OK),但**派工 prompt 字段没引 dispatcher-template.md**(line 150-156 自列字段 — 应改"按 dispatcher-template.md 字段集,本 slot 必填扩展")。
- [SKILL.md:468-479] "完成判定" 段 6 条 — 应纳入 Output Contract 的 `verdict` 字段语义里(`completed-all-platforms` / `partial` / `failed`),而不是独立段。
- [SKILL.md:107-117] Required Workflow 是 5 步 numbered list,但**每步没明示 gate**(只 line 117 一句 "Step 3 前不得进入 Step 4")。**改法**:每步后加 "Gate: <hard condition>"(对齐 director-template.md 第 7 段 "每步有 actionable gate")。

**改 P2**(可改):
- [SKILL.md:285-318] Step 4 工具路由约束 + Playwriter / agent-browser 执行约束(共 ~35 行)可下沉到 `references/store-tools.md`。

**Outdated**:
- [SKILL.md:191-198] "A 路径里调用 huashu-design / ai-image-generation" 禁止行为 — **huashu-design 是当前 skillshare 里的 skill**(从系统提示可见),但 ext-publish 把它列为禁用 → 这条作为 A 路径的"禁止 stock 图"信号是对的,但**句子结构容易误读**为 "禁止任何调用 huashu-design",和 flow-project-finish line 36 / project-bootstrap 都调用 huashu-design 形成认知冲突。**改法**:改为 "禁止用 huashu-design / AI 文生图**绕过项目资产约束做 stock 主视觉**;非主视觉的 logo / 装饰仍可走对应 skill"。

---

### flow-project-bootstrap (171 行, 9 refs)

**优**:
- **体积控制最好** — 171 行,大块流程下沉到 `references/stage-1-discovery.md` + `references/stage-2-build.md`,主体只保留顶层 phase + user gate + handoff contract。这是其他大 skill(codex-goal / ext-publish)应抄的范本。
- 角色信条(line 27-42)聚焦 Stage 1 锁死 + written choices 的核心信念。
- Stage 1 / Stage 2 user gate 段(line 84-98)4 问明示 + "至少 1/2/3 三项明确回答"硬约束。
- Codex Delegation Hook 按 Stage 切 ROI(line 150-167),颗粒度对。

**改 P0**(必改):
- [SKILL.md:135-143] **Output Contract 段不引 schema 基线**:line 137 只引 `output-contract-template.md`,**没引 schema**。**改法**:加 "按 `references/output-contract-schema.md` 基线 + 本 skill 扩展字段(`mvp_slice_locked` / `selected_mockup_id` / `deployment_target` / `design_doc_path` / `preview_url`)",再保留 template 引用。
- [SKILL.md:无] **没有 Q gate 段** — Stage 1 user gate(line 84-98)是 mode-level 决策门,不等于 Step 0 Q gate(对齐 question-gate.md 第 1 段 — 在 mode 判定 + Step 1 探测完成后才 Q gate)。**改法**:加 "## Question Gate(Phase 1.1 前置)" 段说明 "调 project-prep 前已知 MVP / 用户 / 调性 → 0 问;含糊 → 引用 question-gate.md ≤3 问"。
- [SKILL.md:无] **handoff-payload-template.md 没引** — bootstrap 的下游是 dev-task / dir-architect / frontend-design / huashu-design / dir-design(详见 handoff-payload-template.md line 59),**没有任一上下游 payload 声明**。**改法**:加 "## Upstream / Downstream Handoff Payload" 段,引用 _shared 元规范。

**改 P1**(应改):
- [SKILL.md:144-148] "Red Flags / Rationalizations / Common Mistakes / Delivery Check → references/failure-modes.md" — 主体里**完全没有 Top N trip-wire**。其他 4 个 flow-*(codex-goal / dev-task / project-finish)主体都保留了 Top 3-6 trip-wire 作为快速速查。**改法**:主体加 3-5 条速查 "Stage 1 没锁就跑 Stage 2 / 只给 1 套设计候选 / 私有仓库默认 GitHub Pages / 部署 token 写进 git / logo 用 emoji 占位"。
- [SKILL.md:108-118] Stage 2 三路并行表引了 parallelization-template + dispatcher-template(line 107) — OK,但**写入目录列**没给路径模板("`assets/logos/` 或 `branding/`" 选哪个?)。**改法**:补 "若项目已有 branding/ → 用 branding/,否则新建 assets/logos/"。
- [SKILL.md:130-132] "用户声明的数值约束覆盖默认值" 一句话太轻 — 数值字段(候选数 / mockup 路数 / logo 方向数)在哪声明默认值?**改法**:加表 "默认值清单"(3 mockup / 2 logo / 3 设计方向)。

**改 P2**(可改):
- [SKILL.md:119-133] Handoff Contract 段 + 下方的"派工 prompt 字段集 → dispatcher-template"双源 — 可合并为 "## Relationship to Other Skills" 段,对齐 director-template.md 第 12 段。

**Outdated**: 无明显死引用。

---

### flow-project-finish (276 行, 8 refs)

**优**:
- Step 0 项目快照(line 74-103)字段化非常具体,9 类信号 + 落盘字段名硬约束 — 反 AI 自由探测精到。
- Step 1 并行 4 路 subagent 表(line 110-118)字段齐全,reduce 模式(line 119)明示。
- 角色信条(line 24-52)5 条翻车每条带二阶解释,对齐 director-template.md 第 4 段 "每条带'为什么这是和稀泥'的二阶解释" 要求。
- preview vs landing page 区分(line 81)是项目级好实践,反"模式套用"。

**改 P0**(必改):
- [SKILL.md:233-235] **Output Contract 段不引 schema 基线**: 只引 `output-contract-template.md`(line 235),**没引 schema**。**改法**:加 schema 引用 + 扩展字段(`docs_sync_paths[]` / `readme_status` / `landing_url` / `landing_skipped` / `delivery_gate_verdict` / `commit_sha` / `deployment_switched_files[]`)。
- [SKILL.md:无] **没有 Q gate 段** — 与 bootstrap 同问题。Step 0 探测后是否有 Q gate?Step 3.0 三选一 "refresh / rebuild / skip" 算 Q gate 吗?**改法**:加 "## Question Gate" 段说明 "Step 0 完成后 0 问 OK,若 Step 3.0 触发用户必选 → 算阶段门不计 Q;Step 3.2.6 等用户挑 mockup 同样"。
- [SKILL.md:223-232] Handoff Contract 段**没引** `_shared/handoff-payload-template.md`,且没声明 Upstream Payload(谁触发本 skill?从 flow-dev-task 收尾还是用户直接触发?)。**改法**:加 Upstream Payload 字段表。

**改 P1**(应改):
- [SKILL.md:175-183] Step 4 Delivery Gate + Step 4.0 director-design audit 派 subagent **没引 dispatcher-template.md**(只引了内联字段 "audit 的是 3.3 落地后的生产代码")。**改法**:补一句 "派工 prompt 按 `references/dispatcher-template.md` 字段集"。
- [SKILL.md:81] "Existing web preview" 类别探测 — **没有写明 preview 字段在 Step 3.0 分流时怎么用**(line 167 line 一句 "preview ≠ none 不进分流" 太轻)。**改法**:在 Step 0 字段表加 "preview 字段在 Step 3.0 仅用于警示;在 Step 3.3.5 部署切换时 preview 子路径保留,详见 references/approval-land-workflow.md"。
- [SKILL.md:237-248] Failure Modes 主体 6 条 + "完整 21 条 → references/failure-modes.md" — **没有 Top 3** trip-wire(对齐 flow-codex-goal TL;DR / flow-dev-task line 285),只是 6 条平铺。**改法**:6 条改成"Top 3 必停 + 3 条次要"分级。

**改 P2**(可改):
- [SKILL.md:106-119] Step 1 派 4 路 subagent 段 + reduce 段(line 119)**应单建 `## Parallelization Plan` 段**(对齐 director-template.md 第 10 段),而不是嵌在 Step 1 内文。
- [SKILL.md:250-270] Codex Delegation Hook 7 条 — 同其他 5 个 flow-* 一样,应下沉到 `_shared/codex-delegation-template.md`。

**Outdated**: 无明显死引用。

---

### flow-skill-dev (573 行, 3 refs)

**优**:
- Step 2 / Step 2.5 关于"中心仓库 vs 下游副本"的硬阻断逻辑(line 142-253)是项目级特色,反"改下游被覆盖"很到位。
- 角色信条(line 28-61)5 条翻车 + "substantial-update 必须更新 _shared 元规范" 是元规范级自我意识。
- Completion Rules 段(line 506-523)9 条硬清单 — 收尾门齐全。

**改 P0**(必改):
- [SKILL.md:无] **完全没有 Output Contract 段**!output-contract-schema.md line 179 明确列 flow-skill-dev 为必须遵守。Step 9 "Write the Final Report" 段(line 441-505)是 markdown 模板,**没声明对齐基线 JSON schema**。**改法**:加 "## Output Contract" 段在 Step 9 之前,引 schema + 扩展字段(`skill_name` / `skill_type` / `authoritative_dir` / `chose_center` / `behavior_test_status` / `integration_test_status` / `sync_to_center_status`)。
- [SKILL.md:无] **没有 Q gate 段** — Step 1 Classify the Work 涉及判断 new / substantial / minor,但没说该步是否问用户;Step 3 skill-creator scope 是否问用户?**改法**:加 Q gate 段引 question-gate.md,明示 "Step 1 / Step 3 之间允许 ≤ 3 问"。
- [SKILL.md:无] **完全没引** `_shared/parallelization-template.md`,但 flow-skill-dev 派 subagent 跑 skill-creator / writing-skills / skill-behavior-test / skill-integration-test / sync-skills — **是典型的 dispatcher**。**改法**:加 "## Parallelization Plan" 段(虽然 skill 开发多数串行,也应明示"通常串行,跨独立 skill 文件可并行")。
- [SKILL.md:无] **完全没引** `dispatcher-template.md`,虽然 references 目录(line 3 ls 输出)**有** dispatcher-template.md 的 sync — 元规范同步了但 SKILL.md 没用。**改法**:Required Workflow Step 3-7 各步派 skill-creator / writing-skills 等时,加 "派工 prompt 字段集对齐 `references/dispatcher-template.md`"。

**改 P1**(应改):
- [SKILL.md:104-121] Required Workflow 9 步 list,**每步没明示 gate**(对齐 director-template.md 第 7 段 + question-gate.md 模式)。**改法**:Step 2.5 / Step 5 / Step 6 / Step 8 各加 "Gate: <硬条件> 不通过 → 停"。
- [SKILL.md:535-572] Codex Delegation Hook 写了"全部 🔴 不建议派"是合理判断,但**段位置在 SKILL.md 末尾**(其他 5 个 flow-* 都也在末尾) — 一致 OK,但应统一引用 flow-dev-task 唯一规范。
- [SKILL.md:528-533] Minimal Operating Principle 段(line 525-533)和 Overview 内容重复("拦住三类常见失败" vs Overview "默认执行不是建议")。**改法**:删 Minimal Operating Principle,内容并入 Overview 末段。

**改 P2**(可改):
- [SKILL.md:155-188] Step 2 中心仓库切换规则 + ❌ 严禁条款 ~ 35 行,可下沉到 `references/authoritative-dir-rules.md`。
- [SKILL.md:195-253] Step 2.5 Pre-flight 4 分支(A / B / C / D)~ 60 行,可下沉到 `references/preflight-conflict.md`,主体只留判定表。
- [SKILL.md:386-438] Missing Dependency Fallbacks ~50 行,可下沉到 `references/fallbacks.md`。**主因**:573 行 SKILL 体积过大,但 references 目录只有 3 个文件 — 严重失衡(应是 references 主体 + SKILL 顶层)。

**Outdated**:
- [SKILL.md:139] 提到 "skillshare sync --force" — 工具命令稳定,但 line 196 / 224 fetch 分支策略未给 "last-tested 日期"。

---

### flow-skill-research (235 行, 3 refs)

**优**:
- Step 5 "读取真实内容" 段(line 125-149)反"只看 description / 安装量"AI slop 设计精到。
- 安装边界段(line 173-192)默认不安装明示,符合 constitution.md 第 6 段 High-Risk Action Gate。

**改 P0**(必改):
- [SKILL.md:无] **完全没有"角色信条"段**!其他 6 个 flow-* 都有(对齐 director-template.md 第 4 段)。**改法**:加 "## 角色信条" 段在 Overview 之后,5 条翻车 + 心理测试题。例如 "我是 skill 调研官,不是装一堆 skill 上身的人;我读真实文件,不信描述"。
- [SKILL.md:无] **没有 Output Contract 段** — output-contract-schema.md line 179 列 flow-skill-research 为必须遵守。Step 6 "输出调研结论"(line 151-171)是个列表,没声明 JSON schema。**改法**:加 "## Output Contract" 段,引 schema + 扩展字段(`local_install_check` / `search_terms[]` / `candidates[]` / `recommendation` / `install_executed`)。
- [SKILL.md:无] **没有 Q gate 段** — Step 1 定义调研目标可能需要追问。**改法**:加 Q gate 段引 question-gate.md。
- [SKILL.md:无] **没引 `dispatcher-template.md`**,虽然 references 目录有(line 7 ls 输出) — 同 flow-skill-dev 问题。即便本 skill 主要是查 + 读,仍可能派 subagent 批量读 SKILL.md(line 220 Codex Delegation Hook 提了 "🟡 中 ROI 视情况派")。**改法**:Codex Delegation Hook 段补 "派工 prompt 按 `references/dispatcher-template.md` 字段集"。
- [SKILL.md:无] **没引** `_shared/parallelization-template.md`,虽然 Step 3-5 批量读 ≥20 候选时是天然并行场景。**改法**:加 "## Parallelization Plan" 段。
- [SKILL.md:无] **没引** `_shared/handoff-payload-template.md`,虽然 Handoff 段(line 194-204)说 "转交 flow-skill-dev" 时要传 4 字段 — 字段集应对齐 handoff-payload-template.md 规范。**改法**:Handoff 段加引用,说明 "字段集遵循 _shared/handoff-payload-template.md,本 skill 额外传 `research_target` / `searched_keywords` / `gap_analysis` / `new_skill_scope`"。

**改 P1**(应改):
- [SKILL.md:35-50] 必要流程 8 步 numbered list,**每步没明示 gate**。**改法**:Step 7 推荐前加 "Gate: 至少有 1 个候选过初筛 + 已读真实 SKILL.md,否则输出'未找到可靠候选'"。
- [SKILL.md:207-214] "常见错误" 7 条 — 应拆到 `references/failure-modes.md`(对齐其他 4 个 flow-* 模式),不是叫 "常见错误" 也不是 "Red Flags" — 命名 drift。
- [SKILL.md:174-192] 安装边界段没给"安装失败如何回滚" — `npx skills add` 失败时是否回退?**改法**:补 "安装失败 → 立刻报告 stderr + 不自动重试 + 不破坏本地已装 skill"。

**改 P2**(可改):
- [SKILL.md:64-67] Step 1 关键词扩展示例(React / Preact / 重构)3 行可下沉到 `references/keyword-expansion.md` 或合并 evidence-discovery.md。
- [SKILL.md:216-235] Codex Delegation Hook 7 条 — 同其他 5 个 flow-* 模式,应下沉到 _shared。

**Outdated**: 无明显死引用。

---

## Master 跨 flow 一致性 drift 表

| 维度 | flow-codex-goal | flow-dev-task | flow-ext-publish | flow-project-bootstrap | flow-project-finish | flow-skill-dev | flow-skill-research | 元规范要求 |
|---|---|---|---|---|---|---|---|---|
| **constitution.md 引用** | ✅ + 实用 line 127/405/827 | ✅ 顶部 | ✅ 顶部 | ✅ 顶部 | ✅ 顶部 | ✅ 顶部 | ✅ 顶部 | 全部必引(director-template 第 13 段 + constitution.md 第 8 段) |
| **constitution 实用度** | ✅ 实际用进决策 | ❌ 仅顶部声明 | ❌ 仅声明 | ❌ 仅声明 | ❌ 仅声明 | ❌ 仅声明 | ❌ 仅声明 | 应实际引用条款做判断 |
| **output-contract-schema.md 引用** | ❌ 用私有 template,**没引 schema** | ✅ schema + template | ❌ 没 OC 段 | ❌ 只引 template,**没引 schema** | ❌ 只引 template,**没引 schema** | ❌ **没有 OC 段** | ❌ **没有 OC 段** | output-contract-schema.md line 179 列 7/7 必须 |
| **handoff-payload-template.md 引用** | ✅ line 955 | ❌ 没引 | ❌ 没引 | ❌ 没引 | ❌ 没引 | ❌ 没引 | ❌ 没引 | handoff-payload-template.md line 47 要求所有 flow-* 在 Relationship 段引 |
| **question-gate.md 引用** | ❌ 自创 Q budget | ❌ 自创 Question Budget | ❌ 没 Q gate 段 | ❌ 没 Q gate 段 | ❌ 没 Q gate 段 | ❌ 没 Q gate 段 | ❌ 没 Q gate 段 | question-gate.md 是 director-* 强制,flow-* 应类比;7/7 drift |
| **parallelization-template.md 引用** | ❌ 主体没引(只在 line 648 单点) | ✅ line 80 | ✅ line 142 | ✅ line 107 | ✅ line 107, 171 | ❌ 没引 | ❌ 没引 | parallelization-template.md line 232 列为 "reference design" 的 codex-goal 反而没在主体引 |
| **dispatcher-template.md 引用** | ✅ line 648 (单点) | ✅ line 211 | ❌ 没引 | ✅ line 107, 133 | ✅ line 107, 173 | ❌ 没引 | ❌ 没引 | dispatcher-template.md line 233 列 7/7 必须 |
| **evidence-discovery.md 引用** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | director-* 强制,flow-* 多数也有证据,7/7 drift |
| **Red Flags 段位置/结构** | ✅ "## Red Flags + Rationalizations" + 下沉 failure-modes.md | ✅ "## Failure Modes — STOP" + 下沉 | ❌ "## 禁止行为" 内联 21 条,命名 drift | ❌ "## Red Flags / Rationalizations / Common Mistakes / Delivery Check" + 全下沉,**主体无 Top N** | ✅ "## Failure Modes" + 下沉 + 主体 6 条 | ❌ "## Completion Rules" 命名 drift,内容混入"完成判定" | ❌ "## 常见错误" 命名 drift | 应统一命名为 "## Red Flags + Rationalizations" |
| **failure-modes.md 是否存在** | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ | 5 个有 / 3 个没 |
| **角色信条段** | ✅ 5 翻车 + 心理测试 | ✅ 5 翻车 + 心理测试 | ✅ 5 翻车 | ✅ | ✅ 5 翻车 + 二阶解释 | ✅ 5 翻车 | ❌ **没有** | director-template 第 4 段要求 |
| **Mode Selection 表** | ✅ Run Modes 4 路 | ❌ N/A(单 mode) | ❌ N/A | ❌ N/A(Stage 1/2) | ❌ N/A | ❌ N/A | ❌ N/A | director-template 第 6 段(flow-* 可选) |
| **Workflow numbered steps + gate** | ✅ Phase 0-3 + Step + gate | ✅ Stage 0-9 + gate(表里) | △ 5 步 + Step 3 gate 单点 | ✅ Stage 1/2 + user gate | ✅ Step 0-6 + gate | △ Step 1-9 + 部分 gate | △ Step 1-8 + 无 gate | 每步应有 actionable gate |
| **TL;DR 段** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | 大 skill 应有,**没沉淀到元规范** |
| **Upstream/Downstream Payload 段** | ✅ 完整 | ❌ 没声明 payload schema | ❌ 没 | ❌ 没 | ❌ 没 | ❌ 没 | △ 只 Handoff 段提了字段 | handoff-payload-template 要求 7/7 |
| **Codex Delegation Hook 段** | ✅ | ✅(唯一规范源) | ✅ | ✅ | ✅ | ✅ | ✅ | 一致 OK |
| **Codex Hook 引用 dev-task 唯一规范** | ❌ 自定不引 | N/A(本体) | ✅ | ✅ | ✅ | ✅ | ✅ | 5/7 引,codex-goal 自定 |
| **SKILL 体积控制** | 992 行 ⚠️ 过大 | 317 ✅ | 479 ⚠️ 偏大 | 171 ✅ 最佳 | 276 ✅ | 573 ⚠️ 偏大 | 235 ✅ | 主体 < 350 行,大段下沉 references |
| **references 数量 / SKILL 体积比** | 36 / 992 = 0.036 ✅ | 9 / 317 = 0.028 ✅ | **4 / 479 = 0.008** ❌ | 9 / 171 = 0.053 ✅ | 8 / 276 = 0.029 ✅ | **3 / 573 = 0.005** ❌ | **3 / 235 = 0.013** ❌ | 大段细节应下沉 references |

---

## 特别关注 — flow-codex-goal 992 行单独深审

### 体积结构(按行号粗分)

| 行号区间 | 段名 | 行数 | 评估 |
|---|---|---|---|
| 1-65 | Frontmatter + TL;DR | 65 | ✅ 高密度 |
| 67-110 | Overview / 角色信条 | 43 | ✅ 必要 |
| 112-180 | Codex 限制 + Run Modes | 68 | ⚠️ Run Modes 表可下沉到 references/run-mode.md |
| 182-410 | Phase 0(Pre-flight + AC + Worktree + APPROVAL) | 228 | ⚠️ Step 0.2 bash + Step 0.4 APPROVAL.md 模板可下沉 |
| 412-535 | Phase 1(Goal Codex 启动 + watcher + milestone) | 123 | ⚠️ Step 1.1 4 mode 启动 bash 可下沉 |
| 537-675 | Phase 2(Final Review + 仲裁) | 138 | ⚠️ Step 2.2 / 2.3.1 bash 块可下沉到 references/reviewer-arbitration.md |
| 677-721 | Phase 3(Delivery + 清理) | 44 | ✅ 必要 |
| 723-849 | Hard Isolation + Idle Model + Wake-up Combo | 126 | ✅ 核心价值,保留 |
| 852-901 | Decision Rules | 49 | ✅ 速查必备 |
| 903-988 | Output Contract + Red Flags + Codex + Relationship + Reuse | 86 | ✅ |

**结论**: 992 行里约 **400-450 行是 bash 块 + 模板示例**,可下沉到 references/(已存在但未使用), 主体压缩到 ~550-600 行可行。

### 切分建议(按优先级)

1. **Step 0.2 创建任务目录 + worktree bash**(line 305-318, 14 行)→ 已有 `references/codex-goal-setup.md`,合并进去
2. **Step 0.4 APPROVAL.md / TMUX-YOLO Acceptance 模板**(line 365-407, 42 行)→ 新建 `references/approval-template.md`
3. **Step 1.1 4 mode 启动 bash**(line 416-460, 45 行)→ 已有 `references/run-mode.md` + `tmux-yolo-runtime.md`,合并进去
4. **Step 2.2 review-readonly worktree bash**(line 558-578, 21 行)→ 已有 `references/reviewer-arbitration.md`,合并进去
5. **Step 2.3.1 启动 Reviewer Codex bash + env -i**(line 588-619, 32 行)→ 同上合并
6. **Codex 硬限制表**(line 113-122, 10 行)→ 已有 `references/codex-goal-setup.md`,合并

预期切分后 SKILL.md ≈ 580-620 行,可读性大幅提升 + 减少与 references 双源同步风险。

### codex-goal 独有问题

- **TL;DR 与 Red Flags 主体的"3 翻车点"是双源**(line 40-44 vs line 928-929),drift 风险高。已在 P2 列出。
- **line 872 自承文档矛盾**未消除("旧版有处写 2 是文档矛盾——以本条为准") — 应实际跑 grep 修掉所有 "Review 2 轮" 残留。
- **References 路由表**(line 54-63, 8 行)漏列了 failure-modes.md + task-report-template.md(两者是该 skill 显式下沉的主目标) — drift 风险。

---

## 优先级汇总

- **P0 总计**: 24 项(7 skill 平均 3.4 项)
- **P1 总计**: 18 项
- **P2 总计**: 14 项
- **跨 flow drift 总计**: 17 项(见 Master 表)
- **Outdated**: 3 项(codex-goal 版本元信息 / codex-goal 文档矛盾自承认 / ext-publish huashu-design 措辞)

### P0 最高优先级 3 项(改一项 = 修 N 个 skill)

1. **下沉 `_shared/codex-delegation-template.md`** + 7 个 flow-* 全部改成"按 _shared/codex-delegation-template.md 通用规范" — 1 改修 5 处 drift
2. **强制 7 个 flow-* Output Contract 段引 schema 基线** — output-contract-schema.md line 179 早已列必须,实际 4/7 没做到(ext-publish / skill-dev / skill-research 完全没有 OC 段;codex-goal / bootstrap / finish 只引 template 不引 schema)
3. **建 `_shared/flow-template.md`** 作为 7 个 flow-* 的统一元规范(平行 director-template.md) — 当前 7 skill 横向对齐互抄,structural drift 必然
