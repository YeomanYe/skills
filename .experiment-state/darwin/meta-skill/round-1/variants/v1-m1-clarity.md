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

> 受 `../_shared/constitution.md` 约束(always-follow,身份 / 安全 / 高风险动作 gate)

# meta-skill — 项目级 skill 自适应配置

## Overview

日常加载 26+ skill 会污染 context,实际只有少数跟当前项目相关。本 skill 在以下时刻**探测项目特征 → 生成 manifest → 让 skillshare enable/disable**:

- cwd 进入新 git repo
- 用户显式说"配置这个项目的 skill"
- `experience-summary` 监测到阶段切换

**核心信念**: 决策依据 = 技术栈 + 阶段 + 历史 incident;manifest 是配置产物(非执行入口);skillshare 是执行者;实际改 `.skillshare/` 必须 user gate。

## When to Use / NOT to Use

**Use**:
- cwd 切到本会话内首次进入的 project
- 用户说"配什么 skill"/ "重新评估"/ "项目阶段变了"
- `experience-summary` 上游触发
- 已有 `manifest.json` 但 mtime > 7 天 + 状态明显变化(新 release tag / 切主分支)

**NOT use**:
- 改全局配置(`~/.config/skillshare/`)
- 改其他项目的 manifest
- 新建 skill 到中心库 → `flow-skill-dev`
- 同步 skill 到中心库 → `sync-skills`
- 用户只问"我项目里有哪些 skill?" → 直接 ls `.skillshare/manifest.json`,不重新生成

## Required Workflow

### Step 1 — 探测项目特征(并行,只读)

**A. 技术栈** — 从文件 + manifest 推断:

| 信号 | 判定 |
|---|---|
| `package.json` deps: `react`/`next`/`vue`/`svelte` | frontend |
| `package.json` deps: `electron`/`tauri` | desktop |
| `package.json` deps: `react-native`/`expo` | mobile |
| `wxt`/`plasmo`/`manifest.json` | browser extension |
| `Cargo.toml` / `pyproject.toml`+`requirements.txt` / `go.mod` / `Gemfile` | rust / python / go / ruby |
| 多个共存 | 多栈混合 |

**B. 项目阶段** — 从 git history 推断:

| 信号 | 阶段 |
|---|---|
| 0 / < 5 commits | `bootstrap` |
| 有 commit + 主分支活跃 + 无 release tag | `dev` |
| 含 `release-*` / `v[0-9]` tag + 持续 maintenance | `finish` |
| 最近 log "fix"/"revert"/"hotfix" > 30% (last 7d) | `debug` |

> 多信号叠加取最强;无法判定 → 默认 `dev`。

**C. 项目规则** — `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` / `CONTRIBUTING.md` / `docs/**/rules.md`,提取 hint(如 "use pnpm not npm")。

**D. 历史 incident**:
- `flow-codex-goal` / `todo-flow` 残留 → 跑过编排任务
- commit 含 "incident" / "rollback" / "revert" → high-attention
- `.agent/tasks/` 未完成任务 → follow-up needed

### Step 2 — 推断阶段 + 候选 skill 集

按 `references/manifest-schema.md` 的"阶段 × 技术栈 → 候选 skill"矩阵生成候选。

| 阶段 | 默认 skill |
|---|---|
| `bootstrap` | `project-prep` / `flow-project-bootstrap` / `director-architect` |
| `dev` | `flow-dev-task` / `director-frontend` (UI 栈) / `clean-commit` / `todo-flow` (如已 init) |
| `debug` | `superpowers:systematic-debugging` / `unblock-recipes` / `cdp-browser-control` (UI 栈) |
| `finish` | `flow-project-finish` / `delivery-gate` / `clean-commit` / `flow-ext-publish` (扩展项目) |

**正交常驻候选**(任何阶段):`hat` / `experience-summary` / `unblock-recipes`。但这 3 个由 skillshare 单独管,本 skill **不**重复推荐(避免噪音)。

### Step 3 — 输出 manifest JSON

写到 `<project>/.skillshare/manifest.json`,必含:
- `project_type` / `stage` / `signals[]`(推断依据)
- `enable[]` / `disable[]` / `keep[]`(下次同步动作)
- `rationale[]`(逐项推断说明)
- `generated_at` / `meta_skill_version`

