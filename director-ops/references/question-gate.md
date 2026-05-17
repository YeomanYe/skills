# Question Gate(Step 0)— director-* 通用开干前澄清规范

> 借鉴 ACBDQC Q + `flow-dev-task` Question Budget。
> 适用所有 director-* skill 的 Required Workflow Step 0。

## 1. 触发时机

在以下两件事**都完成后**、进入 mode-specific 执行前:
- mode 已判定(从 5 个/2 个 mode 表中选定)
- Step 1 通用前置已完成(项目规范探测 / 证据收集 / 知识库查询)

**禁止**在没探测就先问问题(那会问已经能从 Step 1 拿到答案的事)。

## 2. 决策树

```
Step 1 完成后
  ↓
当前任务/材料是否有关键歧义(无法从 context 推断且会影响下一步执行)?
  ├── No → 直接进入执行,不要为"确认一下"而问
  └── Yes ↓
        当前歧义点是否 ≤ 3 个?
          ├── Yes → 一次性列出,每个带建议默认值
          └── No  → 取前 3 个关键的,其余按默认值跑(在 Output Contract 标注)
        ↓
        用户回复
          ├── 明确答 → 按答案执行
          ├── 模糊("随便/按你的来/直接做") → 取默认,不再问
          └── 拒绝继续 → 退出 skill,不强求
```

## 3. 硬约束

| 约束 | 说明 |
|---|---|
| **一轮**(必须) | Q gate 只一轮。第二轮追问 = Red Flag,违反 ACBDQC + flow-dev-task 设计 |
| **≤ 3 个问题** | 超 3 个说明 mode/Step 1 不够,**回去补 Step 1**,不要靠问用户补 |
| **每个问题带默认值** | 默认值应是当前推断的最优解;用户模糊回复时取默认 |
| **不为"确认一下"问** | 没歧义就执行;问"是不是真要做 X"是 anti-pattern |
| **不问已知** | Upstream Handoff Payload 已传的字段、Step 1 已探测的事实,**禁止再问** |

## 4. 应该问 vs 不应该问(示例)

### director-design audit

**应该问**(关键决策 + 多解):
- "audit 范围只看 hero 还是全屏?(默认: 全屏)"
- "目标设备视口是?(默认: 桌面 1440×900 + 移动 375×812)"

**不应该问**:
- "需要我审一下吗?"(用户已经说审,问就是冗余)
- "你想用 huashu-design 出方向吗?"(应该自己按 mode 判断)

### director-frontend implement

**应该问**:
- "本组件用项目现有 cn 工具还是新加 cva?(默认: 用 cn,与项目其他组件一致)"
- "组件层级 primitive 还是 business?(默认: business,因为含价格逻辑)"

**不应该问**:
- "用 TypeScript 吗?"(项目已有 tsconfig.json,Step 1 应已探测)
- "组件名叫什么?"(用户已经在原话给了 / 应从 boundaries 推断)

### director-promote dispatch

**应该问**:
- "发哪些平台?(默认推荐: twitter + v2ex,你的项目偏开发者社区)"
- "twitter 配图用 hero-poster.png 还是 marquee.png?(默认: hero-poster.png,首选项)"

**不应该问**:
- "你想发 twitter 吗?"(用户已经说发,该问"哪些平台"而非"是否")
- "v2ex 节点选哪个?"(应按项目类型推断 `create` / `share` 默认值,再问)

### director-ops install

**应该问**:
- "用 brew 还是 pip 还是 cargo?(本机 brew 可用 + 该工具 brew 源最新,默认: brew)"
- "需要加到 PATH 吗?(默认: 是,加到 ~/.zshrc)"

**不应该问**:
- "确认要装 X 吗?"(用户已说装,问就是冗余)
- "需要 sudo 吗?"(应按命令前缀自动判断 + 暴露给用户看)

## 5. 输出 Output Contract 时的 Q gate 段

每个 director-* 的 Output Contract 必须含:

```md
### Question Gate
- 问题数: 0 | 1 | 2 | 3
- 问题清单:
  - Q1: ...(默认值: ...)
  - Q2: ...
- 用户回复: <quote 或 "用默认值">
- 影响的执行决策: <list>
```

`问题数 = 0` 时仍要写出"无歧义,直接执行",证明走过 Q gate(不是漏跑)。

## 6. Red Flags(Q gate 反模式)

- 第二轮追问(只允许一轮)
- 问已经在 Upstream Handoff Payload 给的字段
- 问 Step 1 已探测的事实
- "为了更准确,我再问一下..."(没有歧义就别问)
- 问超过 3 个问题(说明 mode/Step 1 不够)
- 问"是否要执行"(用户已触发 skill = 已要执行)

违反任一 = Red Flag,跳到 Rationalizations to Reject 段评估是否要降级 verdict。
