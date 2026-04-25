# 链路测试用例

验证 `flow-project-finish → huashu-design → frontend-design → delivery-gate → clean-commit` 的衔接是否完整,以及 Step 0 探测结果在下游阶段是否被正确继承。

## C1. 正常流转(浏览器扩展 → 落地页 → 审查 → 提交)

输入:

> 我的浏览器扩展(Plasmo + React + Tailwind)主要功能写完了,做完整收尾:同步设计 tokens 到设计系统文档、出 README、做落地页,审查通过就提交。

预期:

- 入口触发 `flow-project-finish`
- Step 0 输出 `Project type: browser-extension`、`Frontend stack: react + tailwind + plasmo`、`Already a website: no`、`Git state: dirty:main`
- Step 1 找到 `tailwind.config.*` 与 `styles/globals.css`,把代码里实际使用的 token 同步到设计系统文档
- Step 3 进入,**调用 `huashu-design`** 时上下文里**已含**项目类型/前端栈/调性,**不向用户重复追问**
- `huashu-design` 返回 3 套方向 → 用户挑选 → `frontend-design` 用 `react + vite + tailwind`(对齐项目栈,不是回退栈)
- 落地页放在 `website/` 子目录,不污染主扩展构建;3.4 在 4 个断点截图
- Step 4 调 `delivery-gate`,递交 Step 1~3 全部产出 + Git state + 4 张响应式截图
- delivery-gate 判 all clear → Step 5 调 `clean-commit`,**只 staging 本次收尾涉及的文件**
- clean-commit 产出真实 commit hash + 简洁 message(类型为 `docs` 或 `chore: project finish`)
- 收尾报告 7 节齐全

失败信号:

- Step 3 重复问"这是什么项目""用什么技术栈"
- frontend-design 用了 vite+pnpm+react 但忽略了项目自带的 tailwind
- huashu-design 只拿到 1 套方向就接 frontend-design
- delivery-gate 没拿到响应式截图(Step 3.4 跳了但没声明)
- clean-commit 收到 "git add -A" 这种全量 staging 指令
- delivery-gate 给了 must-fix 却仍然进 Step 5

## C2. 反例流转(项目本身就是网站)

输入:

> 我的 Astro 落地页站要发布了,做收尾,审查完提交。

预期:

- 入口可触发 `flow-project-finish`(收尾意图明确,涉及多件)
- Step 0 输出 `Already a website: yes`
- Step 3 显式跳过,跳过原因为"项目自身即网站"
- 不调用 `huashu-design` / `frontend-design`
- Step 4 仍调 `delivery-gate`(审查 Step 1 文档同步 + Step 2 README)
- Step 5 仍调 `clean-commit`
- 收尾报告 Step 3 节存在,内容是跳过说明

失败信号:

- 仍然给 Astro 站点再造一份独立"落地页"
- 跳过但没在报告里写跳过段落
- 因为没建落地页而连 delivery-gate 也跳过(错误!Step 4 永远要跑)

## C3. 字段保真(Step 0 探测结果在 Step 3 不丢失)

输入:

> 我的 Rust CLI 主要功能 OK 了,做收尾,要一份 README 和落地页,审查后提交。

预期:

- Step 0 输出 `Project type: cli`、`Frontend stack: none`
- Step 3 调用 `frontend-design` 时,技术栈契约触发**回退路径**:`vite + pnpm + react`
- 收尾报告中明确记录"项目无前端栈,落地页采用 vite+pnpm+react 默认栈"
- Step 4 / Step 5 正常跑

失败信号:

- 上游识别为无前端栈,下游却问用户"用什么栈"
- 落地页用了 React + 某种生态混搭(如 next.js 全栈),违反"无栈回退 vite+pnpm+react"契约
- 报告里没记录回退原因

## C4. 路线图来源贯穿

输入:

> 项目主体差不多了,做收尾。我有一份 progress.md 在根目录记着 TODO,落地页里 roadmap 段就用它,提交记得只带本次收尾的改动。

预期:

- Step 0 标 `Roadmap source: progress.md`
- Step 3.1 收集落地页输入时,roadmap 显式来源于 progress.md(而非临时编造)
- frontend-design 拿到的内容契约里 Roadmap 段填充的是 progress.md 真实条目
- Step 5 clean-commit 的 staging 范围被显式限定到本次收尾文件,不带工作区其他改动
- 收尾报告里 Step 3 / Step 5 注明 roadmap 来源 + commit 范围

失败信号:

- 落地页 roadmap 段填了项目里没有的内容(凭印象编)
- 落地页 roadmap 段做成"暂无路线图"(数据源在,却没用)
- clean-commit 把工作区里其他无关改动也带进来

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

## C6. delivery-gate must-fix 回流(新增,验证审查回流闭环)

输入:

> 我的 Vue 项目做完整收尾。

中途 delivery-gate 返回:`must-fix: README 里的 dev 命令是 npm run dev,但 package.json 里只有 pnpm 脚本,会误导用户`。

预期:

- 不直接进 Step 5
- 路由回 Step 2 修复 README 的命令
- 修复后**重跑 delivery-gate**(不是直接跳过)
- 重跑判定 all clear 后才进 Step 5
- 收尾报告 Step 4 节记录 `re-ran 2 times`,Step 2 记录 must-fix 修复点

失败信号:

- must-fix 被合理化成 should-fix 直接通过
- 修复后没重跑 delivery-gate 就 commit
- Step 4 报告里没记录回流次数

## C7. clean-commit 选择性 staging(新增,验证提交边界)

输入:

> 项目做收尾,我工作区还有一些跟收尾无关的实验代码,别一起提交。

预期:

- Step 5 调用 clean-commit 时显式传入"本次收尾涉及的文件清单"(Step 1 patch 路径 + Step 2 README 路径 + Step 3 落地页路径)
- clean-commit 选择性 staging,只把这些路径加入 commit
- 用户工作区里其他改动保持 untracked / modified 状态不变
- 收尾报告 Step 5 注明"已剥离 N 个无关文件"

失败信号:

- skill 让 clean-commit 跑 git add -A 或 git add .
- 实验代码被夹带进 commit
- 没在报告里说明 staging 范围
