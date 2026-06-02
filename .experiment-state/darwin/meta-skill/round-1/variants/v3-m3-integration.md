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

不同项目需要不同的 skill 集合。日常加载 26+ skill 会污染 agent context,实际只有少数 skill 跟当前项目相关。

本 skill 自动探测项目特征 → 生成 skill manifest → 让 skillshare 按 manifest enable/disable。

## End-to-End Flow (ASCII)

```
 cwd 变化 / user 显式 / exp-sum 信号
            │
            ▼  Step 1-2  探测 + 推断 (read-only)
   ┌──────────────────┐
   │ probe project    │ ← package.json / git log / CLAUDE.md / .agent/
   └────────┬─────────┘
            ▼  Step 3  写 manifest
   .skillshare/manifest.json   (canonical artifact)
            │
            ▼  Step 4  user gate (markdown 摘要)
   user: apply ? ── skip / modify ──▶ halt, manifest 留盘
            │ apply
            ▼  Step 5  唯一执行入口
   skillshare apply --from .skillshare/manifest.json
            │ 写 applied-at + applied_at 字段
            ▼  Step 6  halt
```

## When to Use

- agent cwd 切到一个**新 project**(本会话内首次进入)
- 用户说"这个项目要配什么 skill"/ "重新评估 skill"/ "项目阶段变了"
- `experience-summary` 监测到阶段切换信号,主动调本 skill
- 项目内已有 `.skillshare/manifest.json` 但 mtime > 7 天前 + 项目状态明显变化

## When NOT to Use

- 改**全局** skill 配置(`~/.config/skillshare/`)/ 改**其他项目** manifest
- 新建 skill 到中心库 → `flow-skill-dev`;同步到中心库 → `sync-skills`
- 用户只问"我项目里有哪些 skill?" — read-only,直接 ls `.skillshare/manifest.json`

## Required Workflow

### Step 1 — 探测项目特征(并行,只读)

**A. 技术栈**(从文件存在性 + package manifest 推断):
- `package.json` → 检 dependencies/scripts(react/next/vue/svelte → frontend;electron/tauri → desktop;react-native/expo → mobile;wxt/plasmo/manifest.json → browser extension)
- `Cargo.toml` → rust; `pyproject.toml`/`requirements.txt` → python; `go.mod` → go; `Gemfile` → ruby
- 多个共存 → 多栈混合

**B. 项目阶段**(从 git history 推断):
- 0 commit / < 5 commits → `bootstrap`
- 有 commit + 主分支活跃 + 无 release tag → `dev`
- 含 `release-*` / `v[0-9]` tag + 持续 maintenance → `finish`
- 最近 git log 含 "fix"/"revert"/"hotfix" 集中(> 30% commits in last 7d)→ `debug`
- 多信号叠加 → 取最强;无法判定 → 默认 `dev`

**C. 项目规则**(从 docs 推断):`CLAUDE.md` / `AGENTS.md` / `GEMINI.md` / `CONTRIBUTING.md`

**D. 历史 incident**(从 git log / .agent/ 残留 / commit message 推断):
- 含 `flow-codex-goal` / `todo-flow` 历史产物 → 跑过编排任务
- commit 含 "incident" / "rollback" / "revert" → 标记 high-attention
- `.agent/tasks/` 有未完成任务 → 标记 follow-up needed

### Step 2 — 推断阶段 + 候选 skill 集

| 阶段 | 默认 skill |
|---|---|
| `bootstrap` | `project-prep` / `flow-project-bootstrap` / `director-architect` |
| `dev` | `flow-dev-task` / `director-frontend` (UI 栈) / `clean-commit` / `todo-flow` |
| `debug` | `superpowers:systematic-debugging` / `unblock-recipes` / `cdp-browser-control` |
| `finish` | `flow-project-finish` / `delivery-gate` / `clean-commit` / `flow-ext-publish` |

**正交常驻候选**:`hat` / `experience-summary` / `unblock-recipes` — 由 skillshare 全局管,本 skill **不**重复推荐。

### Step 3 — 输出 manifest JSON

写到 `<project>/.skillshare/manifest.json`。

