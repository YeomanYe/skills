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

本 skill 在以下时刻被触发,**自动探测项目特征 → 生成 skill manifest → 让 skillshare 按 manifest enable/disable**:
- agent 进入新项目目录(cwd 变化 + 是 git repo)
- 用户显式说"配置这个项目的 skill"
- 项目阶段切换信号触发(由 experience-summary 监测)

**核心信念**:
- 项目特征决定 skill 集合(技术栈 + 阶段 + 历史 incident)
- manifest 是**配置产物**,不是 agent 直接 import 的执行入口
- skillshare 是真正的 enable/disable 执行者,本 skill 只生成 manifest
- 高风险动作(实际改 `.skillshare/`)必须 user gate
- **边界情况比主流程更重要**:monorepo / nested / 多语言 / corrupt manifest 都要明确处理路径,不能默认 fallthrough

## When to Use

- agent cwd 切到一个**新 project**(本会话内首次进入)
- 用户说"这个项目要配什么 skill"/ "重新评估 skill"/ "项目阶段变了"
- `experience-summary` 监测到阶段切换信号,主动调本 skill
- 项目内已有 `.skillshare/manifest.json` 但 mtime > 7 天前 + 项目状态明显变化(比如新增 release tag / 切了主分支)
- monorepo 内切到某个子 package 目录(子 project 视为独立单元,见 Q&A)

## When NOT to Use

- 改**全局** skill 配置(`~/.config/skillshare/`)— 本 skill 只动当前项目
- 改**其他项目**的 manifest(只评估 cwd 项目)
- 新建 skill 到中心库 → 用 `flow-skill-dev`
- 同步 skill 到中心库 → 用 `sync-skills`
- 用户只问"我项目里有哪些 skill?" — 这是 read-only,直接 ls `.skillshare/manifest.json`,不重新生成
- 用户明确说"我自己来配,别 enable 任何"→ 写空 manifest(`enable: []`)后 halt,不推断

## Required Workflow

### Step 1 — 探测项目特征(并行,只读)

**Step 1.0 — 边界判定(必先做)**:
- **找 project root**:从 cwd 向上找 `.git` / `package.json` / `Cargo.toml` / `pyproject.toml`,取最近的作为 root。
- **submodule / nested 检测**:cwd 含 `.git` 文件(而非目录)→ 是 submodule,把 submodule 视为独立 project(其 `.skillshare/` 走 submodule 自己的)。
- **monorepo 检测**:root 含 `pnpm-workspace.yaml` / `lerna.json` / `nx.json` / `turbo.json` / `Cargo.toml` 带 `[workspace]` / `packages/*` 目录结构 → 标记 `is_monorepo: true`,workflow 分叉(见下文 Step 2.5)。
- **nested project**:cwd 不在 git root 但本目录有自己的 manifest(如 `apps/web/package.json`)→ 当作 sub-project,manifest 落在本目录的 `.skillshare/`,不污染 root。

**A. 技术栈**(从文件存在性 + package manifest 推断):
- `package.json` → 检 dependencies/scripts:
  - `react` / `next` / `vue` / `svelte` → frontend
  - `electron` / `tauri` → desktop
  - `react-native` / `expo` → mobile
  - `wxt` / `plasmo` / `manifest.json` → browser extension
- `Cargo.toml` → rust(若有 `[workspace]` 段,展开 members)
- `pyproject.toml` / `requirements.txt` → python
- `go.mod` → go
- `Gemfile` → ruby
- 多个共存 → **多栈混合**(详见 Step 2.5)

**B. 项目阶段**(从 git history 推断):
- 0 commit / < 5 commits → `bootstrap`
- 有 commit + 主分支活跃 + 无 release tag → `dev`
- 含 `release-*` / `v[0-9]` tag + 持续 maintenance → `finish`
- 最近 git log 含 "fix"/"revert"/"hotfix" 集中(> 30% commits in last 7d)→ `debug`
- 多信号叠加 → 取最强;无法判定 → 默认 `dev`
- submodule:阶段独立判定,不继承宿主项目

