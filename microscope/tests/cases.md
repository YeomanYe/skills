# microscope 行为测试用例

验证 `microscope` 两种模式:**A 设计文档**(给有内部复杂度的组件写分层可懂的技术文档)、**B 改动讲解**(改完代码出用户视角 recap)。并验证它是 **callable-only**(显式点名 / 编排调才触发,不按关键词自动触发)。

---

## 触发纪律(callable-only)

### TT1. 正例 — 显式点名(模式 A)
> 用 microscope 给这个导出组件写个设计说明。

预期:触发,走模式 A,按固定结构产出 + persona 复审闭环。

### TT2. 正例 — 显式点名(模式 B)
> 刚修了那个登录卡顿的 bug,讲一下 / recap 这次改动。

预期:触发,走模式 B,收集 git diff,task_type=bugfix,audience=end-user,输出 3 段。

### TT3. 正例 — 编排调(模式 B)
> flow-dev-task Stage 7.5 pre-hook 调用 microscope(task_type=bugfix,--auto-recap=true)。

预期:触发模式 B,audience 透传,3 段 markdown 返回编排方。

### TT4. 反例 — 关键词出现但无人点名/无编排调(护栏)
> (对话里出现"这个组件挺复杂的""刚改了点东西"等,但用户没说"用 microscope"、也无编排调用)

预期:**不自动触发**。本 skill callable-only,只在显式点名或被编排调时启动。

---

## 模式 A:设计文档

### A1. 给组件写设计文档(正例)
> 给这个列宽可拖拽的表格组件写一份技术设计文档,讲清楚内部怎么实现的。

预期:先吃透源码再动笔;产出术语表、§1 总览(逻辑+先后)、§2 各 case(功能效果用户视角+ASCII+核心改动带因果)、§3 依赖顺序;写完派"只懂表格、不懂技术栈"的 persona 子 agent 复审,按反馈改。

### A-N1. API 参考 / README / changelog(反例)
> 给这个组件 props 写 API 参考表 / 写 README / 把改动写成 changelog。

预期:**不触发**(那些不是内部设计文档)。

### A-G1. §3 写成数据流被纠正
场景:把"依赖顺序"写成 `collectLeaf → leafStates → decorated` 自然数据流。
预期:识别为 §1 的料,§3 改写成"独立效果谁压谁、否则冲突"(z-index 层叠 / 点击抢占),每条带"判错出什么问题"。

### A-G2. 功能效果夹带术语被纠正
场景:功能效果写"mousedown 记 offsetWidth 再 clamp"。
预期:改成用户视角"拖动列右边线,这列实时变宽其他列不动",技术词挪进核心改动。

### A-G3. persona 复审不可跳过
场景:写完想直接交付。
预期:必派 persona 子 agent 通读标卡壳,改到能顺下来才算完成;跳过=未完成。

### A-G4. persona 复审必须用弱模型
场景:派 persona 复审时用了默认/强模型。
预期:改用能力较弱的模型(如 haiku)当评审员——弱模型才暴露得出文档"讲不清"处;用强模型它会脑补看懂、放过问题,复审失真,判未达标。

---

## 模式 B:改动讲解(recap)

### B1. task_type 推断 — merge-resolve
> merge 完了,recap 一下这次改动。

预期:task_type=merge-resolve,输出含"两边意图/取舍"语义。

### B-N1. "为啥这段代码这样写"(反例)
> 为啥这段代码用了 useEffect?

预期:**不**进模式 B(那是代码 walkthrough,走 `教` hat / 普通解释),不收集 diff。

### B-N2. 改动还没发生(反例)
> 等下要修 X,讲讲准备怎么做。

预期:**不**进模式 B(recap 对象是已发生改动),走 plan/brainstorm。

### 受众 Tests
- **B2 end-user(默认)**:diff=fix race condition in payment checkout → 输出不含 race condition/mutex/Promise/file:line,可含"结算/下单/卡顿"。
- **B3 pm**:`--audience pm` → 可含"结算流程/并发延迟",不含 file:line/框架名/变量名。
- **B4 dev**:`--audience dev` → 可含模块名+行为("checkout 同步锁→无锁队列"),不含 file:line。

### 长度护栏 Tests
- **B5 超 200 字符** → 自检 `within_length:false`,当场重写。
- **B6 end-user 含 jargon**(如 "stale closure")→ `no_tech_jargon:false`,重写成"按钮偶尔点了没反应"。
- **B7 含 file:line**(如 "PaymentForm.tsx:128")→ `no_file_line:false`(任何 audience),重写去掉。
- **B8 三段缺一段** → 拦住,补回缺的段。

### 非 UI 边界 Tests
- **B9 非 UI 改动**(`services/payment.ts`)→ 不提示,正常 3 段。
- **B10 纯 UI 改动**(仅 `Header.tsx` 颜色/间距)→ 降级提示"建议 director-design + 截图",用户回"继续"才往下。
- **B11 混合**(UI+逻辑)→ 不降级,以逻辑改动为主讲。

### Output Contract
- **B12** 正例输出 JSON 含全字段:skill / mode / audience / task_type / is_ui_change / ui_warning_shown / recap_markdown / char_count / self_check(4 子) / im_pushed / next_action。

---

## 编排联动 Tests(flow-dev-task → microscope)

### O1. auto-recap=true(默认)bugfix
flow-dev-task Stage 7.5,task_type=bugfix,--auto-recap 未指定(默认 true)。
预期:flow-dev-task 自动调 **microscope**(模式 B);audience 透传;3 段返回 flow-dev-task;推 IM(若 IM 会话);然后走 Stage 8 clean-commit。

### O2. auto-recap=false
预期:flow-dev-task **不调** microscope,直接 Stage 8;用户可后续显式调。

### O3. task_type=feature
预期:flow-dev-task **不调** microscope(不在 bugfix/merge/accept-review 列表),直接 Stage 8。

### O4. microscope 生成失败 fallback
预期:flow-dev-task **不阻断** Stage 8,跳过 IM + commit body 不拼 recap,Final Report `errors[]` 标记 "microscope recap failed: <reason>"。

---

## skill-doctor lint

### D1. lint 通过
`node ~/Documents/projects/node-scripts/dist/skill-doctor/index.js --root ~/Documents/projects/skills`
预期:microscope 0 ERROR;description 长度在阈值内;change-recap 已删除、无悬空引用。
