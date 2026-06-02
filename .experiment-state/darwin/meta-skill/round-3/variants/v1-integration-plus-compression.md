---
name: meta-skill
description: >
  Use when an agent enters a new project directory, or when project lifecycle stage changes,
  and needs to decide which skills to enable for that project. Probes project context
  (tech stack / stage / project rules / recent incidents) and emits a skill manifest
  consumed by skillshare to enable/disable skills per project.
  自动激活信号:cwd 切到新项目目录 / 进入 git repo 后第一次 agent 启动 / 用户说"配下这个项目的 skill"/"刷新 skill manifest"。
  显式触发:"meta-skill refresh" / "重新评估这个项目要哪些 skill" / "configure skills for this project" /
  "regenerate skill manifest" / "项目阶段变了重新配 skill"。
  上游触发:experience-summary 检测到项目阶段切换信号(从 dev → finish / debug → dev 等)时主动 invoke。
  Do NOT use for: 改全局 skill 配置(~/.config/skillshare/)/ 改其他项目的 manifest(只动当前 cwd 项目)/
  从中心库新建 skill(那是 flow-skill-dev)/ 同步 skill 到中心库(那是 sync-skills)。
---

> 本 skill 受 `../_shared/constitution.md` 约束(always-follow,身份 / 安全 / 高风险动作 gate)

# meta-skill — 项目级 skill 自适应配置

## Overview

日常加载 26+ skill 会污染 agent context,实际只有少数跟当前项目相关。本 skill 在 cwd 切换 / 用户显式 / exp-sum 信号触发时,**自动探测项目特征 → 生成 skill manifest → 让 skillshare 按 manifest enable/disable**。

**核心信念**:项目特征(技术栈+阶段+历史 incident)决定 skill 集合;manifest 是配置产物(非 import 入口);skillshare 是执行者;改 `.skillshare/` 必须 user gate;**边界情况(monorepo/submodule/corrupt/opt-out)比主流程更重要**。

## End-to-End Flow (ASCII)

```
 cwd 变化 / user 显式 / exp-sum 信号
   │ Step 1-2 probe+infer (read-only)
   ▼  package.json / git log / CLAUDE.md / .agent/
 Step 3  →  .skillshare/manifest.json (canonical)
   │ Step 4  Pre-action Self-Check (5Q) → user gate (md 摘要)
   ▼  user apply ? ── skip/modify ──▶ halt, manifest 留盘
 Step 5  skillshare enable/disable (唯一执行入口) + applied_at
 Step 6  halt    Step 7  7-day cooldown 复审
```

## When to Use / NOT to Use

**Use**:cwd 切到本会话内首次进入的 project / 用户说"配什么 skill"/"重新评估"/"项目阶段变了" / `experience-summary` 上游触发 / 已有 manifest 但 mtime > 7 天 + 状态明显变化 / monorepo 内切到子 package。

**NOT use**:改全局配置(`~/.config/skillshare/`)/ 改其他项目 manifest / 新建 skill → `flow-skill-dev` / 同步 → `sync-skills` / 用户只问"有哪些 skill?"(read-only,直接 ls)/ 用户说"我自己来配"→ 写 `enable: []` + `user_opt_out: true` halt,不推断。

## High-Risk Actions — 必经 User Gate

以下任何一个触发前必须走 Step 4 User Gate,不能跳过、合并、"顺手"做掉:

1. 跑 `skillshare enable <skill>` / `skillshare disable <skill>`(实际改 enable 状态)
2. 写 / 改 `<project>/.skillshare/enabled.txt` 或等价 config 文件
3. 覆盖已有 `<project>/.skillshare/manifest.json`(必须先 backup 到 `previous_manifest` 字段)
4. 把任何 user-managed 常驻 skill(`hat` / `experience-summary` / `unblock-recipes`)写入 `disable[]`
5. reset / 删除 user 在 manifest 里手改过的字段(如 user 加了 `pinned[]` / `notes`)
6. 调 `flow-skill-research` 派生新候选 skill 后**直接** enable(必须先回 user gate)
7. 把推断 confidence 为 `low` 的 stage 当 high 处理,自动 enable 该 stage 默认 skill 集
8. 把上一次 manifest 的 `applied_at` 字段清空或回填假时间(等于伪造历史)

