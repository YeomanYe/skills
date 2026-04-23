---
name: flow-project-rules
description: Use when a project's engineering rules (CONTRIBUTING.md, docs/<domain>/, AGENTS.md, RULE.md) need to be evaluated, consolidated, aligned with the actual tech stack, or authored from scratch — especially when rules are missing, scattered across multiple entry points, stale relative to the code, or the user wants to mirror a reference project's rule structure. 用于当前项目的工程规范需要审查、收敛、与实际技术栈对齐，或从零开始起草时；尤其适用于规范缺失、多入口散落、与代码脱节，或用户希望对齐某个参考项目规范结构的场景。
---

# 项目规范编排

## Overview

这个 skill 编排「项目规范从评估到落地」的完整链路。

它不替代 `project-rules-design`，也不替代任何具体的技术栈 best-practice skill。它的职责是：

- 识别当前项目用到的技术栈
- 在本地 skill 目录中动态匹配相关的 best-practice skill
- 串成「评估 → 建议 → 用户确认 → 落地」的闭环
- 在用户明确同意前，不修改任何规范文件

## When to Use

以下情况使用本 skill：

- 用户问「当前项目的规范合理吗」「帮我整一套规范」「规范要不要对齐一下 X 项目」
- 项目没有 `CONTRIBUTING.md` / `docs/<domain>/` / `AGENTS.md` 之类的规范体系，要从 0 建立
- 项目规则散落在 `RULE.md`、`ai/`、`AGENTS.md` 或各处 README 里，要收敛
- 用户希望参照另一个项目（本地路径或远程 git URL）的规范做一次对齐

以下情况通常不使用：

- 只改单条规则的文字或错别字
- 只讨论某个 skill 自身的写法（用 `skill-creator` / `writing-skills`）
- 只审阅一次代码实现（用 `superpowers:code-reviewer` 或对应技术栈 best-practice skill）

## Execution Default

默认一路推进到「输出可执行的改进计划，并等待用户确认」。

不允许在未收到明确确认前动任何规范文件。
只有收到用户确认后，才进入落地阶段。

## Required Workflow

按顺序执行：

1. 盘点输入
2. 识别技术栈
3. 动态匹配 best-practice skill
4. 读取规范资产（本项目 + 可选参考项目）
5. 联合评估
6. 输出改进计划 → 暂停
7. 等待用户确认
8. 落地修改
9. 输出最终报告

Step 6 之后必须停下。不允许「估计用户会同意」就直接落地。

## Step 1: 盘点输入

收集：

- 当前项目根目录（默认用 `pwd` 或 git 顶层）
- 用户是否手动指定过技术栈（例如「我这是 fresh + deno + preact」）— 以用户为准，不覆盖
- 用户是否指定过参考项目
  - 本地路径：直接用
  - 远程 git URL：`git clone --depth 1 <url> $(mktemp -d)/ref-project`，用完可删
- 用户是否点名额外的 skill

若用户未指定参考项目，跳过该项，不要编造。
若用户指定的路径或 URL 无法访问，如实告知并继续走「只评估本项目」的分支。

## Step 2: 识别技术栈（粗粒度）

只读元信息文件，不深度扫描源码：

- `package.json` → 看 `dependencies` / `devDependencies` 的主框架 key：`react`、`next`、`vue`、`nuxt`、`svelte`、`solid`、`preact`、`astro`、`remix`、`vite`、`tailwindcss`、`fresh`
- `deno.json` / `deno.jsonc` → `deno`
- `go.mod` → `go`
- `Cargo.toml` → `rust`
- `pyproject.toml` / `requirements.txt` / `uv.lock` → `python`
- `pnpm-workspace.yaml` / `nx.json` / `turbo.json` / `lerna.json` → `monorepo`
- `tsconfig.json` → `typescript`

把自动识别的栈与用户手动指定的栈合并，用户指定的优先。最终产出一份明确的 stack 列表，例如 `["fresh", "deno", "preact", "tailwindcss"]`。

不做深度代码扫描，也不猜测未出现在元信息里的栈。

## Step 3: 动态匹配 best-practice skill

在以下本地目录中扫描：

- `~/.claude/skills/`
- `~/.agents/skills/`
- `~/.config/skillshare/skills/`
- `~/.cursor/skills/`
- 当前项目的 `.claude/skills/`、`.agents/skills/`（若存在）

匹配规则（从高到低）：

1. skill 目录名或 `SKILL.md` 的 `name` 包含 stack 关键字（如 `fresh`、`preact`、`deno`、`react`、`vercel-react`、`vue`、`tailwind`）
2. `SKILL.md` 的 `description` 含 stack 关键字
3. 用户明确点名的 skill 直接纳入
4. `project-rules-design` **永远**纳入

去重后产出本次评估的 skill 列表，在计划里显式列出来源路径。某个栈若完全找不到对应 skill，如实标注「未覆盖」，不要硬套不相关的 skill。

这一步只读本地目录，不访问网络，不调用 `npx skills`。

## Step 4: 读取规范资产

本项目侧默认扫描：

