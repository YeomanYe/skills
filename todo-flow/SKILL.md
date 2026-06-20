---
name: todo-flow
description: >
  TODO Flow 流水线(TODO → spec → dev → done)人手触发端点(human-facing endpoints)。
  6 模式:`init`(项目接入 / onboard) / `add`(加带 slug 的 TODO) / `adjust`(调整未起 spec 的 TODO 顺序与 hints) /
  `revise`(给已 verify 的 spec 写返工指令 + status → needs-rework) /
  `exec`(前台 orchestrator 自闭环跑 stage1→2→3 直到 verified/blocked) /
  `done`(审 ready spec + squash merge + semver bump + CHANGELOG;旧名 review-merge)。
  触发短语:「todo-flow <mode>」/「初始化 todo-flow」/「加 TODO」/「调整 todo 顺序」/「修订 spec」/
  「批量执行 todo」/「自动循环 stage 直到 verified」/「done 这个 todo」/
  「setup todo-flow / add todo / reorder / revise spec / auto-loop until verified」;
  兼容旧名:「todo-driver <mode>」/「review-merge」。
  Do NOT use for: 改/删 slug、不带 slug 的备忘、通用 PR review(→ requesting-code-review)、
  stage 1/2/3 cron prompt 本身、长跑无验收标准的 codex 后台任务(→ flow-codex-goal)。
---

# todo-flow

## Overview

本 skill 是 TODO Flow 流水线**人手触发**的六个端点。每个 mode 一次调用只做一件事,不混做。中间的 stage 1(起草 spec)/ stage 2(开发 + push branch)/ stage 3(验证 + 飞书回传)由 cron 喂的 prompt 接管(见 `references/stage1-prompt.md` / `stage2-prompt.md` / `stage3-verify-prompt.md`),不在本 skill 范围。

核心原则:
- **一次调用只处理一个 mode**,不混做
- mode 解析有明确顺序,不靠模糊推测
- 共享约束严格对齐(slug 格式 / frontmatter 字段名 / 工程规范源头)
- 高风险动作(merge / push / 删 branch)有硬护栏

**角色信条**(调度员不是工人;`done` 是核武器;5 类最容易翻的车)见 `references/role-doctrine.md` — 接到任何 mode 前先读。

## When to Use

满足任一即可触发:
- 用户想把一个项目接入 todo-flow 流水线(无 `TODO.md` / `docs/spec/` 的工程)
- 用户描述了一个想加进 `TODO.md` 的新需求/功能/重构
- 用户想给一个**还没起 spec** 的 TODO 改顺序 / 修改内容 / 补 hints
- 用户想给一个已经 stage2/3 跑过的 spec 写返工指令(verify-failed 或不满意 verified)
- 用户想前台自闭环跑完一批 spec(stage1→2→3 直到 verified 或 blocked,无人审介入)
- 项目有 `docs/spec/*.md` 文件且其中至少一个 `status: ready-for-review` / `verified`,用户希望审核并完成
- 用户在 todo-flow 流水线相关的上下文里提及 init / add / adjust / revise / exec / done / review / merge 这类动作

## When NOT to Use

- 用户在做不需要编号面板、也不需要 commit/push 的随手 TODO 文案小改(直接 Edit)
- 用户只想随手记一行不需要被流水线处理(直接 Edit TODO.md)
- 用户在做通用 PR 审查(用 `requesting-code-review`)
- 用户要 merge 一个不在 todo-flow 流水线里的分支(直接 `git merge`)
- 用户在问"如何用 todo-flow"等元问题(解释,不真的执行)

## Mode 速查表