read-only(ls / cat / git log / 读 package.json / `skillshare list-available`)**不**算 high-risk,直接做;输出**必须**记到 `signals[].evidence`。

## Required Workflow

### Step 1 — 探测项目特征(并行,只读)

**1.0 边界判定(必先做)**:从 cwd 向上找 `.git` / `package.json` / `Cargo.toml` / `pyproject.toml` 最近作 root。其余边界 case 见 Edge Cases 表。
**A. 技术栈**:`package.json` deps `react`/`next`/`vue`/`svelte` → frontend;`electron`/`tauri` → desktop;`react-native`/`expo` → mobile;`wxt`/`plasmo`/`manifest.json` → extension。`Cargo.toml` → rust(`[workspace]` 展开);`pyproject.toml`/`requirements.txt` → python;`go.mod` → go;`Gemfile` → ruby;多个共存 → 多栈混合(Step 2.5)。
**B. 项目阶段**(git):0 / < 5 commits → `bootstrap`;有 commit + 主分支活跃 + 无 release tag → `dev`;含 `release-*` / `v[0-9]` tag + 持续 maintenance → `finish`;近 7d log "fix"/"revert"/"hotfix" > 30% → `debug`;多信号取最强;无法判定 → 默认 `dev` 且 `stage_confidence` 显式 `low`;submodule 独立判定不继承宿主。
**C. 项目规则**:`CLAUDE.md` / `AGENTS.md` / `GEMINI.md` / `CONTRIBUTING.md` / `docs/**/rules.md` 提取 hint(如 "use pnpm not npm")。monorepo:root + 各子 package CLAUDE.md 都读,子优先。
**D. 历史 incident**:`flow-codex-goal` / `todo-flow` 残留 → 跑过编排;commit 含 "incident"/"rollback"/"revert" → high-attention;`.agent/tasks/` 未完成 → follow-up needed。

### Step 2 — 推断阶段 + 候选 skill 集

| 阶段 | 默认 skill |
|---|---|
| `bootstrap` | `project-prep` / `flow-project-bootstrap` / `director-architect` |
| `dev` | `flow-dev-task` / `director-frontend` (UI 栈) / `clean-commit` / `todo-flow` (如已 init) |
| `debug` | `superpowers:systematic-debugging` / `unblock-recipes` / `cdp-browser-control` (UI 栈) |
| `finish` | `flow-project-finish` / `delivery-gate` / `clean-commit` / `flow-ext-publish` (扩展项目) |

**正交常驻候选**:`hat` / `experience-summary` / `unblock-recipes` — 由 skillshare 单独管,本 skill **不**重复推荐(避免噪音),**绝对不能**写进 `disable[]`(见 Why-Keep-It)。

### Step 2.5 — Monorepo / 多语言混合

- **monorepo**:root 生成 union manifest(`enable[]` = 子并集 + `scope: "monorepo-root"`);**同时**为每个子 package 写各自 manifest(stage 独立判定)。
- **多栈混合**:合并候选,enable 数 > 12 → 让 user 选 1-2 主栈,其他栈只装 skeleton(`clean-commit` / `hat`)。
- **冲突**:子显式 disable 的 skill,union 不可 enable(子优先)。

### Step 3 — 输出 manifest JSON

写到 `<project>/.skillshare/manifest.json`(主体摘要):

```jsonc
{
  "$schema": "meta-skill/manifest/v1",
  "meta_skill_version": "1.x.x",
  "generated_at": "2026-06-03T08:00:00Z",
  "applied_at": null,            // 填:user gate 通过后
  "last_evaluated_at": null,     // 复审仅更新此字段(hash 同)
  "project": {
    "root": "/abs/path/to/project", "name": "unimail",
    "type": ["frontend", "extension"],  // 多栈数组 1+
    "stage": "dev",                // bootstrap|dev|debug|finish
    "stage_confidence": "high"     // high|medium|low(必填)
  },
  "scope": "project",              // project|monorepo-root|submodule
  "parent_manifest": null,         // 子 package 指向 root manifest
  "signals": [                     // 每条必带 source/evidence/implies
    { "source": "package.json", "evidence": "react@19", "implies": "frontend", "weight": 0.9 }
  ],
  "enable":  ["flow-dev-task", "director-frontend", "clean-commit"],
  "disable": ["flow-project-finish", "flow-ext-publish"],
  "keep":    ["hat", "experience-summary"],  // 全局常驻,本 skill 不动
  "rationale": [{ "skill": "flow-dev-task", "reason": "stage=dev 默认配" }],
  "user_opt_out": false,
  "previous_manifest": null        // 覆盖时存旧版 sha256 + 字段 diff
}
```

