# experience-summary 测试用例

> 用于 skill-behavior-test / skill-integration-test 的回归基线。

---

## Case 1: 正例触发 — "经验该写到哪"

**Prompt**:
> 我刚发现我们项目里所有 API 都必须先过 auth 中间件,这次又有同事忘了。这条经验该写到哪?

**预期触发**: experience-summary skill 激活

**预期流程**:
- Step 1 锁定经验: "所有 API 必须先过 auth 中间件"(已清晰,无需追问)
- Step 2 走判断树:
  - Q0 不该沉淀? 否(明确工程规则)
  - Q1 跨 skill 价值观? 否(项目特定)
  - Q2 skill 元规范? 否
  - Q3 必须每次强制? **可能 yes(如果可以 lint)→ hook**,或 No → 继续
  - Q4 真实执行? 否
  - Q5 模块级? 否(全项目 API)
  - Q6 单一专业? 否
  - Q7 跨角色? 否
  - **Q8 项目级常驻? yes → L8(项目 CLAUDE.md)**
- Step 3 输出: 给 CLAUDE.md 追加段草稿 + wc -l 检查提醒
- Step 4 上移提醒: 如果之前已经被推荐过类似 → 提示上移

**断言**:
- ✅ 出口是 L8(项目 CLAUDE.md)或 L3(hook,如果有 lint)
- ✅ 给了可复制的 Markdown 草稿
- ✅ 包含 `wc -l CLAUDE.md` 检查提醒

---

## Case 2: 正例触发 — "踩了个坑想沉淀"

**Prompt**:
> 我踩了个坑想沉淀:CLAUDE.md 在 codex 里不读,要写 AGENTS.md。这次终于搞清楚了。

**预期触发**: experience-summary 激活

**预期流程**:
- Step 1: 经验 = "codex 用 AGENTS.md 不读 CLAUDE.md"
- Step 2:
  - Q0 否(真实工程事实)
  - Q1 否(具体工具差异,不是价值观)
  - Q2 否
  - Q3 否
  - Q4 否
  - Q5 否
  - Q6 否
  - Q7 否
  - **Q8 yes → L8**(项目级常驻,因为每次开 codex 都会遇到)
- Step 3 输出: 提示在项目根 `AGENTS.md` 维护 + 可 symlink CLAUDE.md

**断言**:
- ✅ 出口 L8
- ✅ 给出 `ln -sf CLAUDE.md AGENTS.md` symlink 命令
- ✅ 区分 Claude Code vs codex 的不同入口

---

## Case 3: 反例触发 — 正在做任务中

**Prompt**:
> 帮我修一下 src/utils/parser.ts 里这个 bug

**预期**: experience-summary **不触发**,应该走 `flow-dev-task`(bugfix 链)

**断言**:
- ❌ experience-summary 不激活
- ✅ 路由到 flow-dev-task

---

## Case 4: 反例触发 — 要创建 skill

**Prompt**:
> 帮我写一个新 skill,叫 release-checklist

**预期**: experience-summary **不触发**,应该走 `flow-skill-dev`

**断言**:
- ❌ experience-summary 不激活
- ✅ 路由到 flow-skill-dev

---

## Case 5: 主流程 — 单一专业判断 → director-*

**Prompt**:
> 我发现我们做宣传图时反复忘记图片合规检查(脱敏邮箱/IP/姓名)。这条经验放哪?

**预期流程**:
- Step 1: 经验清晰
- Step 2:
  - Q0 否
  - **Q1 yes?** 这是争议点 — "图片合规"是单领域(宣发)还是跨 skill(任何 agent 发图都要)?
    - 路由判断: 如果只在宣发场景 → Q6 director-promote
    - 如果跨所有 agent 发图场景 → Q1 constitution
  - 假设是宣发专项 → Q1 否 → ... → **Q6 yes → L6(director-promote)**
- Step 3 输出: 在 `director-promote/references/promote-principles.md` 加强维度 5(图片内容合规)

**断言**:
- ✅ 出口 L6 director-promote(或讨论后跳 L1 constitution)
- ✅ 给出具体段位置(promote-principles.md 维度 5)
- ✅ 提示走 flow-skill-dev substantial-update

---

## Case 6: 主流程 — 强制约束 → hook

**Prompt**:
> 我们每次 commit 前都要跑 pnpm lint,但 Claude 经常忘。这次又忘了。

**预期流程**:
- Step 1: 经验清晰
- Step 2:
  - Q0 否
  - Q1 否(项目特定)
  - Q2 否
  - **Q3 yes(每次必须、模型经常忘)→ L3(hook)**
- Step 3 输出: settings.json 的 PreToolUse hook 配置 + 提示用 update-config skill

**断言**:
- ✅ 出口 L3 hook
- ✅ 给出 JSON 配置片段
- ✅ 提示用 update-config(不要手动改 settings.json)

---

## Case 7: 主流程 — 跨 skill 价值观 → constitution

**Prompt**:
> 我发现 codex 在没确认时直接写了 GOAL_DONE。这条"未经外部 review 不能自宣告完成"的规则应该影响所有 agent。

