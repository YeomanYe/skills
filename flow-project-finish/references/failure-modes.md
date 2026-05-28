# Failure Modes — flow-project-finish 红线 / 合理化 / 常见错误

> 抽离自 SKILL.md。三段失败模式索引(Red Flags / Rationalizations / Common Mistakes)集中在此,
> SKILL.md 主体只保留 5-15 行引用 + "翻车 = 假装在收尾,实际在抹掉项目个性"的核心信条。

## Red Flags —— STOP 并重新考虑

- 没探测项目状态就直接开写文档 → 停下,先做 Step 0
- 找不到设计系统文档却创建了一份"占位空文档" → 停下,删掉,改为在报告里标"未发现"
- README 已存在却被整体重写为"更专业的版本" → 停下,恢复原文,改为增量 patch
- 落地页的路线图区从 README 抄一遍而不是从真实 TODO/ROADMAP 来 → 停下,重抓数据源
- **3.2 只派了 1-2 路 mockup(不是默认 3 路)→ 停下,补齐 3 路**(v5)
- **3 路 mockup 只换主色不换布局结构 → 停下,违反独立性硬规则**(v5)
- **未等用户挑选就 auto-pick mockup-1 进 Step 3.3 → 停下,不超时**(v5)
- **重做时覆盖原 mockup 目录(不用 -v2 后缀) → 停下,旧 mockup 必须保留**(v5)
- 项目已经是 Next.js/Nuxt 网站还在生成"落地页" → 停下,跳过 Step 3 并说明
- 项目里已经有 `website/` 等既存落地页子目录,却被当作"无落地页"重做 → 停下,先走 3.0 refresh/rebuild/skip 三选一
- **把 preview/demo 目录当成"既存落地页"做 refresh/rebuild → 停下,preview 是平行资产,落地页另开目录(默认 `landing/`),preview 原位不动**
- **删除/重命名/移动 preview 目录以"腾位置"给落地页 → 停下,平行存在,preview 不动**
- **3.3 落地页码写完了却没动部署配置 → 停下,补 3.3.5;否则用户线上看到的还是旧 preview**
- **检测到多个部署配置时,自动改了 secondary 配置 → 停下,primary 由 Claude 改,secondary 必须用户确认**
- **部署配置仅存在于平台后台(toml 中不可见)却被声明"切换完成" → 停下,在报告"开放决策"里显式列"需后台手动改"**
- **landing Links 段直接放旧 preview URL → 停下,部署已切,旧 URL 现在指向 landing,等于自指**
- **递交 delivery-gate 时漏带 `Deployment switched` / `Preview retained at` 两项证据 → 停下,补完再 hand off,否则 gate 看不到部署侧的变更上下文**
- **声明 `Deployment switched: vercel.json:<old> → <new>` 但 `git diff vercel.json` 实际为空 → 停下,要么真去改文件,要么删掉声明,二选一,不要骗 gate**
- **传给 clean-commit 的变更范围只列了 `docs+landing` 没列部署配置文件 → 停下,显式列文件路径;否则 clean-commit 会把根目录的 vercel.json 当无关脏改动排除**
- **跳过 delivery-gate 直接进 Step 5 commit** → 停下,这是硬阻断;审查必须先于提交
- **delivery-gate 给了 must-fix 却直接 commit** → 停下,回流到对应阶段修复后重跑
- **clean-commit 把收尾以外的改动一起夹带提交** → 停下,要求 clean-commit 走选择性 staging
- 收尾报告省略某个阶段 → 停下,补上(即使跳过也要有跳过段落)
- README 写了根本不存在的 `pnpm something` 命令 → 停下,以 `package.json scripts` 为准

## Rationalizations to Reject

