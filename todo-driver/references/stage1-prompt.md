# Spec Drafter Prompt (multi-project, self-driving)

把整篇内容作为 prompt 喂给 agent。**完全无入参**：调用方不需要 cd、不需要传任何参数，本 prompt 自己从仓库状态推断该处理什么。可被 cron / 定时器无参重复调度。

---

你的任务：在一组工程里挑出"**下一个需要起草 spec 的 TODO**"，为其生成 spec 写到该工程的 `docs/spec/${slug}.md`、commit 到默认分支、push 到远端。**所有 spec 一律自审通过、直接 `status: approved`**，可被 stage2 立即接力——本流程不留人工审核环节。一次调用只产出 **1 个 spec**（处理完一个工程的一个 todo 就停）。

> ⚠️ **stage1 在主仓库主分支直接操作，不创建任何 worktree / 不创建任何 branch**。这是 docs-only 改动（只动 `docs/spec/${slug}.md`），不需要隔离环境。worktree / `todo/${slug}` branch 是 stage2 的事。

## 占位符约定

- `${slug}` — kebab-case 唯一标识，正则 `^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$`
- `${today}` — 今天日期，用 `date -u +%Y-%m-%d`（不要靠语境推断）
- `${project_root}` — 当前处理工程的绝对路径

## 工程清单（在 prompt 内硬编码）

> ⚠️ **使用前修改这份清单为你的实际工程绝对路径**。遍历顺序 = 数组顺序。

```
PROJECTS=(
  "/Users/ym/Documents/projects/A"
  "/Users/ym/Documents/projects/B"
  "/Users/ym/Documents/projects/C"
)
```

## 工程内 TODO 约定（与 todo-driver skill 对齐）

每个工程根目录有 `TODO.md`，每项格式：

```md
- [ ] `<slug>` <title> — <summary> (<hint 1>; <hint 2>; ...)
```

- `- [ ]` = 未完成（待起 spec / 开发中 / 待 merge 全都算）
- `- [x]` = 已 merge
- slug 用反引号包裹，正则 `` `([a-z0-9][a-z0-9-]{1,28}[a-z0-9])` ``
- 项目可以没有 `TODO.md` → 跳过该工程
- TODO 项解析不到 slug → 跳过该项继续找下一项

**hints 抽取（结构化、严格按正则）**：

```bash
# 抽出行末整对括号里的内容
hints_block=$(echo "$todo_line" | sed -nE 's/.*\(([^)]+)\)[[:space:]]*$/\1/p')
# 用英文分号分多条；中文逗号/英文逗号/中文分号都不切（允许单条 hints 内自然用逗号）
IFS=';' read -ra hints <<< "$hints_block"
# 每条 trim 两端空白
hints=("${hints[@]## }"); hints=("${hints[@]%% }")
```

- 抽不到括号 → 视为无 hints，正常起 spec
- 抽到但 split 后某条为空（如 `(a;;b)`）→ 跳过空条，不报错
- 每条 hints 都是用户的硬性约束，**必须在 Step 4 写进 spec**（详见 Step 4 开头的处理规则）

## 写入语言：中文（强制）

往 spec 文件里写的**叙述性内容一律用中文**——目标、现状、方案选项、推荐方案+理由、影响范围说明、验收标准描述、风险、Decisions log、反例文字、走查报告等等。

**保持英文/原文**（结构性，不翻）：

- frontmatter 字段名（`id` / `title` / `status` / ...）和枚举值（`approved` / `true` / `1440x900` ...）
- `${slug}` 本身（kebab-case 英文）
- 文件路径 / 行号引用 / API 名 / 库名 / 命令 / 代码片段

判定原则：**结构（字段名 / 枚举 / 标识符 / 代码引用）保持英文；人读的句子一律中文**。

例：

```md
## 目标

新增主题切换组件，支持深色 / 浅色 / 跟随系统三态，由 `src/stores/uiStore.ts` 统一管理状态。

## 现状

`src/components/popup/Header.tsx:42` 处当前固定使用 `punk-bg-dark` class，没有主题感知逻辑。
```

注意上面正文里 `src/...` `punk-bg-dark` 是英文（代码引用），其余叙述全中文。

## 执行算法（严格按顺序）

### Step 0：选择本次处理的工程和 slug（无入参，从仓库状态推断）

遍历上面硬编码的 `PROJECTS` 数组，对每个 `${project_root}` 按下面规则找候选：