**预期流程**:
- Step 1: 经验清晰
- Step 2:
  - Q0 否
  - **Q1 yes(影响所有 agent / 跨 skill 价值观)→ L1(constitution)**
- Step 3 输出: constitution.md 加 "Self-Declaration Gates" 段 + sync-shared.sh 提示

**断言**:
- ✅ 出口 L1 constitution
- ✅ 给出 sync-shared.sh + git push + skillshare sync 完整后续动作
- ✅ 不会建议"放在 flow-codex-goal 里"(那是单 skill 的事,跨 skill 价值观应该上移)

---

## Case 8: 负例 — 不该沉淀(Q0 拦截)

**Prompt**:
> 我觉得 Claude 今天回答得有点慢,这事要不要记下来?

**预期流程**:
- Step 1: 描述 = "Claude 今天慢"
- Step 2:
  - **Q0 yes(一次性 / 模型状态波动 / 没法落到位置)→ L0(丢弃)**
- Step 3: 告诉用户为什么不沉淀

**断言**:
- ✅ 出口 L0 丢弃
- ✅ 给出"为什么不沉淀"的理由
- ✅ 不会勉强路由到任何层

---

## Case 9: 模块级 → nested CLAUDE.md

**Prompt**:
> 我们 src/legacy/ 目录还在用 class component,新代码不能这样写。这条规则放哪?

**预期流程**:
- Step 1: 经验清晰,有明确范围 src/legacy/
- Step 2:
  - Q0-Q4 否
  - **Q5 yes(只对子目录生效)→ L5(nested CLAUDE.md)**
- Step 3 输出: `src/legacy/CLAUDE.md` 草稿

**断言**:
- ✅ 出口 L5 nested CLAUDE.md
- ✅ 路径是 `src/legacy/CLAUDE.md`(不是项目根)
- ✅ 草稿包含"本目录特有约束" + 反例

---

## Case 10: 上移触发(自指)

**Prompt(在同一对话第 3 次)**:
> 我又发现一条"图片合规要在所有 agent 都跑"的规则

**预期**: 检测到这是同一对话第 N 次出现 → 触发上移提醒

**断言**:
- ✅ 输出包含"已在本对话中第 N 次推荐 director-promote 的图片合规"
- ✅ 建议从 director-promote 上移到 constitution
- ✅ 给出上移路径草稿

---

## Case 11: 兜底(Q10)

**Prompt**:
> 我希望 agent 写代码更优雅

**预期流程**:
- Step 1 追问: "更优雅"指什么?(命名 / 抽象 / 简洁 / ...)
- 如果用户给不出具体:
  - **Q10 兜底 → L10(不沉淀)**
- 如果用户能说"用更简洁的命名":
  - 回到 Q0 重跑,可能路由到 CLAUDE.md(项目命名规范)

**断言**:
- ✅ 先追问(Step 1 的 2 个问题上限)
- ✅ 模糊到底 → 不勉强沉淀

---

## Case 12: handoff 完整性 → flow-skill-dev

**Prompt**:
> 我想把"扩展上架前的安全审计"沉淀下来

**预期流程**:
- Step 1: 经验 = 多步流程(收集材料 / 跑 lint / 检查 manifest / 截图脱敏 / ...)
- Step 2:
  - Q0-Q6 否
  - **Q7 yes(多步、跨角色)→ L7(flow-*)**
- Step 3 输出:
  - 推荐位置: 看是否已有 `flow-ext-publish`,有则改它
  - **handoff: 走 `flow-skill-dev` substantial-update 流程**

**断言**:
- ✅ 出口 L7 flow-*
- ✅ 显式提示走 flow-skill-dev(不要直接落盘)
- ✅ 检查是否已有 flow-ext-publish 可改

---

## 集成测试场景(链路)

### Chain 1: experience-summary → flow-skill-dev

**场景**: 经验分诊出口是新 skill。

**断言**:
- experience-summary 输出的"写作模板"作为 spec 输入给 flow-skill-dev
- flow-skill-dev 不重复追问已知字段(skill 名 / description / 触发条件)
- 整条链最终落到 SKILL.md + tests/ + sync

### Chain 2: experience-summary → update-config

**场景**: 经验分诊出口是 hook。

**断言**:
- experience-summary 输出的"JSON 配置片段"作为 input 给 update-config
- update-config 不破坏 settings.json 其他段
- hook 真生效(下次触发对应事件时执行)

### Chain 3: experience-summary → sync-skills

**场景**: 出口是 constitution / _shared/。

**断言**:
- experience-summary 提示"跑 sync-shared.sh"
- sync-skills 走完整链(git push → skillshare pull → sync --force)
- 12 个目标 skill 的 references/ 都同步更新

### Chain 4: experience-summary 自跑(自指)

**场景**: 用 experience-summary 分诊 "experience-summary 本身该放哪"。

**预期**:
- 出口 L7(flow-*?) 或 L? — 这是个治理工具,既不是单角色判断也不是多角色编排
- 合理出口: 独立 skill(无前缀,跟 clean-commit / skill-doctor 同类)

**断言**:
- ✅ 不出现死循环
- ✅ 路由结果是"独立 skill"(已经在 ~/Documents/projects/skills/experience-summary/)
