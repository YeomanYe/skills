# todo-driver Test Cases

按 mode 分两组。每组覆盖：正例触发 / 反例触发 / 主成功 / 护栏。

---

## Mode `init`

### Case 1: 标准追加（TODO.md 存在 + 走 todo-driver）

- 前置：`TODO.md` 存在，`docs/spec/` 存在，已有 1-2 个带 slug 的条目
- 输入：用户说"加个 TODO 支持快捷键设置"
- 预期：
  - mode 解析为 `init`（含"加 TODO"短语）
  - 不再追问（除非 hints / depends_on 有不确定）
  - 生成 slug `keyboard-shortcuts` 或 `shortcut-settings`
  - 追加到 `## Features` 末尾
  - 输出含 mode + slug + 行号 + `next_step`

### Case 2: TODO.md 不存在 → 护栏

- 前置：cwd 下没有 TODO.md
- 输入：用户说"加个 TODO 主题切换"
- 预期：
  - 不替用户创建 TODO.md
  - 报告"TODO.md 不存在，请先 touch"，stop
  - **不**输出 slug / 行号

### Case 3: slug 冲突 → 护栏

- 前置：TODO.md 已有 `- [ ] \`theme-toggle\` ...`
- 输入：用户说"加个 TODO 支持主题切换"
- 预期：
  - 检测到 slug `theme-toggle` 已存在
  - **不**自动改成 `theme-toggle-2`
  - 提示语义后缀（`theme-toggle-system` / `theme-color-picker`），让用户确认
  - 用户确认后才追加

### Case 4: 用户手指定不合法 slug

- 输入：用户说"slug 用 ThemeToggle，summary 是 主题切换"
- 预期：
  - 校验 `ThemeToggle` 失败（含大写）
  - 提示合法版本 `theme-toggle`
  - 让用户 yes/no
  - yes → 用 `theme-toggle` 追加；其他 → stop

### Case 5: 带 depends_on（被依赖 slug 存在）

- 前置：TODO.md 有 `- [ ] \`theme-toggle\` ...` 为 `- [ ]` 状态
- 输入：用户说"加 style-switch，依赖 theme-toggle"
- 预期：
  - 追加 `- [ ] \`style-switch\` ...`
  - 输出含 `depends_on: ["theme-toggle"]`
  - **不**把 depends_on 写进 TODO.md（写 spec frontmatter 是 stage 1 的事）
  - `depends_warn` 为空

### Case 6: 带 depends_on（被依赖 slug 不存在）

- 输入：用户说"加 user-settings，依赖 onboarding-flow"，`onboarding-flow` 既不在 TODO.md 也不在 `docs/spec/_done/`
- 预期：
  - 仍然追加（不阻止）
  - `depends_warn: ["onboarding-flow"]`
  - 输出提示"被依赖项不存在，stage 2 拾起前请先确认"

### Case 7: 带 hints

- 输入：用户说"加 dark-mode，提示用 uiStore 管理，参考 tab-shelf"
- 预期：
  - 追加为 `- [ ] \`dark-mode\` Dark mode — ... (用 uiStore 管理，参考 tab-shelf)`
  - hints 写在行末括号
  - **不**把 hints 当 depends_on

### Case 8: 模糊回复

- 输入：用户说"加个 TODO 多语言"，AskUserQuestion 问 hints，用户回"随便"
- 预期：
  - 取空值默认（无 hints）
  - 不再追问
  - 正常追加

### Case 9: 中文 summary 生成英文 slug

- 输入：用户说"加个 TODO 收藏夹一键导出 HTML"
- 预期：
  - 生成 `bookmark-export-html`
  - **不**用拼音兜底，除非中文无对应英文

### Case 10: 非项目根调用 → 护栏

- 前置：cwd 是子目录，TODO.md 在项目根
- 输入：用户说"加个 TODO"
- 预期：
  - 不向上查找
  - 报告"当前目录没有 TODO.md"，stop
  - **不**自动 cd

### Case 11: 已知信息不重复追问

- 输入：用户一次性说"加 TODO：slug=theme-toggle，summary=支持深色/浅色/跟随系统三态，hints=用 uiStore"
- 预期：
  - 0 次 AskUserQuestion 调用
  - 直接 Step 3 校验 slug + Step 4 写入

### Case 12: 反例触发 — 改已有 TODO

- 输入：用户说"把 theme-toggle 的描述改一下，加上'跟随系统'"
- 预期：
  - mode 解析为 `init` 但 Step 1 探测到 slug 冲突 → 进入 Case 3 分支
  - 或外层 agent 直接用 Edit，**不**触发本 skill

### Case 13: 反例触发 — 不走 todo-driver 项目

- 前置：项目没有 docs/spec/，TODO.md 里所有条目都没 slug
- 输入：用户说"加个 TODO 修复 #42"
- 预期：
  - mode 解析为 `init`，Step 1 识别 "DRIVER_INACTIVE"
  - 提示"该项目未启用 todo-driver，仍可追加但不会被流水线自动处理"
  - 用户确认后追加

