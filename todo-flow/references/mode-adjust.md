# Mode `adjust` — TODO panel 调整未起 spec 的条目

进入 **TODO panel 模式**,用编号表格连续调整 TODO:改位置(影响 stage1 下次挑哪条)、修改条目内容、追加 hints。面板不会在每次小改后立刻 commit;只有用户明确说"退出模式" / "退出" / "exit" / "done" 时,才统一校验、commit,并尝试 push。

> 设计原则:**一旦 stage1 给该 slug 起过 spec(`docs/spec/${slug}.md` 存在),spec 就成了事实源,本 mode 不再改 TODO 行的位置或实质内容**。要影响实现,直接 Edit `docs/spec/${slug}.md`。已 merge 的 `_done/${slug}.md` 一律不可改。

> 硬规则:`adjust` panel 退出时,只要 `TODO.md` 有实际改动,就必须创建一次 git commit,并且必须尝试 `git push origin ${default_branch}`。未 commit 的本地修改不能报告为完成;push 失败时只允许报告 `local-only`,不得静默吞掉。

## Required Workflow

按以下顺序:

1. 探测环境
2. 进入 panel,输出完整 TODO 表格
3. 循环接收用户指令:移动 / 交换 / 修改 TODO / 添加 hint / 退出
4. 每次成功修改后立即输出完整表格
5. 单个 TODO 内容被改时,额外原封不动输出该 TODO 行
6. 用户退出后校验单文件改动 + commit + push
7. 输出报告

### Step 1: Probe Environment

```bash
# 必须 git 仓库根 + 默认分支 + 工作树干净(panel 期间会产生 TODO.md 脏改动)
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || { echo "ERROR: not a git repo"; exit 1; }
test "$(git rev-parse --show-toplevel)" = "$(pwd -P)" || { echo "ERROR: must run at repo root"; exit 1; }

default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
default_branch=${default_branch:-main}
[ "$(git rev-parse --abbrev-ref HEAD)" = "$default_branch" ] || { echo "ERROR: must run on ${default_branch}"; exit 1; }
test -z "$(git status --porcelain)" || { echo "ERROR: working tree dirty before panel"; exit 1; }

test -f TODO.md || { echo "ERROR: no TODO.md, run 'todo-flow init' first"; exit 1; }
```

任一硬错 → stop,不进入 panel,不改文件。`.zread/`、临时文件、其它未跟踪文件都算脏工作树,避免退出时把用户改动卷入 commit。

### Step 2: Render Panel Table(强制)

进入 panel 后,必须把 `TODO.md` 中所有未完成 TODO 以 Markdown 表格输出;每一行前面必须有从 1 开始的编号。每次成功修改后都重新输出完整表格,方便用户继续用编号调整。

表格字段固定:

```md
| # | slug | title | summary | hints | spec_state |
|---:|---|---|---|---|---|
| 1 | `theme-toggle` | 主题切换 | 支持深色 / 浅色 / 跟随系统三态 | 用 uiStore 管理 | none |
```

解析规则:
- 默认列出所有 `- [ ]` TODO 行;如果未来支持多段且用户指定段名,再只列该段。
- `spec_state`:
  - `none`:`docs/spec/${slug}.md` 和 `docs/spec/_done/${slug}.md` 都不存在
  - `pending-spec`:`docs/spec/${slug}.md` 存在
  - `done`:`docs/spec/_done/${slug}.md` 存在
- `hints` 取 TODO 行末最后一对括号内容;没有则填 `-`。
- 表格外不要省略长行。必要时保留完整内容,不能用 `...` 截断。

### Step 3: Panel Commands

panel 持续到用户说"退出模式" / "退出" / "exit" / "done"。用户每次输入只解析为以下命令之一;不清楚时重新输出表格并用一句话提示支持的命令,不要猜。

