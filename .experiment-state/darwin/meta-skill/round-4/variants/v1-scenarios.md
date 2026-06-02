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
26+ skill 全加载污染 context。本 skill 在 cwd 切换 / 显式 / exp-sum 信号触发时,**探测 → 写 manifest → 让 skillshare 按 manifest enable/disable**。**核心**:项目特征(栈+阶段+incident)决定集合;manifest 是配置产物;skillshare 是唯一执行者;改 `.skillshare/` 必须 user gate;**边界(monorepo/submodule/corrupt/opt-out)比主流程更重要**。

## End-to-End Flow (ASCII)
```
 cwd 变化 / user 显式 / exp-sum 信号
            │
            ▼  Step 1-2  probe + infer (read-only)
   ┌──────────────────┐
   │ probe project    │ ← package.json / git log / CLAUDE.md / .agent/
   └────────┬─────────┘
            ▼  Step 3  write manifest
   .skillshare/manifest.json   (canonical artifact)
            │
            ▼  Step 4  Pre-action Self-Check (5Q) → user gate (markdown 摘要)
   user: apply ? ── skip / modify ──▶ halt, manifest 留盘
            │ apply
            ▼  Step 5  skillshare enable/disable (唯一执行入口)
            │ 写 applied-at + applied_at 字段
            ▼  Step 6  halt   /   Step 7 7-day cooldown 复审
```

## When to Use / NOT to Use
- **Use**:cwd 首次进入 project / 显式触发关键词 / exp-sum 上游信号 / 已有 manifest mtime > 7 天 + 状态变化 / monorepo 切到子 package。
- **NOT use**:全局配置 / 其他项目 manifest / 新建 skill → `flow-skill-dev` / 同步 → `sync-skills` / 只 read 列表 → 直接 ls。
- **opt-out**:user 说"我自己来配"→ 写 `enable: []` + `user_opt_out: true` halt,不推断。

## High-Risk Actions — 必经 User Gate
以下任一**触发前必须**走 Step 4,不能跳过 / 合并 / "顺手"做:

1. `skillshare enable/disable <skill>`(实际改 state)
2. 写改 `<project>/.skillshare/enabled.txt` 或等价 config
3. 覆盖已有 `manifest.json`(必须先 backup 到 `previous_manifest`)
4. 把常驻 skill(`hat`/`experience-summary`/`unblock-recipes`)写入 `disable[]`
5. reset/删除 user 手改字段(`pinned[]`/`notes`)
6. 调 `flow-skill-research` 后**直接** enable 派生候选
7. 把 `low` confidence 当 high 自动 enable 该 stage 默认集
8. 清空/回填 `applied_at`(伪造历史)

read-only(ls/cat/git log/读 package.json/`skillshare list-available`)**不**算 high-risk,但输出**必须**记 `signals[].evidence`。

## Required Workflow
### Step 1 — 探测项目特征(并行,只读)
**Step 1.0 边界判定(必先)**:
- **root**:cwd 向上找 `.git`/`package.json`/`Cargo.toml`/`pyproject.toml`,取最近。
- **submodule**:cwd 含 `.git` **文件**(非目录)或宿主有 `.gitmodules` 且 cwd 在子路径 → 独立 project,manifest 落子 `.skillshare/`,不继承宿主 stage。
- **monorepo**:`pnpm-workspace.yaml`/`lerna.json`/`nx.json`/`turbo.json`/`Cargo.toml [workspace]`/`packages/*` → `is_monorepo: true`,走 Step 2.5。
- **nested**:cwd 不在 git root 但有自己 manifest → 当 sub-project,manifest 落本目录。

**A. 技术栈**:`package.json` deps → frontend/desktop/mobile/extension;`Cargo.toml`→rust;`pyproject.toml`→python;`go.mod`→go;`Gemfile`→ruby;多栈共存 → Step 2.5。
**B. 项目阶段**:0/<5 commits → `bootstrap`;有 commit + 主分支活跃 + 无 release tag → `dev`;含 `v[0-9]` tag + 持续 maintenance → `finish`;近 7d log "fix"/"revert"/"hotfix" > 30% → `debug`;无法判定 → 默认 `dev` 且 `stage_confidence` 显式 `low`;submodule 独立判定。
**C. 项目规则**:`CLAUDE.md`/`AGENTS.md`/`GEMINI.md`/`CONTRIBUTING.md` 提取 hint。monorepo:root + 各子都读,子优先。
**D. 历史 incident**:`flow-codex-goal`/`todo-flow` 残留;commit 含 "incident"/"rollback"/"revert" → high-attention;`.agent/tasks/` 未完成 → follow-up。

