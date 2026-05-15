# Run Mode 三模式说明

orchestrator agent 调用本 skill 时所处的运行环境**决定能用哪种 Goal Codex 启动方式**。Phase 0.0 必须先探测，后续步骤按模式选路径。

## 三种模式对照

| 维度 | CLI-YOLO | CLI-EXEC | SUBAGENT |
|---|---|---|---|
| TTY 要求 | ✅ 有 | ❌ 无 | ❌ 无 |
| Goal Codex 启动 | `codex --dangerously-bypass-approvals-and-sandbox --cd $WORKTREE` 长跑 | `codex exec --cd $WORKTREE < goal-prompt-N.md` 单 Phase | orchestrator 派 subagent (e.g. `Agent(codex-rescue, ...)`) |
| watcher | nohup 后台进程 | 同 CLI-YOLO，但 mini-review 由 watcher 派单次 codex exec | 无 watcher，orchestrator 兼任 |
| inbox poll | watcher 做 | watcher 做 | orchestrator 自己做（每 1-2 个 Phase） |
| 适用场景 | 终端直接调用 / cron / IM bridge daemon | Claude Code Bash 工具 / 部分 IDE 沙箱 | Claude Code 主上下文 / Codex 调度 sub-codex |
| 隔离严格度 | 高（worktree + watcher + readonly review worktree 全部启用） | 高（同上） | 中（无 watcher，orchestrator 必须人工守约束）|

## 探测逻辑

`run-mode.sh detect` 输出三选一：
1. `tty -s` 成功 → **CLI-YOLO**
2. 无 TTY 但 `CC_PROJECT` 或 `ANTHROPIC_AGENT_RUNTIME` 存在 → **SUBAGENT**
3. 否则 → **CLI-EXEC**

`codex` 不存在或不在 worktree → 立即报错，整个 skill 退出。

## 关键纪律

无论哪种模式，以下纪律**全部不能省**：

1. Phase 0 契约门 + APPROVAL.md 签字
2. BASELINE.md 由独立 reviewer 跑（reviewer_pid ≠ orchestrator_pid）
3. 两 Codex 硬隔离（进程 + 会话 + 文件系统 + 网络/凭据）
4. snapshot + 最高分回退
5. review-audit/round-N.jsonl 完整记录
6. UI 任务的截图协议

模式只决定**怎么启动 Codex**和**watcher 是否独立**，不决定是否能省审计/隔离/快照。

## SUBAGENT 模式的特殊注意

orchestrator 兼任 watcher 时**最容易出错**的点：
- 派完 subagent 后必须 `git diff --stat` 自检，区分"真完成"vs"agent 转发后台但实际 idle"
- 必须主动跑 mini-review subagent（不能省，省了就没退化检测）
- 必须主动 git tag snapshot
- 必须主动写 review-audit
- IM 推送由 orchestrator 自己发（cc-connect send + view_image 校验）
- inbox poll 是用户主动 ping 时被动触发，不是周期 poll

但**仍然不破坏**两 Codex 硬隔离原则——subagent 也是新进程，启动方式仍走 `codex exec --cd <readonly-worktree>` + env 清空。

## 模式切换

Phase 0.0 探测得到的 `run_mode` 写入 `.agent/tasks/<id>/RUN_MODE` 后**全程不变**。
中途环境变化（比如从 IM 桥接 daemon 切换到本地终端）不允许重新探测——会造成 watcher 状态不一致。
如果必须切换，正确做法是：
1. 写 `STOPPED: run-mode-changed` 到 STATUS.md
2. 等当前 Phase / Review 收尾
3. 重新进 Phase 0
