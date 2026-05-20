#!/usr/bin/env bash
# watcher.sh — Goal Codex 看门狗（health + boundary + inbox-poll + milestone + final-review）
#
# 用法: ./watcher.sh <task-id> [check-interval-sec]
# 后台运行: nohup ./watcher.sh <task-id> > .agent/tasks/<task-id>/logs/watcher.log 2>&1 &
#
# 职责:
#   - 周期 health-check.sh（每 INTERVAL 秒）
#   - 周期 boundary-watch.sh（每 30 秒）— codex 不沙箱时的边界守卫
#   - 周期 cc-connect inbox poll（每 60 秒）— 接收人类 IM 回复
#   - milestone 触发：runtime-evidence + mini-review codex + snapshot + audit + IM push
#   - done 触发：创建 readonly worktree + 启动 reviewer codex（env -i 隔离）+ copy REVIEW + 销毁 readonly
#   - boundary 违反：hard kill goal codex + alert 人类
#
# 注意：用 `set -u` 而非 `set -euo pipefail`
#   历史 bug：管道（如 jq | head）配合 pipefail 在 head 提前关闭时 SIGPIPE，导致脚本异常退出。
set -u

TASK_ID="${1:?task-id required}"
INTERVAL="${2:-300}"   # health-check 间隔（默认 5 分钟）
BOUNDARY_INTERVAL=30    # boundary-watch 间隔
INBOX_INTERVAL=60       # IM inbox poll 间隔

TASK_DIR=".agent/tasks/$TASK_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_CHECK="$SCRIPT_DIR/health-check.sh"
BOUNDARY_WATCH="$SCRIPT_DIR/boundary-watch.sh"
SNAPSHOT="$SCRIPT_DIR/snapshot.sh"
WRITE_AUDIT="$SCRIPT_DIR/write-audit.sh"

[[ -x "$HEALTH_CHECK" ]] || chmod +x "$HEALTH_CHECK"
[[ -x "$BOUNDARY_WATCH" ]] || chmod +x "$BOUNDARY_WATCH"
[[ -x "$SNAPSHOT" ]] || chmod +x "$SNAPSHOT"
[[ -x "$WRITE_AUDIT" ]] || chmod +x "$WRITE_AUDIT"

[[ -d "$TASK_DIR" ]] || { echo "task-dir-missing: $TASK_DIR" >&2; exit 2; }

LOG="$TASK_DIR/logs/watcher.log"
mkdir -p "$(dirname "$LOG")"
mkdir -p "$TASK_DIR/snapshots" "$TASK_DIR/scores" "$TASK_DIR/reviews" "$TASK_DIR/review-audit"

WORKTREE="${WORKTREE:-$(pwd)}"

# === Portable helpers ===
# `timeout` is GNU coreutils; macOS doesn't ship it by default.
# Prefer `timeout` → `gtimeout` → bash fallback (bg job + sleep+kill).
# Usage: run_with_timeout <seconds> <cmd> [args...]
run_with_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
    return $?
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
    return $?
  else
    # bash fallback: launch in bg, sleep-kill
    "$@" &
    local cmd_pid=$!
    local i=0
    while (( i < secs )); do
      if ! kill -0 "$cmd_pid" 2>/dev/null; then
        wait "$cmd_pid" 2>/dev/null
        return $?
      fi
      sleep 1
      i=$((i + 1))
    done
    # exceeded budget: TERM then KILL
    kill -TERM "$cmd_pid" 2>/dev/null
    sleep 2
    kill -KILL "$cmd_pid" 2>/dev/null
    wait "$cmd_pid" 2>/dev/null
    return 124  # GNU timeout convention: 124 on timeout
  fi
}

# Build a PATH that always includes the codex binary's directory.
# env -i strips PATH; if /opt/homebrew/bin or similar holds codex, we must
# re-include it or `env: codex: No such file or directory` kills the reviewer.
codex_safe_path() {
  local codex_bin
  codex_bin=$(command -v codex 2>/dev/null)
  local codex_dir=""
  [[ -n "$codex_bin" ]] && codex_dir=$(dirname "$codex_bin")
  if [[ -n "$codex_dir" ]]; then
    echo "$codex_dir:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin"
  else
    echo "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
  fi
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"
}

notify_human() {
  local subject="$1"
  local body="$2"

  log "NOTIFY: $subject"

  if [[ -n "${CC_SESSION_KEY:-}" ]] && command -v cc-connect > /dev/null 2>&1; then
    cc-connect send --message "[$TASK_ID] $subject

$body" 2>>"$LOG" || log "cc-connect send failed (non-fatal)"
  fi

  cat >> "$TASK_DIR/notifications.log" <<EOF
=== $(date '+%Y-%m-%d %H:%M:%S') ===
$subject

$body

EOF
}

cleanup_codex() {
  if [[ -f "$TASK_DIR/codex.pid" ]]; then
    local pid
    pid=$(cat "$TASK_DIR/codex.pid")
    if ps -p "$pid" > /dev/null 2>&1; then
      log "Stopping Codex pid=$pid"
      kill "$pid" 2>/dev/null || true
      sleep 2
      ps -p "$pid" > /dev/null 2>&1 && kill -9 "$pid" 2>/dev/null || true
    fi
  fi
}