**字段约束**:`enable ∩ disable = ∅`(冲突 reject);`enable[i]` 必须 ∈ `skillshare list-available`;`rationale` 覆盖 `enable ∪ disable` 全集;`signals[]` ≥ 1;`keep[]` 仅限 `hat`/`experience-summary`/`unblock-recipes`。

### Step 4 — User Gate

**禁止**未经 user 确认就实际改 `.skillshare/enabled.txt` 或 skillshare config。

#### Pre-action Self-Check(进入 user gate 前必跑,5 条 yes/no)

任何一条答 No → **回 Step 3 修 manifest**,不向 user 推送。回答必须显式写进对话或思考。

1. `signals[]` 的每一条都有 `source` + `evidence` + `implies` 三字段吗?
2. `enable[]` 里每个 skill 都跑过 `skillshare list-available` 验证存在吗?
3. 任何 user-managed 常驻 skill(`hat` / `experience-summary` / `unblock-recipes`)是否**未**被写入 `disable[]`?
4. `stage` 如果是 fallback 默认(`dev`)或多信号冲突,`stage_confidence` 是否显式标 `low` / `medium`?
5. 旧 manifest 若 user 手改过(`pinned[]` / `notes` / 注释)→ 是否已存进 `previous_manifest` 而非直接覆盖?

#### User Gate 流程

1. markdown 摘要给 user(候选 + rationale + `stage_confidence`);等确认 "apply" / "skip" / "modify X"
2. 仅 user 明确 `apply` 后跑 skillshare 命令
3. 模糊回复 / 沉默 / "看起来 ok / 差不多 / 应该可以" → 不动,manifest 留盘等下次显式
4. "modify X" → 改 manifest → **重跑 Pre-action Self-Check** → 再 gate
5. "我自己来配" → 写 `enable: [] + user_opt_out: true` halt,跳过自动复审

### Step 5 — 落地 + 记录版本

写 `<project>/.skillshare/manifest.json`(canonical);user apply → 跑 skillshare + 写 `.skillshare/applied-at`(ISO)+ manifest 加 `applied_at`。monorepo:子先 apply,root 后。

### Step 6 — Halt

不主动重复触发自己。下次由 cwd 变化 / user 显式 / exp-sum 信号。`skip` 时 manifest.json 仍留盘,**不**跑 skillshare、**不**写 `applied_at`。下次推断主体同上次 skip → 复用 + 更新 `last_evaluated_at`(避免 skip 循环)。

### Step 7 — 复审(7 天冷却)

全部满足才自动重 invoke:manifest 存在 + `generated_at` mtime > 7 天 + 状态明显变化(新 release tag / 主分支切换 / commit +20% / CLAUDE.md mtime 更新)+ `user_opt_out: false`。重跑时上次 manifest 作 `previous_manifest`。否则跳过。

## Edge Cases(必查表)

| Case | 检测 | 处理 |
|---|---|---|
| **submodule** | cwd 含 `.git` **文件**(非目录) / 宿主 root 有 `.gitmodules` 且 cwd 在 submodule 路径下 | 视为独立 project,manifest 落 submodule 自己 `.skillshare/`,**不继承宿主 stage** |
| **monorepo** | root 含 `pnpm-workspace.yaml` / `lerna.json` / `nx.json` / `turbo.json` / `Cargo.toml [workspace]` / `packages/*` | 标 `is_monorepo: true`,走 Step 2.5(子+root 都写) |
| **nested project** | cwd 不在 git root 但本目录有自己 manifest(如 `apps/web/package.json`) | 当 sub-project,manifest 落本目录,不污染 root |
| **corrupt manifest** | 已存在但 JSON parse 失败 / schema 不符 | 备份 `.skillshare/manifest.json.broken.<timestamp>`,提示 user,当首次生成(禁止静默覆盖) |
| **user opt-out** | user 说"我自己来配" / 旧 manifest `user_opt_out: true` | 写 `enable: [] + user_opt_out: true`,halt,跳过 7 天复审 |
| **cooldown 未到** | `generated_at` mtime < 7 天且无明显状态变化 | 跳过自动 invoke,仅显式触发时跑 |

