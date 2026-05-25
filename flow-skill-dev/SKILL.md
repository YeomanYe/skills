---
name: flow-skill-dev
description: >
  Use when creating or substantially updating a skill — needs a structured workflow for
  scoping, authoring, testing, and reporting the result. 用于新建 skill 或对已有 skill
  做实质性更新（改触发条件 / 必要流程 / 输出契约 / handoff / 路由），需要 scope →
  writing → behavior test → integration test → sync → report 完整链路。触发短语：「写个
  skill 用来 X」、「改一下 X skill」、「新建 skill」、「create a skill for X」、
  「substantially update X skill」、「编排 skill 开发」。Do NOT use for: 只改文案 / 错别字
  / 不影响行为的 reference / 很小的 metadata 改动（minor-update 不必走 orchestrator）。
---

> 本 skill 受 `references/constitution.md` 约束(always-follow,跨 skill 通用价值观/安全/身份层)

# Orchestrating Skill Development

## Overview

这个 skill 用于编排完整的 skill 开发流程。

它不替代 `skill-creator`、`writing-skills`、`skill-behavior-test` 或 `skill-integration-test`。
它的职责是决定何时调用这些 skill、强制执行顺序，并要求真实落盘、真实测试和最终输出报告。

默认行为是执行，不是只给流程建议。

## 角色信条

**我是 skill 作者编排器,不是 skill 设计师本人;我跑流程,不替你拍 skill 该写啥。**

**写 skill 最容易死在"看起来都对,但跑起来不触发"**——一旦我跳过 behavior test
就交付,**用户带着新 skill 回去发现 description 没匹配上、references 路径写错、
handoff payload 字段名不对** = 我做了个不工作的 skill 还以为做完了。

我执行任务时心里只问一个问题:**"这个 skill 别人第一次用,有没有可能因为我没测
某条路径而当场翻车?"** 有可能 = 没做完,跟它写了多少字、references 多齐全、
中文多漂亮,**一点关系都没有**。

**真实落盘 + 真实测试**是默认,不是可选。"我先描述一下应该怎么写,你看可不可以"
不是 skill 开发,是讨论。**默认行为是执行**——我直接动手写 SKILL.md、跑 skill-doctor、
跑 behavior test,跑挂了再问,不是问完才跑。

**substantial-update 必须更新 _shared 元规范**(如果改动跨 ≥3 个 skill)。最近的教训:
5 个 director 加角色信条之后 _shared/director-template.md 没同步,下个 director 不知道
要不要加。**跨 N 个 skill 的统一模式 = 元规范级别变更,光改 skill 不算完成**。

我最容易翻的车——每一条都是"看起来在做 skill 开发,实际在交付半成品":

- **跳 behavior test** — 写完 SKILL.md 直接交付,**没跑 trigger 测试 / 没跑 references
  路径校验 / 没跑 handoff payload schema 验证** = 用户用的时候发现 description 不匹配。
  behavior test 是 step 5,不是"如果时间够"。
- **substantial-update 不更新元规范** — 改了 ≥3 个 skill 的共同段,只改 skill 不改
  `_shared/`,**下一个新 skill 跟旧 skill 不一致** = 仓库走向碎片化。
- **写文档式 skill** — 把 SKILL.md 当 README 写"这个 skill 介绍 / 主要功能 / 使用方法"
  = **skill 不是文档,是 agent 的执行脚本**。"使用方法"段不需要,trigger 短语 + Required Workflow
  + Output Contract 才需要。
- **scope 失控** — "我写到一半发现还得加个 mode" = **scope 漂移,原 scope 没收口就铺更大**。
  Step 3 锁定 scope 之后,新需求记到 follow-up,不在当前 skill 里加。
- **越界做 skill 内容判断 / 做产品决策** — 我管编排 + 阶段顺序 + 真实测试;
  **skill 该不该写、写什么找用户拍板;写得好不好用 skill-behavior-test 评;
  多 skill 协同测试用 skill-integration-test**。越界 = 假装自己什么都懂 = 让每个环节
  都做半吊子。

## When to Use

以下情况使用本 skill：

- 新建一个 skill
- 对已有 skill 做实质性流程变更
- 修改 skill 的触发条件、输出契约、路由行为或 handoff 行为
- 准备把 skill 交付为可复用能力，并希望补齐测试与交付报告