**C. 项目规则**(从 docs 推断):
- `CLAUDE.md` / `AGENTS.md` / `GEMINI.md`(根目录或 docs/)
- `CONTRIBUTING.md` / `docs/**/rules.md`
- 内含 hint(如 "use pnpm not npm" / "MobX with makeObservable")
- monorepo:root CLAUDE.md + 各子 package 自己的 CLAUDE.md 都要读,子 package 规则覆盖 root

**D. 历史 incident**(从 git log / .agent/ 残留 / commit message 推断):
- 含 `flow-codex-goal` / `todo-flow` 历史产物 → 跑过编排任务
- commit 含 "incident" / "rollback" / "revert" → 标记 high-attention 项目
- `.agent/tasks/` 有未完成任务 → 标记 follow-up needed

### Step 2 — 推断阶段 + 候选 skill 集

按 `references/manifest-schema.md` 的"阶段 × 技术栈 → 候选 skill"矩阵,生成候选列表。

**4 个阶段的默认 skill 集**(详见 `references/manifest-schema.md`):

| 阶段 | 默认 skill |
|---|---|
| `bootstrap` | `project-prep` / `flow-project-bootstrap` / `director-architect` |
| `dev` | `flow-dev-task` / `director-frontend` (UI 栈) / `clean-commit` / `todo-flow` (如已 init) |
| `debug` | `superpowers:systematic-debugging` / `unblock-recipes` / `cdp-browser-control` (UI 栈) |
| `finish` | `flow-project-finish` / `delivery-gate` / `clean-commit` / `flow-ext-publish` (扩展项目) |

**正交常驻候选**(任何阶段都建议):`hat` / `experience-summary` / `unblock-recipes`
> 但用户已声明这 3 个由 skillshare 单独管,本 skill **不**重复推荐它们(避免 manifest 噪音)。

### Step 2.5 — Monorepo / 多语言混合分叉

- **monorepo**:为 root 生成一份 union manifest(`enable[]` 取所有子 package 的并集 + 标 `scope: "monorepo-root"`);**同时**为每个子 package 写各自 `.skillshare/manifest.json`(stage 独立判定)。
- **rust workspace + 前端 + python ML 混合**:多栈合并候选,但若 enable 数 > 12 → 让 user 选主栈,避免 skill 过载。
- **冲突规则**:子 package 显式 disable 的 skill,union manifest 不可 enable(子 package 优先)。

### Step 3 — 输出 manifest JSON

写到 `<project>/.skillshare/manifest.json`(详见 `references/manifest-schema.md`)。

JSON 必含:
- `project_type` / `stage` / `signals[]`(推断依据)
- `enable[]` / `disable[]` / `keep[]`(下次同步动作)
- `rationale[]`(逐项推断说明)
- `generated_at` / `meta_skill_version`
- monorepo 时加 `scope` / `parent_manifest`(子 package 指向 root)

**Corrupt manifest 处理**:若 `.skillshare/manifest.json` 已存在但 JSON parse 失败 / schema 不符 → 备份到 `.skillshare/manifest.json.broken.<timestamp>`,提示 user,然后当作首次生成。**不要**静默覆盖。

### Step 4 — User Gate(高风险动作)

**禁止**未经 user 确认就实际改 `.skillshare/enabled.txt` 或对应 skillshare config。

输出 manifest 后:
1. 用 markdown 摘要给 user 看(候选 skill 列表 + rationale)
2. 等待 user 确认("apply" / "skip" / "modify X")
3. 仅在 user 明确 `apply` 后,跑 skillshare 实际命令(如 `skillshare enable <skill>` / `skillshare disable <skill>`)
4. 若 user 模糊回复或沉默 → **不动**,只留 manifest.json 在 `.skillshare/`
5. user 说"我自己来配"→ 写空 `enable: []` + `user_opt_out: true`,halt

