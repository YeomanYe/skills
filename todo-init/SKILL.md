---
name: todo-init
description: >
  Use when adding a new TODO entry with a slug to a project's TODO.md so the
  todo-driver pipeline (TODO → spec → dev → merge) can pick it up. Generates a
  kebab-case slug, validates uniqueness inside TODO.md, supports optional
  depends_on for cross-TODO ordering.
  用于给项目 TODO.md 追加一条带 slug 的待办，让 todo-driver 流水线（TODO → spec →
  dev → merge）能识别和处理。自动生成 kebab-case slug，校验在 TODO.md 内的唯一性，
  支持可选 depends_on 表达跨 TODO 依赖。
  触发短语：「新建 TODO」「加一个待办」「记个新需求带 slug」「ext-helper 记个 TODO」
  「create a TODO」「add todo with slug」「new todo」「todo-init」。
  Do NOT use for: 修改已有 TODO（直接用 Edit）、不带 slug 的快速备忘（直接 Edit
  TODO.md）、不走 todo-driver 流水线的项目、把已有 TODO 转 spec（由 todo-driver
  Stage 1 prompt 处理，不归本 skill 管）。
---

# todo-init

## Overview

本 skill 只做一件事：向当前项目的 `TODO.md` 追加一条**带 slug 的**新 TODO，使其满足 todo-driver 流水线的格式要求。

它**不**做：
- 修改或重排已有的 TODO 条目
- 创建 spec、worktree、branch（那是 stage 1/2 的事）
- 跨项目操作（只看当前 `cwd` 下的 `TODO.md`）

核心原则：
- **slug 在 TODO.md 内唯一**
- slug 格式 `^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$`
- 追加位置：文件末尾的 `## Features` 或类似列表区段，找不到就在末尾新加一段

## When to Use

满足任一即可触发：
- 用户说"加个 TODO"/"记个新需求"/"new todo"/"todo-init"
- 用户描述了一个想做的功能/重构/bugfix，希望被 todo-driver 流水线接管
- 当前项目已经在用 todo-driver（存在 `docs/spec/` 目录或 TODO.md 中已经有带 slug 的条目）

## When NOT to Use

- 用户在改已有 TODO（用 Edit 直接改）
- 用户只想随手记一行不需要被流水线处理（用 Edit）
- 项目不走 todo-driver（没有 docs/spec/、TODO.md 里所有条目都没 slug）
- 用户在问"如何用 todo-driver"等元问题（解释，不真的写 TODO）

## Required Workflow

按以下顺序执行：

1. 探测环境（TODO.md 存在性、是否已用 todo-driver）
2. 一次性收集所需输入（summary + 可选 hints + 可选 depends_on）
3. 生成或校验 slug
4. 追加条目到 TODO.md 正确位置
5. 输出报告

不要在 Step 2 之后还重复追问已知信息。

## Step 1: Probe Environment

在 `cwd` 执行：

```bash
test -f TODO.md && echo "TODO_MD_EXISTS" || echo "TODO_MD_MISSING"
test -d docs/spec && echo "DRIVER_ACTIVE" || echo "DRIVER_INACTIVE"
```

判定：

- `TODO.md` 不存在 → **报告用户先 `touch TODO.md` 再来**，stop。不要替用户创建（避免给不该有 TODO 的目录加文件）
- `TODO.md` 存在但 `docs/spec/` 不存在 → 提示用户"todo-driver 流水线还没初始化，但 TODO 可以照样写"，继续
- 两者都在 → 标准流程

同时 grep 出 TODO.md 中所有已存在的 slug 入集合，备用：

```bash
grep -oE '`[a-z0-9][a-z0-9-]*[a-z0-9]`' TODO.md | tr -d '`' | sort -u
```

## Step 2: Collect Inputs (一次问完)

用 **AskUserQuestion** 一次性问完，最多 3 个 question，绝不分轮追问。

| 问题 | 必答? | 说明 |
|---|---|---|
| Summary | 是 | 一句话描述这个 TODO 要做什么。供后续生成 slug 和写入 title-summary |
| Hints / 约束 | 否 | 任何对实现方案的偏好或限制（如"用 zustand"、"不能引入新依赖"）。会原样附在 TODO 行末作为 hint，供 stage 1 起草 spec 时参考 |
| Depends on (slug 列表) | 否 | 若该 TODO 必须在某些 slug 完成后才能做，列出来。逗号分隔 |

如果用户在调用时已经把这些信息**完整**写在 prompt 里 → **不要**再问，直接进 Step 3。

模糊回复（"随便"/"都行"）→ 取空值默认，不追问。

## Step 3: Generate or Validate Slug

**生成规则**（用户没指定 slug 时）：

1. 从 summary 提取 3-5 个关键词（去虚词、动词转名词形式）
2. 中文 summary → 用关键词的英文/拼音翻译。优先英文。例：
   - "支持主题切换" → `theme-toggle`
   - "扩展使用日志" → `extension-usage-log`
   - "多浏览器同步" → `multi-browser-sync`
3. kebab-case 拼接，3-30 字符，仅 `a-z0-9-`
4. 校验唯一性：不在 Step 1 收集的现有 slug 集合中
5. 若冲突 → 加短后缀（`-v2`、`-ui`、`-api` 等语义后缀，避免数字递增）

**手动指定 slug 时**：

- 校验正则 `^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$`
- 不合法 → 拒绝，给用户一个建议的合法版本，让用户回 yes/no 接受或换一个
- 已存在 → 拒绝，告诉用户该 slug 在 TODO.md 哪一行已经用了
- 这两种拒绝是这个 skill 唯一允许的二次追问场景

## Step 4: Append to TODO.md

定位写入位置（按以下优先级找）：

1. 若 TODO.md 中有 `## Features` 区段 → append 到该区段末尾
2. 否则若有 `## TODO` 或 `## Backlog` 等列表区段 → 同上
3. 否则 → 在文件末尾新增一段 `## TODO` + 空行 + 该条目