```bash
cd "${project_root}"
test -f TODO.md || continue   # 没 TODO.md → 跳过工程
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || continue   # 不是 git 仓库 → 跳过

# 必须在默认分支上（避免把 spec commit 到用户的 feature branch）
default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
default_branch=${default_branch:-main}
current_branch=$(git rev-parse --abbrev-ref HEAD)
[ "$current_branch" = "$default_branch" ] || { echo "skip: ${project_root} on ${current_branch}, not ${default_branch}"; continue; }

# 主仓库工作树脏 → 跳过整个工程（用户可能正在开发；本 prompt 之后要 commit spec，
# 不能在脏工作树上 add，防止误把用户改动卷进 spec commit）
test -z "$(git status --porcelain)" || { echo "skip: ${project_root} dirty"; continue; }
```

在该工程的 `TODO.md` 中按文档**出现顺序**扫描 `- [ ]` 项，对每一项：

1. 解析 slug（反引号正则 `` `([a-z0-9][a-z0-9-]{1,28}[a-z0-9])` ``）。解析不到 → 跳过该项，看下一项。
2. 检查 `docs/spec/${slug}.md` 是否存在 + `docs/spec/_done/${slug}.md` 是否存在。
   - 任一存在 → 该 TODO 已经在流水线上（起过 spec / 已 merge），**跳过该项，看下一项**
   - 都不存在 → **选中**，记下 `${project_root}` `${slug}` `${title}` `${summary}`，跳出整个遍历

遍历完所有工程都没选中 → 报告 `🟰 nothing to draft` 并 exit 0。这是正常空跑，cron 会下次再来。

**轮转效果**：因为每次都是"挑第一个还没起 spec 的 TODO"，工程 A 的 todo#1 起完 spec 后下次扫到 A 时它有 spec 了会跳过，自然轮到 B 的 todo#1；等所有工程的 todo#1 都起完，再次扫到 A 时第一个未起 spec 的就是 todo#2，自然轮到第二轮。**无状态、无 round 概念、断点续跑天然安全**。

### Step 1：环境 sanity check（在选中的 `${project_root}`）

Step 0 已完成 git 仓库 / 默认分支 / 工作树干净 的全部筛选，并把 `${default_branch}` 留在变量里供后续使用。这里只补 `docs/spec/` 目录：

```bash
set -euo pipefail
cd "${project_root}"
test -d docs/spec || mkdir -p docs/spec
test -f "docs/spec/${slug}.md" && { echo "spec already exists, abort"; exit 0; }
```

### Step 2：理解项目

按顺序读（缺哪个跳哪个，**用 Read 的 offset/limit 控制每次读取量**，单文件总读取行数控制在 ~200 行内）：

1. `AGENTS.md`（首选工程规范源）
2. `CLAUDE.md`（次选）
3. `README.md` / `README.zh-CN.md`（产品上下文）
4. `package.json` / `Cargo.toml` / `pyproject.toml` / `go.mod`（技术栈）

不要读整个 src/。只针对 TODO 行的 `summary` / `hints`（行末括号里的内容）提到的具体模块做**最小**的 Grep + Read。**总文件读取数 ≤ 15**，超了就用已有信息出 spec，并在 spec "风险" 区段写"信息不足：仅读了 X 个文件"。

### Step 3：估算改动规模（评估性，不卡门槛）

按下列启发规则估算改动**文件数**和**总行数**，写进 spec 的"影响范围"区段。这是给 stage2 看的影响范围预判，**不再用来决定是否 approved**——所有 spec 都直接 approved。

| 信号 | 估算 |
|---|---|
| 新增功能 / 加按钮 / 加设置项 | 通常 ≤ 5 文件，≤ 200 行 |
| 重构 / 抽象 / 命名空间化 / 跨模块 | ≥ 10 文件 |
| 迁移 / 升级 / 重写 | 大改 |
| 全局样式（如 globals.css）的命名规则改动 | ≥ 8 文件 |

如估算出**高风险信号**（auth / payments / 加密 / 数据迁移 / 跨模块重构 / 新增依赖 / 公开 API 变更），在 spec 的"风险"区段**显著标注**，方便人类事后回看，但仍 approved。

### Step 3.5：判定 `needs_visual_check` / `needs_video_check`

#### `needs_visual_check`（截图走查）

任一为 true → `needs_visual_check: true`：

