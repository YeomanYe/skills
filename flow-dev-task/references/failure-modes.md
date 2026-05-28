# Failure Modes — Red Flags / Rationalizations / Common Failure Modes

> 本文件汇总 flow-dev-task 的反模式清单：Red Flags（必须停下的硬条件）+ Rationalizations（常见自我合理化说辞 → 现实拆穿）。
> SKILL.md 主体仅保留指向本文件的引用 + 核心 4-6 条 trip-wire；详尽清单查这里。

## Red Flags — STOP

命中任一必须**停下并返回上一阶段**，不允许合理化继续：

- 同一轮追问超过 3 个问题
- 未做 Context Harvest 就开始提问
- 跳过 systematic-debugging 直接改 bug
- verification-before-completion 未跑就进 delivery-gate
- delivery-gate 返回 must-fix 但直接进 commit
- 以"时间紧"或"这块不好测"为由跳 TDD
- "我觉得修好了" 就宣告完成
- 派 Codex 但没写 SPEC（凭一句话指令直接派）
- Codex 报告 `spec_compliance != "full"` 但直接进 Stage 6
- Codex 改了 SPEC 之外的文件没 review 就接受
- 信 Codex 自报的 `tests_passed: true`，没自己跑一遍验证
- 派 Codex 时把 auth / 支付 / 加密代码也派出去
- 永久性错误（额度耗尽 / 认证失效 / 挂起超时）走返工循环而不立即退回 Claude
- Codex 失败但不告知用户原因，默默退回

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "这块不好写测试，跳 TDD 吧" | 不在 Whitelist 就不能跳。白名单是穷举的 |
| "计划太简单就不走 writing-plans 了" | 跳 plan 看文件数规则，不看感觉 |
| "bug 不复杂，跳 systematic-debugging" | 修复链不可跳 debug，skill 原文硬门槛 |
| "delivery-gate 过了，不用再 verify" | 顺序是 verify → delivery-gate，互不替代 |
| "分支就在 main，不用 finishing" | 要检查跳过条件是否真满足（worktree/分支名） |
| "先问一下用户用哪种模式吧" | 命中推断规则就直接走，禁止回问 |
| "改动看起来小，跳 TDD 直接写" | 小改动不在白名单。白名单只认 4 种 |
| "我理解的用户意图应该没错，直接写代码" | 新功能链至少一次 Context Harvest + brainstorm（除非命中跳过信号）|
| "派 Codex 后我懒得 review，反正 Codex 说测试过了" | review 是 Codex 派工的 50% 价值，跳了就变 AI slop 引入项目 |
| "改动只有 20 行，但派 Codex 顺手吧" | < 30 行不该派，编排开销 > 节省，直接 Claude 写更快 |
| "高风险代码 Codex 也能写，反正我会 review" | auth / 支付 / 加密必须 Claude 自写，护城河在判断力不在 review |
| "Codex 改了 SPEC 之外的文件，但好像也对" | 严禁。必须返工，否则失控蔓延 |
| "Codex 第 2 次返工还是不过，再试一次吧" | ≥ 3 次还不过 = SPEC 有问题或任务不该派，退回 Claude 自写 |
