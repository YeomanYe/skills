---
name: flow-skill-research
description: Use when researching existing agent skills for a domain, technology stack, workflow, or capability before choosing what to inspect, compare, recommend, or install; 用于围绕领域、技术栈、工作流或能力调研现有 agent skills，并在安装前完成搜索、筛选、内容审查、风险判断和推荐。
---

# Skill 调研编排

## 概览

这个 skill 用于编排完整的 skill 调研流程。

它不替代 `find-skills`，而是负责把需求澄清、本地已安装 skill 检查、关键词搜索、候选筛选、真实内容审查、风险判断、推荐和可选安装串成一个稳定流程。

默认行为是调研与推荐，不是安装。

## 适用时机

以下情况使用本 skill：

- 用户询问“有没有某类 skill”
- 用户要求查找、调研、比较某个技术栈或工作流相关 skill
- 用户要求查看候选 skill 里实际写了什么
- 用户想知道应该安装哪个 skill
- 用户想先调研生态，再决定是否创建自定义 skill

以下情况通常不要使用本 skill：

- 用户已经明确指定一个 skill，并且只要求立即安装
- 用户要编写或实质更新 skill，此时应转交 `orchestrating-skill-development`
- 用户要直接完成某个业务或代码任务，而不是调研 skill

## 必要流程

必须按以下顺序执行：

1. 定义调研目标
2. 先检查本地已安装 skill 是否满足要求
3. 若本地不足，再使用 `find-skills` 或 `npx skills find` 搜索候选
4. 对候选做初筛
5. 读取入围候选的真实内容
6. 汇总每个候选满足需求的具体证据点、适用场景和风险
7. 给出推荐与安装命令
8. 只有用户明确要求时才执行安装

不要只根据搜索结果标题、描述或安装量直接推荐。

不要只说“这个 skill 相关”或“可以满足要求”；必须说明该 skill 中哪些触发条件、流程、脚本、references 或约束能满足用户需求。

## Step 1: 定义调研目标

先提炼：

- 领域或技术栈
- 用户想解决的具体任务
- 关键词同义词
- 明确排除项

若上下文足够，应直接推断并继续，不要为了明显信息重复追问。

示例关键词扩展：

- React: `react`, `nextjs`, `frontend`, `performance`, `component`
- Preact/Fresh: `preact`, `fresh`, `deno frontend`, `deno`
- 重构: `refactor`, `component split`, `code review`, `architecture`

## Step 2: 检查本地已安装 Skill

搜索外部生态前，必须先检查本地已安装 skill。

优先检查：

- 当前会话可用 skill 列表
- `~/.agents/skills/`
- 与当前项目相关时，检查项目内 `.agents/skills/`
- 必要时检查 `~/.codex/skills/` 或其他已知 agent skill 目录

检查时应：

- 读取候选的 `SKILL.md`
- 用 description、适用时机、核心流程和资源判断是否满足需求
- 标记为 `本地已安装`、`部分满足` 或 `不满足`
- 如果本地已有强匹配，优先推荐本地已安装 skill，并说明无需安装

本地检查不能只看目录名。

## Step 3: 搜索外部候选

优先使用 `find-skills` 的规则。

搜索时应：

- 至少使用 2 个关键词变体，除非用户给了极窄目标
- 保留搜索命令或搜索词
- 区分直接匹配、相邻匹配和噪声匹配
- 记录候选来源、安装量、仓库或包名

可用命令：

```bash
npx skills find "<query>"
```

如果用户明确要求“使用 find-skill / find-skills”，必须使用 `find-skills`。

## Step 4: 初筛候选

初筛优先级：

1. 任务直接匹配
2. 来源可信度
3. 安装量
4. 技术栈时效性
5. 是否包含脚本、references 或明确工作流

判断规则：

- 官方或知名来源优先，例如 `anthropics`、`vercel-labs`、`denoland`
- 1K+ installs 通常更可信
- 100 以下 installs 要标记为低信心，除非内容非常直接
- 直接匹配优先于高安装量但不相关的候选
- 对老技术栈或旧版本框架要明确标注风险

## Step 5: 读取真实内容

对准备推荐的候选，必须尽量读取真实 `SKILL.md` 或等价源文件。

可接受方式：

- 从已安装目录读取
- 从临时 clone 的仓库读取
- 从可信页面读取原始内容

不应为了“查看内容”而安装候选 skill，除非用户已经明确要求安装。

临时 clone 建议放在 `/tmp`，调研结束后无需纳入项目。

读取时重点提炼：

- 触发条件
- 核心流程
- 是否有脚本、references、assets
- 适用场景
- 能满足用户需求的具体条目
- 不能覆盖或只能部分覆盖的需求
- 版本或生态风险
- 安全扫描或安装警告如果已知

## Step 6: 输出调研结论

输出必须包含：

- 本地已安装 skill 检查结果
- 使用过的搜索词或搜索命令
- 候选列表
- 入围候选内容摘要
- 每个推荐候选满足需求的具体证据点
- 推荐安装项
- 不推荐或谨慎使用项
- 安装命令
- 是否需要创建自定义 skill

如果没有强匹配，应明确说“未找到可靠候选”，而不是凑推荐。

推荐候选的证据点应具体到：

- skill 中的触发条件如何匹配用户需求
- skill 的必要流程或工作流能覆盖哪些任务
- skill 附带的脚本、references、assets 能提供什么能力
- 哪些需求未覆盖或需要组合其他 skill

## 安装边界

默认不要安装。

只有用户明确说“安装”“装到全局”“install”等，才执行安装。

安装时：

- 只安装用户指定或刚刚确认的候选
- 全局安装使用 `-g -y`
- 保留并报告安全扫描结果、warning 和失败信息
- 不要自动同步到 `~/.config/skillshare/skills/`

示例：

```bash
npx skills add owner/repo -g -y --skill skill-name
```

若用户明确要求把已安装 skill 纳入 skillshare source，再调用 `sync-skills`。

## Handoff

如果调研发现没有合适候选，并且用户希望沉淀为能力，应转交：

- `orchestrating-skill-development`

handoff 内容至少包含：

- 调研目标
- 已搜索关键词
- 为什么现有候选不够
- 新 skill 应覆盖的触发条件和边界

## 常见错误

- 只看 `npx skills find` 的摘要就推荐
- 把“相邻技术栈”说成直接匹配
- 未经用户确认就安装
- 安装后自动同步到 skillshare source
- 忽略低安装量、未知来源或旧框架版本风险
- 用户问“里面写了什么”时，只复述搜索结果而不读取真实文件