### Step 5 — 落地 + 记录版本

- 写 `<project>/.skillshare/manifest.json`(canonical 记录)
- 若 user apply 了 → 跑 skillshare 实际启用 + 写 `<project>/.skillshare/applied-at` 记录 ISO 时间
- 同时在 manifest.json 加 `applied_at` 字段
- monorepo 场景:root + 各子 package 各写一份,apply 顺序 = 子 package 先,root 后

### Step 6 — Halt

不主动重复触发自己。下次触发由:
- cwd 变化
- user 显式 ask
- experience-summary 阶段切换信号

### Step 7 — Manifest 复审(可选,自动)

后续会话进入同一项目时,若同时满足:
- `.skillshare/manifest.json` 存在
- `generated_at` mtime > 7 天前
- 项目状态明显变化(新增 release tag / 主分支切换 / commit 数 +20% / CLAUDE.md mtime 更新)

→ 自动重新 invoke 本 skill(从 Step 1 重跑),把上次 manifest 作为 `previous_manifest` 字段写入新 JSON 供 diff 对照。若 user 已 `user_opt_out: true`,跳过自动复审。

## Output Contract

- **基线 JSON / markdown 分流** 见 `../_shared/output-contract-schema.md`
- **本 skill 落盘产物** = `<project>/.skillshare/manifest.json`(canonical)
- **对话响应**(给 user)= markdown 摘要(候选 skill + rationale + 等确认指令)
- **不向 user 输出整个 JSON**(读不动);user 想看完整 JSON 自己 cat 文件
- 完整 schema 见 `references/manifest-schema.md`

## Q&A — 常见边界场景

**Q1: 我项目是个 monorepo(pnpm workspace + 5 个 packages),你怎么处理?**
A: 走 Step 2.5 分叉。root 生成 union manifest(并集 + 标 monorepo-root),每个子 package 独立判定 stage 再各写一份。子 package 的 disable 优先于 root enable。

**Q2: cwd 是 submodule,我希望它继承宿主项目的 skill 集?**
A: 默认**不**继承(submodule 独立)。若要继承,user 显式说"继承宿主"才走;否则按 submodule 自己的 git history 判定。

**Q3: 项目是 rust workspace + 前端 + python ML 三栈混合,enable 列表会不会爆?**
A: 会。Step 2.5 规则:enable 数 > 12 时,让 user 选 1-2 个主栈,其他栈只装 skeleton skill(如 clean-commit / hat),不装该栈的全套 director-*。

**Q4: 我自己来配 skill,别 enable 任何,你能跳过吗?**
A: 能。Step 4 第 5 条:写空 `enable: []` + `user_opt_out: true`,后续 Step 7 自动复审也跳过。user 可随时手动 refresh 重置。

**Q5: 已有 manifest 但是损坏 / 无效 JSON,你会直接覆盖吗?**
A: 不会。Step 3 corrupt 分支:备份到 `.broken.<timestamp>`,提示 user,然后当首次生成。绝不静默覆盖(对应 Red Flags 第 7 条)。

**Q6: 上游 experience-summary 的触发条件升级了,会不会双触发?**
A: 本 skill 自己 idempotent — 同 input 同 output,且 Step 7 复审带 7 天冷却。即使 exp-sum 在短期内重复 invoke,Step 1 推断 hash 相同时仅更新 `last_evaluated_at`(对应 Rationalizations 表第 3 行),不重写主体也不重复 user gate。

## Red Flags — STOP