| Mode | 用途 | 主要触发短语 | 副作用 | 风险 | 详细流程 |
|---|---|---|---|---|---|
| `init` | 项目接入流水线 / onboard | "初始化"/"接入"/"setup"/"onboard" + "todo-flow" | 创建 `TODO.md` + `docs/spec/` + 改 `.gitignore`;幂等 | 低 | `references/mode-init.md` |
| `add` | 加带 slug 的 TODO | "新建"/"加"/"add" + "TODO"/"待办" | 在 `TODO.md` 对应段末追加一行 | 低 | `references/mode-add.md` |
| `adjust` | panel 调整未起 spec 的 TODO 顺序与 hints | "调整"/"排序"/"补思路"/"panel"/"reorder" + todo/slug | panel 模式连续改 `TODO.md`;退出后 commit + push | 低 | `references/mode-adjust.md` |
| `revise` | 给已 verify 的 spec 写返工指令 | "修订"/"revise"/"rework"/"needs-rework" + spec/todo | spec 头部插 `## Rework instructions`,status → `needs-rework`,commit + push | 中 | `references/mode-revise.md` |
| `exec` | 前台 orchestrator 自闭环跑 stage1→2→3 直到 verified/blocked | "批量执行"/"自动循环 stage"/"auto-loop"/"foreground orchestrator" + todo/spec | per-stage subagent + 心跳轮询 + 自动重做 verify-failed + director-* AND-pass + IM 同步推;**不自动 done** | 中 | `references/mode-exec.md` |
| `done` | 审 ready spec + squash merge + semver bump + CHANGELOG | "done"/"完成"/"审"/"合并"/"merge" + ready/spec;旧名 `review-merge` | squash merge + 归档 spec 到 `_done` + 删 branch/worktree + push 默认分支 + semver bump + CHANGELOG | **高** | `references/mode-done.md` |

## Resolving Mode

按以下顺序判定:

1. **用户显式指定**(如 `todo-flow init` / `todo-flow add` / `todo-flow adjust` / `todo-flow revise` / `todo-flow exec` / `todo-flow done`;旧 mode `todo-flow review-merge` 与旧 skill 名 `todo-driver <mode>` 同样兼容)→ 用指定的
2. **触发短语推断**:按上表"主要触发短语"列匹配
3. **状态推断**(兜底):
   - 项目根**没有** `TODO.md` 也**没有** `docs/spec/` → 倾向 `init`
   - 项目根有 `docs/spec/*.md` 且至少 1 个 `status: ready-for-review` / `verified` → 倾向 `done`
   - 否则 → 倾向 `add`(注:`adjust` / `revise` / `exec` 不进兜底——需要明确意图)
4. **模糊但含"跑/执行/批量/自动/无人值守/auto"等动作词** → 用 AskUserQuestion 在 `exec` / `done` 之间二选一(都是"推进流水线"语义,但安全等级差很多);**不要**默认 `add`
5. **仍模糊** → 用 AskUserQuestion 多选一(init / add / done / exec)

判定后**立即声明**当前 mode(一句话),再开始执行。用户在调用上下文里明确给了 mode 就不要二次确认。

> ⚠️ **历史改名**:
> - v1 的 `init` 是"追加 TODO",v2 重命名为 `add`,`init` 这个词回归"初始化"本意。看到旧调用 `todo-flow init` 而上下文是"加 todo"语义时,自动按 `add` 处理并提示一次新名字。
> - skill 旧名是 `todo-driver`,现名 `todo-flow`。看到 `todo-driver <mode>` 时按 `todo-flow <mode>` 处理,并在报告里提示一次旧名兼容。
> - 最终收口 mode 旧名是 `review-merge`,现名是 `done`。看到 `review-merge` 时按 `done` 处理,并在报告里提示一次旧 mode 兼容;对外输出优先使用 `mode: done`、`verdict: done`。

## Mode 入口判定(每个 mode 一句话)

### `init`
**一句话**:把普通工程初始化为支持 todo-flow 流水线(幂等)。
**入口判定**:项目根没 `TODO.md` 或没 `docs/spec/` + 用户说"初始化/接入/setup todo-flow"。
**详细流程**:`references/mode-init.md`(6 步:probe → collect → skeleton → gitignore → commit/push → verify)