# === IM inbox poll（替代原来 orchestrator 的活）===
poll_inbox() {
  [[ -n "${CC_SESSION_KEY:-}" ]] || return 0
  command -v cc-connect > /dev/null 2>&1 || return 0

  # cc-connect 当前没标准 inbox API（按当前实现）。这里留 hook：
  # 如果未来加了 `cc-connect inbox poll --since <ts>`，在这里调用并解析回复关键词
  # 关键词协议：
  #   "approve goal <TASK_ID>" → 写 APPROVAL.md
  #   "pause"                  → 写 STOPPED: human-paused
  #   "abort"                  → 写 STOPPED: human-aborted
  #   "adjust: <text>"         → 写 STATUS.md ## Human Feedback 段
  #   "continue"               → 不动作
  #
  # 当前 fallback: 检测 STATUS.md 是否被人类手动追加了 ## Human Feedback 段
  # 如果有新增段（mtime 比上次 poll 新），log 一下让 orchestrator 知道
  local last_poll_marker="$TASK_DIR/.last-inbox-poll"
  local now=$(date +%s)
  local since=0
  [[ -f "$last_poll_marker" ]] && since=$(cat "$last_poll_marker")
  echo "$now" > "$last_poll_marker"

  if [[ -f "$TASK_DIR/STATUS.md" ]]; then
    local status_mtime
    status_mtime=$(stat -f %m "$TASK_DIR/STATUS.md" 2>/dev/null || stat -c %Y "$TASK_DIR/STATUS.md" 2>/dev/null || echo 0)
    if (( status_mtime > since )); then
      if grep -q "^## Human Feedback" "$TASK_DIR/STATUS.md" 2>/dev/null; then
        log "Detected Human Feedback in STATUS.md (mtime updated)"
      fi
    fi
  fi
}

# === TMUX-YOLO PHASE marker scanner（修复 P1 #7）===
#
# 旧版 watcher 完全不扫 tmux buffer，只靠 STATUS.md 里的 `^MILESTONE:` 行触发
# milestone 事件。但 TMUX-YOLO 模式下 Codex 是按 `# PHASE-N-DONE @ <ts>` marker
# 报告进度（见 references/tmux-yolo-runtime.md §1.1），自己不写 STATUS.md
# MILESTONE 行——结果 18min 跑完 5 个 phase，watcher 一次 milestone 都没触发，
# mini-review / snapshot / IM 推图全失灵。
#
# 新版：TMUX-YOLO 模式下每 5s 抓 tmux buffer，识别新出现的 PHASE-DONE / ABORTED
# marker，翻译成 STATUS.md "MILESTONE: phase-N-done" 让 health-check.sh 自然拾起。

# 默认已剥 SGR 颜色，再剥 CSI/OSC 残留 + CR
strip_tmux_artifacts() {
  sed -E \
    -e 's/\x1B\[[0-9;?]*[a-zA-Z]//g' \
    -e 's/\x1B\][^\x07]*\x07//g' \
    -e 's/\x1B[()][AB012]//g' \
    -e 's/\r//g'
}

