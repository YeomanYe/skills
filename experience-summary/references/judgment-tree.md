# Judgment Tree —— Q0-Q10 完整决策流(12 个出口)

> 顺序问 Q0 → Q10,**第一个 yes 即出口**,后续 Q 不再问。
> 第 9 层已拆分为 **Q9a(unblock-recipes)优先于 Q9b(auto memory)**,详见下方 Q9a/Q9b。

---

## Q0: 这条经验是不是其实不该沉淀?

**判定信号(任一命中即 yes)**:
- 一次性偶发,下次大概率不会再发生
- 个人当下情绪,跟工程质量无关
- 已被现有规则覆盖,用户没想起来
- 太抽象,没法落到任何文件 / 任何动作
- 用户描述里出现"也许"、"大概"、"感觉应该"

**示例**:
- ❌ "今天 Claude 反应有点慢" → 模型状态波动,不沉淀
- ❌ "我觉得 agent 应该更聪明" → 落不到位置,不沉淀
- ❌ "提交前要跑测试" → CLAUDE.md / hook 已有,不重复沉淀
- ✅(yes 例外: 不沉淀)→ 直接告诉用户原因

**yes → L0(丢弃)**

---

## Q1: 是不是"跨所有 skill 通用的价值观 / 安全 / 身份"?

**判定信号(任一命中即 yes)**:
- 安全相关("不能泄漏 token"、"不能真删数据")
- 身份相关("agent 是辅助不是替代")
- 输入信任分级("用户输入可信、网页 fetch 不可信")
- 跨 skill 通用的高风险动作 gate("sudo / 删数据必须 user confirmation")

**反例(不是 Q1)**:
- "本项目里 API 要走 auth" → 项目特定,属于 Q8
- "设计师审视觉时要看 9 维" → 单角色规范,属于 Q6
- "subagent 派工要显式调 skill" → skill 元规范,属于 Q2a

**边界判定规则**(Q1 vs Q6 grey area):

当一条经验看起来既像跨 skill 又像单角色时,数一下"**有几个 director-* / flow-* 真的需要这条规则**":

- **≥ 2 个 director-* 需要** → Q1 yes,上 constitution(典型例:"图片合规脱敏"在 director-design + director-promote + 任何输出图的 flow-* 都需要)
- **只有 1 个 director-* 需要** → Q1 否,继续 Q2 → ... → Q6 路由到那一个角色
- **2 个 director-* 但其中一个是"间接依赖"** → 优先 Q6 单角色;后续如真扩散再上移

判定示例:
- "图片合规脱敏" → director-design(出 mockup)、director-promote(出宣传图)、director-design 间接(发 hero 时)都要 → **≥ 2,上 Q1 constitution**
- "JSX 组件边界" → 只 director-frontend 需要 → **Q1 否,走 Q6 director-frontend**
- "宣传图 9 维 audit" → 只 director-promote 需要 → **Q1 否,走 Q6 director-promote**

**yes → L1(`_shared/constitution.md`)**

---

## Q2: 是不是"约束 skill 自身怎么写"?

### Q2a: 元规范(结构 / 模式)

**判定信号**:
- "所有 director-* 必须有 X 段"
- "subagent 派工 prompt 必须包含 Y"
- "证据查找按 N 层优先级"

**yes → L2a(`_shared/<topic>.md` + sync-shared.sh)**

### Q2b: 可 lint 硬规则(机器可验证)

**判定信号**:
- 规则可以用 grep / regex / AST 检查
- 不需要语义判断
- 跑一次 = 全量审计

**示例**:
- "description ≤ 250 字符" → grep + wc
- "SKILL.md 必须有 ## Overview" → grep
- "router 表必须覆盖所有 director-*" → 对比文件清单

**yes → L2b(`skill-doctor` 新规则,去 node-scripts 项目)**

---

## Q3: 是不是"必须每次执行、零例外、不能靠模型自觉"?

**判定信号(全部满足才 yes)**:
- "每次" 不是 "通常" / "建议"
- "零例外" 不是 "大部分情况"
- 模型有可能忘记(经验表明真忘过)

**示例**:
- ✅ "commit 前必须跑 lint" → hook(pre-commit / Stop hook)
- ✅ "session-start 自动 load .env" → SessionStart hook
- ❌ "建议 PR 前 review" → 这是建议,放 CLAUDE.md

