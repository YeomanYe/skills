# TMUX-YOLO Runtime 协议

> **状态：v1 — pending real-run feedback**。
> 本文档把 SKILL.md Phase 1.1「TMUX-YOLO 模式」三行启动示例下沉为可参考的协议层。三条协议（marker / strip / cleanup）的措辞与代码片段在首次真实长跑后会按发现回修。

适用范围：`run_mode = TMUX-YOLO` 时（无 TTY + `CLAUDECODE` 等 subagent env hint 非空 + `tmux -V` 可用），watcher 与 orchestrator 协作消费 Codex 跑在 detached tmux session 内的输出。其它运行模式（CLI-YOLO / CLI-EXEC / SUBAGENT）不应用本文。

---

## 1. `PHASE-N-DONE` marker 协议

### 1.1 goal-prompt 强制条款

`/goal` 指令的 prompt 模板里**必须**包含以下一段，让 Goal Codex 在每个 Phase 收尾时打出可被 watcher 抓到的边界标记：

```text
每完成一个 Phase 的最后一步，单独输出一行 marker：

# PHASE-<N>-DONE @ <ISO-8601-UTC-timestamp>

其中：
- N 是 PLAN.md 里的 phase 序号（整数）
- timestamp 形如 `2026-05-19T12:34:56Z`，使用 UTC
- 该行**必须独占一行**、出现在 Codex 流式输出最末端、**不要包含在 markdown code block / triple backtick 内**

如果某个 Phase 因 stop condition 提前终止，**改输出**：

# PHASE-<N>-ABORTED @ <ts> reason: <stop-condition-id>

不要在同一个 Phase 输出多个 marker；不要在 Phase 中途预先打 marker。
```

> Codex 偏离此条款会导致 watcher 漏触发 snapshot/review-audit。这条与 SKILL.md Step 0.4 APPROVAL.md 的 TMUX-YOLO 5 项 cost 是关联的——签字即接受"靠 marker 协议判 phase 边界"的可靠性折扣。

### 1.2 watcher 扫法（伪代码）

```bash
# watcher.sh 主循环
SESSION="codex-job-$TASK_ID"
MARKER_LOG=".agent/tasks/$TASK_ID/phase-markers.log"
LAST_SEEN_PHASE=0
POLL_INTERVAL_SEC=5
BUFFER_LINES=2000  # capture-pane 历史窗口

while true; do
  pane=$(tmux capture-pane -t "$SESSION" -J -p -S -"$BUFFER_LINES" 2>/dev/null) \
    || { echo "[watcher] session $SESSION gone" >&2; break; }

  # 抓 DONE marker，按 phase 序号去重 + 严格行首匹配
  echo "$pane" | strip_tmux_artifacts | \
    grep -E '^# PHASE-[0-9]+-(DONE|ABORTED) @ ' | \
    awk -v last="$LAST_SEEN_PHASE" '
      {
        match($0, /PHASE-[0-9]+/)
        n = substr($0, RSTART+6, RLENGTH-6) + 0
        if (n > last) { print n "|" $0; last = n }
      }
    ' > /tmp/new-markers.$$

  while IFS='|' read -r phase marker; do
    [[ -z "$phase" ]] && continue
    echo "$marker" >> "$MARKER_LOG"
    LAST_SEEN_PHASE=$phase
    if [[ "$marker" == *-ABORTED* ]]; then
      echo "STOPPED: phase-${phase}-aborted-by-codex" >> .agent/tasks/$TASK_ID/STATUS.md
      break 2  # 跳出外层 while，watcher 退出
    fi
    trigger_phase_boundary "$phase"   # → snapshot + 派 reviewer + 写 review-audit
  done < /tmp/new-markers.$$
  rm -f /tmp/new-markers.$$

  sleep "$POLL_INTERVAL_SEC"
done
```

`trigger_phase_boundary` 应组合调用 SKILL.md 里既有的 snapshot / reviewer 派发 / review-audit 写入逻辑，不在本文重复定义。

### 1.3 已知边界与折扣