### Step 2 — 推断阶段 + 候选 skill 集
按 `references/manifest-schema.md` "阶段 × 技术栈 → 候选 skill" 矩阵生成。

| 阶段 | 默认 skill |
|---|---|
| `bootstrap` | `project-prep` / `flow-project-bootstrap` / `director-architect` |
| `dev` | `flow-dev-task` / `director-frontend`(UI 栈)/ `clean-commit` / `todo-flow` |
| `debug` | `superpowers:systematic-debugging` / `unblock-recipes` / `cdp-browser-control`(UI)|
| `finish` | `flow-project-finish` / `delivery-gate` / `clean-commit` / `flow-ext-publish`(扩展) |

**正交常驻**:`hat` / `experience-summary` / `unblock-recipes` — skillshare 单独管,本 skill **不**重复推荐,**绝对不能**写进 `disable[]`。

### Step 2.5 — Monorepo / 多语言混合分叉
- **monorepo**:root 出 union manifest(`scope: "monorepo-root"`);同时给每个子 package 写各自 manifest(stage 独立)。
- **多栈混合**:enable 数 > 12 → user 选 1-2 主栈,其他栈装 skeleton(`clean-commit` / `hat`)。
- **冲突**:子 package 显式 disable 的,union 不可 enable(子优先)。

### Step 3 — 输出 manifest JSON
写 `<project>/.skillshare/manifest.json`。**Corrupt**:parse 失败 / schema 不符 → 备份 `manifest.json.broken.<timestamp>`,提示 user,当首次生成。**不要**静默覆盖。
#### Inline Manifest JSON Schema(主体摘要)

```jsonc
{
  "$schema": "meta-skill/manifest/v1", "meta_skill_version": "1.x.x",
  "generated_at": "2026-06-03T08:00:00Z",
  "applied_at": null,                    // user gate 通过后填
  "last_evaluated_at": null,             // 复审仅更新此(hash 同)
  "project": {
    "root": "/abs/path", "name": "unimail",
    "type": ["frontend","extension"],    // 多栈数组,1+ entry
    "stage": "dev",                      // bootstrap | dev | debug | finish
    "stage_confidence": "high"           // high | medium | low (必填)
  },
  "scope": "project",                    // project | monorepo-root | submodule
  "parent_manifest": null,               // 子 package 指向 root manifest
  "signals": [                           // 每条必带 source/evidence/implies
    { "source":"package.json", "evidence":"react@19", "implies":"frontend", "weight":0.9 }
  ],
  "enable":  ["flow-dev-task","director-frontend","clean-commit"],
  "disable": ["flow-project-finish","flow-ext-publish"],
  "keep":    ["hat","experience-summary"],  // 全局常驻,本 skill 不动
  "rationale": [{ "skill":"flow-dev-task", "reason":"stage=dev 默认配" }],
  "user_opt_out": false,
  "previous_manifest": null              // 覆盖时存旧版 sha256 + 字段 diff
}
```

**字段约束**:`enable ∩ disable = ∅`;`enable[i] ∈ skillshare list-available`;`rationale` 覆盖 `enable ∪ disable` 全集;`signals[]` ≥ 1;`keep[]` 仅限 `hat`/`experience-summary`/`unblock-recipes`。

### Step 4 — User Gate(高风险动作)
**禁止**未经 user 确认就改 `.skillshare/enabled.txt`。
#### Pre-action Self-Check(进 user gate 前必跑,5 条 yes/no)
任一 No → **回 Step 3 修 manifest**,不推 user 摘要。回答必须显式写进对话或思考,不允许默念跳过。

1. `signals[]` 每一条都有 `source` + `evidence` + `implies` 三字段?
2. `enable[]` 里每个 skill 都跑过 `skillshare list-available` 验证存在?
3. 常驻 skill(`hat`/`experience-summary`/`unblock-recipes`)**未**被写入 `disable[]`?
4. `stage` 是 fallback 默认或多信号冲突时,`stage_confidence` 显式标 `low`/`medium`?
5. 旧 manifest 有 user 手改(`pinned[]`/`notes`/注释)→ 已存进 `previous_manifest` 而非直接覆盖?
#### User Gate 流程
1. markdown 摘要给 user(候选 + rationale + `stage_confidence`)
2. 等 user 确认("apply" / "skip" / "modify X")
3. 仅在明确 `apply` 后跑 skillshare 命令
4. 模糊回复或沉默 → **不动**,manifest 留盘,等下次显式触发
5. "modify X" → 改 manifest → **重跑 Self-Check** → 再 gate
6. "看起来 ok / 差不多" 非显式 apply → 视为模糊,走 #4
7. "我自己来配" → `enable: [] + user_opt_out: true`,halt