- `CONTRIBUTING.md`
- `AGENTS.md`
- `RULE.md`（若存在）
- `docs/` 下所有 md
- `.claude/`、`.agents/`（若存在）

参考项目（若有）扫同一组文件。

记录清单：入口文件、正文文件、重复内容、放错层的内容、明显缺失的领域。这一层跟 `project-rules-design` 的盘点口径保持一致。

## Step 5: 联合评估

让每个被选中的 skill 在自己的职责范围内审视当前规范：

- `project-rules-design` 负责：入口结构、分域、层级、重复、混层、优先级
- 技术栈 skill 负责：该栈应该被写入规范的工程约束
  - 例：`vercel-react-best-practices` → Server Component / data fetching / 性能约束是否进入 `coding` 域
  - 例：`deno-frontend` / `deno-expert` → import map、permissions、Edge 运行期约束
  - 例：`developing-preact` → signals、islands、hydration 边界
- 用户额外指定的 skill：按其自述职责审视

评估时要明确区分「规范缺失」「规范偏差」「规范冗余」「规范放错层」四类问题。

## Step 6: 输出改进计划并暂停

计划必须包含以下节：

```md
## 项目规范改进计划

### 识别到的技术栈
- ...

### 参与评估的 skill
- <skill-name> (<路径>)
- ...
- 未覆盖的栈: ...

### 当前规范问题
- 阻塞:
- 建议:
- 可选:

### 目标结构
- 总入口:
- 分域目录与二级文件:

### 文件级变更
- 新增: <路径>
- 修改: <路径>
- 迁移: <从 → 到>
- 合并: <多个 → 一个>
- 删除: <路径>

### 遗留入口如何下线

### 若参考项目
- 参考项目路径: ...
- 借鉴哪些模式:
- 为什么 / 为什么不照搬:
```

输出后明确询问用户：**「以上方案是否可以落地？要不要调整？」**

在收到明确同意前，不得进入 Step 7。用户部分同意时，以其反馈重写计划并再次等待确认；不要把「似乎没有反对」当作同意。

以下含糊回应**不算**同意，收到时应再次澄清：

- 「嗯」「嗯嗯」「哦」
- 「ok 吧」「行吧」「好像可以」
- 「随便」「都行」「你看着办」
- 只是复述了部分计划但没有表态

明确同意至少需要类似「可以落地」「就按这个改」「go ahead」「开始吧」这种不含保留的表态，或逐条勾选哪些可改哪些不改。

## Step 7: 用户确认后落地

只执行用户已确认的部分。

落地前：

- 运行 `git status` 确认工作区干净；若不干净，提示用户并等待处理
- 若计划包含大量文件迁移，提醒用户当前 commit 可作为回退点

落地时：

- 按计划新增 / 修改 / 迁移 / 合并 / 删除文件
- 迁移内容要真实搬运正文，不只是重命名
- 更新活跃引用路径（例如 `AGENTS.md` 指向 `CONTRIBUTING.md`）
- 不允许新旧两套规则入口同时有效

落地后可建议（不强制）调用 `clean-commit` 做一次收尾提交。若用户明确要求「顺便提交」「帮我 commit」，**不要**自己 `git add` / `git commit`，转交给 `clean-commit` 处理。

## Step 8: 最终报告

```md
## 项目规范整改报告

### 输入
- 项目根: 
- 技术栈: 
- 参与 skill: 
- 参考项目: 

### 问题摘要
- 阻塞已解决: 
- 建议已采纳: 
- 用户否决: 

### 变更清单
- 新增: 
- 修改: 
- 迁移: 
- 合并: 
- 删除: 

### 遗留
- 待处理的历史引用: 
- 未覆盖的栈: 

### 下一步建议
```

## Fallbacks

- 找不到当前项目根：让用户手动指定，不要假设
- 参考项目 clone 失败：如实告知，改为只评估本项目
- 某个栈没有 best-practice skill：标注「未覆盖」，不捏造规则
- 用户只给口头指示（没有 reference、没有 stack）：按默认的「识别 → 匹配」流程走，不追问已知信息
- `project-rules-design` 不在本地：继续，但在最终报告中注明缺失的是结构评估维度

## 禁止行为

- 未经用户确认就动任何规范文件
- 直接套用参考项目的文件名和结构，不按本项目分类
- 只改文件名而不重构内容归属
- 把 best-practice skill 当成「读一下文档」就算评估
- 跳过 `project-rules-design`，只靠技术栈 skill 评估
- 保留双轨规则体系（新旧同时有效）
- 跳过 Step 6 的暂停，估计用户会同意就落地
- 技术栈识别阶段深度扫描源码或做框架推断

## 完成判定

同时满足以下条件才算本次编排完成：

- 已识别技术栈并显式列出
- 已动态匹配 skill 并列出路径
- 已读取本项目规范资产（及可选的参考项目）
- 已完成联合评估
- 已输出改进计划并**收到用户明确确认**
- 已按确认内容落地文件变更
- 已输出最终报告

若中途被用户拒绝或暂停，报告中如实记录停在哪一步、为什么停。
