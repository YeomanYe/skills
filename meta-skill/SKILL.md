---
name: meta-skill
description: >
  [explicit-only · 用户显式点名才触发] 给项目配置项目级 skill overlay —— 检测技术栈/类型后挑选推荐
  skill、算出相对全局已有 skill 的 delta、symlink 进项目 agent-native 目录(.claude/skills /
  .codex/skills / .agents/skills)并更新 CLAUDE.md / AGENTS.md 的 sentinel block。apply 需用户
  显式确认;refresh 人手触发。本 skill **不自主触发**——只在用户显式点名("meta-skill" /
  "meta-skill refresh" / "配下这个项目的 skill" / "configure skills for this project")时使用。
  **不要根据场景关键词自动触发。**
  Do NOT use for: 改全局 skill 配置(~/.config/skillshare/)/ 改其他项目的配置 /
  新建 skill(那是 flow-skill-dev)/ 同步到中心库(sync-skills)/ 自动 hook 触发(必须人手)。
---

> 本 skill 受 `../_shared/constitution.md` 约束(always-follow,身份 / 安全 / 高风险动作 gate)

# meta-skill — 项目级 skill 自适应配置

## Overview

把"这个项目应该启用什么 skill"做成一个**差分编排**动作:

```
recommended(stack × type) − globally_active(skillshare 当前 active 集) = delta
```

只把 `delta` 那部分 symlink 到项目内 agent-native 目录(`.claude/skills/` `.codex/skills/`
`.agents/skills/`),同步把"全局已可用 + 项目级补充"两段写进 `CLAUDE.md` /
`AGENTS.md` 的 sentinel 块,让 LLM 看 .md 时知道项目有哪些 skill,agent harness 看 fs
时能触发它们。

**不发明 manifest.json,不动全局,不订阅自动触发**——结构清爽,自愈幂等。

## When to Use

- 用户首次进入项目,说"配下这个项目的 skill" / "看看项目要哪些 skill"
- 用户手动 refresh(中心库新加了 skill,或全局集变了想重算 delta)
- 检测到项目根有 `.claude/skills/` 但 sentinel 块过期或不一致

## When NOT to Use

- 改全局配置 `~/.config/skillshare/`(meta-skill **从不**改这里)
- 新建 skill → `flow-skill-dev`
- 把单个 skill 同步到中心 → `sync-skills`
- 用户只问"全局有什么 skill?"(read-only 用 `skillshare list` 即可,不必走本流程)
- 用户说"我自己手动配" → 直接 halt,不要推断
- **不允许任何自动 hook 触发**(cwd 切换、exp-sum 上游、cron 都不行)

## Architectural Principles

| # | 原则 | 含义 |
|---|---|---|
| 1 | **不动全局** | 不改 `~/.config/skillshare/config.yaml`、不删 `~/.claude/skills/` 母目录任何文件、不跑 `skillshare disable/enable` |
| 2 | **Apply Gate** | 任何 fs 写操作前用户必须明确 yes/apply/go;模糊回复("好"/"嗯"/"随便")= 不执行 |
| 3 | **可审计** | sentinel 段在 git diff 可见 + symlink 在 ls -la 可见 |
| 4 | **Idempotent** | refresh 多次跑结果一致,不累加垃圾;sentinel 段每次重算后**结构等价** |
| 5 | **Agent native** | 用 `.claude/skills/` `.codex/skills/` `.agents/skills/`,不发明 `.skillshare/skills/` |

## High-Risk Actions — 必经 User Gate

以下动作**任何一个**触发前必须先输出 plan + 等用户明确同意,不能跳过、不能合并:

1. 建 / 改 / 删 `<project>/.claude/skills/<name>` 任何 symlink
2. 建 / 改 / 删 `<project>/.codex/skills/<name>` 或 `<project>/.agents/skills/<name>`
3. 写 `CLAUDE.md` / `AGENTS.md` 的 sentinel 段(无论新建还是改写)
4. 改 `<project>/.gitignore`(自动加 `.claude/skills/` 等条目算改)
5. 覆盖用户在 sentinel 段内**手改过**的内容(必须 diff 给用户看)
6. 触碰 `<project>/.claude/skills/<name>` 但发现是**非 symlink**(实文件)→ 不覆盖,报错
7. 写 / 覆盖 `<project>/prepare.sh`(用户手改过 → diff 后确认;非 meta-skill 生成的 → halt)

read-only 动作(读 `package.json` / `git log -1` / `skillshare list --json` / ls 项目目录)
**不**算 high-risk,可以直接做。但输出必须记到 plan 的 `signals` 字段。

## Required Workflow

### Step 1 — 边界 + 探测(只读)

**Step 1.0 — 项目根判定**:
- 从 cwd 向上找最近的 `.git` 目录(file 或 directory 都算);找不到 → halt,要求用户 cd 到正确根
- root 找到后,**所有后续操作以 root 为基准**,不操作 root 外路径
- monorepo 检测(`pnpm-workspace.yaml` / `lerna.json` / `nx.json` / `turbo.json` / `Cargo.toml` 含 `[workspace]`)→ 询问用户是为**整个 monorepo** 配还是**当前 subpackage** 配

**Step 1.1 — 并行探测 4 个信号(只读)**:

| 信号 | 来源 | 用途 |
|---|---|---|
| 技术栈 | `package.json` deps / `Cargo.toml` / `pyproject.toml` / `go.mod` / `pubspec.yaml` | 决定 stack(react / vue / next / rust / python / go / flutter / ...) |
| 项目类型 | 同上 + manifest 字段 / 目录结构(`/src/components` `/src/popup` `/src/background`)| 决定 project_type(frontend / browser-extension / mobile / backend / cli / mixed) |
| 项目规则 | `CLAUDE.md` / `AGENTS.md` / `CONTRIBUTING.md` | 作为偏好上下文(写入 plan,不直接驱动决策) |
| 当前 sentinel | `CLAUDE.md` / `AGENTS.md` 里的 `<!-- meta-skill:begin -->` 段 | 跟新算结果对比看是否有用户手改 |

详细 signature mapping 见 `references/project-detection.md`。

**Step 1.2 — 不做的事**:
- ❌ 不探测 stage(bootstrap/dev/debug/finish)— **stage 是用户意图,不是代码可探测属性**;skill 自己的 description 处理"何时该触发",meta-skill 不预判
- ❌ 不读 `git log` 推断阶段
- ❌ 不读 `.agent/tasks/` 推断 incident 历史

### Step 2 — 计算 recommended(查表)

按 Step 1 探测到的 `stack + project_type` 查 `references/recommendations.md` 里的 lookup table,
得到一组 `recommended_skills: string[]`。

规则:
- 每个 (stack, project_type) 组合给一组 baseline skill
- 多 stack(如 React 前端 + Hono BFF)→ 各自 baseline 并集去重
- 多 project_type(如 frontend + browser-extension)→ 同上
- 没匹配的 stack/type → 用 `common-fallback` 集

### Step 3 — 计算 globally_active

```bash
# skillshare list --json 返回的是**扁平数组**(无 .skills 键),每项 keys:
# disabled / kind / name / relPath / repoName。
# .name 带 source 前缀(如 _YeomanYe-skills__meta-skill / _HKUDS...__skills__cli-hub),
# 前缀形态不统一;**最干净的 leaf skill 名 = relPath 的 basename**,直接用它。
skillshare list --json 2>/dev/null \
  | jq -r '.[] | select(.disabled | not) | .relPath' \
  | sed 's#.*/##' \
  | sort -u
```

若 `skillshare` CLI 不可用 / 报错 → fallback:

```bash
ls -1 ~/.claude/skills/ 2>/dev/null \
  | sed 's/^_[^_]*__skills__//; s/^_[^_]*__//' \
  | sort -u
```

(剥掉 plugin 前缀,得 skill name 集)

输出 `globally_active: string[]`。

### Step 4 — 计算 delta + 准备 plan

```
delta = recommended − globally_active
already_global_relevant = recommended ∩ globally_active
```

输出给用户的 plan(markdown,**不直接动文件**):

```
## meta-skill plan · <project name>

探测到:
- 技术栈: <stack list>
- 项目类型: <project_type>
- 偏好规则: <CLAUDE.md / AGENTS.md 关键摘要,若有>

已全局可用(无需 link,LLM 已能看到):
- `<name>` — <一句话用途>
- ...

项目级要新增 symlink(共 N 个):
- `<name>` — <一句话用途>
- ...

将要执行:
1. 在 <project>/.claude/skills/ 建 N 个 symlink → ~/.config/skillshare/skills/<src>/<skill>
2. 在 <project>/.codex/skills/ 同步建(low cost,保险)
3. 在 <project>/.agents/skills/ 同步建
4. 改写 CLAUDE.md 的 sentinel 段(diff 见下)
5. 改写 AGENTS.md 的 sentinel 段(diff 见下)
6. .gitignore 自动加: .claude/skills/ .codex/skills/ .agents/skills/
7. 写 / 刷新 <project>/prepare.sh(让 clone 到新机器的人能一键重建 symlink)

回 "apply" / "yes" / "go" 我执行;回别的 = 不动。
```

**plan 末尾必须明确写**:"等你明确 apply"——不可以用"我帮你做了"之类暧昧措辞。

### Step 5 — Apply Gate(必经)

用户回复必须满足:
- 明确肯定:`apply` / `yes` / `go` / `执行` / `开始` / `做吧` / `ok 开始`
- 部分肯定但说改某项:按用户改的版本重出 plan,继续等明确

**视为不同意,halt**:
- 模糊回复:`好` / `嗯` / `随便` / `按你说的来` / 沉默
- 含拒绝词:`不要` / `等等` / `先别` / `再看看`

halt 时**不留任何 fs 残留**(plan 只在对话里,没落盘任何文件)。

### Step 6 — Apply(执行,只在用户明确同意后)

按 plan 顺序执行 6 个动作:

#### 6.1 建 symlink

source 解析**必须**和 `references/prepare-sh-template.sh` 的 `resolve_source()` 一致:
`skillshare list --json` 是**扁平数组**,每项只有 `disabled/kind/name/relPath/repoName`(**无 `.path`**)。
leaf skill 名 = `relPath` 的 basename;真实 source 目录 = `$SKILLSHARE_ROOT/<relPath>`
(`SKILLSHARE_ROOT` 默认 `~/.config/skillshare/skills`)。**不要**再用 `realpath ~/.config/skillshare/skills/<source>/$skill` 这种猜前缀的旧写法。

```bash
SKILLSHARE_ROOT="${SKILLSHARE_ROOT:-$HOME/.config/skillshare/skills}"
mkdir -p <project>/.claude/skills <project>/.codex/skills <project>/.agents/skills

# 与 prepare.sh 同一 resolver:用 relPath 重建真实 source 路径
resolve_source() {
  local name="$1" relpath path
  relpath=$(skillshare list --json 2>/dev/null \
    | jq -r --arg n "$name" '.[] | select((.relPath | sub(".*/"; "")) == $n) | .relPath' \
    | head -1)
  [[ -n "$relpath" ]] || return 1
  path="$SKILLSHARE_ROOT/$relpath"
  [[ -d "$path" ]] && { echo "$path"; return 0; }
  return 1
}

for skill in $delta; do
  src=$(resolve_source "$skill" || true)
  if [[ -z "$src" ]]; then echo "errors[]: source 推断失败,跳过 $skill" >&2; continue; fi
  for target_dir in .claude/skills .codex/skills .agents/skills; do
    dst=<project>/$target_dir/$skill
    if [[ -L $dst ]]; then continue; fi          # 已是 symlink → 跳
    if [[ -e $dst ]]; then halt "非 symlink 文件已存在: $dst"; fi
    ln -s "$src" "$dst"
  done
done
```

