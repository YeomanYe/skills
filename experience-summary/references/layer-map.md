# Layer Map —— 11 个出口完整说明

> 本文档是 `experience-summary` 的层级出口字典。每层定义 = **叙事模板** + 性质 + 该放什么 + 不该放什么 + 写在哪里 + 写完后续动作。
>
> **叙事模板**用于 SKILL.md Step 5 输出契约的【一句话沉淀】行 — 不带技术细节、用户口语可读、3 槽位(X 做了什么 / Y 变成了什么载体 / Z 沉淀到哪个概念位置)。

## 11 层叙事模板速查

| 出口 | 一句话叙事模板(X→Y→Z) | 套用例子 |
|---|---|---|
| L0 丢弃 | 这条经验不值得沉淀(<原因>) | "下次大概率不会再发生" → 不沉淀 |
| L1 constitution | 把**<跨 agent 的安全/价值观底线>**变成了**所有 agent 都遵守的宪法**,沉淀到了**全局约束层** | 把"不能在没确认时删数据"变成了所有 agent 都遵守的宪法,沉淀到了全局约束层 |
| L2a 元规范 | 把**<skill 该怎么写的结构规范>**变成了**统一模板**,沉淀到了**共享规范库** | 把"所有 director-* 必须有 9 维 audit"变成了统一模板,沉淀到了共享规范库 |
| L2b skill-doctor | 把**<skill 质量的硬规则>**变成了**自动检查工具**,沉淀到了**质量门禁** | 把"description 不能超 250 字符"变成了自动检查工具,沉淀到了质量门禁 |
| L3 hook | 把**<必须每次发生的小动作>**变成了**会话触发器**,沉淀到了**自动化钩子** | 把"commit 前必须跑 lint"变成了会话触发器,沉淀到了自动化钩子 |
| L4 script/MCP | 把**<重复执行的过程>**变成了**代码/工具**,沉淀到了**项目脚本** | 把"重复的浏览器操作过程"变成了代码,沉淀到了项目脚本 |
| L5 nested CLAUDE.md | 把**<某目录的特殊约定>**变成了**局部规则**,沉淀到了**目录小约定** | 把"/legacy/ 用 class component"变成了局部规则,沉淀到了目录小约定 |
| L6 director-* | 把**<某个领域的专业判断>**变成了**专家角色**,沉淀到了**领域专家库** | 把"图片合规审查 9 维"变成了宣发专家的能力,沉淀到了领域专家库 |
| L7 flow-* | 把**<多步任务的标准流程>**变成了**编排步骤**,沉淀到了**流水线库** | 把"扩展上架的 12 步"变成了编排步骤,沉淀到了流水线库 |
| L8 CLAUDE.md/AGENTS.md | 把**<每次会话都该知道的项目知识>**变成了**启动手册**,沉淀到了**项目说明书** | 把"本项目用 pnpm"变成了启动手册的一条,沉淀到了项目说明书 |
| L9 auto memory | 把**<你的长期偏好>**变成了**对你的认识**,沉淀到了**长期记忆** | 把"用户偏好简洁回复"变成了对你的认识,沉淀到了长期记忆 |
| L10 兜底丢弃 | 这条经验太抽象/太私人,现在还不该沉淀 | "希望 agent 更聪明" → 兜底丢弃 |

**叙事行使用规则**:
- 必须填全 3 个槽位(X/Y/Z)
- 不带技术词(不写"L3"、"hook"、"frontmatter"、"git push")
- Y 用"代码/规则/触发器/启动手册/记忆"这种用户可懂的词
- Z 用"项目脚本/全局宪法/领域专家"这种概念位置,不写绝对路径

---

## L0: 丢弃(不沉淀)

**性质**: 经验未达到沉淀阈值。

**该放什么**: 无。

**不该放什么**: 一次性偶发现象 / 个人当下情绪 / 已被现有规则覆盖 / 太抽象落不到位置的"经验"。