以下情况通常不要使用本 skill：

- 只修正文案、错别字
- 只补充不影响行为的 reference 内容
- 只改很小的 metadata，且不影响触发和流程

## Execution Default

当本 skill 被触发时，默认直接推进到可交付产物，除非缺少关键上下文。

默认应执行到以下终点：

- 真实创建或修改目标 skill 文件
- 真实创建或修改目标 `tests/` 用例
- 真实执行行为测试
- 命中 gate 时真实执行集成测试
- 当目标 skill 需要进入全局复用范围时，调用 `sync-skills`
- 输出最终报告

不要停留在：

- 只给流程建议
- 只给 `SKILL.md` 草稿
- 只给测试思路，不实际补用例
- 只说“建议运行测试”，但没有实际执行

只有在以下情况下才应暂停并向用户说明：

- 缺少目标 skill 名称或目标位置，且无法合理推断
- 本次请求的职责边界本身不清，继续写会导致 skill 定义错误
- 工作区存在直接冲突，无法安全落盘

## Required Workflow

必须严格按以下顺序执行：

1. 先判定本次工作类型
2. 定位权威副本（在中心仓库则切到中心仓库）
2.5. **Pre-flight: 检查远端冲突意图**（新增,防止多 agent 并发改同一 skill）
3. 调用 `skill-creator` 理清范围与契约
4. 调用 `writing-skills` 编写或修订 skill
5. 运行 `skill-behavior-test`
6. 判定是否需要 `skill-integration-test`
7. 若需要，则运行 `skill-integration-test`
8. 判定是否需要调用 `sync-skills`
9. 输出最终报告

在最终报告完成前，不得宣称该 skill 已准备就绪。
除非命中暂停条件，否则不要在中途停下来等待用户二次确认。

## Step 1: Classify the Work

先判断本次请求属于哪一类：

- `new-skill`
- `substantial-update`
- `minor-update`

若改动涉及以下任一项，应视为 `substantial-update`：

- 触发条件
- 必要流程
- 禁止行为
- 输出契约
- handoff 契约
- 上下游路由行为

如果只是 `minor-update`，通常不必使用这个 orchestrator。**但 Step 2 的"在中心仓库 → 在中心仓库改"规则对所有 update 都适用**——即便绕过 orchestrator 直接用 Edit 改单行，也得先确认 cwd 在中心仓库副本，否则同样会被下次 skillshare sync 覆盖丢失。

## Step 2: Locate Authoritative Copy

在执行任何编辑动作之前，**必须**确定本次修改要作用在哪个物理副本上。规则按以下优先级判定：

1. **中心仓库**：`~/Documents/projects/skills/<skill-name>/`
2. **AI 工具同步目标**（plugin 安装位置）：
   - `~/.claude/skills/_<plugin>__<skill-name>/`
   - `~/.claude/skills/_<plugin>__skills__<skill-name>/`
   - `~/.agents/skills/...`
   - `~/.codex/skills/...`
   - `~/.config/skillshare/skills/<skill-name>/`
3. **项目内 skill**：`<project-root>/.skillshare/skills/<skill-name>/` 或类似

**判定与切换规则**：

```bash
center="$HOME/Documents/projects/skills/<skill-name>"
if [[ -d "$center" && -f "$center/SKILL.md" ]]; then
  # 中心仓库已有该 skill → 强制在中心仓库改
  authoritative_dir="$center"
else
  # 中心仓库没有 → 用用户当前所在或指定的位置
  authoritative_dir="<current-location>"
fi
cd "$authoritative_dir"
```

**为什么强制在中心仓库改**：

- `~/Documents/projects/skills/` 是 [[sync-skills]] 推到 GitHub 的**单一事实源**（`YeomanYe/skills` repo）
- 其它位置（`~/.claude/skills/` 等）是 **下游副本**：由 skillshare 工具用 `git pull` / `skillshare sync` 从 GitHub 拉取
- 改下游副本 → 下次 `skillshare sync --force` 会被 GitHub 上游的旧版本覆盖，**改动丢失**
- 改下游副本然后 `sync-skills` 反向推 → 中心仓库会得到 plugin 前缀剥离过的目录，但工作流上**绕过了正常的 git 历史**

**报告里必须显式声明**：

```
authoritative_dir: ~/Documents/projects/skills/<name>/   # 或其它位置
chose_center: true | false（false 时说明原因，如 "中心仓库无此 skill，本次是 new-skill"）
```

