# Run Mode 三模式说明

orchestrator agent 调用本 skill 时所处的运行环境**决定能用哪种 Goal Codex 启动方式**。Phase 0.0 必须先探测，后续步骤按模式选路径。

## 模式对照

| 维度 | CLI-YOLO | TMUX-YOLO | CLI-EXEC | SUBAGENT |
|---|---|---|---|---|
| TTY 要求 | ✅ 有 | ❌ 无（用 tmux 的伪 pty 替代） | ❌ 无 | ❌ 无 |
| Goal Codex 启动 | `codex --dangerously-bypass-approvals-and-sandbox --cd $WORKTREE` 长跑 | `tmux new-session -d -s codex-job-$ID "codex --dangerously-bypass-approvals-and-sandbox --cd $WORKTREE"` 长跑 | `codex exec --cd $WORKTREE < goal-prompt-N.md` 单 Phase | orchestrator 派 subagent (e.g. `Agent(codex-rescue, ...)`) |
| orchestrator 观察方式 | 直接看终端 | `tmux capture-pane -t codex-job-$ID -p` 拉 buffer；用 `# PHASE-N-DONE` marker 协议判定 phase 边界 | 每 Phase 启停 codex，stdout 抓即结果 | subagent 返回值 |
| 投喂反馈 | 直接键盘输入 | `tmux send-keys -t codex-job-$ID "feedback" Enter` | 下一次 codex exec 的 prompt | 下一次 subagent 派单 |
| watcher | nohup 后台进程 | nohup 后台进程；额外负责扫 tmux buffer 找 phase marker | 同 CLI-YOLO，但 mini-review 由 watcher 派单次 codex exec | 无 watcher，orchestrator 兼任 |
| inbox poll | watcher 做 | watcher 做 | watcher 做 | orchestrator 自己做（每 1-2 个 Phase） |
| 适用场景 | 终端直接调用 / cron / IM bridge daemon | **Claude Code Bash 工具 / IDE 沙箱里要长跑 Codex**（首选） | 没有 tmux 的 Claude Code Bash 工具 / 受限沙箱 | Claude Code 主上下文派 Agent / Codex 调度 sub-codex |
| 隔离严格度 | 高 | 高（worktree + tmux session + readonly review worktree 全部启用） | 高 | 中 |
| 额外依赖 | 无 | tmux 已装 | 无 | Agent 工具 |

## 探测逻辑

`run-mode.sh detect` 按以下优先级选模式：

1. `tty -s` 成功 → **CLI-YOLO**
2. **无 TTY + tmux 可用 + `CLAUDECODE` / `CLAUDE_CODE_ENTRYPOINT` / `CC_PROJECT` / `ANTHROPIC_AGENT_RUNTIME` 任一 存在（Claude→Codex 派任务场景）→ **TMUX-YOLO**（首选）**
3. 无 TTY 但 `CC_PROJECT` / `ANTHROPIC_AGENT_RUNTIME` 存在但 tmux 不可用 → **SUBAGENT**
4. 否则（无 TTY、不在 subagent env、tmux 不一定可用）→ **CLI-EXEC**

`codex` 不存在或不在 worktree → 立即报错，整个 skill 退出。

## 强烈建议规则：Claude→Codex 派任务场景优先 TMUX-YOLO

当 orchestrator 是 Claude Code（或任何把 Codex 当 subagent 派的 LLM agent）时：

- **判定信号**：`tty -s` 失败、`CLAUDECODE` / `CLAUDE_CODE_ENTRYPOINT` / `CC_PROJECT` / `ANTHROPIC_AGENT_RUNTIME` 任一 非空、`tmux -V` 能跑。
- **强烈建议**：直接用 **TMUX-YOLO** 替代 CLI-EXEC / SUBAGENT。
- **理由**：
  - CLI-EXEC 每 Phase 启停一次 Codex，丢失了 Codex 内部上下文连续性（如 working memory、试错经验、prompt cache），长跑任务效率显著低于一直挂着的 YOLO 进程。
  - SUBAGENT 模式 orchestrator 必须自己守 watcher / snapshot / review-audit 全部纪律，最容易因为 orchestrator 注意力切换而漏 step。
  - TMUX-YOLO 让 Codex 一直跑在 detached tmux session，orchestrator 通过 `capture-pane` / `send-keys` 旁观+投喂，**watcher 仍由独立进程负责，纪律与 CLI-YOLO 完全一致**。
- **接受条件**：用户在 `APPROVAL.md` 签字时必须显式确认接受以下 5 项 TMUX-YOLO 代价（具体协议落地见 `references/tmux-yolo-runtime.md`）：
  1. tmux session 异常退出会留尸进程，需 cleanup 协议（kill orphan sessions）→ `tmux-yolo-runtime.md` §3
  2. `capture-pane` 抓的 buffer 含 ANSI 转义残留（光标/清屏序列），下游消费要 strip → `tmux-yolo-runtime.md` §2
  3. phase 边界靠 `# PHASE-N-DONE` marker 协议，prompt 必须显式要求 Codex announce → `tmux-yolo-runtime.md` §1
  4. orchestrator 主任务超时不会终止 tmux 里的 Codex（这是优势也是风险）
  5. tmux 不是普遍可用——CI 容器、Vercel Sandbox、部分受限沙箱可能没有；fallback 必须保留 CLI-EXEC 路径

- **强制 fallback**：tmux 探测失败时不允许继续 TMUX-YOLO 路径；orchestrator 必须自动降级到 CLI-EXEC（或 SUBAGENT）并在 STATUS.md 记录原因。

- **不适用场景**（即便 tmux 可用也不应用 TMUX-YOLO）：
  - 单个 Phase 预计 < 5 分钟：长跑没收益，CLI-EXEC 更轻量
  - Phase 边界需要 orchestrator 做强人工决策（如安全审查、外部审批）：TMUX-YOLO 让 Codex 跑过头反而麻烦
  - 任务定义里有"每个 Phase 之间必须 hard-pause 等用户确认"约束

## 探测脚本输出新字段

`run-mode.sh capabilities` 输出 JSON 现在包含：

```json
{
  "tty": false,
  "codex_installed": true,
  "tmux_installed": true,
  "tmux_version": "tmux 3.4",
  "subagent_env_hint": true,
  "recommend": "TMUX-YOLO"
}
```

`recommend` 字段：
- `"TMUX-YOLO"`：满足强烈建议条件（无 TTY + subagent env + tmux + codex + worktree 全 OK）
- `"none"`：不触发强烈建议（按主探测逻辑选 CLI-YOLO/CLI-EXEC/SUBAGENT）

Phase 0.0 必须读这个字段并将"是否采纳建议"写入 APPROVAL.md。

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