**判定信号**(任一命中即丢弃):
- "下次大概率不会再发生"
- "我就是当时心情不好"
- "翻一下 CLAUDE.md 已经写了类似的"
- "好像很重要但说不清是什么"

**后续动作**: 直接告诉用户原因,不写文件。

---

## L1: `_shared/constitution.md`(跨 skill 顶层契约)

**性质**: 跨所有 skill 通用的价值观 / 安全 / 身份层。**always-follow**,优先级最高。

**该放什么**:
- Identity(本 agent 是什么 / 不是什么)
- Output Safety(不泄漏 token / 不真删用户数据 / 不替按破坏性按钮)
- Input Trust Tiers(用户输入 vs 网页 fetch vs IM 消息哪些可信)
- Prompt Injection Defense
- External Data Validation
- High-Risk Action Gates(sudo / 删数据 / 发布按钮都要 user confirmation)

**不该放什么**:
- 单一专业领域规则(放对应 director-*)
- 项目特定规则(放 CLAUDE.md)
- 单 skill 自己的流程(放对应 SKILL.md)

**路径**: `~/Documents/projects/skills/_shared/constitution.md`

**后续动作**:
1. 改完跑 `bash scripts/sync-shared.sh` 分发到 12 个 skill 的 references/
2. 跑 `git add -A && git commit && git push origin main`
3. `cd ~/.config/skillshare/skills && git pull origin main`
4. `skillshare sync --force`

---

## L2a: `_shared/<topic>.md`(skill 元规范)

**性质**: 约束 skill 自身**怎么写**的结构 / 模式规范。

**该放什么**:
- "所有 director-* 必须有 N 维 audit checklist"
- "所有 director-* 必须有 Step 0 Question Gate"
- "subagent 派工 prompt 必须显式调用 skill"
- "证据查找 5 层优先级"

**不该放什么**:
- 单 skill 自己的步骤(放对应 SKILL.md)
- 可机器 lint 的硬约束(放 skill-doctor 规则)

**路径**: `~/Documents/projects/skills/_shared/<topic>.md`

**现有 metaspec**: `director-template.md` / `evidence-discovery.md` / `question-gate.md` / `parallelization-template.md` / `handoff-payload-template.md`

**后续动作**: 同 L1(sync-shared.sh + git push + skillshare sync)

---

## L2b: `skill-doctor` 新规则(可 lint 硬约束)

**性质**: 可机器化验证的 skill 质量约束。

**该放什么**:
- "description 字段 ≤ 250 字符"
- "SKILL.md 必须有 ## Overview"
- "router-coverage(所有 director-* 在 router 里都被引用)"
- "bsd-compat(shell 脚本不能用 GNU-only flag)"

**不该放什么**:
- 需要语义判断的约束(机器查不出)
- 单次约束(写在用户提示里就行)

**路径**: `~/Documents/projects/node-scripts/src/skill-doctor/rules/<rule-name>.ts`

**后续动作**:
1. 切到 node-scripts 项目走 `flow-dev-task`(rule 实现 + fixture + test)
2. 默认 dry-run,有 fix 模式时考虑加 fixer
3. `pnpm test` 全过
4. `pnpm build` 编译 → `node dist/skill-doctor/index.js --root ~/Documents/projects/skills` 跑通

---

## L3: hook(deterministic 强制)

**性质**: 每次都必须发生、零例外、不能靠模型自觉的动作。

**该放什么**:
- "commit 前必须跑 lint"
- "修改 db schema 前必须 dry-run"
- "stop hook: 任务结束自动跑测试"
- "session-start hook: 加载项目特定 context"

**不该放什么**:
- 决策性逻辑(模型自己判断更好的事)
- 复杂多步流程(写成 skill)

**路径**:
- 用户级: `~/.claude/settings.json` 的 `hooks` 段
- 项目级: `<project>/.claude/settings.json` 的 `hooks` 段