**唯一例外**：用户在**当前会话里显式提出**要在下游副本改（典型措辞："只想本地试一下、不打算回流到中心" / "就改 ~/.claude 下面的那份" / "别动中心仓库" / "I just want to patch the installed copy"）→ 才可以在下游副本改。

**❌ 严禁 agent 主动走例外路径**：
- 不允许 agent 自己建议"要不要在下游改?"
- 不允许 agent 询问"我可以改这里吗?"——默认行为永远是**自动切回中心仓库**，不需要用户确认
- 不允许从历史会话 / memory 推断"用户上次说过" → 例外必须是**当前会话**的显式陈述
- 走例外时**必须在最终报告里 flag 警告**"该改动不会进入 GitHub source，下次 skillshare sync 会被覆盖"

## Step 2.5: Pre-flight — 检查远端冲突意图

**为什么必跑**：多 agent 并发改同一 skill 会出现"我设计 A 版,另一 agent 已 push B 版,我 push 时冲突"。在动手前 fetch + diff 检查能秒发现冲突意图,避免推完发现要 reset/重做。**Step 2 已经决定了 `authoritative_dir`,Step 2.5 据此分支跑命令**。

**按 authoritative_dir 类型分支执行**:

### 分支 A: 中心仓库 `~/Documents/projects/skills/`(99% 情况)

```bash
cd ~/Documents/projects/skills

# 1. fetch 最新远端,但不 merge(只看)
git fetch origin main

# 2a. 现有 skill: 看远端有没有改 <skill-name>/ 下的文件
git log HEAD..origin/main --oneline -- <skill-name>/

# 2b. new-skill 额外查: 远端是否已有同名 skill(防止跟别的 agent 撞名)
git ls-tree origin/main -- <skill-name>/ 2>/dev/null

# 3. 看本地有没有未提交改动跟该 skill 相关
git status --short <skill-name>/
```

**判定**:

| 远端有改动? | 本地有改动? | 行动 |
|---|---|---|
| 无 | 无 | ✓ 直接进 Step 3 |
| 无 | 有 | ✓ 进 Step 3(本地是之前会话延续或正在改) |
| **有** | 无 | **停止,问用户**:"远端已有 N 个 commit 改了 `<skill>/`,要 merge/rebase 后再改,还是丢弃远端继续我的设计?" |
| **有** | 有 | **停止,问用户**:同上 + 建议 `git stash` 暂存本地未提交内容,再决定 merge/rebase/丢弃 |
| new-skill 命中已有同名 | — | **停止,问用户**:"远端已有同名 skill `<name>`,是冲突(rename)还是接力(继续他人设计)?" |

### 分支 B: skillshare clone `~/.config/skillshare/skills/_YeomanYe-skills/`

**硬阻断**:该路径是 skillshare 的 source clone,**禁止直接修改**(改动会被下次 `git pull` 覆盖,且无法回流 GitHub)。

**默认动作(不询问用户)**:**自动**返回 Step 2,把 `authoritative_dir` 改为 `~/Documents/projects/skills/<name>/`,在中心改完后通过 sync-skills 分发到 skillshare clone。**不要问用户"要不要在下游改"** —— 唯一允许走例外的触发是 Step 2 例外条款里规定的"用户在当前会话里显式提出"。

### 分支 C: 项目级 `.claude/skills/` 或 `.skillshare/skills/`

**项目级 skill,跳过 Step 2.5**(项目 git 不是 skills repo,无远端冲突风险;但 Step 8 sync 仍按项目自己的 git remote 处理)。

### 分支 D: 用户级 `~/.claude/skills/`(skillshare 同步 target)

**硬阻断**:该路径是 skillshare 的 sync target(symlink 或 copy),不是源,**禁止直接修改**(改这里不会进任何 git,下次 `skillshare sync --force` 会覆盖)。

**默认动作(不询问用户)**:**自动**返回 Step 2 切到中心仓库,不询问用户是否要破例。例外触发同分支 B —— 必须用户在当前会话里显式提出。

---

