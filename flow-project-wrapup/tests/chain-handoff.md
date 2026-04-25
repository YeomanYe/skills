# 链路测试用例

验证 `flow-project-wrapup → huashu-design → frontend-design` 的衔接是否完整,以及 Step 0 探测结果在下游阶段是否被正确继承。

## C1. 正常流转(浏览器扩展 → 落地页)

输入:

> 我的浏览器扩展(Plasmo + React + Tailwind)主要功能写完了,做完整收尾:同步设计 tokens 到设计系统文档、出 README、做落地页。

预期:

- 入口触发 `flow-project-wrapup`
- Step 0 输出 `Project type: browser-extension`、`Frontend stack: react + tailwind + plasmo`、`Already a website: no`
- Step 1 找到 `tailwind.config.*` 与 `styles/globals.css`,把代码里实际使用的 token 同步到设计系统文档
- Step 3 进入,**调用 `huashu-design`** 时上下文里**已含**项目类型/前端栈/调性,**不向用户重复追问**
- `huashu-design` 返回 3 套方向 → 用户挑选 → `frontend-design` 用 `react + vite + tailwind`(对齐项目栈,不是回退栈)
- 落地页放在 `website/` 子目录,不污染主扩展构建
- 收尾报告 5 节齐全

失败信号:

- Step 3 重复问"这是什么项目""用什么技术栈"
- frontend-design 用了 vite+pnpm+react 但忽略了项目自带的 tailwind
- huashu-design 只拿到 1 套方向就接 frontend-design

## C2. 反例流转(项目本身就是网站)

输入:

> 我的 Astro 落地页站要发布了,做收尾。

预期:

- 入口可触发 `flow-project-wrapup`(用户说的是"做收尾"且涉及多件)
- Step 0 输出 `Already a website: yes`
- Step 3 显式跳过,跳过原因为"项目自身即网站"
- 不调用 `huashu-design` / `frontend-design`
- 收尾报告 Step 3 节存在,内容是跳过说明

失败信号:

- 仍然给 Astro 站点再造一份独立"落地页"
- 跳过但没在报告里写跳过段落

## C3. 字段保真(Step 0 探测结果在 Step 3 不丢失)

输入:

> 我的 Rust CLI 主要功能 OK 了,做收尾,要一份 README 和落地页。

预期:

- Step 0 输出 `Project type: cli`、`Frontend stack: none`
- Step 3 调用 `frontend-design` 时,技术栈契约触发**回退路径**:`vite + pnpm + react`
- 收尾报告中明确记录"项目无前端栈,落地页采用 vite+pnpm+react 默认栈"

失败信号:

- 上游识别为无前端栈,下游却问用户"用什么栈"
- 落地页用了 React + 某种生态混搭(如 next.js 全栈),违反"无栈回退 vite+pnpm+react"契约
- 报告里没记录回退原因

## C4. 路线图来源贯穿

输入:

> 项目主体差不多了,做收尾。我有一份 progress.md 在根目录记着 TODO,落地页里 roadmap 段就用它。

预期:

- Step 0 标 `Roadmap source: progress.md`
- Step 3.1 收集落地页输入时,roadmap 显式来源于 progress.md(而非临时编造)
- frontend-design 拿到的内容契约里 Roadmap 段填充的是 progress.md 真实条目
- 收尾报告里 Step 3 落地页区注明 roadmap 来源

失败信号:

- 落地页 roadmap 段填了项目里没有的内容(凭印象编)
- 落地页 roadmap 段做成"暂无路线图"(数据源在,却没用)

## C5. 用户跨阶段补充上下文,不应回到 Step 0

输入:

启动后用户说"我的 Vue 项目主功能完了,做收尾。"
进到 Step 1 时用户补一句"对了,设计 tokens 在 src/styles/tokens.scss,别忘了"。

预期:

- skill 把这条信息合并进 Step 0 的 `Design tokens source` 字段(更新而不是重启)
- 不重新触发整个 Step 0 探测
- 后续阶段沿用更新后的快照

失败信号:

- 把"对了 tokens 在哪"当成新需求,重启整个流程
- 忽略掉用户的补充