完整 schema 见 `references/manifest-schema.md`。

### Step 4 — User Gate(高风险动作)

**禁止**未经 user 确认就改 `.skillshare/enabled.txt` 或 skillshare config。

1. 给 user 看 markdown 摘要(候选 skill + rationale)
2. 等待确认("apply" / "skip" / "modify X")
3. 仅在明确 `apply` 后跑 skillshare 命令(`skillshare enable/disable <skill>`)
4. 模糊回复或沉默 → **不动**,只留 manifest.json

### Step 5 — 落地 + 记录版本

- 写 `<project>/.skillshare/manifest.json`(canonical)
- 若 user apply → 跑 skillshare 实际启用 + 写 `<project>/.skillshare/applied-at`(ISO 时间)+ manifest.json 加 `applied_at` 字段

### Step 6 — Halt

不主动重复触发自己。下次触发由:cwd 变化 / user 显式 ask / `experience-summary` 阶段切换信号。

## Output Contract

- 基线 JSON / markdown 分流见 `../_shared/output-contract-schema.md`
- **落盘产物** = `<project>/.skillshare/manifest.json`(canonical)
- **对话响应** = markdown 摘要(候选 skill + rationale + 等确认指令)
- **不**向 user 输出整个 JSON(读不动);要看完整内容自己 cat

## Red Flags — STOP

- **不经 user 确认就实际改 `.skillshare/enabled.txt` 或 skillshare config**(高风险动作 gate 违反)
- **改全局 skillshare 配置**(`~/.config/skillshare/`)— 本 skill 只动当前项目 `.skillshare/`
- **改其他项目的 manifest**(不是当前 cwd)
- **manifest 推断没列 rationale**(说不清为什么 enable / disable 不允许写入)
- **同时 enable + disable 同一个 skill**(矛盾,必须 reject)
- **enable 一个根本不在 skillshare 源里的 skill**(`skillshare list-available` 应当先 check)
- **覆盖一份用户手改过的 manifest**(应当先 backup 旧版,加 `previous_manifest` 字段)

## Always-Follow 底线

`../_shared/constitution.md` 优先。本 skill 永远尊重 constitution 的高风险动作 gate(不替 user 单方面动 `.skillshare/`)。

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "user 之前 apply 过类似 manifest,这次直接 apply 吧" | 不行。每次都要显式 apply,缓存信任不延续 |
| "项目还没 git init,先按 bootstrap 配吧" | 不行。无 git = 无足够信号,应让 user 显式声明 |
| "manifest 跟上次一样,跳过写盘" | 可以。hash 相同只更新 `last_evaluated_at`,不重写主体 |
| "skillshare 命令报错,我自己改 enabled.txt" | 不行。skillshare 是唯一执行入口,绕过 = 状态漂移 |

## Codex Delegation Hook

元判断 + 配置生成,**不**派 Codex(SPEC 写完输出已成型,Codex 无增值)。

## Relationship to Other Skills

**Upstream(谁触发本 skill)**:
- agent 主对话 / orchestrator 检测 cwd 变化
- 用户显式触发(关键词见 description)
- `experience-summary` 监测阶段切换信号

**Downstream(本 skill 输出给谁)**:
- `skillshare`(读 manifest + applied list,实际 enable/disable)
- 后续 agent 会话(读 manifest 知道项目要的 skill)

**并列 meta 类 skill**:
- `hat`:default 激活,但本 skill 输出是配置文件不是对话响应,hat 告知行**不**写入 manifest.json(详见 hat SKILL.md "跟其他 meta 类 skill 的优先级"段)
- `unblock-recipes`:本 skill 卡壳(推断不出 stage)→ 让 unblock 接手,不死循环
- `experience-summary`:上游触发本 skill;输出 `signals[]` 可作为 exp-sum 后续分诊输入

**不替代**:`flow-skill-dev`(新建)/ `sync-skills`(同步)/ `flow-skill-research`(调研)— 但本 skill **可调用** flow-skill-research 当某 stage 候选不明确时。

## Reuse

- `references/project-detection.md` — 技术栈 / 阶段 / 规则 / incident 探测细则
- `references/manifest-schema.md` — manifest JSON schema + 4 阶段候选 skill 矩阵
- `tests/cases.md` — 行为测试用例