- **marker 出现在 code block 内**：goal-prompt 已强制"不要包含在 code block"。仍命中时 watcher 不应触发 phase boundary，但要在 `phase-markers.log` 加 `# PROTOCOL-VIOLATION` 注释行供 audit
- **跨 capture-pane 截断**：`-S -2000` 抓 2000 行历史；如果 phase 间隔很长（数千行 stdout）可能仍丢。建议 watcher 启动时同步开 `tmux pipe-pane -o -t $SESSION 'cat >> .agent/tasks/$TASK_ID/codex-full.log'` 保完整 stream 作为兜底
- **多个同号 marker**：以最早出现的为准（`LAST_SEEN_PHASE` 防重复），其余视为协议违规
- **timestamp 不解析**：v1 只看 marker 出现顺序触发 boundary，不依赖 timestamp 排序。timestamp 是给 audit 用的，不是控制流输入

---

## 2. `tmux capture-pane` ANSI strip

### 2.1 实测：`capture-pane` 默认已剥颜色

`tmux capture-pane -p`（**不加 `-e`**）默认剥掉 SGR 颜色码（CSI `[xx;xxm`）。无需自己处理大部分颜色噪音。

仍可能保留的残留：

| 残留 | 来源 | 处理 |
|---|---|---|
| 光标定位序列 `\e[<row>;<col>H` | Codex UI 重绘进度条 | sed 剥 CSI |
| 清屏 `\e[2J` / `\e[K` | Codex 全屏渲染时 | sed 剥 CSI |
| OSC 序列 `\e]...\x07` | 终端 title 设定（rare） | sed 剥 OSC |
| 软换行无 `\n` | tmux 自动 wrap 长行 | 用 `-J` flag join |
| `\r`（CR） | Windows 风格回车 | sed 替换 |

### 2.2 推荐 strip 函数

```bash
strip_tmux_artifacts() {
  # 输入: stdin（建议来自 tmux capture-pane -J -p ...）
  # 输出: stdout（人类与 grep 都能消费的纯文本）
  sed -E \
    -e 's/\x1B\[[0-9;?]*[a-zA-Z]//g'  `# CSI 序列（颜色 / 光标 / 清屏 / DECSET 等）` \
    -e 's/\x1B\][^\x07]*\x07//g'      `# OSC 序列（终端 title 等，少见）` \
    -e 's/\x1B[()][AB012]//g'         `# 字符集切换（极少见，rxvt 风格）` \
    -e 's/\r//g'                       `# CR`
}

# 推荐调用范式
capture_clean() {
  local sess="$1" lines="${2:-2000}"
  tmux capture-pane -t "$sess" -J -p -S -"$lines" 2>/dev/null | strip_tmux_artifacts
}
```

### 2.3 大 buffer 与完整日志

- `-S -N` 抓最近 N 行历史；不加 `-S` 只抓当前可见行（默认 ~24 行，太少）
- 长跑任务建议 `-S -5000`，下游按内存承受能力调
- 要保完整历史（供事后审计 / 调试 prompt），启动 Goal Codex 时加 `pipe-pane`：

```bash
tmux new-session -d -s "$SESSION" "codex --dangerously-bypass-approvals-and-sandbox --cd $WORKTREE"
tmux pipe-pane -o -t "$SESSION" "cat >> .agent/tasks/$TASK_ID/codex-full.log"
```

`codex-full.log` 含原始 ANSI；用 `strip_tmux_artifacts < codex-full.log` 拿干净版本。

---

## 3. Cleanup 协议

### 3.1 session 命名约定

- 唯一 prefix：`codex-job-`
- 后缀必须是 task id（不依赖随机串防撞）：`codex-job-${TASK_ID}`
- 同一个 task **不允许并发两个 session**——发现既有同名 session 时按 3.2 stale scan 处理或 abort

### 3.2 Phase 0.0 启动前 stale scan

新任务进 Phase 0.0 时，先扫一遍其它残留的 `codex-job-*` session：

```bash
# Phase 0.0 prelude（启动 watcher / Goal Codex 之前跑）
SELF_SESSION="codex-job-$TASK_ID"
NOW=$(date +%s)
STALE_THRESHOLD_HOURS=24