### `add`
**一句话**:向 `cwd/TODO.md` 追加一条带 slug 的新 TODO。
**入口判定**:有 `TODO.md` + 用户说"加/新建 TODO"+ 给了 summary。无 `TODO.md` 时拒绝并提示先 `init`。
**详细流程**:`references/mode-add.md`(5 步:probe → collect inputs → slug → append → verify)

### `adjust`
**一句话**:进入 panel,连续调整**还没起 spec** 的 TODO 顺序/内容/hints,退出时一次性 commit + push。
**入口判定**:有 `TODO.md` + 用户说"调整 todo 顺序/补 hints/panel"。
**详细流程**:`references/mode-adjust.md`(7 步,panel 持续到用户说"退出/exit/done")

### `revise`
**一句话**:给已 stage2/3 跑过的 spec 写返工指令,status → `needs-rework`,等下次 stage2 拾起重做。
**入口判定**:存在 spec status ∈ `{ready-for-review, verified, verify-failed}` + 用户说"修订 spec/rework"。
**详细流程**:`references/mode-revise.md`(5 步:列候选 → 显示上下文 → panel 收指令 → 写 Rework instructions → commit/push)

### `exec`
**一句话**:前台 orchestrator 自闭环跑 stage1→2→3 直到 verified 或 blocked,**不自动 done**。
**入口判定**:用户说"批量执行/自动循环/auto-loop until verified" + 指定 project 或 slug 列表。
**详细流程**:`references/mode-exec.md`(入口流程 + 关键设计 + 5 种 blocked 触发);完整 prompt 在 `references/exec-orchestrator-prompt.md`,Step 2 必读全文 + 字面替换占位符。

### `done`
**一句话**:审 ready/verified spec + squash merge + semver bump + CHANGELOG + 清理 branch/worktree。**4 个不可逆动作打包,核武器**。
**入口判定**:存在 `status: ready-for-review` 或 `verified` 的 spec + 用户说"done/完成/合并/merge"。0 个候选 → idle。
**详细流程**:`references/mode-done.md`(11 步:list candidates → pick → prepare → hard gates → acceptance → engineering rules → diff audit → review report → pass/reject 分叉 → epic auto-close)

## Shared Constraints

四个 mode 都必须遵守,**不可妥协**:

### Slug 格式
正则 `^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$`,kebab-case,3-30 字符。slug 是流水线内部标识,**不论项目本身用什么语言,slug 永远是 kebab-case 英文**。

### 写入内容的语言:中文

**TODO.md 与 spec 文件里所有用户可读的文本内容一律用中文**——这是中文项目的硬约定。

| 位置 | 必须中文 | 例外(保持英文/原文) |
|---|---|---|
| `TODO.md` 行的 title / summary / hints | ✅ | 文件路径 / API 名 / 命令 / 第三方库名 / 代码片段保持原文 |
| spec frontmatter `title` | ✅ | — |
| spec 七章正文(目标/现状/方案/推荐/影响/验收/风险) | ✅ | 同上 |
| spec 验收 `- [ ]` checkbox 描述 | ✅ | — |
| spec Decisions log / ❌ 反例 | ✅ | — |

**永远是英文 / 保持原状**:`slug` 本身、frontmatter 字段名、枚举值(`approved` / `ready-for-review` / `true` 等)、conventional commits 前缀(`feat:` / `docs:` / `chore:`,body 可中文)、代码 / 路径 / API / 库名 / 命令。

**判定原则**:结构性字段(字段名 / 枚举 / 标识符)保持英文;叙述性内容(人读的句子)一律中文。

### Spec frontmatter 字段名(严格对齐 stage 1/2/3 prompt + exec-orchestrator-prompt.md + cases.md)

**基础字段**(各 mode 都用):
`id` / `title` / `status` / `kind` / `epic` / `depends_on` / `attempts` / `project_root` / `needs_visual_check` / `needs_video_check` / `created` / `updated`

**stage3 / done 相关**(可选,按需写):
`verify_attempts` / `verified_at` / `verify_failed_at` / `change_type`(added/changed/fixed) / `bump_hint`(patch/minor/major)

