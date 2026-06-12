# Failure Modes —— Red Flags & Rationalizations

> experience-summary 调用过程中容易踩的坑 + 容易给自己找的台阶。
> 主体 SKILL.md 不再展开,只在 Red Flags / Rationalizations 段引用本文件。

## Red Flags — 命中任一**停止并修正**

- 用户描述模糊就直接路由(必须 Step 1 追问到清晰)
- 跳过 Q0 直接选层(很多冲动其实不该沉淀)
- 同一条经验路由到 2 个出口(判断树是顺序的,**第一个 yes 即出**)
- 推荐写 CLAUDE.md 但没检查当前行数(超 200 行还往里塞 = 加剧问题)
- 推荐写 hook 但没提供具体配置示例
- 推荐写 skill 但没提示走 `flow-skill-dev`(直接落盘 = 跳过 scope/test/sync)
- 推荐 constitution 但没提示跑 sync-shared.sh
- 输出"建议沉淀到 xxx 层"但不给具体路径 + 草稿
- 路由到 L9 但没先判 L9a(跨 agent 通用 > per-user 个人偏好,顺序不能反)
- 路由到 L9a 但没提示用户同步更新 `mem/INDEX.md` unblock 段两处(原 `unblock-recipes/INDEX.md`)
- 输出叙事行【一句话沉淀】含禁用词(L1 / hook / CLAUDE.md / 绝对路径 等)
- 输出 5 段缺段或顺序错乱(顺序固定: 沉淀 → 结论 → 位置 → 模板 → 提醒)

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "这是个好经验,先写进 CLAUDE.md 再说" | 没过 Q0-Q9 顺序判断 = 选错层概率高 |
| "skill 和 CLAUDE.md 差不多,放哪都行" | 本 skill 的核心论点就是反对这个 |
| "用户很想沉淀,就别 Q0 拦了" | Q0 是过滤"沉淀冲动"的关键阀门 |
| "走 flow-skill-dev 太重,直接帮用户写 SKILL.md 落盘" | 跳过 scope/test/sync 三个门 = 引入低质量 skill |
| "constitution 改起来麻烦,塞 CLAUDE.md 算了" | 跨 skill 通用约束放 CLAUDE.md = 其他 skill 看不到 |
| "用户说'记住这个',就直接写 auto memory" | 检查 Q1-Q8,是不是其实是 constitution/CLAUDE.md 级;Q9 内先判 9a(mem unblock 分类,原 unblock-recipes),不是个人偏好不要 default memory |
| "卡壳-解法也是个人经验,丢 memory 就行" | memory 是 per-user 不跨 agent,通用解法该进 mem(unblock 分类,原 unblock-recipes)让任何 agent 受益 |
| "mem 不就是错题本嘛,直接 add 一条" | 写入入口唯一是 experience-summary Q9a 分诊,不允许绕过(防止 catalog 垃圾化) |
| "叙事行带点技术词更精准" | 叙事行是给人类一眼可读,带技术词 = 失去这层价值;技术细节进【分诊结论/推荐位置】段 |
| "只触发一次的 director-* 改动也要走 flow-skill-dev?" | substantial-update 才走;只改文案/错别字直接 Edit。判定见 flow-skill-dev When NOT to Use |

## 上移信号(命中任一 → 触发 Step 4 上移检查清单)

1. **用户口头明示**: "又是这条"、"这已经第 N 次了"、"老问题"
2. **本对话计数**: 在**当前对话**里,experience-summary 已经第 ≥ 2 次推荐**同一个出口位置**
   (例如:连续两次都路由到同一个 director-* skill 的同一份 reference 文件)
3. **跨 director 信号**: 当前出口是 director-* L6,但描述里还提到"在另一个领域也遇到过类似"
   → 触发 Q1 重判

## 上移路径表

| 当前层 | 上移到 | 触发条件 |
|---|---|---|
| director-* (L6) | constitution (L1) 或 _shared/ metaspec (L2a) | ≥ 2 个 director-* 都需要这条 |
| skill / hook / script | CLAUDE.md (L8) | 项目里多个 skill 都重复了这条 |
| CLAUDE.md (L8) | constitution (L1) | 跨项目 / 跨 agent 通用 |

## 上移检查清单(命中信号时,本 skill 必须输出)

- ☐ 当前对话 experience-summary 调用次数: <N>
- ☐ 出口分布: <list>
- ☐ 建议上移目标层: <L?>
- ☐ 上移路径草稿: <新位置的写法>
- ☐ 旧位置处理: 保留 / 删除 / 改为引用新位置