### Step 5 — 落地 + 记录版本
写 manifest.json(canonical);user apply → 跑 skillshare + 写 `.skillshare/applied-at`(ISO)+ manifest 加 `applied_at`。monorepo:子先 apply,root 后。

### Step 6 — Halt
不主动重复触发。下次触发:cwd 变化 / user 显式 / exp-sum 信号。user `skip` → manifest 留盘,**不**跑 skillshare、**不**写 `applied_at`。新推断同上次 skip → 复用 + 更新 `last_evaluated_at`。

### Step 7 — Manifest 复审(7 天冷却)
后续进入同项目,**全部**满足才自动 invoke:manifest 存在 + `generated_at` mtime > 7 天 + 状态变化(新 release tag / 主分支切换 / commit +20% / CLAUDE.md mtime 更新) + `user_opt_out: false`。重跑时上次 manifest 作 `previous_manifest`。

## Worked Examples — 抄作业模板
### Example 1 — React + Next.js frontend(dev 阶段)  探测:`package.json` 含 `next@15 + react@19`,30 commits 无 release tag,主分支活跃。
```json
{
  "$schema": "meta-skill/manifest/v1", "meta_skill_version": "1.0.0",
  "generated_at": "2026-06-03T09:00:00Z", "applied_at": null,
  "project": { "root": "/Users/me/web-app", "name": "web-app",
    "type": ["frontend"], "stage": "dev", "stage_confidence": "high" },
  "scope": "project",
  "signals": [
    { "source": "package.json", "evidence": "next@15 + react@19", "implies": "frontend", "weight": 0.95 },
    { "source": "git log", "evidence": "30 commits, no v* tag, main active", "implies": "stage=dev", "weight": 0.9 },
    { "source": "CLAUDE.md", "evidence": "use pnpm not npm", "implies": "rule:pnpm-only", "weight": 0.8 }
  ],
  "enable": ["flow-dev-task", "director-frontend", "cdp-browser-control", "clean-commit"],
  "disable": [], "keep": ["hat","experience-summary","unblock-recipes"],
  "rationale": [
    { "skill": "flow-dev-task", "reason": "stage=dev 默认编排单任务" },
    { "skill": "director-frontend", "reason": "type=frontend (Next.js)" },
    { "skill": "cdp-browser-control", "reason": "frontend dev 需浏览器验证" },
    { "skill": "clean-commit", "reason": "dev 频繁 commit 需规范" }
  ]
}
```

### Example 2 — Rust CLI(bootstrap 阶段)  探测:`Cargo.toml` 单 crate,3 commits,无 tag,刚 `cargo init`。
```json
{
  "$schema": "meta-skill/manifest/v1", "meta_skill_version": "1.0.0",
  "generated_at": "2026-06-03T09:05:00Z", "applied_at": null,
  "project": { "root": "/Users/me/rust-cli", "name": "rust-cli",
    "type": ["rust"], "stage": "bootstrap", "stage_confidence": "medium" },
  "scope": "project",
  "signals": [
    { "source": "Cargo.toml", "evidence": "single crate, no [workspace]", "implies": "rust-single", "weight": 0.9 },
    { "source": "git log", "evidence": "3 commits since init", "implies": "stage=bootstrap", "weight": 0.7 },
    { "source": "fs", "evidence": "no README, empty src/main.rs", "implies": "early-skeleton", "weight": 0.6 }
  ],
  "enable": ["flow-project-bootstrap", "director-architect", "delivery-gate"],
  "disable": [], "keep": ["hat","experience-summary","unblock-recipes"],
  "rationale": [
    { "skill": "flow-project-bootstrap", "reason": "stage=bootstrap 默认编排" },
    { "skill": "director-architect", "reason": "新项目需架构方向" },
    { "skill": "delivery-gate", "reason": "通用交付闸门" },
    { "skill": "(confidence=medium)", "reason": "commit 少可能误判,gate 时确认" }
  ]
}
```