> source 路径**只**经 `relPath` 重建,与 `prepare.sh` 的 `resolve_source()` 单一写法,
> 不再有"主体伪码 vs reference 双写法"漂移。`prepare.sh` 多一层 `SKILLSHARE_ROOT` 目录扫描兜底
> (新机器 CLI 可能缺失),apply 阶段 CLI 必在,故此处只保留 CLI 路径。

#### 6.2 写 sentinel 段

CLAUDE.md / AGENTS.md 里的 sentinel 段格式(**严格遵守**):

```md
<!-- meta-skill:begin -->
## 本项目可用 skill(meta-skill 自动维护,勿在 begin/end 之间手改)

### 全局已可用
- `<name>` — <一句话用途>

### 项目级补充(symlink 到 .claude/skills/ 等)
- `<name>` — <一句话用途>

<!-- meta-skill:meta -->
generated_at: <iso8601>
stack: <stack list>
project_type: <project_type>
total: <recommended count> = global <N> + project <M>
<!-- meta-skill:end -->
```

写入规则:
- 文件没有 sentinel 段 → 追加到文件末尾(前留一空行)
- 已有 sentinel 段 → 用新内容**完全替换** begin 和 end 之间所有内容
- begin/end **之外的内容一字不动**
- 用户手改了 begin/end 之间的内容 → 必须先 diff 给用户看,确认覆盖才动

#### 6.3 改 .gitignore

```
# meta-skill: agent-native skill dirs (symlinks, not committed)
.claude/skills/
.codex/skills/
.agents/skills/
```

只加未有的条目,已有跳过。
**注意**:`prepare.sh` 是要 commit 的,**不**进 .gitignore。

#### 6.4 写 / 刷新 `prepare.sh`(clone-portable)

`.claude/skills/` 等三个 symlink 目录都进 .gitignore,**clone 到新机器后 symlink 不复存在**。
为此每次 apply 在项目根写一份 `prepare.sh`,新机器跑一次就能按 sentinel 段重建 symlink。

**模板见 `references/prepare-sh-template.sh`**,逐字复制即可(不需要 templating);写完
`chmod +x prepare.sh`。

设计要点(模板已实现,这里说明背后逻辑):

- **不带 skill 名清单**:脚本运行时**从 `CLAUDE.md` 的 sentinel 段读"项目级补充"列表**,
  保证唯一事实源(sentinel 段已 commit)。改 sentinel = 改 prepare.sh 行为,自动同步,
  不会双源漂移
- **target 全相对**:`cd "$(dirname "$0")"` 自定位后,所有 link 写到 `./.claude/skills/<name>`
  等,不写绝对路径
- **source 多 fallback**:
  1. `$SKILLSHARE_ROOT`(显式覆盖)
  2. `skillshare list --json` 查 CLI 真实路径
  3. 兜底 `$HOME/.config/skillshare/skills/` 按目录名匹配
  4. 都拿不到 → 打印 `skillshare install <repo>` 提示但不静默跳过
- **幂等**:已存在 symlink 指对 source → skip;指错 → 报告不覆盖;非 symlink 实文件 → 报错不动
- **前提**:新机器需先装 skillshare CLI(`brew install skillshare` 或同等);**不内嵌 git clone fallback**(维护成本太高)

写入规则:
- 项目根没有 `prepare.sh` → 创建
- 已有 `prepare.sh` 且内容 = 当前模板 → skip
- 已有 `prepare.sh` 且**内容跟模板不一致**(用户手改了) → diff 给用户看,确认覆盖才动
- 已有 `prepare.sh` 但**不是 meta-skill 生成的**(无 `# meta-skill prepare.sh v1` 头) → halt,让用户重命名或确认覆盖