**exec 相关**(可选,按需写):
`director_audit`(`always` / `last-pass`(默认) / `never`) / `required_directors`(数组,空则自动嗅探)

> ⚠️ 旧字段 `self_approved` / `self_approved_reasons` 在 v2 stage1 prompt 中已删除(所有 spec 一律 `status: approved`)。如读到老 spec 仍带这两个字段,忽略即可。`exec` 模式**忽略** `self_approved` 字段,强制按 approved 进 stage2。

### 工程规范源头(三级回退)
1. `<project-root>/AGENTS.md`
2. `<project-root>/CLAUDE.md`
3. 通用规则(lint / typecheck / tests / 无意外依赖)

### TODO.md 格式
```md
- [ ] `<slug>` <title> — <summary> (<hint 1>; <hint 2>; <hint 3>)
```

- `- [ ]` = 未合并(pending / draft / approved / in-progress / ready)
- `- [x]` = 已合并(由 done mode 在 merge 后改)

**hints 抽取规则**(stage1 / agent 都按此处理):
- 行末**一对**括号 `( ... )` 内是 hints;正则 `\(([^)]+)\)\s*$` 抽出整段
- 整段内用**英文分号 `;`** 分隔成多条;中文逗号 / 英文逗号 / 中文分号 **都不当分隔符**
- 每条 hints 是对本 spec 的硬性约束。语义自由,由 stage1 路由到 spec 对应章节
- 无 hints 时整对括号可省略

示例:
```md
- [ ] `theme-toggle` 主题切换 — 三态切换 (复用 src/hooks/useDarkMode; 不引入新依赖; 必须支持 RTL)
```

### 高风险动作护栏
- merge / push main / 删 branch 都属高风险,**永远不 force**
- IM 会话调用即视为 full flow 授权;终端调用且 main protected → push 失败让用户手动
- 工作树脏 → refuse;半成品 commit → stop 不静默继续
- 不修改 stage 1/2 prompt 的状态机定义(cron 端的文件不动)

### 不重复追问
若用户在调用 prompt 里已经把 mode + summary / slug + 其他参数说全 → 不再追问,直接执行。

## Output Contract

每个 mode 的具体 JSON 字段在各自 各 mode 的 reference 文件(`mode-init.md` / `mode-add.md` / `mode-adjust.md` / `mode-revise.md` / `mode-exec.md` / `mode-done.md`,均在 `references/` 下) 的 `## Output Contract` 段定义。

**跨 skill 基线 JSON schema**(`verdict` / `must_fix` / `artifact_path` 等)以及 markdown 报告落盘约定见共享文件 `references/output-contract-schema.md`,本 skill 各 mode 的字段是基线 + mode 专属扩展。

## Subagent 派工(仅 `exec` mode)

`exec` 模式 per-stage 派 subagent 跑 stage1/2/3;派工 prompt 字段集 + subagent 行为约束(必填字段、skill invocation directive、handoff payload、IM 出口单一规则等)遵循共享模板 `references/dispatcher-template.md`。

`exec` 自身的 orchestrator prompt(主 agent 自己用,不派下去)见 `references/exec-orchestrator-prompt.md`,SKILL 解析 `exec` mode 时必读全文 + 字面替换占位符。

## Templates / Reference Files