**禁止**:
- ❌ "我先做,push 失败再说" — push 失败的代价是 rebase + 可能完全重做
- ❌ 跳过 Step 2.5 直接进 Step 3 — 即使你"觉得"远端不会冲突,也必须实跑命令
- ❌ 看到冲突就自动 `git reset --hard origin/main` 或 `git merge` — 必须让用户决定取舍
- ❌ 在分支 B/D 警告下硬改 — 改了等于白改
- ❌ **agent 主动建议用户"要不要在下游改"** — 唯一例外路径必须由用户**自己**提出,agent 不得引导
- ❌ **agent 询问"我可以直接改 ~/.claude/skills/ 这份吗?"** — 默认动作就是自动切回中心仓库,不需要确认轮次

**例外**:
- minor-update 不走本 orchestrator → 不适用 Step 2.5
- 自指场景(用 flow-skill-dev 改 flow-skill-dev 自己): 仍按分支 A 跑,实测可终止无死循环

## Step 3: Scope With `skill-creator`

在编写或修订 skill 之前，必须先用 `skill-creator` 理清：

- 这个 skill 负责什么
- 什么情况应该触发
- 什么情况不该触发
- 它是单体能力还是多-skill 链路中的一环
- 是否需要额外资源

此步骤结束后，必须提炼并记录：

- skill 名称
- 触发条件
- 边界
- 所需资源
- 预期输出或 handoff 产物

如果这些信息已经能从当前请求和上下文中可靠推断，应直接整理并继续，不要为已知信息重复追问用户。

## Step 4: Author With `writing-skills`

使用 `writing-skills` 编写或修订 skill 正文。

如果当前环境中的 `writing-skills` 明确要求先满足某个前置 skill 或前置方法论，也必须先补齐该前置条件，再继续进入编写阶段。

这一阶段必须产生真实文件变更，而不是只输出建议文本。

执行时强制遵守以下规则：

- **语言约定**：SKILL.md 正文、`tests/` 用例、`references/` 等附加资产默认使用中文；技术术语、工具名、命令、配置键、文件路径、代码、frontmatter 字段名保持英文原文不翻译
- **description 语言**：frontmatter 的 `description` 允许中英文并存——可以纯中文、纯英文或中英混合列出触发短语，目的是提升跨语言召回（例如同时写 "项目初始化" 与 "bootstrap this project"）
- frontmatter 的 description 只写触发条件，不要摘要化流程
- 正文保持简洁、偏流程化
- 不要把下游测试 skill 的完整内容复制进来
- 如果可复用测试场景有价值，应补充 `tests/` 资产
- 尽量写成明确 gate，不要写模糊建议

至少应创建或更新：

- 目标 skill 的 `SKILL.md`
- 必要时的 `tests/cases.md` 或等价测试用例文件

## Step 5: Run Behavior Testing

在宣称 skill 已可用之前，必须运行 `skill-behavior-test`。

行为测试至少覆盖：

- 一个正例触发场景
- 一个反例触发场景
- 一个主流程成功场景
- 一个负例或护栏场景

如果 skill 目录下已经有可复用的 `tests/`，必须优先复用。
不要只生成测试提示词而不执行测试。

## Step 6: Decide Whether Integration Testing Is Required

集成测试是“条件必跑”，不是一律必跑。

若满足以下任一条件，必须运行 `skill-integration-test`：

- 该 skill 会参与多-skill 工作流
- 该 skill 会将工作 handoff 给其他 skill
- 该 skill 依赖上游 skill 提供 plan、handoff、evidence 或 contract 输入
- 该 skill 本身就是 orchestrator、router、gate 或 workflow coordinator
- 本次改动影响路由、handoff 字段、上下文传递或“禁止重复追问”策略

只有同时满足以下条件，才可以跳过集成测试：

- 该 skill 是单体能力
- 本次改动不影响触发条件或流程契约
- 本次改动不影响上下游协作

若跳过集成测试，必须在最终报告中说明原因。

## Step 7: Run Integration Testing When Required

当集成测试是必需项时，使用 `skill-integration-test` 验证：

- 是否正确进入 skill 链路
- 是否正确 handoff 给下游 skill
- 关键约束和产物是否完整保留
- 在上下文已足够时是否避免冗余追问
- 是否避免过早宣称完成

不要把“理论上应该能衔接”当作集成测试通过；至少要完成一次基于真实 skill 文件和测试资产的链路检查。

## Step 8: Sync To Center When Needed

**前置说明**：如果 Step 2 已经把工作锁定在中心仓库（`chose_center: true`），那么 `sync-skills` 的"复制"动作就不必要了——文件已经在中心仓库就位。此时本步骤简化为：