## Integration with skillshare

skillshare 是 manifest 的**唯一消费者 + 唯一执行入口**。本 skill 永远不直接改 `.skillshare/enabled.txt`。

**4-command 契约**:

```bash
skillshare list-available --scope project --cwd .  # (read) Step 2 验证 + 列池
skillshare enable  <skill> --scope project --cwd . # (write) Step 5 唯一写入口
skillshare disable <skill> --scope project --cwd . # (write) Step 5
skillshare list-enabled  --scope project --cwd .   # (read) Step 7 复审 diff
```

**契约不变量**:skillshare 以 manifest 的 `enable[]` / `disable[]` / `keep[]` 为准;skillshare 错误(skill 不存在 / 冲突)必须 surface 回本 skill **不**静默吞;本 skill 永远不绕过 skillshare 直写 `enabled.txt`(绕过 = 状态漂移)。

## Why-Keep-It — 常驻 skill 规则段(强制 cite)

凡推断触及下述 3 个 skill,`rationale[]` 里 reason 必须以 `keep-rule:<id>` 开头(manifest 留痕),而**不是**只跳过 disable 检查。

- **`hat`** — `keep-rule:hat-001` — 每对话开头默认激活,提供 persona 执行风格基线。本 skill 输出是配置**不是对话响应**,无权 disable;hat "告知行"也**不**写入 manifest(避免污染配置语义)。
- **`experience-summary`** — `keep-rule:exp-sum-001` — 本 skill 的**上游触发者**(stage_switch / drift_detected / stack_change / incident_burst),disable 等于切断自动复审链路。即便 `finish` 阶段、即便 user 觉得"没新经验",仍由 skillshare 单独管。
- **`unblock-recipes`** — `keep-rule:unblock-001` — 本 skill 卡壳(stage 推不出 / monorepo 边界失败 / signals 冲突)时需 unblock 接手,disable 会让 meta-skill 陷入"我推不出 → 没人接 → 死循环"。跨 agent 的错题本,作用域不止本项目。

这 3 个一律**不**进 `enable[]` 或 `disable[]`,由 skillshare 全局管(违反 → Self-Check Q3 拦)。

## Cross-Skill Boundaries

### Upstream — experience-summary 信号契约

```jsonc
{
  "trigger": "stage_switch",     // stage_switch | drift_detected | stack_change | incident_burst
  "from": "dev",
  "to":   "finish",
  "evidence": ["git tag v1.0.0 created", "main branch frozen"],
  "confidence": 0.8              // < 0.6 时本 skill 应 user gate 更谨慎
}
```

收信号后**仍走完整 6 步**(不跳 user gate)。信号只是触发,不是授权。idempotent:同 input 同 output,推断 hash 相同时仅更新 `last_evaluated_at`。

### Downstream — flow-skill-research / sync-skills / skill-doctor 契约

- **flow-skill-research**:Step 2 候选不明确时**可调用**,输入 `{ project_type, stage, gap_description }`,输出候选并入 `enable[]` 候选池,**仍走 Step 4 user gate**,不直接 apply。
- **sync-skills**:本 skill **不**调用。若 Step 1 发现 manifest 引用了本机中心库不存在的 skill(`skillshare list-available` 漏报),Step 4 摘要必须提示 user "缺失:X,Y → 跑 sync-skills 同步",不擅自调用、不擅自从 `enable[]` 删。sync 是 user gesture。
- **skill-doctor**:在本 skill 之前跑(orchestrator 编排),lint 级 hard rule。本 skill **假设**已 pass 不重复 lint;但若 `list-available` 报 skill 被标 `disabled-by-doctor`,本 skill 必须从候选剔除,`rationale` 写 `excluded: doctor-flag`。

