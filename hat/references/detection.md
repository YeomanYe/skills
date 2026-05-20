# 任务类型 → hat 自动路由

> 按优先级从高到低匹配,第一个命中即戴。

---

## 优先级 1: 用户显式指定(最高,直接生效)

用户消息含以下任一关键词 → 立即戴对应 hat,**不走探测**:

| 用户关键词 | hat |
|---|---|
| "换严格点" / "戴上严" / "/hat strict" / "严谨点" / "strict mode" | `严` |
| "发散一下" / "戴上散" / "/hat explore" / "想几个方案" / "explore mode" | `散` |
| "收敛点" / "戴上收" / "/hat focus" / "只挑致命" / "focus mode" | `收` |
| "正常点" / "脱了" / "/hat lean" / "默认" / "lean mode" | `快` |
| "挑刺" / "戴上挑" / "/hat critic" / "review 模式" / "critic mode" | `挑` |
| "教我" / "戴上教" / "/hat teach" / "解释下" / "teach mode" | `教` |
| "帮我想想" / "戴上问" / "/hat ask" / "我卡壳了" / "ask mode" | `问` |

---

## 优先级 2: 任务关键词探测(prompt 含以下)

### 戴 `收` focus(MVP / 决策 / 砍需求)

**强信号**(任一命中):
- "MVP"
- "选型"
- "决定要不要做"
- "砍需求"
- "最小可行"
- "minimum viable"
- "v0"
- "scope down"

**弱信号**(多个组合):
- "我们需要决定..."
- "时间紧"
- "先上线再说"

### 戴 `散` explore(发散 / 探索 / 风格)

**强信号**:
- "想几个方案"
- "有什么思路"
- "brainstorm"
- "风格"
- "方向"
- "mockup"
- "什么样的好"
- "几种选择"

**弱信号**:
- "怎么设计"
- "可能性"

### 戴 `严` strict(测试 / 走查 / 上线前)

**强信号**:
- "测试"
- "走查"
- "上线前"
- "边界"
- "安全审"
- "验证"
- "可靠"
- "production-ready"
- "release check"

**弱信号**:
- "确保..."
- "万一..."
- "如果出错..."

### 戴 `挑` critic(review / audit)

**强信号**:
- "review"
- "PR 审"
- "挑刺"
- "评一下"
- "audit"
- "看看有什么问题"
- "找问题"
- "code review"

### 戴 `教` teach(学习 / 不熟)

**强信号**:
- "教我"
- "我不熟悉"
- "解释下"
- "什么意思"
- "怎么理解"
- "我第一次..."
- "新手"

### 戴 `问` ask(卡壳 / 拿不准)

**强信号**:
- "我不确定"
- "卡住了"
- "帮我想想"
- "怎么办"
- "我应该..."
- "你觉得呢"(让 agent 决定 → `问` 反问回去)

---

## 优先级 3: 调用的 skill 推断

如果主对话调用了以下 skill,默认推荐对应 hat:

| 调用 skill | 推荐 hat |
|---|---|
| `superpowers:brainstorming` | `散` |
| `superpowers:verification-before-completion` | `严` |
| `superpowers:requesting-code-review` / `superpowers:receiving-code-review` | `挑` |
| `superpowers:systematic-debugging` | `严`(找 bug 要严)或 `教`(学新栈 bug) |
| `flow-codex-goal` Phase 0(GOAL.md 起草) | `收`(砍需求) |
| `flow-codex-goal` Phase 0(extra_reviewers 选择) | `散`(多 reviewer 候选) |
| `director-design` audit / `director-frontend` audit | `挑` |
| `director-design` variants / `director-design` direction | `散` |
| `director-promote` audit | `挑` |
| `delivery-gate` | `严` |
| `flow-skill-dev` Step 1 classify | `问`(让用户讲清楚) |
| `experience-summary` | `快`(决策本身要快) |

如果同一 skill 在不同 mode/step 有不同 hat 倾向,以最近一次显式 mode 为准。

---

## 优先级 4: 上下文推断(最近 3 轮对话)

- 用户最近一直在选型 / 讨论 trade-off → `收`
- 用户最近一直在 prototype / 试不同方案 → `散`
- 用户最近一直在写测试 / 验证 / 修 corner case → `严`
- 用户最近一直在 review 别人代码 → `挑`
- 用户最近问了多个"为什么 X" / "什么意思" → `教`
- 用户最近反复说"不知道" / "拿不准" → `问`

---

## 优先级 5: 兜底

**全部不命中 → `快` lean**(默认最常用)。

---

## 切换信号(任务中途)

任务进行中,以下信号触发**切换提示**(不一定真切,留给主对话判断):

- 用户说"不对,这不是我要的" → 可能任务类型判错,考虑换 hat
- 用户说"再多给几个" → `散`(原本可能是 `快` / `收`)
- 用户说"太多了,挑最重要的" → `收`(原本可能是 `散`)
- 用户说"细一点" → `严`(原本可能是 `快`)
- 用户说"快点别想太多" → `快`(原本可能是 `严`)

---

## 反向规则: 何时**不重新探测**(保持当前 hat)

以下场景**保持当前 hat 不变**(不重新走 detection),且**告知行可豁免**(详见 SKILL.md Output Contract 豁免规则):

- prompt < 5 字("好" / "谢谢" / "再来一个")
- 纯执行命令("跑下测试" / "git status")
- 单次问答不涉及决策("这个函数干啥的")
- 用户已经在一个 hat 里,新 prompt 没明显切换信号 → 保持当前

**注意**: "保持当前 hat" ≠ "不戴 hat"。hat 仍激活,只是不重新探测 + 可跳过告知行。

## Self-Reference: hat skill 自己用什么 hat?

- **默认**: `快` lean — 决策本身要快,7 个 persona 选 1 个不该分析半天
- **用户问"我该戴哪顶?"**: 切到 `问` ask — 反问 3 个问题帮用户判断
- **用户想新增第 8 顶**: 切到 `严` strict — 走 flow-skill-dev,严格 review 必要性

---

## 多信号冲突时

按优先级 1 > 2 > 3 > 4 > 5。

如果同一优先级内多个 hat 都命中:
- `收` vs `散` 冲突 → 戴 `问`(让用户澄清要收还是散)
- `严` vs `快` 冲突 → 戴 `严`(谨慎为先)
- `挑` vs `教` 冲突 → 看是审已有代码(`挑`)还是讲新概念(`教`)
- 其他 → 默认 `快`