| 命令 | 例子 | 行为 |
|---|---|---|
| 移动 | `9 放到 3 后面` / `move 9 after 3` / `8 移到 2` | 用当前表格编号解析目标和锚点,移动整行 |
| 交换 | `3,6 交换` / `swap 3 6` | 交换两条 TODO 行 |
| 修改 TODO | `改 4 title 为 大模型分组` / `改 4 summary 为 ...` / `改 4 为 <完整 TODO 行>` | 修改单行 title / summary / hints,或用一整条合法 TODO 行替换该行 |
| 添加 hint | `给 4 加 hint 设置里支持本地模型和远程模型` | 把一条 hint 追加到目标行末括号内 |
| 退出 | `退出模式` / `退出` / `exit` / `done` | 结束 panel,进入提交与 push |

编号必须来自当前表格。每次修改后编号可能变化;下一条用户指令必须基于最新表格重新解析。

判定矩阵:

| 状态 | 允许的动作 |
|---|---|
| `none`(spec 还没起) | **移动 / 交换 / 修改 TODO / 添加 hint 都允许** |
| `pending-spec`(已起 spec,未 merge) | **拒绝移动、交换、修改 TODO、添加 hint**;提示直接编辑 `docs/spec/${slug}.md` |
| `docs/spec/_done/${slug}.md` 存在(已 merge) | **全部拒绝**——该项应该已经是 `- [x]`,TODO 行不该被动 |

### Step 4: Apply One Panel Command

**追加 hints**(如有):

```bash
# 把 hints 数组追加到目标行末
# 1. 抽出现有 hints
existing_hints=$(echo "$target_line" | sed -nE 's/.*\(([^)]+)\)[[:space:]]*$/\1/p')

# 2. 拼接新旧 hints(用英文分号;分隔,与 Shared Constraints 对齐)
if [ -n "$existing_hints" ]; then
  new_hints_block="$existing_hints; $(IFS='; '; echo "${new_hints[*]}")"
else
  new_hints_block=$(IFS='; '; echo "${new_hints[*]}")
fi

# 3. 用 sed 替换该行末尾——优先保留行内已有的部分,仅在末尾改/加括号
```

**校验**:
- 单条 hints 内**禁止**含 `;`(会破坏分隔);含则报错让用户改写。
- 修改 TODO 时必须保持合法格式:`- [ ] \`<slug>\` <title> — <summary> (...)`。默认不允许改 slug;用户明确要求改 slug 时,拒绝并说明应删旧项 + add 新项。
- 单个 TODO 内容改动后,必须额外输出该行完整 Markdown 原文,格式为:

```md
updated_line:
- [ ] `slug` 标题 — 摘要 (hint)
```

**移动行**(如有):

| 动作 | 行为 |
|---|---|
| `--before <S>` | 把目标行剪切,插到 `\`<S>\`` 所在行**之前** |
| `--after <S>` | 同上,插到**之后** |
| `--top` | 移到目标行所在段(`## Features` / `## TODO` / `## Backlog`)的**段首**(标题下第一条) |
| `--bottom` | 移到所在段**段末** |
| 编号交换(如 `3,6 交换`) | 用 Step 1.5 编号清单解析两个编号对应的 slug,交换两行位置 |
| 编号移动(如 `8 移到 2`) | 用 Step 1.5 编号清单解析目标编号和目标位置,把目标行移动到该序号所在位置 |

锚点 slug(`<S>`)必须也存在且未完成;否则报错。

**不跨段移动**:目标 TODO 在哪个 `##` 段下就只能在该段内移动。需要跨段先用 Edit 改段名。

每次成功应用命令后必须:
1. 重新解析 `TODO.md`
2. 校验所有被调整 slug 仍唯一存在
3. 输出完整 panel 表格
4. 若是单行内容改动,再输出 `updated_line`

### Step 5: Exit Panel + Commit + Push

这是 `adjust` 的硬门,不是可选收尾。用户退出 panel 后,只要 `TODO.md` 相比进入 panel 时有实际改动,就必须执行本步。若没有实际改动,输出 `adjust_commit: no-op`,不 commit、不 push。

