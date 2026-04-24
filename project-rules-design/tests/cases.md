# Project Rules Design Test Cases

## Case 1: 从零设计规范体系

- 输入: “帮我设计一个前后端项目的规范文档结构。”
- 预期触发: `project-rules-design`
- 预期行为: 先定义规则领域，再设计 `CONTRIBUTING + docs/<domain>/index.md + 子文件` 结构。
- 失败信号: 直接给几个零散文件名，不先定义领域边界。

## Case 2: 重构已有混乱规则

- 输入: “当前项目的 RULE、ai、docs 很乱，帮我重构一下规范结构。”
- 预期触发: `project-rules-design`
- 预期行为: 先盘点入口与正文，再判断哪些内容放错层，再给出内容级重构方案。
- 失败信号: 只做旧文件到新文件的机械映射。

## Case 3: 判断规则归属

- 输入: “这个路由注册规则到底属于 architecture 还是 coding？”
- 预期行为: 根据职责判断其属于结构与落位规则，而不是编码写法规则。
- 失败信号: 只按旧文件名或习惯随意归类。

## Case 4: 入口文件边界

- 输入: “`CONTRIBUTING.md` 里应该写什么？”
- 预期行为: 明确它只做总入口、优先级和任务路由，不承担大量正文规则。
- 失败信号: 把具体编码规范和 UI 细则直接堆进 `CONTRIBUTING.md`。

## Case 5: 目录化与 index

- 输入: “`docs` 下要不要分目录，并用 `index.md` 做入口？”
- 预期行为: 能判断目录化的收益，并强调 `index.md` 只做入口，不做大杂烩正文。
- 失败信号: 只说“可以”，但不给入口与正文的边界。

## Case 6: 反例触发

- 输入: “帮我写一个登录页表单组件。”
- 预期行为: 不应优先触发本 skill，这更像 UI 或功能实现任务。
- 失败信号: 把普通功能实现强行拉到规则架构设计流程中。

## Case 7: 要求真实案例

- 输入: “给我一个真实项目的规范重构案例。”
- 预期行为: 读取 `references/` 中最相关的案例，说明重构前后结构和关键重构动作。
- 失败信号: 只重复抽象原则，不给任何真实案例。

## Case 8: 要求规则归类示例

- 输入: “拿一个真实项目说明哪些规则属于 architecture、coding、ui、ai-guide。”
- 预期行为: 使用真实案例说明各规则域的职责边界和常见误放。
- 失败信号: 只给抽象定义，没有真实规则例子。

## Case 9: 通用资产层边界

- 输入: “`components`、`hooks`、`lib` 这类目录是不是应该被当作更稳定的通用资产层来定义规范？”
- 预期行为: 能识别这是规则架构问题，并建议在 `architecture` / `coding` 中明确资产层边界和注释要求。
- 失败信号: 把这类问题仅当成普通代码风格建议，不上升为规则层设计。

## Case 10: 组件分类收敛

- 输入: “组件在规范里是不是只分 `primitive` 和 `composite` 就够了？”
- 预期行为: 能判断这属于通用资产层组件分类设计，并把它放入规则模型而不是只给口头建议。
- 失败信号: 只讨论命名，不说明它应该落在哪类规范文件里。

## Case 11: coding 总纲纯度

- 输入: “`coding/rules.md` 里现在有很多杂项，它是不是不够像总纲？”
- 预期行为: 能识别这是规则架构问题，并建议把总纲收窄为原则与顶层约束，把小规则下沉到对应专题文件。
- 失败信号: 只说内容太多，却不给出哪些该下沉、为什么下沉。

## Case 12: completion 边界

- 输入: “一些小规则是不是都塞进 `completion` 就行了？”
- 预期行为: 能判断 `completion` 只适合项目级完成与收尾检查，不应吞掉所有实现期规则。
- 失败信号: 把实现期数据流、建模、命名规则也全部归到 `completion`。

## Case 13: 领域目录缺 rules.md

- 输入: 项目 `docs/coding/` 下只有 `index.md` 和几个专题文件（`naming.md`、`data-flow.md`），没有 `rules.md`。
- 预期行为: 指出缺失规则总纲——读者读完 `index.md` 只看到文件列表，没有地方找到本域的基本规则 / MUST / SHOULD；建议新增 `coding/rules.md` 承载总纲原则。
- 失败信号: 只说"文件不少已经够了"，或把总纲正文塞回 `index.md`。

## Case 14: 领域目录缺 index.md

- 输入: 项目 `docs/ui/` 下有 `rules.md`、`components.md`、`tokens.md`，但没有 `index.md`。
- 预期行为: 指出缺失导航——多文件时读者不知道从哪个开始读；建议新增 `ui/index.md` 只列子文件职责，指向 `rules.md`。
- 失败信号: 接受"反正就几个文件自己扫一下"的说法。

## Case 15: index 长成大杂烩

- 输入: 项目 `docs/architecture/index.md` 里既列了子文件目录，又直接展开了模块拆分原则、命名规范、10 多条 MUST。
- 预期行为: 识别 index 层被当总纲用，建议把正文迁移到 `rules.md`，让 `index.md` 只做导航。
- 失败信号: 只是说内容多，不指出是层级职责被破坏。

## Case 16: rules.md 塞命令与验证步骤

- 输入: 项目 `docs/coding/rules.md` 里除了原则，还写了 `pnpm test`、`pnpm lint` 的交付检查项和 `.tmp/` 目录清理命令。
- 预期行为: 识别总纲被当成杂项筐，建议把命令类规则下沉到 `completion.md` 或独立专题文件。
- 失败信号: 认为总纲可以包含一切"重要"内容。

## Case 17: 栈未被任何规则覆盖

- 输入: 项目 `package.json` 里有 `next`、`tailwindcss`，但 `docs/coding/rules.md` 对 Server Component 边界、数据获取位置、缓存策略没有任何约束；`docs/ui/` 也不提 `cn` / `cva` / variant 组织。
- 预期行为: 读取 `references/stack-checklist.md`，对照 `react/next.js` 和 `tailwind/shadcn` 两节，指出当前规则体系未覆盖这些关键点；建议在 `coding/rules.md` 或新增专题文件中显式覆盖。
- 失败信号: 只看现有规则文档的自洽性，不对照项目实际在用的栈。

## Case 18: 规则已覆盖栈——不要误判为缺口

- 输入: 项目用 Next.js，`docs/coding/rules.md` 已明确定义 Server/Client Component 标记方式、`fetch` 的缓存策略、`'use client'` 边界；`docs/ui/components.md` 已约束 `cn` / `cva` 用法。
- 预期行为: 对照 `stack-checklist.md` 确认相关关键点已被覆盖，不追加虚假建议；如有不在 checklist 中的内容也应如实说明。
- 失败信号: 机械按 checklist 生成一堆"建议新增"条目，即使项目已有对应规则。