## Output Contract

落盘 = `<project>/.skillshare/manifest.json`(canonical);对话 = markdown 摘要(候选 + rationale + `stage_confidence` + 等确认指令);**不**向 user 输出整个 JSON。JSON/markdown 分流基线见 `../_shared/output-contract-schema.md`,完整 schema 见 `references/manifest-schema.md`。

## Red Flags — STOP

- 不经 user 确认就实际改 `.skillshare/enabled.txt` 或 skillshare config
- 改全局 skillshare 配置(`~/.config/skillshare/`)
- 改其他项目的 manifest(不是当前 cwd)
- manifest 推断没列 rationale
- 同时 enable + disable 同一个 skill(矛盾 reject)
- enable 一个不在 `skillshare list-available` 池里的 skill
- 覆盖一份 user 手改过的 manifest 而不存 `previous_manifest`
- reset user 在旧 manifest 的 override 字段(`pinned[]` / `notes` / 自定义 disable)
- 把 user-managed 常驻 skill(`hat` / `experience-summary` / `unblock-recipes`)写进 `disable[]`
- 推断 stage 但不写 `stage_confidence`(下游默认 high,等于盲信)
- `signals[]` 缺 `source` / `evidence` / `implies` 任一字段
- 跳过 Pre-action Self-Check 直接进 User Gate
- 静默覆盖 corrupt manifest(必须备份 `.broken.<timestamp>` 并提示 user)
- monorepo root manifest enable 了子 package 显式 disable 的 skill(子优先违反)
- submodule 推断时继承宿主 stage(应独立判定,除非 user 显式说继承)

## Always-Follow 底线

`../_shared/constitution.md` 优先。本 skill 永远尊重 constitution 的高风险动作 gate(不替 user 单方面动 `.skillshare/`)。

## Codex Delegation Hook

元判断 + 配置生成,**不**派 Codex。推断卡死(stage 多信号冲突且 user 不在场)**也不**派 Codex;直接落 manifest + `stage_confidence: low` + 等下次 user 显式触发。

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "user 之前 apply 过类似 manifest,这次直接 apply 吧" | **不行**。每次都要 user 显式 apply,缓存信任不延续 |
| "项目还没 git init,先按 bootstrap 配吧" | **不行**。无 git = 无足够信号,让 user 显式说要哪些 skill |
| "manifest 跟上次一样,跳过写盘" | **可以**。hash 同只更新 `last_evaluated_at` |
| "skillshare 命令报错,我自己改 enabled.txt" | **不行**。skillshare 是唯一执行入口,绕过 = 状态漂移 |
| "user 这次没回但上次说过 always apply,默认 apply 吧" | **不行**。"always apply" 不是有效 standing order |
| "stage 推不出来,跳过 confidence 字段比标 low 干净" | **不行**。缺字段 = 下游默认 high,比标 low 更危险 |
| "self-check Q2 懒得跑 `skillshare list-available`,这些 skill 我都见过" | **不行**。源会变(rename / 移除),凭印象 = 写废 manifest |
| "user 手改的 `notes` 看起来过期了,顺手删掉重写" | **不行**。user 手改字段一律进 `previous_manifest` |

## Relationship to Other Skills

- **Upstream**:agent 主对话 / orchestrator 检测 cwd 变化;用户显式触发;`experience-summary` 阶段切换信号。
- **Downstream**:`skillshare`(实际 enable/disable);后续 agent 会话(读 manifest);`sync-skills`(仅提示 user 调,不自调);`skill-doctor`(本 skill 假设已 pass)。
- **不替代**:`flow-skill-dev`(新建)/ `sync-skills`(同步)/ `flow-skill-research`(调研,可调但仍需 user gate)。

## Reuse

- `references/project-detection.md` — 探测细则;`references/manifest-schema.md` — JSON schema 完整版 + 阶段 × 栈矩阵 + monorepo union;`tests/cases.md` — 行为测试(含 monorepo / submodule / corrupt / opt-out / cooldown 边界)。