- 在中心仓库目录下 `git add <skill-name> && git commit && git push`（如果是 IM 会话且配置了 remote）
- 跳过 `sync-skills` 调用，但在报告里说明"已在中心仓库直接修改 + 已 git 提交，无需调用 sync-skills"

只有 Step 2 选择了**非中心位置**（如新建 skill 直接写在项目内、或用户明确要本地试改）才需要走下面的 sync-skills 决策树。

---

`sync-skills` 不是一律必跑，而是条件必跑。

若满足以下任一条件，应在收尾阶段调用 `sync-skills`：

- 用户明确希望该 skill 进入全局复用范围
- 该 skill 不仅用于当前项目，还应在其他上下文中复用
- 本次工作目标明确包含“发布到全局”或“纳入 skillshare source”

若满足以下任一条件，则不要调用：

- 该 skill 明确只应保留在当前项目内
- 当前产物仍是半成品，不应覆盖全局版本
- 用户明确表示本次只做本地迭代，不做全局发布

若调用该 skill，默认只同步到中心源头 `~/Documents/projects/skills/`（推 GitHub `YeomanYe/skills`）。

注意：`~/.config/skillshare/skills/` 是 skillshare 工具的 **source clone**（同一 GitHub
repo 的另一个 working copy），由 skillshare 用 `git pull` / `skillshare update` 拉取，
**不应**用 `rsync` 等手段从开发位置硬覆盖（那会污染 skillshare 的 git 状态，绕过 GitHub
单一事实源）。

不要把"同步到编辑器或 agent 自己的全局目录"（如 `~/.claude/skills/`）视为该步骤的职责。
那是 skillshare 的 sync target，由 `skillshare sync --force` 处理。

若跳过该步骤，必须在最终报告中明确说明原因。

### Push 失败的诊断

如果 Step 8 的 `git push origin main` 失败(typically `rejected (non-fast-forward)`),按以下顺序检查:

1. **首要怀疑: 漏跑 Step 2.5** — 远端在本会话期间已有新 commit,本地需 rebase。补跑 `git fetch origin main && git log HEAD..origin/main` 看远端有什么
2. **正确恢复**: `git stash`(若有未提交)→ `git pull --rebase origin main` → `git stash pop` → 解冲突 → `git push`
3. **永远不要** `git push --force` 来"解决"这种 push 失败 — 那会冲掉别的 agent 的工作

## Missing Dependency Fallbacks

如果目标环境缺少某个依赖 skill，不要直接中断；应退化为最小可执行流程，并在最终报告中明确说明。

### `skill-creator` 缺失

如果 `skill-creator` 不可用，至少要手工补齐以下设计输入后，才能继续编写：

- skill 名称
- 触发条件
- 不应触发的场景
- 核心职责
- 边界
- 是否属于多-skill 链路
- 预期输出或 handoff 产物

若以上信息仍不完整，不应继续进入编写阶段。

### `writing-skills` 缺失

如果 `writing-skills` 不可用，按以下最小写法手工完成：

1. 先写正反触发场景
2. 再写最小可用的 `SKILL.md`
3. 明确禁止行为与完成判定
4. 补充可复用的 `tests/` 用例骨架
5. 再进入行为测试

不要因为 `writing-skills` 缺失就跳过测试或直接宣称完成。

### `skill-behavior-test` 缺失

如果 `skill-behavior-test` 不可用，至少手工完成以下四类检查，并记录到最终报告：

- 正例触发
- 反例触发
- 主流程成功场景
- 护栏或负例场景

手工验证不等于免测，只是降级执行。

### `skill-integration-test` 缺失

如果 `skill-integration-test` 不可用，但当前 skill 命中了集成测试 gate，至少手工检查：

- 上游输入是否足够让下游接手
- handoff 字段是否完整
- 是否会重复向用户追问已知信息
- 是否会过早宣称完成

这种情况不得标记为“完整通过的集成测试”，只能标记为“手工链路检查已完成”。

## Step 9: Write the Final Report

始终以书面报告收尾，使用以下结构：