```bash
# staged 必须只有 TODO.md
git add TODO.md
staged=$(git diff --cached --name-only)
[ "$staged" = "TODO.md" ] || { echo "ERROR: unexpected staged files: $staged"; git reset HEAD; exit 1; }

# 校验每个被调整的目标 slug 仍唯一存在
for adjusted_slug in "${adjusted_slugs[@]}"; do
  hits=$(grep -cE "^- \[ \] \`${adjusted_slug}\` " TODO.md)
  [ "$hits" = "1" ] || { echo "ERROR: target line not unique after adjust: ${adjusted_slug} (${hits} hits)"; exit 1; }
done

git commit -m "chore(todo): adjust TODO panel

$(adjust_summary)"   # body 内容见下方
adjust_sha=$(git rev-parse HEAD)
if git push origin "${default_branch}"; then
  push_status="pushed"
else
  push_status="local-only"
  echo "WARN: push failed, adjust committed locally only (sha=${adjust_sha})"
fi
```

`adjust_summary` 由本次实际做了哪些动作生成,例:

```
Move `ai-group-suggestions` after `theme-toggle`
Edit `theme-toggle` summary
Append hint to `keyboard-shortcuts`: 使用 chrome.commands API
```

## Output Contract

进入 panel 时必须输出:

- `mode: adjust`
- `panel: open`
- 完整 TODO 表格
- `commands`: 一行提示支持 `移动 / 交换 / 修改 TODO / 添加 hint / 退出模式`

每次成功修改后必须输出:

- `mode: adjust`
- `panel: open`
- `actions_taken`: 本轮动作数组,如 `["moved ai-group-suggestions after theme-toggle"]`
- `updated_line`: 仅当单个 TODO 内容被改时输出,且必须是该行完整 Markdown 原文
- 完整 TODO 表格
- `next_step`: `继续输入调整指令,或说"退出模式"提交并 push`

退出 panel 后必须输出:

- `mode: adjust`
- `panel: closed`
- `actions_taken`: panel 内累计动作数组
- `changed_slugs`: panel 内动过的 slug 数组
- `final_table`: 完整 TODO 表格
- `adjust_commit`: SHA
- `push_status`: `pushed` / `local-only`
- `next_step`:
  - 顺序变了:`下次 stage1 cron 会按新顺序挑选`
  - 加了 hints 且 spec 不存在:`stage1 起 spec 时会读到新 hints 并写进 spec`
  - 没有实际改动:`panel closed with no changes`

## Common Failure Modes

**1. 改已经起过 spec 的 TODO 位置**:位置变了但 stage1 不会重选该项(spec 已存在),徒劳。处理:Step 1 判定矩阵直接拒绝改位置。

**2. 改已 merge 项**:`- [x]` 应该是不可变历史。处理:Step 1 检测到 `_done/${slug}.md` 直接拒绝所有动作。

**3. hints 含 `;` 把分隔符破坏**:用户写 `--add-hint "支持 A; 支持 B"` 期望一次加两条,结果被当成一条。处理:Step 3 校验单条 hints 内不含 `;`,让用户改成两次 `--add-hint`。

**4. 移动行时锚点 slug 不存在**:`--before nonexistent` 静默无操作。处理:Step 3 校验锚点 slug 存在且未完成,否则报错。

**5. 跨段移动破坏组织**:用户期望从 `## Backlog` 移到 `## Features` 顶。处理:本 mode 不跨段;用户先 Edit 改段名再 adjust。

**6. 编号动作未先列表格**:用户说"3、8 交换",agent 直接按自己脑中顺序改。处理:panel 打开和每次改后都必须输出当前 TODO 表格,再把编号解析成 slug;编号越界必须 stop 并重印表格。

**7. 每次小改后就 commit**:panel 还没退出就创建多次 commit。处理:面板期间只改 `TODO.md` 和展示表格;只有用户说退出模式后才 commit + push。

**8. 单行内容改了但没输出原文**:用户无法审查最终 TODO 行。处理:凡是 title / summary / hints / 整行替换这类单行内容改动,都必须输出 `updated_line`,内容必须与 `TODO.md` 中该行完全一致。

**9. 退出后未提交或未推送**:agent 改了 `TODO.md` 就直接回复"已调整"。处理:Step 5 是硬门;必须 commit,并且必须尝试 push。commit 失败 → 不允许成功;push 失败 → 报告 `push_status: local-only` 和失败原因。