**后续动作**: 用 `update-config` skill 配置,不要手动改 settings.json。

---

## L4: script / MCP tool(动作层)

**性质**: agent 需要真实执行命令 / 查询接口 / 读取数据的能力。

**该放什么**:
- "调用某 API 的封装命令"
- "解析某种文件格式的 parser"
- "跑 build / lint / test 的脚本"

**不该放什么**:
- 决策逻辑(skill 决策,脚本执行)
- 文档说明(skill 写)

**路径**:
- 项目脚本: `<project>/scripts/<name>.sh` 或 `<project>/scripts/<name>.ts`
- skill 内脚本: `~/Documents/projects/skills/<skill>/scripts/<name>.sh`
- MCP server: 走 `_skill-creator-official__skills__mcp-builder` 创建

**后续动作**: 脚本要可独立执行 + 有 `--help`。MCP server 走 mcp-builder。

---

## L5: nested `<dir>/CLAUDE.md`(模块级约束)

**性质**: 只对某子目录 / 某类文件生效的局部约束。

**该放什么**:
- "本目录代码风格特殊(legacy)"
- "本目录只用某种 framework"
- "本目录的文件命名规则"

**不该放什么**:
- 全项目通用规则(放项目根 CLAUDE.md)
- 跨项目通用规则(放 user 级 ~/.claude/CLAUDE.md)

**路径**: `<project>/<sub-dir>/CLAUDE.md`(Claude Code 会按目录层级懒加载)

**后续动作**: 检查这个目录的代码是否真的有差异化约束;否则下沉到顶层 CLAUDE.md 即可。

---

## L6: `director-*/`(单一专业角色)

**性质**: 单一专业领域的判断 / 审查 / 出方向 / handoff。

**5 类已实现 director-***:
| Skill | 领域 | 核心 mode |
|---|---|---|
| `director-design` | 视觉 / 设计 / 排版 | audit / direction / variants / mockup |
| `director-frontend` | 前端工程(JSX/CSS/组件) | audit / boundaries / implement / extract |
| `director-promote` | 宣发 / 推广 / 多平台发布 | audit / draft / variants / dispatch |
| `director-ops` | 装 / 卸 / setup / install | install / uninstall |
| `director-architect` | 工程规范体系 / 架构 | research / approval / land |

**该放什么**:
- 改现有 director-* 的某个 mode 内细则
- 新增专业角色(走 `flow-skill-dev`)

**不该放什么**:
- 跨角色编排逻辑(放 flow-*)
- 单 skill 实现细节(放对应 director-* 内部)
- 全局价值观(放 constitution)

**路径**: `~/Documents/projects/skills/director-<role>/`

**后续动作**:
- 改现有 director-* → 走 `flow-skill-dev` substantial-update 流程
- 新建 director-* → 照 `_shared/director-template.md` 13 段标准结构

---

## L7: `flow-*/`(跨角色编排)

**性质**: 多步流程 / 跨多个 skill / 强制阶段推进的流水线。

**7 类已实现 flow-***:
| Skill | 编排链 |
|---|---|
| `flow-dev-task` | 单任务 dev(brainstorm → plan → code → verify → commit) |
| `flow-codex-goal` | 长跑 codex 任务(GOAL/EVAL/STATUS + reviewer 仲裁) |
| `flow-ext-publish` | 浏览器扩展上架全流程 |
| `flow-project-bootstrap` | 项目初始化 |
| `flow-project-finish` | 项目收尾 |
| `flow-skill-dev` | 创建 / 改 skill 的完整流程 |
| `flow-skill-research` | 调研已有 skill 的研究流程 |

**该放什么**:
- 改现有 flow-* 的某个 step
- 新增编排流程(走 `flow-skill-dev`)

**不该放什么**:
- 单一专业判断(放 director-*)
- 一次性脚本(放 script)

**路径**: `~/Documents/projects/skills/flow-<name>/`