#### 6.5 执行后输出

按 Output Contract 出 JSON + 一句话 user-facing 总结。

### Step 7 — Refresh(手动触发)

用户说 `meta-skill refresh` / `重新评估这个项目要哪些 skill` 时:

1. 重跑 Step 1-4(得到新 plan)
2. 跟当前 sentinel 段对比,分三类:
   - **add**:新 delta 含但 sentinel 没列的 skill → 加 symlink + sentinel 加条目
   - **remove**:sentinel 列了但新 delta 没的(可能用户把它装到全局了)→ 撤 symlink + sentinel 删条目
   - **unchanged**:两边都有 → 不动
3. 用户在 sentinel 段**手改过**(begin/end 之间内容 ≠ 上次 meta-skill 写的) → diff 给用户看,问"重算覆盖你的手改吗?"
4. apply gate 同 Step 5

refresh 也走 6.4(prepare.sh):模板没变 → skip;模板版本升级了 → 当作"项目级补充"
变更同样要 diff 给用户看再覆盖。

**幂等保证**:同一项目状态 + 全局 skill 状态 → 连跑 N 次 refresh,fs 和 sentinel 段最终结果完全一致(prepare.sh 也是字节级一致)。

### Step 8 — Output Contract

按 `../_shared/output-contract-schema.md` 基线 JSON + 本 skill 扩展字段:

```json
{
  "verdict": "applied | halted-by-gate | halted-by-error | refresh-no-change",
  "must_fix": [],
  "should_fix": [],
  "evidence_paths": ["<project>/CLAUDE.md", "<project>/AGENTS.md", "<project>/.claude/skills/"],
  "artifact_path": null,
  "project_root": "/abs/path/to/project",
  "detected_stack": ["react", "typescript"],
  "detected_project_type": ["frontend", "browser-extension"],
  "recommended": ["..."],
  "globally_active": ["..."],
  "delta_add": ["..."],
  "delta_remove": ["..."],
  "actions_planned": ["link <skill> → .claude/skills/", "...", "write prepare.sh"],
  "actions_applied": ["..."],
  "user_gate_response": "apply | halt | refused",
  "skillshare_cli_available": true,
  "fallback_used": "none | ls",
  "prepare_sh_path": "<project>/prepare.sh | null",
  "prepare_sh_status": "created | refreshed | skipped-equivalent | halted-user-edited | n/a",
  "errors": []
}
```

## Failure Modes

详细清单见 `references/failure-modes.md`,主体只保留高频:

1. **skillshare CLI 不可用**:fallback 到 `ls ~/.claude/skills/`,`fallback_used: "ls"`,继续
2. **没找到 `.git`**:halt + 提示用户 cd 到正确根
3. **`.claude/skills/<name>` 已是非 symlink 实文件**:halt + 报错,让用户先处理
4. **CLAUDE.md / AGENTS.md 不存在**:apply 时自动创建 + 只写 sentinel 段(不补别的内容)
5. **多个 sentinel 段**(begin/end 配对错乱):halt + 让用户先手动清理
6. **`<source>` 推断失败**(skill 不在任何 skillshare source 里):跳过该 skill + `errors[]` 记录

## Red Flags — STOP

任一命中必须立刻停下不能合理化继续:

1. 用户没说 apply,你已经动了文件
2. 自动 hook(exp-sum / cron / cwd 切换)触发了本 skill
3. 改了 `~/.config/skillshare/config.yaml` 或 `~/.claude/skills/` 母目录任何文件
4. 输出了 stage 字段(`bootstrap/dev/debug/finish`)— **本版本无 stage 概念**
5. 输出了 disable / keep 字段 — **本版本只 enable 增量,不 disable**
6. sentinel 段写到了 begin/end 之外
7. refresh 多次跑结果不一致(说明非 idempotent,有 bug)
8. `prepare.sh` 跟 sentinel "项目级补充"段不一致 — sentinel 是事实源,prepare.sh 运行时**必须**重读 sentinel,不能内嵌固定 skill 清单
9. 写 `prepare.sh` 时没加 `# meta-skill prepare.sh v<N>` 头(无法区分用户脚本和 meta-skill 生成的)