---

## Mode `adjust`

### Case A1: adjust 前强制列出编号清单

- 前置：`TODO.md` 有 5 条 `- [ ]` TODO，目标 slug 尚无 `docs/spec/<slug>.md`
- 输入：用户说"todo-driver adjust，把 theme-toggle 移到第 2 个"
- 预期：
  - mode 解析为 `adjust`
  - 在解析动作前输出 `当前 TODO 顺序:` 编号清单
  - 清单从 1 开始编号，包含 slug、title、summary
  - 把 `theme-toggle` 移到编号 2 对应的位置
  - Output Contract 含 `todo_order_before` 和 `todo_order_after`

### Case A2: 用户用编号交换两项

- 前置：`TODO.md` 当前清单中第 3 项是 `keyboard-shortcuts`，第 6 项是 `theme-toggle`
- 输入：用户说"3,6 交换"
- 预期：
  - 先输出当前编号清单
  - 解析 3 → `keyboard-shortcuts`，6 → `theme-toggle`
  - 交换两行位置
  - `actions_taken` 含 `swapped keyboard-shortcuts and theme-toggle`
  - `todo_order_after` 展示交换后的编号清单

### Case A3: 编号越界 → 护栏

- 前置：`TODO.md` 当前段只有 4 条未完成 TODO
- 输入：用户说"8 移到 2"
- 预期：
  - 先输出当前编号清单
  - 检测编号 8 越界
  - stop，不修改 `TODO.md`
  - 报告"编号 8 不存在"

### Case A4: 已起 spec 的 TODO 拒绝移动

- 前置：`docs/spec/theme-toggle.md` 已存在，`TODO.md` 中有 `theme-toggle`
- 输入：用户说"把 theme-toggle 移到第 1 个"
- 预期：
  - 输出当前编号清单
  - 检测 `spec_state=pending-spec`
  - 拒绝改位置
  - 提示如需影响实现，应直接编辑 `docs/spec/theme-toggle.md`

### Case A5: 每次成功 adjust 后必须 commit + push

- 前置：`TODO.md` 干净，`theme-toggle` 尚无 spec，remote 可 push
- 输入：用户说"把 theme-toggle 移到第 2 个"
- 预期：
  - 改动只涉及 `TODO.md`
  - 执行 `git add TODO.md`
  - 创建 commit，message 形如 `chore(todo): adjust theme-toggle`
  - 尝试 `git push origin <default_branch>`
  - 输出含 `adjust_commit` 和 `push_status: pushed`

### Case A6: push 失败时不能静默成功

- 前置：`TODO.md` 调整成功，commit 成功，但 remote push 被拒
- 输入：用户说"3,6 交换"
- 预期：
  - 输出含 `adjust_commit`
  - 输出 `push_status: local-only`
  - 明确说明 push 失败原因
  - 不回滚本地 commit，不 force push

---

## Mode `review-merge`

### Case 14: 0 ready spec → idle

- 前置：所有 spec 的 status 都不是 `ready-for-review`
- 输入：用户调用"review 这个 todo"
- 预期：
  - mode 解析为 `review-merge`（"review" + "todo"）
  - Step 1 列出 0 个候选
  - 不进 Step 3+
  - `verdict: idle`
  - 不执行任何 git 操作

### Case 15: 1 个 ready spec + 全 pass → 完整 merge

- 前置：
  - `docs/spec/theme-toggle.md` status=ready-for-review
  - branch `todo/theme-toggle` 存在
  - `.worktrees/theme-toggle/` 存在
  - 主仓库工作树干净
  - main 最新
- 预期：
  - Step 2 直接选中
  - Step 4-7 全 pass
  - Step 8 verdict: PASS
  - Step 9 完整执行：squash + archive + mv spec + 标 TODO + 删 worktree + 删 branch + push main
  - Step 11 非 epic 子项 → 跳过
  - 输出 `verdict: merged` + `merge_sha`

### Case 16: 多个 ready spec → 用户选

- 前置：3 个 spec ready-for-review
- 输入：用户调用 review-merge（无具体 slug）
- 预期：
  - Step 2 用 AskUserQuestion 列出 3 个，附 `updated` 时间
  - 用户选 → 用那个
  - 用户不选 → stop

### Case 17: 用户指定 slug 但不在 ready 列表

- 输入：用户说"review theme-toggle"，但 theme-toggle 实际 status=approved
- 预期：
  - 报错 "slug theme-toggle 当前 status=approved，不在 ready-for-review 列表"
  - 列出实际 ready 的 slug 供重选

### Case 18: Hard gate (lint) fail → reject

- 前置：1 个 ready spec，branch 上有未修的 lint error
- 预期：
  - Step 4 跑 lint 看到 error
  - Step 8 REJECT，reason="lint fail"
  - Step 10：不动 main / 切到 branch / spec 末尾追加 review feedback / status → approved（不是 draft）/ commit + push
  - 输出 `verdict: rejected`，must_fix 列出报错