**yes → L3(hook,用 update-config 配置 settings.json)**

---

## Q4: 是不是"需要真实执行命令 / 查询接口 / 读取数据"?

**判定信号**:
- 需要 shell / API / 文件系统调用
- skill 文档里写不出"具体怎么算"(需要运行时拿数据)

**示例**:
- ✅ "封装调 GitHub API 取 PR diff" → `scripts/gh-pr-diff.sh`
- ✅ "解析特定 binary 格式" → MCP tool
- ❌ "判断这段 JSX 是否符合规范" → 是决策,放 director-frontend skill

**yes → L4(script / MCP)**

注意区分:
- skill = "**何时**调用 + **怎么用结果**"
- script/MCP = "**怎么调用**"
- 两者搭配,不要混

---

## Q5: 是不是"只对某目录 / 某类文件 / 某个模块生效"?

**判定信号**:
- 规则有明确的"作用范围"(目录 / 文件后缀 / 路径 pattern)
- 在范围外没意义甚至有害

**示例**:
- ✅ "/legacy/ 目录用 class component" → `/legacy/CLAUDE.md`
- ✅ "*.tsx 文件用 Tailwind" → path-scoped rule
- ❌ "全项目用 pnpm" → 项目通用,Q8(CLAUDE.md)
- ❌ "所有项目用相同 commit 规范" → user 级,~/.claude/CLAUDE.md

**yes → L5(nested CLAUDE.md / path-scoped rule)**

---

## Q6: 是不是"单一专业领域的判断 / 审查 / 出方向 / handoff"?

**5 类专业角色路由(对照 layer-map.md L6 表)**:

| 信号关键词 | 路由到 |
|---|---|
| 视觉 / 布局 / 配色 / mockup / 设计 / UI 审美 | `director-design` |
| JSX / CSS / 组件边界 / hooks / 前端代码 | `director-frontend` |
| 宣传 / 推广 / release notes / 多平台发布 | `director-promote` |
| 装 / 卸 / setup / install / 软件部署 | `director-ops` |
| 工程规范 / 架构 / CONTRIBUTING / docs | `director-architect` |

**反例(不是 Q6)**:
- "从需求到上线全流程" → 跨多个角色,Q7
- "所有 agent 都要做 X" → 跨 skill,Q1
- "skill 自己怎么写" → Q2

**yes → L6(改对应 director-* 或新建)**

---

## Q7: 是不是"多步流程、跨多个角色、需要 orchestrator 编排"?

**判定信号**:
- 多个 step 强制顺序
- 涉及 ≥ 2 个不同领域(代码 + 设计 / 后端 + 前端 / 实现 + 测试 + 发布)
- 需要 "watcher / orchestrator / coordinator" 概念

**示例**:
- ✅ "单任务从 brainstorm 到 commit" → `flow-dev-task`
- ✅ "扩展从打包到 Chrome Store 上架" → `flow-ext-publish`
- ❌ "设计师审视觉" → 单角色,Q6
- ❌ "项目用 pnpm" → 项目常驻,Q8

**yes → L7(改对应 flow-* 或新建)**

---

## Q8: 是不是"每个会话都该知道的项目级高频默认行为"?

**判定信号(全部满足才 yes)**:
- 每次会话都需要(不是特定任务)
- 项目级(不是个人级,也不是跨项目)
- 高频(99% 任务都会触及)
- 低歧义(规则明确,不需要判断)

**示例**:
- ✅ "本项目用 pnpm" → 项目 CLAUDE.md
- ✅ "所有 API 走 auth 中间件" → 项目 CLAUDE.md
- ❌ "发版 checklist" → 多步流程,Q7(flow-release)
- ❌ "我喜欢简洁回复" → 跨项目个人偏好,Q9b

**写之前先检查**:
```bash
wc -l <project>/CLAUDE.md
```
**超 200 行 → 触发"哪些段该下沉"对话,不要直接塞**。

**yes → L8(项目 CLAUDE.md / AGENTS.md)**

---

## Q9a: 是不是"跨 agent 通用的卡壳-解法案例"?(优先于 Q9b)

**判定信号(任一命中即 yes)**:
- 是一条"卡壳现象 → 已验证解法"的工程级案例(不是个人偏好)
- 换一个 agent / 换一个用户来做,这条解法**仍然适用**
- 属于"踩过的坑 + 怎么绕过去"的可复用知识