### Example 3 — Python ML training(debug 阶段)  探测:`pyproject.toml` + `requirements.txt`,近 20 commits 中 12 条含 "fix"/"hotfix"(60%)。
```json
{
  "$schema": "meta-skill/manifest/v1", "meta_skill_version": "1.0.0",
  "generated_at": "2026-06-03T09:10:00Z", "applied_at": null,
  "project": { "root": "/Users/me/ml-train", "name": "ml-train",
    "type": ["python"], "stage": "debug", "stage_confidence": "high" },
  "scope": "project",
  "signals": [
    { "source": "pyproject.toml", "evidence": "torch + transformers deps", "implies": "python-ml", "weight": 0.95 },
    { "source": "git log 7d", "evidence": "12/20 commits fix|hotfix (60%)", "implies": "stage=debug", "weight": 0.95 },
    { "source": ".agent/tasks/", "evidence": "3 unfinished debug tasks", "implies": "incident-burst", "weight": 0.8 }
  ],
  "enable": ["superpowers:systematic-debugging", "flow-dev-task"],
  "disable": [], "keep": ["hat","experience-summary","unblock-recipes"],
  "rationale": [
    { "skill": "superpowers:systematic-debugging", "reason": "stage=debug 默认 root-cause" },
    { "skill": "flow-dev-task", "reason": "debug 单任务仍走 dev-task 编排" },
    { "skill": "(unblock-recipes in keep)", "reason": "已常驻,不重复 enable" },
    { "skill": "(no UI stack)", "reason": "无需 cdp-browser-control" }
  ]
}
```

### Example 4 — Browser Extension(finish 阶段)  探测:`wxt.config.ts` + 已有 `v1.3.0` tag + 近期 commits 偏 release/docs。
```json
{
  "$schema": "meta-skill/manifest/v1", "meta_skill_version": "1.0.0",
  "generated_at": "2026-06-03T09:15:00Z", "applied_at": null,
  "project": { "root": "/Users/me/my-ext", "name": "my-ext",
    "type": ["extension", "frontend"], "stage": "finish", "stage_confidence": "high" },
  "scope": "project",
  "signals": [
    { "source": "wxt.config.ts", "evidence": "WXT extension framework", "implies": "browser-extension", "weight": 0.95 },
    { "source": "git tag", "evidence": "v1.3.0 + maintenance commits", "implies": "stage=finish", "weight": 0.9 },
    { "source": "CHANGELOG.md", "evidence": "active release cadence 30d", "implies": "post-launch", "weight": 0.85 }
  ],
  "enable": ["flow-project-finish", "flow-ext-publish", "delivery-gate", "clean-commit"],
  "disable": ["flow-dev-task"], "keep": ["hat", "experience-summary", "unblock-recipes"],
  "rationale": [
    { "skill": "flow-project-finish", "reason": "stage=finish 默认编排收尾" },
    { "skill": "flow-ext-publish", "reason": "extension 发布专属" },
    { "skill": "delivery-gate", "reason": "每次发布走交付闸门" },
    { "skill": "flow-dev-task (disable)", "reason": "已过 dev,避免误派" }
  ]
}
```

## Integration with skillshare
skillshare = manifest 的**唯一消费者 + 唯一执行入口**。本 skill 永不直接改 `.skillshare/enabled.txt`。**4-command 契约**:

```bash
# 1. (read-only) Step 2,验证 enable[] + 列项目可启用池
skillshare list-available --scope project --cwd .
# 2. (write) Step 5 user apply 后唯一执行入口
skillshare enable <skill>  --scope project --cwd .
skillshare disable <skill> --scope project --cwd .
# 3. (read-only) Step 7 复审做 diff
skillshare list-enabled --scope project --cwd .
```

**契约不变量**:skillshare 读 manifest `enable[]`/`disable[]`/`keep[]` 为准;skillshare 错误必须 surface 回本 skill **不**静默吞;本 skill 永不绕过 skillshare 直写 `enabled.txt`(绕过 = 状态漂移)。

## Cross-Skill Boundaries
### Upstream — experience-summary 信号契约

```jsonc
{
  "trigger": "stage_switch",     // stage_switch | drift_detected | stack_change | incident_burst
  "from": "dev", "to": "finish",
  "evidence": ["git tag v1.0.0 created", "main branch frozen"],
  "confidence": 0.8              // < 0.6 时本 skill 应 user gate 更谨慎
}
```

收信号后**仍走完整 6 步**(不跳 user gate)。信号 = 触发,不是授权。同 input 同 output(idempotent)。

