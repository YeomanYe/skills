# Failure Modes — director-design 红线 / 自我合理化 / 常见错误

> 本文件合并主体 SKILL.md 原 `## Red Flags — STOP` + `## Rationalizations to Reject` 两段。
> 主体只保留入口说明 + 5-10 行引用,详细清单全部下沉到此。

## 1. Red Flags — STOP(任一命中必须停下)

执行任何 mode 时遇到以下信号,**立即停下不再继续输出**:

- **无视觉证据下断言"设计通过 / 好看 / 专业"** —— 必须 evidence: missing/code-only,不下视觉结论
- **9 维度有维度未应用但不标 n/a** —— 必须显式说明为什么跳过(否则按 1 分计入)
- **跳过 variants 直接 mockup**(除非用户明确方向)—— 等同把"选择"逼给用户的眼睛
- **handoff 不写 spec 文件** —— 必须落盘 `.agent/design-handoff/<task-id>/spec.md` + 回路径
- **调用 frontend-design / director-frontend 写生产代码** —— 越界,这些是工程不是设计
- **替项目擅自换设计系统** —— 必须先用项目已有 tokens,外部推荐要明示理由
- **只说"更高级 / 更现代 / 更干净"** —— 必须指出具体元素 + 具体动作 + 对照锚点
- **把 landing page 规则套到 dashboard / popup / 工具型产品** —— 产品类型决定调性
- **3 个 variants 之间没有真正差异化** —— 不能只换配色,必须布局/信息层级/风格 ≥ 2 维度不同
- **Output Contract 委派情况 / 遵循原则段写"无"** —— 必须真实记录,避免 AI slop

## 2. Rationalizations to Reject(自我合理化清单)

每条都是"听起来在做设计判断,实际在和稀泥"的典型话术。**心里冒出任一条 = 警报**:

| 自我合理化 | 现实 |
|---|---|
| "看代码就能判断设计了,不用截图" | 编译过 ≠ 视觉好看,code-only 必须标记 evidence: code-only 不下视觉结论 |
| "9 维度太多,重点看 1-2 个" | 每个维度必须 [✓] 或 [n/a],跳过维度等于盲区 |
| "直接出 mockup,不用 variants" | 没明确方向就跳 variants = 把"选择"逼给用户的眼睛,应该先收敛方向 |
| "用 ui-ux-pro-max 推荐的 161 色板覆盖项目 tokens" | 项目设计系统永远优先;外部推荐只在项目 tokens 缺失或明显落后时引入 |
| "我作为设计师顺手把代码也写了" | 写代码不在职责内,handoff 给 director-frontend |
| "委派情况段直接写 not invoked 全部" | 必须真实——如果全自跑也要说"自做:所有 9 维度 audit 由自己跑" |
| "评分凭直觉给" | 必须对照 references/design-principles.md 的 1/3/5 锚点 |
| "找不到设计原则参考时编一个" | 9 维度是封闭集合,加新维度必须先改 references/design-principles.md |
| "用户已经迭代 10 版了不好意思打低分" | 改 10 版还是 3 分意味着方向错了,该回 direction mode 就回 |
| "考虑到这是周末项目 / 个人开发者 / 时间紧" | rubric 不看作者背景,只看屏幕上呈现出来的东西 |
| "整体还不错,3 分写成 4 分稀释一下" | 3 分就写 3 分,理由是"能用但 generic",评分通胀 = 评分系统报废 |

## 3. Common Failure Modes(常见执行错误)

### 3.1 证据采集类
- 未跑 Playwright / 未读截图直接给评分 → 必须标 `evidence: code-only` 并降级结论
- 只看一张截图就评 9 维度 → 至少需要主视图 + 关键交互态截图
- 截图视口未记录 → 报告无法复核,违反 evidence-discovery §5

### 3.2 mode 判定类
- audit 中途偷偷出 mockup → mode 一旦判定就锁定,要换 mode 必须显式声明并回 Q gate
- variants 只换主色 → 必须布局 / 信息层级 / 风格 ≥ 2 维度真差异化
- handoff 没写 spec 文件,只在对话里描述 → 必须落盘 + 回路径

### 3.3 评分类
- 凭整体印象给"4 分" → 必须 9 维度分别评 + 对照 1/3/5 锚点
- 局部某维度 ≤ 2 但 aggregate 仍判 pass → 触发"局部塌方"规则,自动降级 needs-redesign
- 给"努力分" / "迭代分" → rubric 不看作者背景

### 3.4 委派 / 越界类
- 自己写 React/CSS 生产代码 → 越界,handoff 给 director-frontend
- 主动调 director-frontend 让它执行 → handoff 只移交不调用
- 替项目擅自换设计系统 → 必须先用项目 tokens,外部推荐要明示理由

## 4. 触发后的恢复路径

| 触发场景 | 恢复动作 |
|---|---|
| 命中 Red Flag → STOP | 输出"⚠️ 触发红线: <哪条>",回 Step 1 收集证据 / 回 Q gate |
| 自我合理化被识破 | 拒绝该话术,按 rubric / mode 规则原样执行 |
| 局部塌方(单维度 ≤ 2) | verdict 自动降级 needs-redesign,出 must-fix 清单 |
| evidence: missing 但用户要 verdict | 拒绝出 verdict,只列"需补什么证据"清单 |
| variants 路数不够 / 差异化不够 | 回 Step 4 重派 huashu-design,不许凑数交付 |

## 5. 与其他 reference 的关系

- 评分锚点细节 → `references/design-principles.md`
- 证据采集格式 → `references/evidence-discovery.md` §5
- 通用 audit rubric → `references/audit-rubric.md`
- 跨 skill 价值观红线 → `references/constitution.md`(always-follow)