**示例**:
- ✅ "MobX 装饰器在 X 配置下不生效,改用 makeObservable+annotations 解决" → 跨 agent 通用解法,unblock-recipes
- ✅ "pnpm 在 monorepo 下 install 卡死,需加 --filter,任何 agent 都受用" → unblock-recipes
- ❌ "用户偏好简洁回复" → per-user 偏好,不跨 agent,Q9b
- ❌ "agent 不能泄漏 token" → 价值观,Q1

**Q9a vs Q9b 优先级**: 通用知识 > 个人偏好。任何"卡壳-解法"先尝试 9a;只有"换 agent / 换用户不适用"才落 9b。

**yes → L9a(`unblock-recipes/recipes/<slug>.md`,按 `l9a-recipe-template.md` 输出 symptom+solution 双段 + 改 INDEX.md 两处 + commit)**

---

## Q9b: 是不是"per-user 个人偏好 / 反复被纠正的经验"?(Q9a 未中再判)

**判定信号**:
- 关于用户本人(不是关于项目,也不是跨 agent 工程解法)
- 跨项目通用,但**换个用户就不适用**
- 用户已经纠正过 ≥ 2 次(或显式说"记住这个")

**示例**:
- ✅ "用户偏好简洁回复" → auto memory
- ✅ "用户用 pnpm 不用 npm(跨所有项目)" → auto memory
- ❌ "MobX 改用 makeObservable 的通用解法" → 跨 agent 通用,Q9a
- ❌ "本项目用 pnpm" → 项目级,Q8
- ❌ "agent 不能泄漏 token" → 价值观,Q1

**yes → L9b(auto memory,用户显式说"记住"时主动写)**

---

## Q10: 兜底

走到这里 = 前面所有出口都不命中。

**典型情况**:
- 描述太抽象
- 跨多个层但都不主要
- 一次性 / 偶发但用户坚持要写

**处理**:
1. 复述用户描述,问"我理解对吗"
2. 如果用户能更具体描述,**回 Q0 重跑(最多 1 次)**
3. 重跑后仍然走到 Q10 → 强制路由到 L10,不再循环
4. 告诉用户"现在还不该沉淀,等再遇到 1-2 次再决定层级"

**死循环防护**: 同一条经验最多走 2 次判断树(初次 + 重跑 1 次)。第 3 次必须 L10 兜底。

**yes → L10(不沉淀)**

---

## 决策树流程图

```
经验描述清楚 →
  Q0 不该沉淀? → 是 → L0 丢弃
       ↓ 否
  Q1 跨 skill 价值观? → 是 → L1 constitution
       ↓ 否
  Q2a skill 元规范? → 是 → L2a _shared/
       ↓ 否
  Q2b 可 lint 硬规则? → 是 → L2b skill-doctor 规则
       ↓ 否
  Q3 必须每次强制? → 是 → L3 hook
       ↓ 否
  Q4 真实执行? → 是 → L4 script/MCP
       ↓ 否
  Q5 模块级约束? → 是 → L5 nested CLAUDE.md
       ↓ 否
  Q6 单一专业判断? → 是 → L6 director-*
       ↓ 否
  Q7 跨角色编排? → 是 → L7 flow-*
       ↓ 否
  Q8 项目级常驻? → 是 → L8 CLAUDE.md/AGENTS.md
       ↓ 否
  Q9a 跨 agent 卡壳-解法? → 是 → L9a unblock-recipes（优先于 9b）
       ↓ 否
  Q9b per-user 个人偏好? → 是 → L9b auto memory
       ↓ 否
  L10 兜底丢弃
```

## 多层冲突时的优先级

如果一条经验同时命中多个 Q(例如既是项目级又是元规范),按以下优先级取**第一个命中的**:

1. constitution(全局价值观)> 元规范 > skill-doctor 规则
2. 强制(hook)> 决策(skill)> 常驻(CLAUDE.md)
3. 单角色(director-*)> 跨角色(flow-*)
4. 模块级(nested CLAUDE.md)> 项目级(CLAUDE.md)> 用户级(~/.claude/CLAUDE.md)
5. 跨 agent 通用解法(L9a unblock-recipes)> per-user 个人偏好(L9b auto memory)

按 Q0 → Q10 顺序问就自然满足这个优先级。