### Step 4 — User Gate(高风险动作)

输出 manifest 后:
1. 用 markdown 摘要给 user 看(候选 skill 列表 + rationale)
2. 等待 user 确认("apply" / "skip" / "modify X")
3. 仅在 user 明确 `apply` 后,跑 `skillshare apply --from .skillshare/manifest.json`
4. 若 user 模糊回复或沉默 → **不动**,只留 manifest.json

### Step 5 — 落地 + 记录版本

- 写 `<project>/.skillshare/manifest.json`(canonical)
- 若 user apply 了 → 跑 skillshare 实际启用 + 写 `.skillshare/applied-at` 记录 ISO 时间 + 在 manifest 加 `applied_at` 字段

### Step 6 — Halt

不主动重复触发自己。下次触发由:cwd 变化 / user 显式 ask / experience-summary 阶段切换信号。

## Output Contract

### Manifest JSON Schema(简化版,主体)

```jsonc
{
  "$schema": "meta-skill/manifest/v1",
  "meta_skill_version": "1.x.x",        // 本 skill 自身版本
  "generated_at": "2026-05-30T08:00:00Z",
  "applied_at": null,                    // user gate 通过后填
  "project": {
    "root": "/abs/path/to/project",     // 必须是当前 cwd 项目根
    "name": "unimail",                   // 从 package.json/Cargo.toml/dir
    "type": ["frontend", "extension"],   // 多栈数组,1+ entry
    "stage": "dev"                       // bootstrap | dev | debug | finish
  },
  "signals": [                           // 推断依据,每条带 source
    { "kind": "tech", "evidence": "package.json:react@19", "weight": 0.9 },
    { "kind": "stage", "evidence": "git log: 0 release tag", "weight": 0.7 }
  ],
  "enable":  ["flow-dev-task", "director-frontend", "clean-commit"],
  "disable": ["flow-project-finish", "flow-ext-publish"],
  "keep":    ["hat", "experience-summary"],  // 全局常驻,本 skill 不动
  "rationale": [                         // 逐项,enable/disable 必有
    { "skill": "flow-dev-task",     "reason": "stage=dev 默认配" },
    { "skill": "director-frontend", "reason": "react@19 detected" }
  ],
  "previous_manifest": null              // 若覆盖已有 manifest,放旧版 sha256
}
```

**字段约束**:
- `enable` 与 `disable` 不可交集(冲突 → reject,见 Red Flags)
- `enable[i]` 必须存在于 `skillshare list-available` 输出中
- `rationale` 必须覆盖 `enable ∪ disable` 全集
- `signals[]` 至少 1 条(无信号 = 无依据 = 不写)

### 分流

- **基线 JSON / markdown 分流** 见 `../_shared/output-contract-schema.md`
- **落盘产物** = `<project>/.skillshare/manifest.json`(canonical)
- **对话响应** = markdown 摘要(给 user 看,**不**输出整 JSON)
- 完整 schema 见 `references/manifest-schema.md`

## Integration with skillshare

skillshare 是 manifest 的**唯一消费者 + 唯一执行入口**。本 skill 永远不直接改 `.skillshare/enabled.txt`。

**契约命令**(按调用顺序):

```bash
# 1. (read-only) 列当前项目可启用的 skill 池,Step 2 用来验证 enable[] 合法
skillshare list-available --scope project --cwd .

# 2. (read-only) 看当前生效的 skill,做 diff 用
skillshare status --scope project --cwd .

# 3. (write) user apply 后,Step 5 唯一执行入口
skillshare apply --from .skillshare/manifest.json --scope project

# 4. (optional) revert 到上一次 applied 状态(若 user 后悔)
skillshare revert --scope project --to previous
```

**契约不变量**:
- `skillshare apply` 读取 `enable[]` / `disable[]` / `keep[]`,以 manifest 为准
- skillshare 自身错误(skill 不存在 / 冲突)必须 surface 回本 skill,**不**静默吞
- 本 skill 永远不绕过 skillshare 写 `enabled.txt`(绕过 = 状态漂移,见 Red Flags)

## Cross-Skill Boundaries