tmux ls -F '#{session_name}|#{session_activity}' 2>/dev/null | \
  grep -E '^codex-job-' | \
  while IFS='|' read -r sess last_activity; do
    [[ "$sess" == "$SELF_SESSION" ]] && continue
    age_hours=$(( (NOW - last_activity) / 3600 ))
    (( age_hours <= STALE_THRESHOLD_HOURS )) && continue  # 留着，可能是别人的活任务

    task_id=${sess#codex-job-}
    status_file=".agent/tasks/$task_id/STATUS.md"
    if [[ ! -f "$status_file" ]]; then
      echo "[cleanup] killing orphan (no STATUS.md): $sess (age ${age_hours}h)" >&2
      tmux kill-session -t "$sess" 2>/dev/null
    elif grep -qE '^STATUS: (STOPPED|GOAL_DONE|FAILED)' "$status_file"; then
      echo "[cleanup] killing finished stale: $sess (age ${age_hours}h)" >&2
      tmux kill-session -t "$sess" 2>/dev/null
    else
      echo "[warn] keeping suspicious: $sess (STATUS.md alive but tmux inactive ${age_hours}h); manual check" >&2
      # 不强杀；写 .agent/tasks/<task_id>/STALE-WARNING 提示运维
      touch ".agent/tasks/$task_id/STALE-WARNING"
    fi
  done
```

判断双重确认（age + STATUS.md），避免误杀仍在跑的兄弟任务。

### 3.3 watcher 退出 trap

watcher 是 session 的最终所有者，退出时**必须**杀掉自己负责的 session：

```bash
# watcher.sh 启动开头
SESSION="codex-job-$TASK_ID"
CLEANUP_LOG=".agent/tasks/$TASK_ID/cleanup.log"

cleanup_session() {
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux kill-session -t "$SESSION" 2>/dev/null
    if tmux has-session -t "$SESSION" 2>/dev/null; then
      # 残留：用 pane pid 强杀
      local pid
      pid=$(tmux list-panes -t "$SESSION" -F '#{pane_pid}' 2>/dev/null | head -1)
      [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null
      tmux kill-session -t "$SESSION" 2>/dev/null
    fi
  fi
  echo "[$(date -Iseconds)] cleanup_session $SESSION exit_code=$?" >> "$CLEANUP_LOG"
}

trap cleanup_session EXIT INT TERM
```

### 3.4 兜底失败的处理

| 失败 | 处理 |
|---|---|
| `tmux kill-session` 返回非 0 | 重试 3.3 的 pane-pid `kill -9` 路径 |
| pane pid 也杀不掉（罕见，suid / kernel hang） | 写 `STATUS: cleanup-failed: <sess> <reason>` 到 STATUS.md，停止 watcher，等人工 |
| `tmux ls` 本身报错（tmux server crash） | 跳过 stale scan，记 `[warn] tmux server unavailable` 到 cleanup.log，照常启动新 session（tmux server 会自动 spawn 新的） |

**禁止**：用 `tmux kill-server` 一键清场。它会杀所有 tmux session，包括用户的其它工作 session。仅当本机只为本任务专用（如 CI 容器）时才可用，并必须在 APPROVAL.md 里显式签字。

---

## 4. 与既有协议的交叉引用

- Phase 0.4 APPROVAL.md 的 TMUX-YOLO 5 项 cost：本文 §1.3 / §2.3 / §3.4 是这 5 项的具体兑现
- run-mode.md「强烈建议规则」节：本文是该节"接受条件"项下 5 项 cost 的 runtime 落地
- SKILL.md Step 1.1 TMUX-YOLO 启动段：本文 §3.1 命名 + §1.1 marker 条款 + §2.2 strip 函数应被 SKILL.md 启动代码段直接复用

---

## 5. v1 → v2 待回写

第一次真实跑完 TMUX-YOLO 任务后，按发现回修本文：

- §1.2 watcher 轮询间隔是否合适（5 秒可能过密 / 过疏）
- §1.3 跨 capture-pane 截断的发生频率（看是否要把默认 `-S -2000` 调大）
- §2.1 残留序列清单是否完整（特别是 Codex 0.13x+ 版本如果换了 UI 渲染库）
- §3.2 stale 阈值 24h 是否合理（高频任务可能要降到 6h；长任务可能要升）
- §3.3 cleanup trap 是否被 watcher 异常退出场景（SIGKILL / kernel OOM）规避——这类场景 trap 不生效，需另设 cron / launchd / systemd timer 周期扫