条目格式（严格遵守）：

```md
- [ ] `<slug>` <title> — <summary>
```

其中：
- `<slug>`：Step 3 生成或校验过的 slug
- `<title>`：从 summary 提取的短标题（≤ 20 字符），首字母大写
- `<summary>`：原始 summary，可适度润色

**如果有 hints**：把 hints 用 `(<hints>)` 格式拼到行末，例：

```md
- [ ] `theme-toggle` 主题切换 — 支持深色/浅色/跟随系统三态 (优先 uiStore，参考 tab-shelf 方案)
```

**如果有 depends_on**：仅在报告中提示用户（不写入 TODO.md，因为 depends_on 是 spec 字段，不是 TODO 字段）。提示语句：

> 已设置 depends_on: [...]。stage 1 起草 spec 时会把这个写进 spec frontmatter。请在确认这些 slug 都存在后再让 stage 2 跑这个 TODO。

校验 depends_on 中每个 slug 是否存在于 TODO.md 或 `docs/spec/_done/`。不存在的列出来警告，但**不**阻止追加。

## Step 5: Verify and Report

写入后立即 grep 验证：

```bash
grep -n "^\- \[ \] \`<slug>\`" TODO.md
```

如果返回 1 行 → 成功，记录行号。
如果返回 0 行或 >1 行 → 写入异常，stop 并报告。

## Output Contract

报告必须包含：

- `slug`: 生成或校验过的 slug
- `title`: 提取的 title
- `line`: 在 TODO.md 中的行号
- `depends_on`: 数组（若用户提供）
- `depends_warn`: 未找到的依赖 slug 列表（若有）
- `next_step`: 字符串，下一步用户该做什么。固定模板：
  - 如果项目走 todo-driver：`等 stage 1 cron 起草 spec，到时审 docs/spec/<slug>.md`
  - 如果项目不走 todo-driver：`已记录到 TODO.md。你可以手动起草 spec 或继续用现有工作流`

如果 Step 1-4 任一中途 stop，必须明确说明停在哪一步 + 原因。

## Common Failure Modes

### 1. 替用户创建 TODO.md
问题：TODO.md 不存在时，agent 替用户 `touch TODO.md` 然后追加。
后果：可能在不该有 TODO 的目录（比如 home 目录、临时目录）留下空文件。
处理：报告"TODO.md 不存在"，stop。让用户决定是否创建。

### 2. slug 冲突时数字递增
问题：`theme-toggle` 已存在 → 自动用 `theme-toggle-2`。
后果：未来读 TODO 列表的人不知道 `-2` 是什么意思。
处理：用语义后缀（`-v2` 不算语义；`-dark` / `-ui` / `-api` 才算）。冲突时**问用户**而非自动生成。

### 3. 把 hints 当依赖写
问题：用户说"参考 tab-shelf 方案"，agent 把 `tab-shelf` 写进 depends_on。
处理：hints 和 depends_on 是不同字段。hints 是自由文本写到行末括号里；depends_on 必须是合法 slug 引用。

### 4. 修改已有 TODO 条目
问题：用户说"加个 TODO"，但内容跟已有某条很像，agent 改了那条。
处理：本 skill **只追加**，不改已有条目。即使内容重复，也作为新条目追加（让用户事后自己合并）。

### 5. 在非项目根调用
问题：用户在子目录调用，cwd 不是项目根，`TODO.md` 找不到但项目根有。
处理：只看 cwd 一级，不向上找。报告"当前目录没有 TODO.md"。让用户自己 cd 到项目根。

## Minimal Operating Principle

这个 skill 的目标是"**让 todo-driver 流水线能拾起这条 TODO**"。
不是"把所有信息都收齐"，不是"替用户决定如何实现"，也不是"把 TODO 升级成 spec"。
任何越界都属于 failure mode。