### Downstream — flow-skill-research 调用契约
Step 2 候选不明确时,本 skill **可调用** `flow-skill-research`:输入 `{ project_type, stage, gap_description }`,输出研究 + 候选。候选并入 `enable[]` 池,**仍走 Step 4 user gate**,不直接 apply。

### Sibling meta 类 skill
- `hat`:default 激活,告知行**不**写入 manifest.json
- `unblock-recipes`:本 skill 卡壳 → 让 unblock 接手,不死循环
- `experience-summary`:上游触发本 skill;输出 `signals[]` 可作 exp-sum 输入

这 3 个常驻 skill 一律**不**进 `enable[]`/`disable[]`,由 skillshare 单独管。

## Output Contract
落盘 = `<project>/.skillshare/manifest.json`(canonical);对话 = markdown 摘要;**不**向 user 输出整个 JSON。详细 schema/分流见 `../_shared/output-contract-schema.md` 与 `references/manifest-schema.md`。

## Red Flags — STOP
- **不经 user 确认就改 `.skillshare/enabled.txt` 或 skillshare config**
- **改全局 skillshare 配置**(`~/.config/skillshare/`)
- **改其他项目 manifest**(非当前 cwd)
- **manifest 推断没列 rationale**
- **同时 enable + disable 同一 skill**
- **enable 不在 skillshare 源里的 skill**
- **覆盖 user 手改过的 manifest 而不存 `previous_manifest`**
- **reset/删除 user 手改字段**
- **常驻 skill(`hat`/`experience-summary`/`unblock-recipes`)写进 `disable[]`**
- **推断 stage 但不写 `stage_confidence`**
- **signals[] 缺 `source`/`evidence`/`implies` 任一字段**
- **跳过 Pre-action Self-Check 直接进 User Gate**
- **静默覆盖 corrupt manifest**(必须备份 `.broken.<timestamp>`)
- **monorepo root enable 了子 package 显式 disable 的 skill**
- **submodule 推断时继承宿主 stage**

## Always-Follow 底线
`../_shared/constitution.md` 优先;尊重高风险动作 gate。

## Rationalizations to Reject
| 说辞 | 现实 |
|---|---|
| "user 之前 apply 过类似 manifest,这次直接 apply 吧" | **不行**。每次都要显式 apply,缓存信任不延续 |
| "项目还没 git init,先按 bootstrap 配吧" | **不行**。无 git = 无足够信号,应让 user 显式说 |
| "manifest 跟上次一样,跳过写盘" | **可以**。hash 相同只更新 `last_evaluated_at` |
| "skillshare 命令报错,我自己改 enabled.txt" | **不行**。skillshare 是唯一入口,绕过 = 状态漂移 |
| "user 没回但上次说过 always apply,默认 apply 吧" | **不行**。"always apply" 非有效 standing order;每次都要新 gate |
| "stage 推不出来,跳过 confidence 字段比标 low 干净" | **不行**。缺字段 = 下游默认 high,更危险 |
| "self-check 第 2 条懒得跑 list-available,这些 skill 我都见过" | **不行**。skillshare 源会变,凭印象 enable = 写废 manifest |
| "user 手改的 `notes` 看起来过期了,顺手删掉重写" | **不行**。手改字段一律进 `previous_manifest`,本 skill 无 GC 权限 |

## Codex Delegation Hook
元判断 + 配置生成,**不**派 Codex。推断卡死**也不**派;直接落 manifest + `stage_confidence: low` + 等下次 user 显式触发。
## Relationship to Other Skills
**Upstream**:agent 主对话 / orchestrator 检测 cwd 变化 → 本 skill;用户显式触发;`experience-summary` 阶段切换信号 → 主动 invoke。
**Downstream**:`skillshare`(读 manifest + applied list,实际 enable/disable);后续 agent 会话。
**不替代**:`flow-skill-dev`(新建)/ `sync-skills`(同步)/ `flow-skill-research`(调研)— 本 skill 可调用 research,**调完仍需 user gate**。
## Reuse
- `references/project-detection.md` — 技术栈/阶段/规则/incident/monorepo/submodule 探测细则
- `references/manifest-schema.md` — manifest schema 完整版 + 4 阶段 × 技术栈候选矩阵 + monorepo union 规则
- `tests/cases.md` — 行为测试用例(含 monorepo/submodule/corrupt/opt-out/7-day cooldown 边界)
