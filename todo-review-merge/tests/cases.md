# todo-review-merge Test Cases

## Case 1: 0 ready spec → idle

- 前置：`docs/spec/` 下所有 spec 的 status 都不是 `ready-for-review`（draft / approved / blocked）
- 输入：用户调用 todo-review-merge
- 预期：
  - Step 1 列出来 0 个候选
  - 不进 Step 3+，直接输出 idle 报告
  - `verdict: idle`
  - 提示用户"stage 2 还没跑完，请等待或检查 docs/spec/ 里 approved spec 是否被卡住"
  - **不**执行任何 git 操作

## Case 2: 1 个 ready spec + 全 pass → 完整 merge 流程

- 前置：
  - `docs/spec/theme-toggle.md` status=ready-for-review，验收标准全是可自动验证的
  - branch `todo/theme-toggle` 存在
  - `.worktrees/theme-toggle/` 存在
  - 主仓库工作树干净
  - main 是最新的
- 输入：用户调用 todo-review-merge
- 预期：
  - Step 2 直接选中（只有 1 个）
  - Step 4 hard gates 全 pass
  - Step 5 验收全 pass
  - Step 6 工程规范 pass（或源头不存在走通用检查）
  - Step 7 self-approval audit pass（或 spec.self_approved=false 跳过）
  - Step 8 verdict: PASS
  - Step 9 完整执行：
    - main checkout + pull
    - squash merge + commit（message 含 spec.title）
    - spec mv 到 `_done/`
    - TODO.md 中该行 `- [ ]` → `- [x]`
    - 第二个 commit (archive)
    - 删 worktree
    - 删 local + remote branch
    - push main
  - Step 11 检查 epic，本例非 epic 子项 → 跳过
  - 输出 `verdict: merged`，`merge_sha: <sha>`，`next_step` 提示下一个 TODO 可起步

## Case 3: 多个 ready spec → 用户选

- 前置：3 个 spec 都 ready-for-review
- 输入：用户调用 todo-review-merge（无具体 slug）
- 预期：
  - Step 2 用 AskUserQuestion 列出 3 个，附 `updated` 时间
  - 用户回选哪个 → 用那个
  - 用户不选 → stop

## Case 4: 用户指定 slug 但该 slug 不在 ready 列表

- 输入：用户说"review theme-toggle"
- 但 theme-toggle 实际 status=approved（还没 stage 2 完成）
- 预期：
  - 报错"slug theme-toggle 当前 status=approved，不在 ready-for-review 列表"
  - 不进入 review 流程
  - 列出实际 ready 的 slug 供用户重选

## Case 5: Hard gate (lint) fail → reject

- 前置：1 个 ready spec，branch 上有未修的 lint error
- 预期：
  - Step 4 跑 lint 看到 error
  - 不再继续跑 typecheck / test / build（可选优化：仍跑完所有 gates 给完整报告）
  - Step 8 verdict: REJECT, reason="lint fail"
  - Step 10 执行：
    - 不动 main
    - 切到 branch
    - spec 末尾追加 review feedback 区段
    - frontmatter status → approved（不是 draft）
    - commit + push spec 修改
    - 切回主仓库初始 branch
  - 输出 `verdict: rejected`，must_fix 列出 lint 报错

## Case 6: 验收标准有 subjective 项

- 前置：spec 验收里有 "用户感觉自然" 这类主观项
- 预期：
  - Step 5 把这条标 `subjective`
  - Step 8 report 高亮 subjective 项让用户判断
  - 如果用户回"通过" → 视为 pass 进 Step 9
  - 用户回"不通过" → reject 进 Step 10

## Case 7: self_approved=true 但实际改了 10 文件 / 500 行

- 前置：spec.self_approved=true，spec.self_approved_reasons 说"3 文件 80 行"，但实际 diff 显示 10 文件 500 行
- 预期：
  - Step 7 audit 发现违反硬条件 1（≤5 文件 / ≤200 行）
  - 检查其他 5 条
  - 如果总共违反 ≥ 2 条 → REJECT，reason="self-approval claim doesn't match"
  - 仅违反 1 条 → 仍 PASS 但 report 高亮 abused，提示用户事后调整 stage 1 prompt 阈值

## Case 8: 工程规范违反

- 前置：项目根有 AGENTS.md 写"不允许使用 console.log"，但 diff 含 console.log
- 预期：
  - Step 6 读 AGENTS.md → 检测到违反
  - Step 8 REJECT
  - must_fix 列出具体 file:line

## Case 9: epic 子项 merged 后父 epic 自动关闭

- 前置：
  - epic `style-switch`（kind=decomposition，spec 在 docs/spec/）
  - 子项 `style-tokens-namespace`、`style-toggle-ui`、`style-pack-minimal`
  - 前两个 spec 已在 `docs/spec/_done/`
  - 第三个 spec 当前 ready-for-review
- 输入：review-merge 第三个
- 预期：
  - Step 9 正常 merge 第三个
  - Step 11 检测到该 slug 是 `style-switch` epic 的子项
  - 检查 epic 所有子项全部在 `_done/`（包括刚 merged 的这个）
  - 关闭 epic：把 TODO.md 中 epic 行标 [x]，mv epic spec 到 `_done/`，commit + push
  - 输出 `epic_closed: ["style-switch"]`

## Case 10: 主仓库工作树脏 → refuse

- 前置：用户主仓库有未提交修改
- 输入：调用 todo-review-merge
- 预期：
  - Step 3 检查 `git status --porcelain` 非空
  - 报告 `verdict: refused`，原因 "main repo working tree dirty"
  - 不进 Step 4+
  - 提示用户先 stash / commit

## Case 11: Pass path 中途失败 — squash 后 push main 被拒

- 前置：main 是 protected branch，push 被拒
- 预期：
  - Step 9 前 7 步成功（包括 local commit）
  - 第 9 步 push main 失败
  - **不**尝试 force push
  - 报告：local 已有 2 个 commit（squash + archive），需要用户手动推送
  - branch / worktree 已删（顺序在 push 之前），告知用户清理状态
  - 输出 `verdict: merged` 但 `push_status: failed`，附手动 push 命令

## Case 12: Worktree 内有未提交修改 → 删除前拒绝

- 前置：`.worktrees/<slug>` 内有未提交修改（可能是 stage 2 fix-retry 中途）
- 预期：
  - Step 9 第 6 步删 worktree 前检查 `git -C .worktrees/<slug> status --porcelain`
  - 非空 → 不删，报告用户先处理
  - 主流程已经 merged 完成，仅 cleanup 不完整
  - 输出 `verdict: merged` 但 `cleanup_status: partial`，附待清理项

## Case 13: 反例 — 不在 todo-driver 流水线的分支

- 输入：用户说"review-merge feature/foo"
- 预期：
  - 校验 `feature/foo` 对应的 `docs/spec/foo.md` 是否存在
  - 不存在 → 报告"该 branch 不在 todo-driver 流水线，请用 requesting-code-review"
  - 拒绝触发

## Case 14: 反例 — docs/spec/ 目录不存在

- 前置：项目根没有 docs/spec/ 目录
- 输入：调用 todo-review-merge
- 预期：
  - Step 1 列不出任何 spec
  - 报告"docs/spec/ 不存在，本项目未启用 todo-driver"
  - 不触发实际流程

## Case 15: 反例 — 通用 PR review 应路由到别处

- 输入：用户说"帮我 review 一下这个 PR"，并贴 PR 链接
- 预期：
  - 本 skill **不**触发
  - 由外层 agent 路由到 `requesting-code-review` 或 GitHub PR review 流程
