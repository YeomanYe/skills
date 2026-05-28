# Output Contract Template —— experience-summary 完整 5 段输出格式

> 本文件给出 experience-summary Step 5 的完整 5 段固定格式 + 禁用词清单 +
> handoff 边界说明。主体 SKILL.md 只保留【一句话沉淀】格式硬约束 + 引用本文件。

## 为什么需要

experience-summary 的核心契约是"分诊结论可直接执行 + 一句话沉淀人类可读"。
原 SKILL.md 内联完整 5 段格式 + 禁用词大表占 ~50 行,主体膨胀。
本文件保留全部细节,主体只留入口逻辑。

## 完整 5 段固定格式(顺序固定)

```
【一句话沉淀】把<X>变成了<Y>,沉淀到了<Z>。
【分诊结论】<出口名称>(Q<N> 命中)
【推荐位置】<具体文件绝对路径或相对路径>
【写作模板】
<可复制的 Markdown / YAML / 代码草稿>

【后续提醒】
- (可选)上移路径
- (可选)需要走 flow-skill-dev 完整流程
- (可选)sync-shared.sh / sync-skills 分发要求
- (可选)CLAUDE.md 行数超限警告
```

5 段缺一不可,顺序不可调换。

## 【一句话沉淀】格式硬约束(主体保留)

- 必须有 3 个槽位: **X(做了什么经验)** / **Y(变成了什么载体)** / **Z(沉淀到了哪个概念位置)**
- **不带技术细节** —— 完整禁用词清单见下表
- 用**用户口语**描述(项目脚本 / 全局宪法 / 领域专家 / 启动手册 / 长期记忆 ...)
- 每个出口的 Y/Z 模板见 `references/layer-map.md` 各层"叙事模板"段
- 例子(参考用户思路):"把**重复的浏览器操作过程**变成了**代码**,沉淀到了**项目脚本**"

## 禁用词清单(叙事行**绝对不能出现**)

| 类别 | 禁用词 |
|---|---|
| 出口编号 | L0 / L1 / L2a / L2b / L3 / L4 / L5 / L6 / L7 / L8 / L9 / L10 |
| 判断树编号 | Q0 / Q1 / ... / Q10 |
| 技术形态 | hook / script / MCP / skill / director-* / flow-* / metaspec / frontmatter |
| 文件名 / 路径 | constitution.md / settings.json / CLAUDE.md / AGENTS.md / `_shared/` / 任何绝对或相对路径 |
| 工具命令 | sync-shared.sh / git push / skillshare sync / update-config |
| skill 名 | flow-skill-dev / clean-commit / 任何已实现 skill 名 |

如果叙事行需要表达某个技术概念,用**口语替换**:

| 不写 | 写成 |
|---|---|
| hook | 会话触发器 / 自动化钩子 |
| constitution.md | 全局宪法 / 全局约束层 |
| director-* | 领域专家 / 专家角色 |
| CLAUDE.md | 启动手册 / 项目说明书 |
| settings.json | 配置入口 |
| _shared/<topic>.md | 共享规范库 |
| skill-doctor 规则 | 自动检查工具 / 质量门禁 |
| auto memory | 长期记忆 |
| flow-* | 流水线 / 编排步骤 |

## 为什么【一句话沉淀】放第一行

这是给**人类一眼可读**的沉淀总结;后面的【分诊结论 / 推荐位置 / 写作模板】是给执行者
(走 flow-skill-dev 或直接落盘)的技术细节,可读性弱。两者分层,人类先看一句话,
要落地时再读技术段。

## handoff 边界(critical)

【一句话沉淀】是 **human-facing only**,**不进 handoff payload**。

下游 skill(flow-skill-dev / update-config / sync-skills)消费的是
**【分诊结论 / 推荐位置 / 写作模板】3 段技术契约**。

这条要写进 SKILL.md 让下游不会误解析叙事行。

## 各段写作要求详解

### 【分诊结论】

- 格式: `<出口名称>(Q<N> 命中)`,例如 `L1 constitution(Q1 命中)`
- 出口名称用层级编号 + 一句话出口,不用全路径
- 必须显式标注 Q<N>,方便后续审计

### 【推荐位置】

- 必须给**具体文件路径**,不能写"对应的 constitution"
- 绝对路径优先,相对路径只在 skill 内部引用时用
- 多个目标位置时全部列出(如 _shared 改动需要 sync 到 N 个 skill)

### 【写作模板】

- 必须是**可直接 copy-paste**的 Markdown / YAML / 代码草稿
- 不写"请遵守 xxx 规则"这种空话
- 包含至少 1 个具体例子或反例
- 各层模板见 `references/templates.md`
- L9a 模板见 `references/l9a-recipe-template.md`(单独成文,因为字段多)

### 【后续提醒】

按出口触发对应提醒:

| 出口 | 必须提醒 |
|---|---|
| L1 / L2a | `bash scripts/sync-shared.sh` + git push + skillshare sync 4 步链 |
| L2b | 切到 node-scripts 项目走 flow-dev-task |
| L3 | 用 update-config skill 配置,不要手动改 settings.json |
| L4 | 脚本可独立执行 + 有 --help |
| L6 / L7 | 改 director-* / flow-* 走 flow-skill-dev substantial-update |
| L8 | 检查 wc -l CLAUDE.md,超 200 行触发下沉对话 |
| L9 | 检查 Q1-Q8 是否更高优先级层 |
| L9a | INDEX.md 同步两处(按 tag + 按 symptom),否则等于没入册 |
| 任意 | 同条经验 ≥ 2 次被推荐 → 上移检查清单 |