### Case 19: 验收标准有 subjective 项 → 护栏

- 前置：spec 验收里有 "用户感觉自然"
- 预期：
  - Step 5 标 `subjective`
  - Step 8 report 高亮，让用户判断
  - 用户回"通过" → PASS 进 Step 9
  - 用户回"不通过" → REJECT 进 Step 10

### Case 20: self_approved=true 但实际改了 10 文件 → 护栏

- 前置：spec.self_approved=true，self_approved_reasons 说"3 文件 80 行"，实际 diff 10 文件 500 行
- 预期：
  - Step 7 audit 发现违反条款 1（≤5 文件 / ≤200 行）
  - 检查其他 5 条
  - 违反 ≥ 2 条 → REJECT，reason="self-approval claim doesn't match"
  - 违反 1 条 → PASS 但 report 高亮 abused

### Case 21: 工程规范违反 → reject

- 前置：项目根 AGENTS.md 写"不允许 console.log"，但 diff 含 console.log
- 预期：
  - Step 6 检测违反
  - Step 8 REJECT
  - must_fix 列出 file:line

### Case 22: epic 子项 merged 后父 epic 自动关闭

- 前置：
  - epic `style-switch` spec 在 docs/spec/
  - 子项 `style-tokens-namespace`、`style-toggle-ui`、`style-pack-minimal`
  - 前两个 spec 已在 `_done/`
  - 第三个 ready-for-review
- 预期：
  - Step 9 正常 merge 第三个
  - Step 11 检测父 epic `style-switch`
  - 检查所有子 slug 全在 `_done/`（包括刚 merged）
  - 关闭 epic：标 [x] / mv epic spec / commit + push
  - 输出 `epic_closed: ["style-switch"]`

### Case 23: 主仓库工作树脏 → refuse

- 前置：主仓库有未提交修改
- 预期：
  - Step 3 检查 `git status --porcelain` 非空
  - `verdict: refused`，原因 "main repo working tree dirty"
  - 不进 Step 4+

### Case 24: Pass path 中途失败 — push main 被拒（protected branch）

- 前置：main 是 protected branch
- 预期：
  - Step 9 前 8 步成功（本地 commit + 删 branch + 删 worktree 等）
  - 第 9 步 push main 失败
  - **不**尝试 force push
  - 报告：本地已 2 个 commit，需用户手动推送
  - 输出 `verdict: merged` + `push_status: failed`

### Case 25: Worktree 内有未提交修改 → 拒绝删 worktree

- 前置：`.worktrees/<slug>` 内有未提交修改
- 预期：
  - Step 9 第 6 步删 worktree 前检查
  - 非空 → 不删，报告用户处理
  - 主流程仍 merged 完成
  - 输出 `verdict: merged` + `cleanup_status: partial`

### Case 26: 反例触发 — 通用 PR review

- 输入：用户说"帮我 review 一下这个 PR"，并贴 PR 链接
- 预期：
  - mode 解析可能落到 `review-merge`，但 Step 1 找不到对应 ready spec
  - 报告"该 branch 不在 todo-driver 流水线，请用 requesting-code-review"
  - 拒绝触发

### Case 27: 反例触发 — docs/spec/ 不存在

- 前置：项目根没有 docs/spec/
- 输入：调用 review-merge
- 预期：
  - Step 1 列不出任何 spec
  - 报告"docs/spec/ 不存在，本项目未启用 todo-driver"
  - 不触发实际流程

---

## Mode Resolution Tests（合并后新增）

### Case 28: 显式指定 mode

- 输入：用户说"todo-driver init，加个 TODO 主题切换"
- 预期：
  - mode 解析直接走 `init`，不做触发短语推断
  - 进入 init Step 1+

### Case 29: 触发短语明确指向 init

- 输入：用户说"加个 TODO 多语言支持"
- 预期：
  - 短语含"加" + "TODO" → init
  - **不**触发 review-merge 路径

### Case 30: 触发短语明确指向 review-merge

- 输入：用户说"merge ready 的 todo"
- 预期：
  - 短语含"merge" + "ready" + "todo" → review-merge
  - **不**触发 init

### Case 31: 短语模糊 + 状态明显 → 用状态兜底

- 输入：用户说"跑一下 todo-driver"
- 前置：项目有 1 个 ready-for-review spec
- 预期：
  - 短语无明确指向
  - 状态推断：有 ready spec → review-merge
  - 进入 review-merge 流程并声明"current mode: review-merge"

### Case 32: 短语模糊 + 状态也模糊 → AskUserQuestion

- 输入：用户说"todo-driver"
- 前置：既没 ready spec，TODO.md 也没新增意图
- 预期：
  - AskUserQuestion 让用户二选一：init / review-merge
  - 用户选 → 进对应流程
  - 用户拒选 → stop