| 说辞 | 现实 |
|------|------|
| "项目没设计系统文档,顺手新建一个吧" | 主动新建会污染项目结构。本 skill 默认不新建,在报告里标"未发现"让用户决定 |
| "README 翻译成英文更专业" | 改语言/改风格不是本 skill 职责。增量更新,保留原 voice |
| "落地页直接用 frontend-design 一步到位省时间" | 没有 3 路 mockup 的方向选择,落地页就会是"AI 通用美学"。3.2 → 3.3 两步不可压缩成一步 |
| "默认派 1 路 mockup 就够了,3 路太重" | v5 默认 3 路是为了给用户**视觉化选择**而不是文字方向;1 路 = 无选择 = 强买强卖 |
| "用户没回,就先 auto-pick mockup-1 让流程继续" | 不超时是设计决策。设计选择由用户决定,超时 auto-pick 等于代用户选 |
| "项目本身是网站,落地页和它合并就行" | 网站本身 ≠ 项目落地页;但当项目就是网站时本 skill 直接跳过 Step 3,不强行造一份 |
| "路线图从我对项目的理解写一下就行" | 路线图必须可追溯到真实文件(TODO/ROADMAP/progress);凭印象写会过期或失真 |
| "用户没指定技术栈,我给落地页用我喜欢的" | 默认对齐项目前端栈;无栈才回退 vite+pnpm+react,这是契约 |
| "preview 已经部署了,落地页直接顶替 preview 目录最省事" | preview 和 landing 职能不同(试用 vs 介绍),代码必须平行存在;只切部署目标,不动 preview 代码 |
| "落地页落码就算结束了,部署等用户自己改" | 不行。3.3.5 必须切 primary 部署配置,否则用户线上看到的是过期 preview。Claude 改 primary + secondary 列给用户确认,这是契约 |
| "多个部署配置太麻烦,统一全切了" | secondary 配置必须用户确认。统一改可能破坏用户有意保留的其他部署通道(如内部 staging / PR preview) |
| "preview 既然下线了,代码也删掉吧" | preview 仍是有用的开发资产,代码留着;只是不再是公开部署目标。删除是用户决定,不在收尾职责内 |
| "落地页 Links 段直接放 preview 的旧 URL" | preview 已下线,旧 URL 大概率指向新落地页(因为部署切了),贴这个等于自指。要么指向"clone 后本地跑",要么等用户后续手工部署 preview 到子路径再补 |
| "secondary 部署改了出问题,改回来就行" | 改 secondary 不是 Claude 的权限范围,用户没确认就不改;改了出错的责任和回滚成本本可以避免 |
| "递交 delivery-gate 时部署证据先省略,gate 应该能自己看出来" | gate 看的是 diff + 输入证据;不带 `Deployment switched` 它就不知道你切了部署,无法判断"声明 vs 实际"是否一致。证据必须显式带 |
| "传给 clean-commit 时就说改了 docs+landing,clean-commit 会自己扫到根目录的 vercel.json" | 不会。clean-commit 默认排除"与当前任务无关的脏改动",根目录的 vercel.json 若不在显式列表里会被当成无关而排除。本 skill 必须替 clean-commit 把这些文件认领进当前任务 |
| "PRD/架构文档差太多了,本期重写一遍" | 本 skill 是收尾不是重做。陈旧文档只 patch 实际偏差,大改属于另一项任务 |
| "响应式截图跳过了无所谓" | 跳过可以,但必须在报告里显式声明"未截图";delivery-gate 也会拿这个缺口做判断 |
| "delivery-gate 太重,自己走查一遍就行" | delivery-gate 是独立 gate,不只是 lint/build;它能拦下你正在合理化的"差不多就行"。必须真的调用 |
| "delivery-gate must-fix 是小问题,提交后再修" | must-fix 顾名思义不可绕过;commit 前修完 |
| "clean-commit 太繁琐,我直接 git add . 然后 commit" | 直接全量 add 会夹带无关改动;`clean-commit` 的核心价值就是选择性 staging + 合理 message |

## Common Mistakes

- 把"项目快照"当成挑选性记录:只写存在的、忽略不存在的(导致后续阶段误判)
- 把"未发现的设计系统文档"默默创建一个占位
- README 增量更新时连原作者写的项目背景一起删掉
- 落地页的内容契约里漏掉「路线图」段(以为路线图项目内部用就够)
- 调 huashu-design 时没说"3 套方向",拿到 1 套就开干
- 落地页放进项目源码目录,污染主项目构建
- **把 preview/demo 当成既存落地页,触发 refresh/rebuild 流程**
- **生成落地页时把 preview 目录覆盖、删除或重命名(应平行存在)**
- **落地页落码后忘记切部署目标,用户线上仍看到旧 preview**
- **自动改了 secondary 部署配置,没让用户确认**
- **3.3.5 改了 vercel.json/netlify.toml,但传给 clean-commit 时只列了 docs+landing,部署文件被当无关脏改动排除,commit 漏掉部署侧变更**
- **递交 delivery-gate 时漏带 `Deployment switched` 证据,gate 通过后才发现部署没真切**
- 跳过 delivery-gate 直接 commit
- delivery-gate 给了 must-fix 没回流就 commit
- clean-commit 把工作区里其他改动一起夹带
- 收尾报告里把跳过的阶段直接删掉,而不是显式说"已跳过 + 原因"