**后续动作**: 改 flow-* 一定走 `flow-skill-dev` substantial-update(因为流程改动会影响所有下游)。

---

## L8: `CLAUDE.md` / `AGENTS.md`(项目级常驻)

**性质**: 每次会话都加载的项目级地图 + 默认行为 + 关键 gotchas。

**该放什么**:
- 项目用什么包管理器(pnpm/npm/yarn)
- 默认运行命令(pnpm dev / pnpm test / pnpm build)
- 项目架构地图("monorepo / src/<tool>/ 独立工具")
- 关键约束("提交前必须跑 lint")
- 语言约定("commit message 中文")

**不该放什么**:
- 多步流程 / 专题 checklist(下沉到 skill)
- 模块级特殊约束(下沉到 nested CLAUDE.md)
- 一次性任务上下文(用 plan / task)

**路径**:
- Claude Code: `<project>/CLAUDE.md`
- Codex: `<project>/AGENTS.md`(通常和 CLAUDE.md 内容一致或互相 symlink)
- 用户级: `~/.claude/CLAUDE.md`(所有项目共用)

**硬约束**:
- **≤ 200 行**(Anthropic 官方建议)
- **100-150 行 + 少量引用文档**(Augment 实测推荐)
- 超了就要拆 → 把"多步流程 / 专题"迁到 skill

**后续动作**: 写完检查 `wc -l CLAUDE.md`,超 200 行立即触发"哪些段该下沉到 skill"对话。

---

## L9: auto memory(跨会话长期偏好)

**性质**: 模型在对话中自动沉淀的、跨会话加载的个人偏好 notes。

**该放什么**:
- 用户偏好(简洁回复 / 不要 emoji / 用某种 framework)
- 反复被纠正的细节(用户的工作时区 / 常用工具版本)
- 跨项目通用的工作习惯

**不该放什么**:
- 项目特定规则(放 CLAUDE.md)
- 一次性任务上下文
- 任何安全 / 价值观(放 constitution)

**路径**: `/Users/falcom/.claude/projects/<project-slug>/memory/`(每个 project 一个目录,内含 MEMORY.md 索引 + 各类 memory 文件)

**4 类 memory**:
- user(用户角色 / 知识 / 偏好)
- feedback(用户对 agent 的纠正 / 确认)
- project(具体项目的进行中状态)
- reference(外部系统资源指针)

**后续动作**: auto memory 默认自动沉淀,本 skill 只在用户**显式说"记住这个"**时主动写入。检查 Q1-Q8,确认不是其实更高优先级的层。

---

## L10: 兜底丢弃

同 L0,但走完所有 Q1-Q9 都不命中时的兜底。

**典型例子**:
- "我希望 agent 写代码更优雅" → 太抽象,落不到位置
- "下次别再这样了" → 没说"这样"是什么,没法沉淀
- "感觉 X 工具不好用" → 个人感受,无可沉淀

**后续动作**: 告诉用户为什么不沉淀;如果用户坚持,要求重新描述更具体。

---

## 跨层迁移规则

**上移**(skill → CLAUDE.md → constitution):
- 触发条件: 同一条经验在多个 skill 里反复出现
- 例: director-design 和 director-frontend 都强调"截图脱敏",上移到 constitution

**下沉**(CLAUDE.md → skill / nested CLAUDE.md):
- 触发条件: CLAUDE.md 超 200 行 / 某段只在特定任务有用
- 例: CLAUDE.md 里的"发版 checklist" 下沉为 `flow-release` skill

**横移**(director-* ↔ flow-*):
- 触发条件: 边界判断错了
- 例: 原本写成 flow-design 的其实只是设计师角色判断 → 横移到 director-design

**降级**(skill → script):
- 触发条件: skill 内容主要是 curl/命令调用
- 例: 把 skill 里的 "调 GitHub API 的 prompt" 降为 `scripts/gh-api.sh` + skill 只负责"何时调用"