poll_phase_markers() {
  # 只在 TMUX-YOLO 模式下生效
  local run_mode=""
  [[ -f "$TASK_DIR/RUN_MODE" ]] && run_mode=$(cat "$TASK_DIR/RUN_MODE")
  [[ "$run_mode" == "TMUX-YOLO" ]] || return 0
  local session=""
  [[ -f "$TASK_DIR/tmux.session" ]] && session=$(cat "$TASK_DIR/tmux.session")
  [[ -n "$session" ]] || return 0
  command -v tmux > /dev/null 2>&1 || return 0
  tmux has-session -t "$session" 2>/dev/null || return 0

  local marker_log="$TASK_DIR/phase-markers.log"
  local last_seen_file="$TASK_DIR/.last-phase-seen"
  local last_seen=0
  [[ -f "$last_seen_file" ]] && last_seen=$(cat "$last_seen_file")

  local pane
  pane=$(tmux capture-pane -t "$session" -J -p -S -2000 2>/dev/null | strip_tmux_artifacts)
  [[ -z "$pane" ]] && return 0

  # 抓行首 marker，按 phase 序号去重
  local new_markers
  new_markers=$(echo "$pane" | grep -E '^# PHASE-[0-9]+-(DONE|ABORTED) @ ' | \
    awk -v last="$last_seen" '
      {
        match($0, /PHASE-[0-9]+/)
        n = substr($0, RSTART+6, RLENGTH-6) + 0
        if (n > last) { print n "\t" $0 }
      }
    ')
  [[ -z "$new_markers" ]] && return 0

  while IFS=$'\t' read -r phase marker; do
    [[ -z "$phase" ]] && continue
    echo "$marker" >> "$marker_log"
    echo "$phase" > "$last_seen_file"
    log "TMUX marker: $marker"

    if [[ "$marker" == *-ABORTED* ]]; then
      echo "STOPPED: phase-${phase}-aborted-by-codex" >> "$TASK_DIR/STATUS.md"
      touch "$TASK_DIR/.stop-signal"
      return 0
    fi
    # 翻译成 STATUS.md MILESTONE 行，让 health-check.sh 在下个周期识别为 milestone state
    echo "MILESTONE: phase-${phase}-done" >> "$TASK_DIR/STATUS.md"
  done <<< "$new_markers"
}

# === Boundary check ===
check_boundary() {
  local result
  result=$(bash "$BOUNDARY_WATCH" "$TASK_ID" 2>>"$LOG" || echo "ok")
  if [[ "$result" == "stop-boundary" ]]; then
    log "BOUNDARY VIOLATION detected"
    notify_human "Boundary violation — hard killing Goal Codex" "
codex 越界（动了 worktree 外文件 / 切了主分支 / 改了 git remote / reflog 含破坏性 op）。
详见 $TASK_DIR/logs/boundary-violations.log
"
    cleanup_codex
    echo "STOPPED: boundary-violation" >> "$TASK_DIR/STATUS.md"
    touch "$TASK_DIR/.boundary-violation"
    touch "$TASK_DIR/.stop-signal"
    return 1
  fi
  return 0
}

# === handle_milestone（含 snapshot + audit）===
handle_milestone() {
  local milestone="$1"
  log "MILESTONE detected: $milestone — triggering mini-review + snapshot + audit + IM push"

  local scores_dir="$TASK_DIR/scores/$milestone"
  mkdir -p "$scores_dir/screenshots"

  # 1. runtime evidence
  bash "$SCRIPT_DIR/runtime-evidence.sh" "$TASK_ID" "scores/$milestone" >> "$LOG" 2>&1 || true

  # 2. mini-review codex（独立新进程，10min 超时；内部反复强调 1-5 不准 1-10）
  local milestone_review_log="$scores_dir/review.log"
  log "Launching mini-review codex (timeout 10min, portable timeout)"
  run_with_timeout 600 codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox < "$SCRIPT_DIR/milestone-review-prompt.md" \
    > "$milestone_review_log" 2>&1 || log "mini-review codex timed out or errored (recorded)"

  local score_json="$scores_dir.json"
  if [[ ! -f "$score_json" ]]; then
    log "WARN: mini-review did not produce $score_json; skipping diff/snapshot/audit"
    return 0
  fi

  # 3. score-diff（含 highest-score tracking）
  # 严格匹配 mode 行（4 种合法值之一），避免误匹配 yaml 块中其他字段
  local mode
  mode=$(grep -E "^mode:\s+(threshold|no-improvement-N|regression-prevention|hybrid)" "$TASK_DIR/GOAL.md" 2>/dev/null | head -1 | awk '{print $2}' || echo "regression-prevention")
  local diff_out
  diff_out=$(python3 "$SCRIPT_DIR/score-diff.py" \
    --baseline "$TASK_DIR/BASELINE.md" \
    --current  "$score_json" \
    --mode     "$mode" \
    --no-improvement-history "$TASK_DIR/scores/aggregate-trend.json" \
    --highest-score-file "$TASK_DIR/snapshots/HIGHEST_SCORE" 2>&1)
  local diff_rc=$?

  echo "$diff_out" > "$scores_dir/score-diff.json"

  if [[ $diff_rc -ne 0 ]]; then
    log "Score regression / no-improvement detected: $diff_out"
    echo "STOPPED: score-trigger ($milestone)" >> "$TASK_DIR/STATUS.md"
    notify_human "Score trigger at $milestone" "$diff_out"
    touch "$TASK_DIR/.stop-signal"
    return 0
  fi

  # 4. snapshot（创新高才打 tag）
  local agg
  agg=$(jq -r .aggregate "$score_json" 2>/dev/null || echo 0)
  bash "$SNAPSHOT" "$TASK_ID" "$milestone" "$agg" >> "$LOG" 2>&1 || log "snapshot.sh failed (non-fatal)"

  # 5. audit
  bash "$WRITE_AUDIT" "$TASK_ID" "$milestone" mini-review >> "$LOG" 2>&1 || log "write-audit.sh failed (non-fatal)"

  # 6. IM push（含 UI 截图）
  if [[ -n "${CC_SESSION_KEY:-}" ]] && command -v cc-connect > /dev/null 2>&1; then
    local delta
    delta=$(jq -r '.delta_vs_baseline.aggregate // "?"' "$score_json" 2>/dev/null || echo "?")
    local notes
    notes=$(jq -r .notes "$score_json" 2>/dev/null || echo "")
    local snap_decision
    snap_decision=$(jq -r .snapshot_decision "$scores_dir/score-diff.json" 2>/dev/null || echo "?")

    local msg="[$TASK_ID] MILESTONE: $milestone
Aggregate: $agg (Δ vs baseline: $delta)  snapshot: $snap_decision
$notes

Reply: continue / pause / abort / adjust: <text>"

    local screenshots=()
    while IFS= read -r f; do screenshots+=(--image "$f"); done < <(find "$scores_dir/screenshots" -name "*.png" 2>/dev/null | head -8)

    cc-connect send --message "$msg" "${screenshots[@]}" 2>>"$LOG" \
      || log "cc-connect send failed (non-fatal)"

    # 同时写入 pending-review-images.txt 让 orchestrator 后补校验文件名 ≠ 内容
    {
      echo "=== $milestone @ $(date '+%Y-%m-%d %H:%M:%S') ==="
      find "$scores_dir/screenshots" -name "*.png" 2>/dev/null
    } >> "$TASK_DIR/pending-review-images.txt"
  fi
}

# === trigger_review（升级：readonly worktree + env -i 硬隔离）===
# === v4: Extra Reviewers 通用注册机制 ===

# 解析 GOAL.md 的 extra_reviewers 段，输出 reviewer name 列表（一行一个）
# 注意：用 [[:space:]] 而非 \s，兼容 BSD awk/sed（macOS）
#
# 修复 P0 #3 (2026-05-20)：旧版用 `flag && /^[[:space:]]*-/` 贪婪匹配任何 - 行，
# 导致 `checks:` 下的嵌套数组项（如 `      - UX`、`      - 信息层级`）也被当成
# reviewer 名，2 个 reviewer 被错读成 10 个伪 reviewer。
#
# 新版按 YAML 缩进识别：只取 extra_reviewers: 段下 **第一层缩进** 的 dash 行，
# 同时支持两种 schema：
#   简单：  - director-design
#   详细：  - name: director-design  （checks: 等更深缩进的行不再被误捕获）
parse_extra_reviewers() {
  awk '
    /^extra_reviewers:/ { in_block = 1; base_indent = -1; next }
    /^[a-zA-Z_]/ { in_block = 0; next }
    in_block && /^[[:space:]]*-[[:space:]]+/ {
      # 数前导空格
      indent = 0
      while (substr($0, indent + 1, 1) == " ") indent++
      if (base_indent < 0) base_indent = indent
      # 只接受与第一层缩进相同的 dash 行（跳过 checks: 等更深缩进）
      if (indent == base_indent) {
        # 剥掉 "  - "（缩进 + dash + 空格）
        line = substr($0, indent + 3)
        sub(/^[[:space:]]+/, "", line)
        # 详细 schema 把 "name:" 也剥掉
        sub(/^name:[[:space:]]+/, "", line)
        # 取第一个 token
        split(line, parts, /[[:space:]]/)
        if (parts[1] != "") print parts[1]
      }
    }
  ' "$TASK_DIR/GOAL.md" 2>/dev/null \
    | grep -v "^$" \
    | head -10
}

read_arbitration_rule() {
  grep -E "^arbitration_rule:" "$TASK_DIR/GOAL.md" 2>/dev/null \
    | head -1 | awk '{print $2}' \
    | grep -E "^(AND-pass|OR-pass|weighted-avg|hard-rule-override)$" \
    || echo "AND-pass"
}

# 派 1 个 extra reviewer subagent
launch_one_extra_reviewer() {
  local task_id="$1" round="$2" reviewer_name="$3"
  local round_dir="$TASK_DIR/reviews/round-$round"
  local extras_dir="$round_dir/extras"
  mkdir -p "$extras_dir"

  log "Launching extra reviewer: $reviewer_name (round $round)"

  # subagent 派工 prompt（显式调用 reviewer skill 硬规则）
  local prompt
  prompt=$(cat <<EOF
You are an extra reviewer for a Codex Goal task.

MUST explicitly invoke the \`$reviewer_name\` skill (subagent does NOT auto-trigger skills).

Inputs (read-only):
  - .agent/tasks/$task_id/GOAL.md
  - .agent/tasks/$task_id/EVAL.md
  - .agent/tasks/$task_id/BASELINE.md
  - .agent/tasks/$task_id/review-input/

Forbidden to read:
  - STATUS.md / ISSUES.md / logs/ / 历史 reviews/

Task:
  Run the \`$reviewer_name\` skill in its appropriate audit/review mode.
  Output your report to: .agent/tasks/$task_id/reviews/round-$round/extras/$reviewer_name.md

Required output sections in your .md (EXACT format, parser depends on this):
  - ## Verdict
    <single word: pass | pass-with-fixes | needs-redesign | needs-direction | fail>
  - ## Aggregate
    Aggregate: <X.X>   (must be inline "Aggregate: <number>", number 0.0-5.0)
  - ## Must Fix
    (each: - file: / issue: / why-blocking: / suggested-fix:)
  - ## Should Fix
  - ## Confidence
    <high | medium | low>

Return JSON to stdout (last line):
  {"reviewer_name":"$reviewer_name","verdict":"...","aggregate":X.X,"must_fix_count":N,"errors":[]}
EOF
)

  # 用 Agent / codex exec 等机制启动 subagent；
  # 此处 fallback 用 codex exec（与内置 Reviewer Codex 同模式）
  # 关键：codex_safe_path 保证 env -i 后 codex binary 仍可见（覆盖 P0 #2 bug）
  # 关键：run_with_timeout 在 macOS 没 GNU timeout 时降级到 bg+kill（覆盖 P0 #1 bug）
  run_with_timeout 600 env -i \
    PATH="$(codex_safe_path)" \
    HOME="$HOME" \
    LANG="${LANG:-en_US.UTF-8}" \
    LC_ALL="${LC_ALL:-en_US.UTF-8}" \
    TASK_ID="$task_id" \
    codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox <(echo "$prompt") \
    > "$extras_dir/$reviewer_name.codex.log" 2>&1 \
    || log "extra reviewer $reviewer_name timed out / failed (non-blocking)"

  # 检查是否输出了 .md
  if [[ -f "$extras_dir/$reviewer_name.md" ]]; then
    log "extra reviewer $reviewer_name produced report"
  else
    log "WARN: extra reviewer $reviewer_name did not produce $extras_dir/$reviewer_name.md"
  fi
}

# 并列派所有注册的 extra reviewers
launch_extra_reviewers() {
  local round="$1"
  local reviewers
  reviewers=$(parse_extra_reviewers)

  [[ -z "$reviewers" ]] && { log "No extra reviewers registered (v3 mode)"; return 0; }

  log "Launching extra reviewers: $(echo "$reviewers" | tr '\n' ' ')"

  local pids=()
  while IFS= read -r reviewer; do
    [[ -z "$reviewer" ]] && continue
    launch_one_extra_reviewer "$TASK_ID" "$round" "$reviewer" &
    pids+=($!)
  done <<< "$reviewers"

  # collect-all：所有 reviewer 都返回，单路失败不阻塞
  wait "${pids[@]}" 2>/dev/null || log "some extra reviewer subagent exited non-zero (recorded)"
}

# 合并多 reviewer 仲裁
# 用法: arbitrate_reviews <round> verdict|aggregate
arbitrate_reviews() {
  local round="$1" field="$2"
  local round_dir="$TASK_DIR/reviews/round-$round"
  local rule
  rule=$(read_arbitration_rule)

  # 收集所有 reviewer 报告
  local reports=()
  [[ -f "$round_dir/REVIEW.md" ]] && reports+=("$round_dir/REVIEW.md")
  if [[ -d "$round_dir/extras" ]]; then
    while IFS= read -r f; do reports+=("$f"); done < <(find "$round_dir/extras" -name "*.md" 2>/dev/null)
  fi

  [[ ${#reports[@]} -eq 0 ]] && { echo "fail"; return; }

  # 解析每个 reviewer 的 verdict / aggregate
  local verdicts=() aggs=()
  for r in "${reports[@]}"; do
    local v
    v=$(awk '/^## Verdict/{flag=1;next} /^## /{flag=0} flag && NF>0 {print tolower($1); exit}' "$r" 2>/dev/null)
    [[ -z "$v" ]] && v="fail"
    verdicts+=("$v")

    local a
    a=$(grep -oE "Aggregate:\s*[0-9.]+" "$r" 2>/dev/null | head -1 | awk '{print $2}')
    [[ -z "$a" ]] && a=0
    aggs+=("$a")
  done

  if [[ "$field" == "verdict" ]]; then
    [[ ${#verdicts[@]} -eq 0 ]] && { echo "fail"; return; }
    case "$rule" in
      AND-pass)
        for v in "${verdicts[@]}"; do [[ "$v" != "pass" ]] && { echo "fail"; return; }; done
        echo "pass"
        ;;
      OR-pass)
        for v in "${verdicts[@]}"; do [[ "$v" == "pass" ]] && { echo "pass"; return; }; done
        echo "fail"
        ;;
      hard-rule-override)
        for v in "${verdicts[@]}"; do [[ "$v" == "needs-redesign" ]] && { echo "fail"; return; }; done
        for v in "${verdicts[@]}"; do [[ "$v" != "pass" ]] && { echo "fail"; return; }; done
        echo "pass"
        ;;
      weighted-avg)
        # 简化版：算术平均（精确加权需读 arbitration_weight，known limitation）
        local sum=0 n=0
        for a in "${aggs[@]}"; do
          [[ "$a" == "0" ]] && continue
          sum=$(awk -v s="$sum" -v a="$a" 'BEGIN{print s+a}')
          n=$((n+1))
        done
        [[ $n -eq 0 ]] && { echo "fail"; return; }
        local avg
        avg=$(awk -v s="$sum" -v n="$n" 'BEGIN{printf "%.2f", s/n}')
        local pass
        pass=$(awk -v a="$avg" 'BEGIN{print (a >= 4.0) ? "pass" : "fail"}')
        echo "$pass"
        ;;
      *) echo "fail" ;;
    esac
  elif [[ "$field" == "aggregate" ]]; then
    [[ ${#aggs[@]} -eq 0 ]] && { echo "0"; return; }
    # 几何平均（强调"两边都好"）
    local product=1 n=0
    for a in "${aggs[@]}"; do
      [[ "$a" == "0" ]] && continue
      product=$(awk -v p="$product" -v a="$a" 'BEGIN{print p*a}')
      n=$((n+1))
    done
    [[ $n -eq 0 ]] && { echo "0"; return; }
    awk -v p="$product" -v n="$n" 'BEGIN{printf "%.2f", p^(1/n)}'
  fi
}

# 写 arbitration.md 合并视图
write_arbitration_md() {
  local round="$1"
  local round_dir="$TASK_DIR/reviews/round-$round"
  local arb_md="$round_dir/arbitration.md"
  local rule
  rule=$(read_arbitration_rule)
  local overall_v overall_a
  overall_v=$(arbitrate_reviews "$round" verdict)
  overall_a=$(arbitrate_reviews "$round" aggregate)

  {
    echo "# Arbitration: round-$round"
    echo
    echo "## Rule"
    echo "$rule"
    echo
    echo "## Reviewers"
    # 内置
    if [[ -f "$round_dir/REVIEW.md" ]]; then
      local v a
      v=$(awk '/^## Verdict/{flag=1;next} /^## /{flag=0} flag && NF>0 {print tolower($1); exit}' "$round_dir/REVIEW.md")
      a=$(grep -oE "Aggregate:[[:space:]]*[0-9.]+" "$round_dir/REVIEW.md" | head -1 | awk '{print $2}')
      echo "- codex-reviewer (内置)"
      echo "  - verdict: ${v:-n/a}"
      echo "  - aggregate: ${a:-n/a}"
      echo "  - source: reviews/round-$round/REVIEW.md"
    fi
    # extras
    if [[ -d "$round_dir/extras" ]]; then
      for f in "$round_dir/extras"/*.md; do
        [[ -f "$f" ]] || continue
        local name v a
        name=$(basename "$f" .md)
        v=$(awk '/^## Verdict/{flag=1;next} /^## /{flag=0} flag && NF>0 {print tolower($1); exit}' "$f")
        a=$(grep -oE "Aggregate:[[:space:]]*[0-9.]+" "$f" | head -1 | awk '{print $2}')
        echo "- $name (extra)"
        echo "  - verdict: ${v:-n/a}"
        echo "  - aggregate: ${a:-n/a}"
        echo "  - source: reviews/round-$round/extras/$name.md"
      done
    fi
    echo
    echo "## Combined"
    echo "- overall_verdict: $overall_v"
    echo "- overall_aggregate: $overall_a (geometric mean)"
  } > "$arb_md"
  log "arbitration.md written: $arb_md"
}

trigger_review() {
  log "Goal complete — triggering FINAL review pipeline (with hard isolation)"

  local round
  round=$(($(ls "$TASK_DIR/reviews/" 2>/dev/null | wc -l | tr -d ' ') + 1))
  local review_round_dir="$TASK_DIR/reviews/round-$round"
  mkdir -p "$review_round_dir"

  # 1. 生成 review-input
  local review_input="$TASK_DIR/review-input"
  mkdir -p "$review_input/screenshots"

  cd "$WORKTREE" || { log "ERR: cannot cd to $WORKTREE"; return 1; }
  git diff main > "$review_input/diff.patch" 2>>"$LOG" || true
  git diff --stat main > "$review_input/diff-stat.txt" 2>>"$LOG" || true
  git status --short > "$review_input/status.txt" 2>>"$LOG" || true

  if [[ -f package.json ]]; then
    local pm="npm"
    [[ -f pnpm-lock.yaml ]] && pm="pnpm"
    [[ -f yarn.lock ]] && pm="yarn"
    $pm run lint > "$review_input/lint.txt" 2>&1 || true
    $pm test > "$review_input/test.txt" 2>&1 || true
    $pm run build > "$review_input/build.txt" 2>&1 || true
  elif [[ -f Cargo.toml ]]; then
    cargo clippy > "$review_input/lint.txt" 2>&1 || true
    cargo test > "$review_input/test.txt" 2>&1 || true
    cargo build > "$review_input/build.txt" 2>&1 || true
  fi

  # 2. 创建 review-readonly worktree（**硬隔离的核心**）
  local review_wt="../$(basename "$WORKTREE")-review-readonly-r$round"
  if [[ -d "$review_wt" ]]; then
    log "Cleaning stale readonly worktree: $review_wt"
    git worktree remove --force "$review_wt" 2>>"$LOG" || rm -rf "$review_wt"
  fi
  log "Creating readonly worktree: $review_wt"
  git worktree add "$review_wt" HEAD 2>>"$LOG" || {
    log "ERR: failed to create readonly worktree"
    return 1
  }

  # 物理屏蔽 implementer 自述 + 历史 reviews
  rm -f "$review_wt/$TASK_DIR/STATUS.md" \
        "$review_wt/$TASK_DIR/ISSUES.md"
  rm -rf "$review_wt/$TASK_DIR/logs/" \
         "$review_wt/$TASK_DIR/reviews/" \
         "$review_wt/$TASK_DIR/review-audit/" \
         "$review_wt/$TASK_DIR/notifications.log" \
         "$review_wt/$TASK_DIR/pending-review-images.txt"

  # copy review-input + 必要 metadata 进 readonly worktree
  cp -r "$review_input" "$review_wt/$TASK_DIR/" 2>>"$LOG" || true
  cp "$TASK_DIR/BASELINE.md" "$review_wt/$TASK_DIR/" 2>>"$LOG" || true
  cp "$TASK_DIR/GOAL.md" "$review_wt/$TASK_DIR/" 2>>"$LOG" || true
  cp "$TASK_DIR/EVAL.md" "$review_wt/$TASK_DIR/" 2>>"$LOG" || true

  # 3. env -i 启动 Reviewer
  # codex_safe_path 保证 PATH 包含 codex binary 所在目录（覆盖 P0 #2 bug）
  log "Launching reviewer codex (env -i hard isolation, codex_safe_path)"
  local reviewer_log="$review_round_dir/codex.log"
  env -i \
    PATH="$(codex_safe_path)" \
    HOME="$HOME" \
    LANG="${LANG:-en_US.UTF-8}" \
    LC_ALL="${LC_ALL:-en_US.UTF-8}" \
    NODE_ENV="test" \
    TASK_ID="$TASK_ID" \
    codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox --cd "$review_wt" < "$SCRIPT_DIR/review-prompt.md" \
    > "$reviewer_log" 2>&1 &
  local reviewer_pid=$!
  echo "$reviewer_pid" > "$review_round_dir/reviewer.pid"

  # 进程隔离硬验证
  local goal_pid
  goal_pid=$(cat "$TASK_DIR/codex.pid" 2>/dev/null || echo 0)
  if [[ "$reviewer_pid" == "$goal_pid" ]]; then
    log "ABORT: reviewer pid == goal pid; killing reviewer"
    kill "$reviewer_pid" 2>/dev/null || true
    notify_human "Reviewer isolation FAILURE" "reviewer_pid=$reviewer_pid == goal_pid; aborted"
    return 1
  fi

  wait "$reviewer_pid" || log "Reviewer codex exited non-zero (recorded)"

  # 4. copy REVIEW.md 回 Goal worktree
  if [[ -f "$review_wt/$TASK_DIR/review-output/REVIEW.md" ]]; then
    cp "$review_wt/$TASK_DIR/review-output/REVIEW.md" "$review_round_dir/REVIEW.md"
  else
    log "WARN: reviewer did not produce REVIEW.md"
  fi

  # 5. 销毁 readonly worktree
  log "Removing readonly worktree: $review_wt"
  git worktree remove --force "$review_wt" 2>>"$LOG" || rm -rf "$review_wt"

  # 5.5 启动 extra reviewers（v4: 通用 reviewer 注册机制）
  launch_extra_reviewers "$round"

  # 6. snapshot 决策（v4: 用 overall_aggregate 几何平均）
  local overall_verdict overall_agg
  overall_verdict=$(arbitrate_reviews "$round" verdict)
  overall_agg=$(arbitrate_reviews "$round" aggregate)
  if [[ "$overall_verdict" == "pass" ]] && [[ "$overall_agg" != "0" ]]; then
    bash "$SNAPSHOT" "$TASK_ID" "final-r$round" "$overall_agg" >> "$LOG" 2>&1 || true
  fi

  # 6.5 写 arbitration.md 合并视图
  write_arbitration_md "$round"

  # 7. audit（含所有 reviewer）
  bash "$WRITE_AUDIT" "$TASK_ID" "$round" final-review >> "$LOG" 2>&1 || true

  # 8. notify orchestrator
  local extra_count
  extra_count=$(ls "$review_round_dir/extras/" 2>/dev/null | wc -l | tr -d ' ')
  notify_human "Final review round-$round complete" "
Overall verdict: $overall_verdict (rule: $(read_arbitration_rule))
Overall aggregate: $overall_agg (geometric mean)
Reviewers: codex-reviewer + $extra_count extra
REVIEW.md: $review_round_dir/REVIEW.md
Extras: $review_round_dir/extras/
Arbitration: $review_round_dir/arbitration.md

orchestrator agent: read all reviewer reports + arbitration.md, decide commit/retry/abort.
"

  touch "$TASK_DIR/.review-pending"
}

handle_stalled() {
  local stall_count_file="$TASK_DIR/.stall-count"
  local count
  count=$(cat "$stall_count_file" 2>/dev/null || echo 0)
  count=$((count + 1))
  echo "$count" > "$stall_count_file"

  log "Stalled (count=$count)"

  if [[ $count -ge 3 ]]; then
    notify_human "Goal stalled 3 times" "
Codex appears stuck:
- pid alive but no file changes for ${STALL_FILE_MIN:-10}+ min
- no log growth
- no STATUS.md update for ${STALL_STATUS_MIN:-15}+ min

Suggested actions:
  continue  - I checked, it's fine, keep watching
  abort     - kill task and discard worktree
  handoff   - I'll take over manually
  rescope   - update GOAL.md and restart

Reply via cc-connect or update STATUS.md with 'STOPPED: human-aborted' to acknowledge.
"
    return 0
  fi
}

reset_stall_count() {
  rm -f "$TASK_DIR/.stall-count"
}

handle_failed() {
  log "Goal process died but STATUS.md has no GOAL_DONE — collecting diagnostics"

  local diag_dir="$TASK_DIR/diagnostics"
  mkdir -p "$diag_dir"

  tail -100 "$TASK_DIR/logs/goal.log" > "$diag_dir/goal-tail.log" 2>/dev/null || true
  cd "${WORKTREE:-.}"
  git diff main > "$diag_dir/diff-at-death.patch" 2>/dev/null || true
  ps -ef | grep -i codex | grep -v grep > "$diag_dir/ps.txt" 2>/dev/null || true

  notify_human "Goal Codex died unexpectedly" "
Process died without writing GOAL_DONE.
Diagnostics: $diag_dir/

Suggested actions:
  continue  - restart Codex from STATUS.md current step
  abort     - kill and discard
  handoff   - I'll debug manually
"
}

handle_stopped() {
  local reason
  reason=$(jq -r '.stopped_reason // "unknown"' "$TASK_DIR/health.json" 2>/dev/null || echo "unknown")

  log "Goal stopped (self-reported): $reason"
  touch "$TASK_DIR/.stop-signal"
  notify_human "Goal stopped: $reason" "
Codex self-stopped. See STATUS.md for details.

Likely human action needed."
}

# === handle_done — 修复 P0 #4 ===
# 必须封成函数，因为 watcher 的 case 分支不在 function 内部，
# 直接在 case 里写 `local x=...` 会触发 "local: can only be used in a function" 错误。
#
# 返回值即 watcher 的 exit code：
#   0 → verdict=pass → 进 Phase 3 (delivery / human sign-off)
#   3 → verdict=fail 且未达 review-fail-3 上限 → orchestrator 派 retry 并重启 watcher
#   2 → verdict=fail 且已达 review-fail-3 上限 → 强停告警，需人类介入
#   4 → verdict 解析失败 → 人类手动检查 arbitration.md
handle_done() {
  local current_round
  current_round=$(ls "$TASK_DIR/reviews/" 2>/dev/null \
    | grep -E '^round-[0-9]+$' | sed 's/^round-//' | sort -n | tail -1)
  local final_verdict="unknown"
  [[ -n "$current_round" ]] && \
    final_verdict=$(arbitrate_reviews "$current_round" verdict 2>/dev/null || echo "unknown")

  case "$final_verdict" in
    pass)
      cleanup_codex
      log "Watcher exiting: round-$current_round verdict=PASS (task complete + verified)"
      return 0
      ;;
    fail)
      local fail_count_file="$TASK_DIR/.review-fail-count"
      local fails
      fails=$(cat "$fail_count_file" 2>/dev/null || echo 0)
      fails=$((fails + 1))
      echo "$fails" > "$fail_count_file"

      if (( fails >= 3 )); then
        cleanup_codex
        log "STOP: review verdict=fail $fails consecutive times (S-2 triggered)"
        notify_human "Review failed 3 rounds in a row — STOP" "
Review 连续 fail $fails 次，已达 stop-conditions.md 第 S-2 条上限。
Goal Codex 已 cleanup。

人类必须决定：
  - abort（删 worktree + cleanup）
  - handoff（接管手动改）
  - rescope（改 GOAL.md 后重启）

不会自动 retry。
"
        log "Watcher exiting: 3 consecutive review fails (exit 2 → manual intervention)"
        return 2
      fi

      log "Round-$current_round verdict=fail (fails=$fails/3) — signaling orchestrator to retry"
      touch "$TASK_DIR/.retry-needed"
      {
        echo ""
        echo "## Retry Needed (round-$current_round verdict=fail, fails=$fails/3)"
        echo ""
        echo "Reviewer must-fix items（合并自所有 reviewer，orchestrator 还需做黑名单仲裁后才能 commit）:"
        if [[ -d "$TASK_DIR/reviews/round-$current_round" ]]; then
          find "$TASK_DIR/reviews/round-$current_round" -name "*.md" 2>/dev/null | while IFS= read -r f; do
            awk '/^## Must Fix/{flag=1;next} /^## /{flag=0} flag && NF>0' "$f" 2>/dev/null | head -10
          done
        fi
      } >> "$TASK_DIR/STATUS.md"
      notify_human "Round-$current_round fail — auto-retry path" "
Review 第 $fails 次 fail（上限 3）。
Orchestrator 应该：
  1. 读 reviews/round-$current_round/arbitration.md 仲裁
  2. 把 accepted must_fix 派给 Goal Codex 修
  3. 重启 watcher，进入 round-$((current_round + 1))
"
      cleanup_codex
      log "Watcher exiting: verdict=fail (exit 3 → orchestrator retry)"
      return 3
      ;;
    *)
      cleanup_codex
      log "WARN: verdict=$final_verdict (unparseable) — orchestrator manual review needed"
      notify_human "Review verdict unparseable" "
arbitration.md 解析不出 verdict。可能原因：
  - reviewer 全部 missing（同 round-1 timeout bug）
  - arbitration.md 格式被改坏
  - 没有 round-N 目录

需要人类手动检查 $TASK_DIR/reviews/
"
      return 4
      ;;
  esac
}

# === 主循环 ===
log "Watcher started for task $TASK_ID (health=${INTERVAL}s, boundary=${BOUNDARY_INTERVAL}s, inbox=${INBOX_INTERVAL}s)"

LAST_BOUNDARY=0
LAST_INBOX=0
LAST_MARKER_POLL=0
MARKER_POLL_INTERVAL=5   # TMUX-YOLO marker 扫描 5s 一次（cheap, capture-pane only）

while true; do
  NOW=$(date +%s)

  # 1. boundary check（每 BOUNDARY_INTERVAL 秒）
  if (( NOW - LAST_BOUNDARY >= BOUNDARY_INTERVAL )); then
    LAST_BOUNDARY=$NOW
    if ! check_boundary; then
      log "Watcher exiting (boundary violation)"
      exit 1
    fi
  fi

  # 2. inbox poll（每 INBOX_INTERVAL 秒）
  if (( NOW - LAST_INBOX >= INBOX_INTERVAL )); then
    LAST_INBOX=$NOW
    poll_inbox
  fi

  # 2.5 TMUX-YOLO phase marker poll（修复 P1 #7）
  # 仅 TMUX-YOLO 模式下扫；poll_phase_markers 内部判定 run_mode 是否匹配
  if (( NOW - LAST_MARKER_POLL >= MARKER_POLL_INTERVAL )); then
    LAST_MARKER_POLL=$NOW
    poll_phase_markers
  fi

  # 3. health check
  STATE=$("$HEALTH_CHECK" "$TASK_ID" 2>>"$LOG" || echo "check-error")

  case "$STATE" in
    running)
      log "running"
      reset_stall_count
      ;;
    milestone)
      reset_stall_count
      MILESTONE_NAME=$(jq -r '.milestone_new // ""' "$TASK_DIR/health.json" 2>/dev/null || echo "")
      if [[ -n "$MILESTONE_NAME" ]]; then
        handle_milestone "$MILESTONE_NAME"
      else
        log "milestone state but no name — skipping"
      fi
      ;;
    done)
      log "DONE marker detected — running final review pipeline"
      reset_stall_count
      trigger_review
      # handle_done 内部跑 arbitration 并按 verdict 选 exit code（修复 P0 #4）
      # 必须封成函数：watcher 的 case 分支不在 function 内，直接写 local 会 runtime error
      handle_done
      exit $?
      ;;
    stalled)
      handle_stalled
      ;;
    failed)
      handle_failed
      cleanup_codex
      log "Watcher exiting (task failed)"
      exit 1
      ;;
    stopped)
      handle_stopped
      cleanup_codex
      log "Watcher exiting (task stopped)"
      exit 0
      ;;
    check-error)
      log "health-check.sh error — retrying next interval"
      ;;
    task-dir-missing)
      log "Task dir gone — exiting"
      exit 2
      ;;
    *)
      log "Unknown state: $STATE — treating as running"
      ;;
  esac

  sleep "$INTERVAL"
done
