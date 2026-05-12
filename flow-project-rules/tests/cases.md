# Test Cases — orchestrating-project-rules

本文件列出的用例同时服务 behavior-testing 与 integration-testing。

## 正例触发

### T1-positive-audit
用户消息：
> 帮我看下当前项目的规范合不合理，不合理的话给一套建议。

期望：进入 orchestrating-project-rules，按链路走到 Step 6 暂停。

### T2-positive-new-rules
用户消息：
> 这个项目现在完全没有 CONTRIBUTING 或 docs 规则，能不能帮我整一套？

期望：进入本 skill，Step 2 识别 stack，Step 3 动态匹配 skill，Step 6 输出「从 0 建立」的骨架。

### T3-positive-reference-remote
用户消息：
> 参考 https://github.com/foo/bar 的规范结构，把当前项目的规范也做一次对齐。

期望：进入本 skill，Step 1 记下远程 URL，后续 clone 成功或如实降级，Step 5 显式对照。

### T4-positive-reference-local
用户消息：
> 我在本地 `/tmp/sibling-project` 有一个做得比较好的规范，能不能参考着改一下我们这个？

期望：进入本 skill，参考项目路径从本地读取，不触发 git clone。

## 反例触发（应当 **不** 触发）

### T5-negative-single-rule-typo
用户消息：
> 把 CONTRIBUTING.md 里「架构」两个字改成「目录结构」。

期望：不触发本 skill，属于 minor-update。

### T6-negative-pr-review
用户消息：
> 帮我 review 一下这个 PR 里的 React hook 写法。

期望：不触发本 skill，应该进入代码审查 / JSX UI skill。

### T7-negative-new-skill
用户消息：
> 我想写一个新的 agent skill，帮我搭个骨架。

期望：不触发本 skill，应该进入 orchestrating-skill-development / skill-creator。

### T8-negative-code-impl
用户消息：
> 帮我实现一下用户登录的接口联调。

期望：不触发本 skill。

## 主流程成功

### M1-main-flow
输入：一个典型前端项目，已有 CONTRIBUTING + docs/，技术栈是 React/Next/Tailwind。

验证：
- Step 2 能识别 `react`, `next`, `tailwindcss`, `typescript`
- Step 3 至少把 `project-rules-design` 纳入，加上 `vercel-react-best-practices` 或等价 skill
- Step 4 列出具体文件清单（不止「docs/ 有内容」这种粗颗粒）
- Step 6 输出完整「改进计划」结构，并显式询问「以上方案是否可以落地」
- 在用户未回复前，**绝对没有任何文件被写**

### M2-from-zero
输入：一个只有 `package.json` + `src/` 的项目，没有任何规范入口。

验证：
- Step 6 输出一份最小可用骨架（CONTRIBUTING + docs/<domain>/index.md + 至少 coding/ui/architecture 三个域）
- 不直接复制 shadcn-admin 的文件名（Fallback 里不许强行套用）

## 护栏 / 负例

### G1-no-write-before-confirm
输入：执行到 Step 6 后用户回复「嗯」「ok 吧」「随便」。

验证：
- 这些含糊回应 **不算确认**
- skill 必须再次澄清，或保持等待，而不是直接动文件

### G2-partial-consent
输入：用户回复「前两条同意，其它先不动」。

验证：
- 只落地前两条
- 重写一份只包含前两条的计划写入最终报告
- 未执行项列入「用户否决」或「未采纳」

### G3-missing-input
输入：没有项目根 / 没有 package.json 的空目录。

验证：
- 进入 Step 1 的 Fallback，向用户索要路径
- 不自己编造 stack 列表

### G4-ref-clone-fail
输入：用户给的远程 URL 实际无法 clone（假 URL 或网络不通）。

验证：
- 如实告知失败
- 自动降级到「只评估本项目」，继续后续链路
- 最终报告中注明「参考项目：clone 失败，已降级」

## 集成 / Handoff

### I1-downstream-project-rules-design
验证：Step 5 真的把评估职责交给 `project-rules-design`，而不是在本 skill 里自己写一套结构判断。

### I2-downstream-best-practice
验证：Step 5 对每个识别到的 stack skill，都让该 skill 在自己职责范围内审视规范，不越权也不省略。

### I3-no-redundant-question
验证：上游已经在用户消息里给出了 stack / 参考项目路径，本 skill 不应再追问这些已知信息（orchestrating-skill-development 规则）。

### I4-commit-handoff
验证：落地完成后可建议（非强制）`clean-commit`；若用户明确说「顺便提交」，本 skill 不替代它自己提交，而是 handoff。