- "影响范围" 改动文件清单含 `*.tsx` / `*.jsx` / `*.vue` / `*.svelte`
- 含 `*.css` / `*.scss` / `*.less`（包含 `globals.css` 这种全局样式）
- 含 `src/components/**` / `src/pages/**` / `src/routes/**` / `popup.tsx` / `popup.html`
- 含 `index.html` / `*.astro`
- spec 验收标准里出现 UI 词汇（"显示" / "看到" / "样式" / "按钮" / "弹窗" / "颜色" / "主题" / "图标" / "排版" / "动画" / "rendered" / "displayed"）

全部为 false → `needs_visual_check: false`（纯逻辑 / 工具脚本 / 文档 / 配置变更）。

#### `needs_video_check`（录屏走查，借鉴 delivery-gate）

`needs_visual_check: false` → `needs_video_check` 自动 false（录屏必有截图，不会单独需要录屏）。

`needs_visual_check: true` 时再判 `needs_video_check`。任一为 true → `needs_video_check: true`：

- "目标" / "影响范围" 出现"**新页面**" / "**新增 modal**" / "**新增 drawer**" / "**新增独立模块**"
- 验收标准描述了**多步骤主交互**（如"用户点 X → 触发 Y → 看到 Z → 可以撤销"这类两步以上的交互链）
- 影响范围含 **CRUD 主链路**变化（create / read / update / delete 完整流的页面级行为变动）
- spec 验收标准出现"交互" / "流程" / "导航" / "撤销/重做" / "拖拽" / "动画过渡"

全部为 false → `needs_video_check: false`（小样式 / 单页改动 / 仅状态切换无流程感）。

#### 在 spec "验收标准" 末尾追加 checkbox

- `needs_visual_check: true` → 追加 `- [ ] Playwright 截图走查通过：关键页面整屏截图（含主页面 / 新弹窗打开态 / 二次确认态）无 console.error 且覆盖验收标准对应状态`
- `needs_video_check: true` → 再追加 `- [ ] Playwright 录屏走查通过：主交互链路录屏覆盖（从入口操作到结果可见的端到端流程）`
- 都为 false → 不追加

### Step 4：产出 spec

**先处理 hints（如果有）**：把 Step 0 抽出的 `hints[]` 数组里每一条按语义写进 spec 最合适的章节，保持原意不丢失。常见路由：实现倾向 → "推荐方案 + 理由"；范围限制（不动 X / 不引依赖 / 不改 API）→ "影响范围" + "风险"；必达指标（必须支持 X / 包体 < Y）→ "验收标准"（转成可测的 `- [ ]` checkbox）；走查特别要求 → "验收标准"里 Playwright 走查那条扩展；已知前提 / 已知坑 → "风险"。

**每条由 hints 转出的 spec 条目必须紧跟一行反例**，格式 `❌ 反例：<具体偷懒路径>`。反例要具体到能客观对照——提某个文件、某个 API、某种做法，**不能写"实现得不好"这种废话**。反例的作用是把 stage2 可能耍小聪明的路径提前堵死。

例（不照抄，按本次 hints 实际语义写）：

- hints "不引入新依赖" → 影响范围里写"本 spec 不引入新依赖"，下一行 `❌ 反例：把目标依赖源码内联进 src/utils/、或换一个等价的新依赖名义上不算"新"`
- hints "复用 useDarkMode" → 推荐方案里列为前置约束，下一行 `❌ 反例：复制 useDarkMode 源码到新文件后改两行；或包一层 wrapper hook 把原 hook 架空`
- hints "必须支持 RTL" → 验收标准里写 `- [ ] 在 dir="rtl" 下所有交互元素位置/对齐正确`，下一行 `❌ 反例：只加了 CSS direction: rtl 但 padding/margin 仍用 left/right 不用 inline-start/end`

某条 hints 实在想不出有意义的反例（如纯事实声明） → 跳过反例不强行编造，但在 Decisions log 注明"hint X 无有意义反例可举"。

---

frontmatter（**强制 `status: approved`，无人工审核环节**）：

```yaml
---
id: ${slug}
title: ${title}
status: approved
created: ${today}
updated: ${today}
project_root: ${project_root}     # 给 stage2 用
needs_visual_check: <Step 3.5 决定>   # 截图走查
needs_video_check: <Step 3.5 决定>    # 录屏走查（仅 visual=true 时可能 true）
---
```

