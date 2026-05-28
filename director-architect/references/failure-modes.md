# director-architect — Red Flags / Rationalizations / Common Mistakes

> SKILL.md 主体只保留 5-10 行引用,本文件汇总所有失败模式 / 借口反驳 / 易踩坑。

## Red Flags — STOP

任一命中必须停下:

- **用户没明确 yes 就 land**(含糊回应、"嗯嗯"、"看着办"都不是 yes)
- **没跑联合评估就给 plan**(Step 4 是强制环节)
- **plan 内容变更后用旧的 yes 当批准**(必须重新征求)
- **把 best-practice skill 列表写死**(必须按当前栈动态匹配,写死 = 漏栈或硬塞)
- **自决冲突时不在 Output Contract 留决策记录**(缺记录 = 黑箱)
- **"按 X 项目"直接 cp 参考项目目录结构**(必须先跑 Step 5 兼容性检查)
- **跳过 Step 1 项目证据采集,凭印象设计结构**
- **机械改文件名而不重写内容边界**
- **保留双轨规则体系**(新旧同时有效)
- **没看到项目证据就断言"规范已完善 / 已对齐"**
- **混入 README / CHANGELOG / 上架文案重写**(越界,归 flow-project-finish / flow-ext-publish)

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "用户输入已经很清楚了,跳过联合评估直接给结构" | 联合评估是 research 的**强制环节**,不是"看情况";跳过 = 漏栈风险 |
| "这个项目没什么栈相关 skill 可匹配,跳过 evaluate" | 至少要显式说"未匹配到栈相关 skill"+ 自己跑结构评估;不能省略输出 |
| "用户说了'按 X 项目做',直接镜像就行" | 仍要先对齐当前项目栈是否兼容(Step 5),不然把不适用的规则硬塞过来 |
| "冲突太微小,不用写决策记录" | 自决就必须留痕,**无例外**;微小冲突也要写"自决了 + 理由:不重要" |
| "用户口头 OK 了就开始 land" | "OK" / "嗯" / "看着办" 都不是明确 yes,必须显式问到"可以落地"级别表态 |
| "plan 没大改,沿用上次的 yes" | 内容变更后任何级别都要重新征求;只有完全没改才能沿用 |
| "顺便把 README 也整理了" | 越界。README → flow-project-finish |
| "顺便把 commit 也帮 ta 提交了" | clean-commit 的职责,转交它,不要自己 git add |
| "AI 没读 stack-checklist 也能凭经验给规则" | 必须查清单,避免漂移;项目实际栈未覆盖时必须显式标"未覆盖" |
| "用户已经走过 project-prep 了,跳过 Step 1 盘点" | project-prep 不读项目规则文档;本 skill 的 Step 1 是独立证据源 |

## Common Mistakes

- 把"梳理"信号当成"审一下"(漏了 Land Phase 询问)
- Step 4 联合评估只读 skill 名,不真消费其 description / SKILL.md 中的判断逻辑
- 决策记录只写"选了 A",不写备选 / 理由(**等于没写**)
- 把 `index.md` 写成总纲(堆正文)或把 `rules.md` 写成导航(只列链接)
- 迁移内容时只 `mv` 文件,不重写内容边界,结果旧分类还残留在文本里
- Approval Gate 后立即开干,不再做最后一次 `git status` 校验
- 把未覆盖的栈静默吞掉,不在报告里显式列出

## Delivery Check(宣称工作完成前核对)

### research 阶段
- [ ] Step 1 盘点项目规则现状(带 `[file:line]` 证据)
- [ ] Step 2 识别技术栈(自动 + 用户指定)
- [ ] Step 3 动态匹配 best-practice skill(写出来源路径)
- [ ] Step 4 联合评估(每个 skill 出一句话结论)
- [ ] Step 5 仅当用户给参考项目时执行
- [ ] Step 6 结构设计 + **决策记录**完整

### Approval Gate(若进入 land)
- [ ] 显式向用户提问"是否可以落地"
- [ ] 收到明确同意表态(不是"嗯"或"看着办")
- [ ] plan 变更后重新征求过

### land 阶段
- [ ] 落地前 `git status` 干净
- [ ] 文件变更与批准的 diff 一致
- [ ] 无双轨规则体系
- [ ] 历史引用已更新或在报告显式列遗留
- [ ] 项目实际栈都有规则覆盖(或显式标"未覆盖")