- **不经 user 确认就实际改 `.skillshare/enabled.txt` 或 skillshare config**(高风险动作 gate 违反)
- **改全局 skillshare 配置**(`~/.config/skillshare/`)— 本 skill 只动当前项目 `.skillshare/`
- **改其他项目的 manifest**(不是当前 cwd)
- **manifest 推断没列 rationale**(说不清为什么 enable / disable 不允许写入)
- **同时 enable + disable 同一个 skill**(矛盾,必须 reject)
- **enable 一个根本不在 skillshare 源里的 skill**(`skillshare list-available` 应当先 check)
- **覆盖一份用户手改过的 manifest**(应当先 backup 旧版,加 `previous_manifest` 字段)
- **静默覆盖 corrupt manifest**(必须备份 `.broken.<timestamp>` 并提示 user)
- **monorepo root manifest enable 了子 package 显式 disable 的 skill**(子优先规则违反)
- **submodule 推断时继承了宿主项目 stage**(应独立判定,除非 user 显式说继承)

## Always-Follow 底线

`../_shared/constitution.md` 优先。本 skill 永远尊重 constitution 的高风险动作 gate(不替 user 单方面动 `.skillshare/`)。

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "user 之前 apply 过类似 manifest,这次直接 apply 吧" | **不行**。每次都要 user 显式 apply,缓存信任不延续 |
| "项目还没 git init,先按 bootstrap 配吧" | **不行**。无 git = 无足够信号,应让 user 显式说要哪些 skill,不擅自推断 |
| "manifest 跟上次一样,跳过写盘" | **可以**。若推断结果跟现有 manifest.json hash 相同,只更新 `last_evaluated_at`,不重写主体 |
| "skillshare 命令报错,我自己改 enabled.txt" | **不行**。skillshare 是唯一执行入口,绕过 = 状态漂移 |
| "monorepo 太麻烦,只给 root 写一份,子 package 共用" | **不行**。子 package stage 不同(如 apps/web 在 dev、apps/api 在 finish),共用会装错 skill |
| "corrupt manifest 反正坏了,直接覆盖省事" | **不行**。先备份 `.broken.<timestamp>`,user 可能手改过想恢复 |

## Codex Delegation Hook

本 skill 是元判断 + 配置生成,**不**派 Codex(SPEC 写完输出已经成型,Codex 没增值)。

## Relationship to Other Skills

### Upstream(谁会触发本 skill)
- agent 主对话 / 主 orchestrator 检测 cwd 变化 → 本 skill
- 用户显式触发(关键词见 description)
- `experience-summary` 监测阶段切换信号 → 主动 invoke(上游触发条件升级时,本 skill 仍 idempotent,见 Q6)

### Downstream(本 skill 输出给谁)
- `skillshare`(读 `.skillshare/manifest.json` + applied list,负责实际 enable/disable)
- 后续 agent 会话(读 manifest 知道该项目要的 skill)

### 并列 meta 类 skill(跟 hat / unblock-recipes / experience-summary 关系)
- **`hat`**:hat default 激活,但本 skill 跑时(输出是配置文件不是对话响应),hat 告知行**不**写入 manifest.json。详见 hat SKILL.md "跟其他 meta 类 skill 的优先级"段。
- **`unblock-recipes`**:本 skill 卡壳(如推断不出 stage / monorepo 边界判定失败)→ 让 unblock 接手,不死循环。
- **`experience-summary`**:上游触发本 skill;同时本 skill 输出的 `signals[]` 段可作为 exp-sum 后续分诊的输入。

### 不替代
- `flow-skill-dev`(新建 skill 到中心库)
- `sync-skills`(同步 skill 到中心库)
- `flow-skill-research`(调研 skill 候选)— 但本 skill **可调用** flow-skill-research 当某 stage 候选 skill 不明确时

## Reuse

- `references/project-detection.md` — 技术栈 / 阶段 / 规则 / incident / monorepo / submodule 探测细则
- `references/manifest-schema.md` — manifest JSON schema + 4 阶段候选 skill 矩阵 + monorepo union 规则
- `tests/cases.md` — 行为测试用例(含 monorepo / corrupt / opt-out 边界)