| 文件 | 用途 | 何时取出 |
|---|---|---|
| `references/state-model.md` | 完整系统说明:状态机 / TODO.md 格式 / spec.md frontmatter / Worktree 命名 / 调用拓扑 | 用户问"todo-flow 是什么 / 怎么用"时;首次给项目初始化流水线时 |
| `references/stage1-prompt.md` | Stage 1 cron 喂给 agent 的 prompt:**完全无入参 self-driving**,遍历硬编码工程清单 → 找首个未起 spec 的 TODO → 出 spec → commit + push 到默认分支 | 用户要把 stage 1 接到 cron / 想手动跑一次起草 spec 时 |
| `references/stage2-prompt.md` | Stage 2 cron 喂给 agent 的 prompt:**完全无入参 self-driving**,遍历工程清单 → 找首个无残留 worktree/branch 的 approved spec → 开 worktree → 实现 + 验证 + 可选 Playwright 走查 → push branch | 用户要把 stage 2 接到 cron / 想手动跑一次 dev 时 |
| `references/stage3-verify-prompt.md` | Stage 3 cron 喂给 agent 的 prompt:**完全无入参 self-driving**,遍历工程清单 → 找首个 `ready-for-review` spec → 跑 hard gates + Playwright 走查 → 写 `## Stage 3 report` + status 改 `verified`/`verify-failed` + 标准 JSON 输出 | 用户要把 stage 3 接到 cron / exec 模式 Step 2 派 stage3 subagent 时 |
| `references/exec-orchestrator-prompt.md` | **`exec` 模式核心 prompt**:per-stage subagent 调度 + 心跳 + IM + director-* 增派 | `todo-flow exec` 被触发时,SKILL 必读全文 + 字面替换占位符再执行 |
| `references/role-doctrine.md` | 调度员角色信条 + 最容易翻的车清单 | 接 mode 前先读 |
| 各 mode 的 reference 文件(`mode-init.md` / `mode-add.md` / `mode-adjust.md` / `mode-revise.md` / `mode-exec.md` / `mode-done.md`,均在 `references/` 下)(6 个) | 各 mode 的详细 workflow + Output Contract + Common Failure Modes | 解析到对应 mode 后读对应文件 |
| `references/output-contract-schema.md`(共享) | 跨 skill 基线 JSON 字段规范 + markdown 报告落盘约定 | 拼报告时对齐字段 |
| `references/dispatcher-template.md`(共享) | 派 subagent 调下游 skill 的 prompt 通用模板 | `exec` 派 per-stage subagent 时对齐 prompt 字段 |

**怎么给用户**:
- 用户问"用法"/"怎么部署" → Read `references/state-model.md` 节选关键部分回答
- 用户要"试跑 stage 1 / 我想看看 prompt 长啥样" → 用 Read 读对应 `stage*-prompt.md` 整篇,或 cp 到用户指定路径
- 用户要"接 cron" → 给出读取这两个 prompt 文件的具体命令

**这些 reference 是状态机的契约定义**。改它们等于改 stage 1/2 prompt 端的行为,必须同步审视 `init` / `done` 两个 mode 的 references 是否还对齐。普通迭代只动 SKILL.md + 各 mode 的 reference 文件(`mode-init.md` / `mode-add.md` / `mode-adjust.md` / `mode-revise.md` / `mode-exec.md` / `mode-done.md`,均在 `references/` 下) 不动 stage*-prompt / state-model。

## Relationship to Other Skills

- **requesting-code-review**:通用 PR review,不带流水线;todo-flow `done` 是流水线收口 + merge + 发版一体的。
- **flow-codex-goal**:长跑无验收标准的 codex 后台任务;todo-flow `exec` 有 spec 验收 + director-* AND-pass + 终态闭环。
- **clean-commit**:单次干净 commit;todo-flow `add` / `adjust` / `revise` / `done` 自带 commit 逻辑,不再调 clean-commit。
- **flow-dev-task**:单任务 end-to-end(plan → code → test → verify → commit);todo-flow 是多 TODO 流水线编排,粒度更大、状态机更严。
- **director-architect / director-frontend / director-design**:`exec` 模式 stage3 verified 前按 spec frontmatter 增派做 AND-pass audit;本 skill 不自己做 spec/code/UI review。
- **experience-summary**:踩坑沉淀路由;本 skill 自己的 Common Failure Modes 写在各 各 mode 的 reference 文件(`mode-init.md` / `mode-add.md` / `mode-adjust.md` / `mode-revise.md` / `mode-exec.md` / `mode-done.md`,均在 `references/` 下),不重复写入错题本。