## Rationalizations to Reject

| 说辞 | 现实 |
|---|---|
| "用户上次说过 apply,这次默认 apply" | 每次 apply 都得当下显式 |
| "改下 ~/.claude/skills/ 顺手清理一下" | 那是 skillshare sync target,会被覆盖 |
| "stage 推断 70% 准也够用了" | stage 已砍,本 skill 不再推 stage |
| "manifest.json 留着方便审计" | sentinel 段就是 manifest,不要平行造一个 |
| "skillshare CLI 慢,我估算一下就行" | 不行,fallback 到 ls,但**必须**真跑一次 |

## Sentinel Block Format Spec

CLAUDE.md / AGENTS.md 共享同一 sentinel 格式(便于解析、便于 diff):

```md
<!-- meta-skill:begin -->
## 本项目可用 skill(meta-skill 自动维护,勿在 begin/end 之间手改)

### 全局已可用
- `flow-dev-task` — 单 task 端到端从需求到 commit
- `exp-sum` — 任务完成后经验分诊
- ...

### 项目级补充(symlink 到 .claude/skills/ 等)
- `director-frontend` — React 组件实现 / 重构 / spec
- `cdp-browser-control` — 调试扩展时绕开 sandbox
- ...

<!-- meta-skill:meta -->
generated_at: 2026-06-03T00:00:00Z
stack: react, typescript
project_type: frontend, browser-extension
total: 12 = global 7 + project 5
<!-- meta-skill:end -->
```

**解析规则**:
- 整段必须用 HTML comment `<!-- meta-skill:begin -->` 和 `<!-- meta-skill:end -->` 包裹
- begin/end 之间的 markdown 是 LLM 看的人类内容
- `<!-- meta-skill:meta -->` 之后到 end 之间是机器元数据(parsing 用,人不必看)
- 同一文件**只能有一组** begin/end;多组 = 错乱,halt 让用户清理

## Relationship to Other Skills

### Upstream(触发本 skill 的)

- **只有用户手动触发**(显式说 `meta-skill` 或触发短语)
- **没有任何自动 hook**(不订阅 exp-sum / 不订阅 cwd 切换 / 不订阅 cron)

### Downstream(本 skill 调用的)

- **不调用其他 skill**(本 skill 是终端 orchestrator,执行完即止)
- 操作的工具:`skillshare`(只读 CLI)、bash(`ln`, `mkdir`, `cat`, `git`)、Edit/Write(改 CLAUDE.md / AGENTS.md / .gitignore)

### Cousin / 互补

- **skillshare** CLI:本 skill 的依赖,但只读用(`list --json`);**不**调用 `enable/disable`
- **find-skills**:用户问"有没有 X 的 skill" → 走 find-skills,不来这里
- **flow-skill-research**:用户调研多个 skill 选哪个 → 走 flow-skill-research

### 明确不调用

- ❌ `flow-skill-dev`(新建 / 改 skill)
- ❌ `sync-skills`(把改完的 skill 推中心)
- ❌ `exp-sum`(分诊新经验)

## Reuse

- `references/recommendations.md` — stack × project_type → skill list lookup table
- `references/project-detection.md` — 各种 manifest 文件的 signature → stack/type 映射细则
- `references/failure-modes.md` — 完整 Red Flags + Rationalizations 清单
- `references/prepare-sh-template.sh` — clone-portable 重建脚本模板(Step 6.4 写入项目根)
- `tests/cases.md` — 回归基线