```md
## Skill Development Report

### 目标
- Skill:
- 路径:
- 范围:
- 类型: new | update
- authoritative_dir:                 # Step 2 决定的修改作用位置
- chose_center: true | false         # 是否在中心仓库 `~/Documents/projects/skills/` 改；false 时下方写原因
- chose_center_reason:                # 仅 chose_center=false 时填

### 设计摘要
- 触发条件:
- 核心职责:
- 边界:
- 所需资源:

### 编写流程
- skill-creator:
- writing-skills:
- 文件变更:
- 备注:

### 行为测试
- 状态:
- 测试方式: skill | manual
- 关键用例:
- 发现:

### 集成测试
- 是否必需:
- 状态:
- 测试方式: skill | manual | skipped
- 原因:
- 发现:

### 中心同步
- 是否需要:
- 状态:
- 测试方式: sync-skills | skipped
- 目标路径:
- 原因:

### 风险
- 风险 1:
- 风险 2:

### 结论
- 可交付:
- 需要修订:
- 建议下一步:
```

最终报告还必须包含：

- 本次新增或修改的文件路径
- 是否真实落盘
- 是否真实执行了行为测试
- 是否真实执行了集成测试，或为何跳过
- 是否真实执行了中心同步，或为何跳过

## Completion Rules

如果出现以下任一情况，则该 skill 不应被视为完成：

- 新建 skill 或实质性更新时跳过了 `skill-creator`
- 没有运行 `skill-behavior-test`
- 集成测试是必需项但没有执行
- 跳过了集成测试但没有给出理由
- 需要进入全局复用范围但没有调用 `sync-skills`
- 缺少最终报告
- 只输出建议，没有实际创建或修改 skill 文件
- 只写了测试思路，没有实际执行测试

若因依赖缺失而走降级流程，最终报告中还必须额外说明：

- 缺失的是哪个 skill
- 使用了哪种降级方式
- 因降级而残留的风险是什么

## Minimal Operating Principle

这个 orchestrator 的存在，是为了拦住三类常见失败：

- 在触发条件和边界尚未明确时就开始写 skill
- 写完 skill 但还没测试就宣称可用
- 把链路影响型改动误当成单 skill 改动

它默认是一条执行链，而不是一份建议清单。

## Codex Delegation Hook

Codex 是对等 agent，能做本 skill 的所有执行工作（包括 writing-skills 内部）。是否派工取决于 **ROI**（净收益 = 省 Claude token + 并行性 - SPEC 成本 - 协调成本 - review 成本 - 质量风险）。

### 🔴 低 / 负 ROI 不建议派（覆盖本 skill 全部步骤）

**核心原因：SPEC 压缩比 ≈ 1**。

要让 Codex 写出合格的 SKILL.md，Claude 必须把以下全部写进 SPEC：
- 触发关键词列表（5-15 个）
- 流程步骤（10-20 步）+ 每步的 gate
- Red Flags 措辞
- Rationalizations 反例
- Output Contract 字段

**这些写完，SKILL.md 已经被 Claude 设计完了 80%**。派 Codex 只剩 20% 的"格式化/排版"工作，但要承担：
- 协调成本（启动 Codex + 传 SPEC + 收结果）
- Review 成本（必须逐字检查触发条件、gate、Red Flag 措辞是否准确）
- 质量风险（一句话措辞失准就让 skill 触发不到/放过违规）

**ROI 净值通常为负**。

### 各步骤独立判断

| 步骤 | 工作性质 | ROI |
|---|---|---|
| Step 1 分类 | 决策 | 🔴 |
| Step 2 skill-creator scope | 设计输入梳理 | 🔴 |
| **Step 3 writing-skills** | **写 SKILL.md** | **🔴 SPEC ≈ 输出，无压缩** |
| Step 4 skill-behavior-test | 测试设计 | 🔴 需理解 skill 契约 |
| Step 5-6 skill-integration-test | 链路验证 | 🔴 全局判断 |
| Step 7 sync-skills | 一条 Bash | 🔴 自跑 1 秒 |
| Step 8 最终报告 | 整理输出 | 🔴 上下文依赖 |

### 例外：批量"按模板复制"场景

如果你要**按已有 skill 模板批量克隆 30+ 个变体**（如 lark-* 系列），SPEC 撰写成本可能 < 输出。但这种场景罕见，且即使如此每个克隆出来的 skill 仍需 Claude 逐个调整触发条件——派工净收益不显著。

派工细则全部以 `flow-dev-task` 的 Codex Delegation Hook 为唯一规范，不在本 skill 重复。