正文按这 7 个固定标题写（**全写**，没有的写"无"）：

1. **目标** — 做完后用户能看到/用到的具体改变（一两句）
2. **现状** — 引用具体 `file:line`，说明当前代码状态
3. **方案选项** — 列 1–3 个备选，每个写优劣
4. **推荐方案 + 理由** — 选哪个，为什么。理由必须可被反驳/检验
5. **影响范围** —
   - 改动文件清单（带行数估算）
   - 总估算行数
   - 新增依赖（无 → 写"无"）
   - 影响公开 API / 类型（无 → 写"无"）
6. **验收标准** — `- [ ]` checkbox 列表，**每条必须可测**。强制末尾两条：`- [ ] 所有现有测试通过` / `- [ ] lint clean / build success`
7. **风险** — 潜在坑 + 回滚方案。**有高风险信号时必须在本节顶部用粗体标出**（例："**⚠️ 高风险：本改动涉及数据迁移**"）。

### Step 5：写 Decisions log

文末附 `## Decisions log` 区段，本次留一条：

```md
- **${today}**: 初版 spec，<一句关键决定>
```

如检出高风险信号，再追加一行：

```md
- **${today}**: 高风险信号：<具体哪几项>（已记入"风险"区段，但仍 approved）
```

### Step 6：commit + push spec（让 stage2 不再被脏工作树阻塞）

写完 spec 文件后，**只把这次新建的 spec 文件 commit 到默认分支并 push**——不能让 spec 留在工作树里，否则下次 stage2 看到工作树脏会跳过整个工程。

```bash
cd "${project_root}"
# 只 add 这次新建的 spec 文件；不要 git add . / git add -A
git add "docs/spec/${slug}.md"

# 确认 staged 列表只有这一个文件（防止 Step 0 之后又有别的脏改动溜进来）
staged_files=$(git diff --cached --name-only)
if [ "$staged_files" != "docs/spec/${slug}.md" ]; then
  echo "ERROR: unexpected staged files:"
  echo "$staged_files"
  echo "abort to avoid mixing user changes into spec commit"
  git reset HEAD -- "docs/spec/${slug}.md"
  exit 1
fi

git commit -m "docs(spec): draft ${slug}

Auto-generated by stage1 spec drafter. status=approved, ready for stage2."
spec_sha=$(git rev-parse HEAD)

# Push 到默认分支。失败（网络 / protected branch）→ 只警告，不报错
# 本地 commit 已落地，stage2 同机能看到；远端没同步可以下次手动 push
git push origin "${default_branch}" 2>&1 || echo "WARN: push failed, spec committed locally only (sha=${spec_sha})"
```

### Step 7：报告

输出简短摘要（≤ 9 行）：

```
✅ Spec drafted: ${slug}
- Project: ${project_root}
- File: ${project_root}/docs/spec/${slug}.md
- Spec commit: <sha>（pushed | local-only）
- Estimated change: <n> 文件 / <n> 行
- High-risk flags: <none | auth/payments/migration/...>
- Skipped projects: <list 或 "无">     # 没 TODO.md / 不在默认分支 / dirty / TODO 全做完了
- Next: 可直接进 stage2
```

空跑（所有工程都没新 TODO 可起）：

```
🟰 Nothing to draft
- Scanned: <list of projects with their TODO 状态>
- 下次 cron 触发再扫
```

## 约束（合并自原 "边界" + "失败处理"）

- **完全无入参**，所有决策从仓库状态推断。同一时刻反复跑只会让"还没起 spec 的下一条"被拿走，不会重复起草。
- 单次调用最多产出 **1 个 spec**。
- 只写 `${project_root}/docs/spec/${slug}.md`，不改任何代码、不创建分支/worktree。
- **必须**在 Step 6 把 spec commit 到默认分支并 push（push 失败容忍，但 commit 不能省）——否则 stage2 看到工作树脏会跳过整个工程，形成死锁。
- commit 只 `git add` 这次新建的 spec 文件，**禁止** `git add .` / `git add -A`。staged 列表 ≠ 单文件 → abort。
- 不覆盖已存在的 spec（Step 0 检测到 → 跳过该 TODO 继续找下一条）。
- 不跑测试 / lint / build。
- 写文件失败 → 用 temp file + `mv` 模式，确保不留半成品；失败时 exit code 非 0。
- 高风险评估只用于"风险"区段标注，**不**用来阻断 approved。