### Upstream — experience-summary 信号契约

`experience-summary` 是主要的非用户上游触发者。它在以下场景主动 invoke 本 skill:

- 检测到项目阶段切换(dev → finish / debug → dev / bootstrap → dev)
- 检测到技术栈新增(新加 framework / 主语言)
- 检测到 incident 频率突变(连续 3 个 hotfix → 标 `debug` 阶段)

**信号 schema**(由 exp-sum 定义,本 skill 消费):

```jsonc
{
  "trigger": "stage-shift",            // stage-shift | stack-change | incident-burst
  "from": "dev",
  "to":   "finish",
  "evidence": ["git tag v1.0.0 created", "main branch frozen"],
  "confidence": 0.8                    // < 0.6 本 skill 应当 user gate 更谨慎
}
```

本 skill 收到信号后**仍走完整 6 步**(不跳 user gate)。信号只是触发,不是授权。

### Downstream — flow-skill-research 调用契约

当 Step 2 候选 skill 不明确(如非主流技术栈 / 无匹配阶段模板),本 skill **可调用** `flow-skill-research`:

- 输入:`{ project_type, stage, gap_description }`
- 输出:研究报告 + 候选 skill 列表
- 本 skill 拿到结果后,把候选并入 `enable[]` 候选池,再进 Step 4 user gate
- **不**让 flow-skill-research 直接改 manifest(隔离责任:research = 出 idea,meta-skill = 出 manifest)

### Sibling meta 类 skill

- `hat`:hat default 激活,但本 skill 跑时输出是配置文件不是对话响应,hat 告知行**不**写入 manifest.json
- `unblock-recipes`:本 skill 卡壳(如推断不出 stage)→ 让 unblock 接手,不死循环

## Red Flags — STOP

- **不经 user 确认就实际改 `.skillshare/enabled.txt` 或 skillshare config**(高风险动作 gate 违反)
- **改全局 skillshare 配置**(`~/.config/skillshare/`)— 本 skill 只动当前项目 `.skillshare/`
- **改其他项目的 manifest**(不是当前 cwd)
- **manifest 推断没列 rationale**
- **同时 enable + disable 同一个 skill**(必须 reject)
- **enable 一个根本不在 skillshare 源里的 skill**(`skillshare list-available` 应当先 check)
- **覆盖一份用户手改过的 manifest**(应当先 backup 旧版,加 `previous_manifest` 字段)

## Always-Follow 底线

`../_shared/constitution.md` 优先。本 skill 永远尊重 constitution 的高风险动作 gate(不替 user 单方面动 `.skillshare/`)。

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "user 之前 apply 过类似 manifest,这次直接 apply" | **不行**。每次都要 user 显式 apply,缓存信任不延续 |
| "项目还没 git init,先按 bootstrap 配" | **不行**。无 git = 无足够信号,应让 user 显式说 |
| "manifest 跟上次一样,跳过写盘" | **可以**。hash 相同只更新 `last_evaluated_at` |
| "skillshare 命令报错,我自己改 enabled.txt" | **不行**。skillshare 是唯一执行入口 |
| "exp-sum 信号 confidence=0.95,跳 user gate" | **不行**。confidence 只影响候选权重,不豁免 gate |

## Codex Delegation Hook

本 skill 是元判断 + 配置生成,**不**派 Codex(SPEC 写完输出已成型,Codex 没增值)。

## Relationship to Other Skills(总览)

- **Upstream**:agent 主对话检测 cwd / 用户显式 / `experience-summary` 阶段切换信号(见 Cross-Skill 段)
- **Downstream**:`skillshare`(命令契约见 Integration 段)/ `flow-skill-research`(候选不明时调用)/ 后续会话
- **不替代**:`flow-skill-dev`(新建 skill)/ `sync-skills`(同步到中心库)/ `flow-skill-research`(本 skill 可调用它)

## Reuse

- `references/project-detection.md` — 技术栈 / 阶段 / 规则 / incident 探测细则
- `references/manifest-schema.md` — manifest JSON schema 完整版 + 4 阶段候选 skill 矩阵
- `tests/cases.md` — 行为测试用例
