# Committing Clean Changes Test Cases

## Case 1: 单一任务的干净提交

- 目标: 验证 skill 会选择本次任务相关文件，生成一次 commit message，并执行一次提交。
- 预期: 只产出一个 commit，不会擅自拆分。

## Case 2: 工作区混有无关改动

- 目标: 验证 skill 会排除无关文件，而不是直接 `git add .`。
- 预期: 只纳入当前任务相关文件，并明确列出排除项。

## Case 3: 临时文件与测试报告存在

- 目标: 验证 `.tmp/`、日志和一次性报告默认不会被纳入提交。
- 预期: 这些文件被排除，并在输出中说明。

## Case 4: 边界不清的混合改动

- 目标: 验证 skill 在无法安全收敛为一次提交时会停止。
- 预期: 不会擅自提交，也不会擅自拆成多个 commit。

## Case 5: 用户明确要求拆分提交

- 目标: 验证 skill 不会自己编排多次提交，而是指出超出默认职责边界。
- 预期: 明确说明默认只处理一次提交，需用户另行指定拆分策略。

## Case 6: 仅提交已暂存内容

- 目标: 验证 `staged-only` 模式下，skill 只基于已暂存内容生成 message 并提交。
- 预期: 不会额外挑选未暂存文件，并会说明当前模式。

## IM 会话自动推送回归（2026-04-22 新增）

### Case 7: 飞书会话下 commit 成功触发 push

- 前置: `CC_SESSION_KEY=feishu:chat_xxx:user_yyy`，当前分支有 upstream
- 目标: 验证 commit 成功后 skill 会自动执行一次普通 `git push`
- 预期: 输出 `push_status=pushed`，附带 `origin/<branch>` 目标；不使用 `--force`

### Case 8: 非 IM 会话（终端直连）不触发 push

- 前置: `CC_SESSION_KEY` 未设置
- 目标: 验证 skill 完成 commit 后**不**自动推送
- 预期: 输出 `push_status=skipped`，原因写明"not an IM session"

### Case 9: IM 会话但被 CCC_AUTOPUSH=0 显式禁用

- 前置: `CC_SESSION_KEY=telegram:xxx:yyy`，`CCC_AUTOPUSH=0`
- 目标: 验证用户显式禁用优先级高于会话检测
- 预期: 输出 `push_status=skipped`，原因写明"CCC_AUTOPUSH=0"

### Case 10: IM 会话下分支无 upstream

- 前置: `CC_SESSION_KEY=feishu:...`，新建的分支尚未设置 upstream
- 目标: 验证首次 push 自动 `-u origin HEAD`
- 预期: 成功 push，输出 `push_status=pushed`，目标 `origin/<new-branch>`；不报"no upstream"错误

### Case 11: IM 会话下 push 失败不触发回滚

- 前置: `CC_SESSION_KEY=feishu:...`，网络异常或远端拒绝（non-fast-forward）
- 目标: 验证 push 失败后 commit 不被 amend/reset/revert
- 预期: 输出 `push_status=committed`、`push_reason=<具体错误>`；本地 commit 保留，HEAD 不变

### Case 12: IM 会话下禁止 force push

- 前置: `CC_SESSION_KEY=feishu:...`，用户未显式要求 force push
- 目标: 验证自动推送只走普通 `git push`
- 预期: 命令里无 `--force` / `--force-with-lease`；如需 force 必须由用户在对话里明确提出

### Case 13: commit 失败时不触发 push

- 前置: `CC_SESSION_KEY=feishu:...`，Step 5 commit 因 pre-commit hook 失败
- 目标: 验证 push 不会在 commit 未成功时执行
- 预期: 输出 `push_status=n/a`，原因写明"commit not completed"

## 触发测试（2026-06-27 新增：放开被动/自动唤起）

### Case 14: 纯提交意图 → 应自动触发（正例）

- 输入: "把这些改动提交了" / "提交一下当前改动" / "帮我 commit" / "整理成一个干净的提交" / "commit these changes" / "make a clean commit"
- 目标: 验证去掉 callable-only 后，未显式点名、不在 flow 编排里也能被动唤起
- 预期: 命中 clean-commit（不再要求"用 clean-commit"显式点名）

### Case 15: 完整开发任务 → 不应抢触发（反例，护栏）

- 输入: "实现一个登录功能并提交" / "修一下这个 bug 然后提交" / "从 0 做到提交" / "ship this feature"
- 目标: 验证含"实现/修 bug 从头到尾"的完整开发请求路由到 flow-dev-task，而非被 clean-commit 截胡
- 预期: 不命中 clean-commit（应走 flow-dev-task；clean-commit 仅在其 commit 阶段被调用）

### Case 16: PR / 分支 / 合并 → 不应触发（反例，护栏）

- 输入: "开个 PR" / "把这个分支 merge 到 main" / "rebase 一下" / "删掉这个分支"
- 目标: 验证超出"单次干净提交"职责的 git 流程不触发本 skill
- 预期: 不命中 clean-commit（PR/merge/rebase/删分支/worktree 清理在 Do NOT 边界）

### Case 17: 被 flow 编排调用（兼容回归）

- 前置: flow-dev-task / flow-* 在 commit 阶段调用
- 目标: 验证放开自动触发后，仍可被编排显式调用，行为不变
- 预期: 正常进入提交流程，输出契约不变
