#!/usr/bin/env bash
# watcher.sh — Goal Codex 看门狗
#
# 用法: ./watcher.sh <task-id> [check-interval-sec]
# 后台运行: nohup ./watcher.sh <task-id> > .agent/tasks/<task-id>/logs/watcher.log 2>&1 &
#
# 职责:
#   - 周期性调用 health-check.sh
#   - 根据状态触发对应动作（review / nudge / notify）
#   - 写状态变化到 logs/watcher.log
#   - 命中 stop condition 时清理 + 通知

set -euo pipefail

TASK_ID="${1:?task-id required}"
INTERVAL="${2:-300}"   # 默认 5 分钟
TASK_DIR=".agent/tasks/$TASK_ID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_CHECK="$SCRIPT_DIR/health-check.sh"

[[ -x "$HEALTH_CHECK" ]] || chmod +x "$HEALTH_CHECK"
[[ -d "$TASK_DIR" ]] || { echo "task-dir-missing: $TASK_DIR" >&2; exit 2; }

LOG="$TASK_DIR/logs/watcher.log"
mkdir -p "$(dirname "$LOG")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"
}

notify_human() {
  local subject="$1"
  local body="$2"

  log "NOTIFY: $subject"

  # 如果是 cc-connect IM 会话，通过 cc-connect 发送
  if [[ -n "${CC_SESSION_KEY:-}" ]] && command -v cc-connect > /dev/null 2>&1; then
    cc-connect send --message "[$TASK_ID] $subject

$body" 2>>"$LOG" || log "cc-connect send failed (non-fatal)"
  fi

  # 写到本地汇总文件方便人类看
  cat >> "$TASK_DIR/notifications.log" <<EOF
=== $(date '+%Y-%m-%d %H:%M:%S') ===
$subject

$body

EOF
}

cleanup_codex() {
  if [[ -f "$TASK_DIR/codex.pid" ]]; then
    local pid=$(cat "$TASK_DIR/codex.pid")
    if ps -p "$pid" > /dev/null 2>&1; then
      log "Stopping Codex pid=$pid"
      kill "$pid" 2>/dev/null || true
      sleep 2
      ps -p "$pid" > /dev/null 2>&1 && kill -9 "$pid" 2>/dev/null || true
    fi
  fi
}

trigger_review() {
  log "Goal complete — triggering FINAL review pipeline"

  # 1. 生成 review-input
  local review_dir="$TASK_DIR/review-input"
  mkdir -p "$review_dir/screenshots"

  cd "${WORKTREE:-.}"
  git diff main > "$review_dir/diff.patch" 2>>"$LOG" || true
  git diff --stat main > "$review_dir/diff-stat.txt" 2>>"$LOG" || true
  git status --short > "$review_dir/status.txt" 2>>"$LOG" || true

  # 2. 跑 EVAL.md 中的命令（自动检测包管理器）
  if [[ -f package.json ]]; then
    local pm="npm"
    [[ -f pnpm-lock.yaml ]] && pm="pnpm"
    [[ -f yarn.lock ]] && pm="yarn"
    $pm run lint > "$review_dir/lint.txt" 2>&1 || true
    $pm test > "$review_dir/test.txt" 2>&1 || true
    $pm run build > "$review_dir/build.txt" 2>&1 || true
  elif [[ -f Cargo.toml ]]; then
    cargo clippy > "$review_dir/lint.txt" 2>&1 || true
    cargo test > "$review_dir/test.txt" 2>&1 || true
    cargo build > "$review_dir/build.txt" 2>&1 || true
  fi

  # 3. 准备 runtime evidence（reviewer 还会自己再跑一遍，但先把环境备好）
  bash "$SCRIPT_DIR/runtime-evidence.sh" "$TASK_ID" final >> "$LOG" 2>&1 || true

  log "review-input prepared at $review_dir"
  notify_human "Goal done, review-input ready" "
Run reviewer Codex now (separate process):
  cd $WORKTREE && codex exec --skip-git-repo-check < $SCRIPT_DIR/review-prompt.md

Reviewer MUST actually run the project + verify user journeys (not just diff review).
"

  # 标记给 orchestrator agent 看
  touch "$TASK_DIR/.review-pending"
}

handle_milestone() {
  local milestone="$1"
  log "MILESTONE detected: $milestone — triggering mini-review + IM push"

  local scores_dir="$TASK_DIR/scores/$milestone"
  mkdir -p "$scores_dir/screenshots"

  # 1. 收集 milestone 当前的 EVAL + 截图证据
  #    传 "scores/$milestone" 作为 stage，这样 runtime-evidence.sh 写入路径
  #    .agent/tasks/<id>/scores/<milestone>/ 与本函数后续读取一致
  bash "$SCRIPT_DIR/runtime-evidence.sh" "$TASK_ID" "scores/$milestone" >> "$LOG" 2>&1 || true

  # 2. 启动 mini-review codex（独立新进程；不阻塞 watcher 太久）
  local milestone_review_log="$scores_dir/review.log"
  log "Launching mini-review codex (timeout 10min)"
  timeout 600 codex exec --skip-git-repo-check < "$SCRIPT_DIR/milestone-review-prompt.md" \
    > "$milestone_review_log" 2>&1 || log "mini-review codex timed out or errored (recorded)"

  # 3. score-diff vs baseline
  local score_json="$scores_dir.json"
  if [[ ! -f "$score_json" ]]; then
    # mini-review 应该写到 scores/<milestone>.json，没写就跳退化检测
    log "WARN: mini-review did not produce $score_json; skipping diff"
  else
    local mode
    mode=$(grep -A1 "^mode:" "$TASK_DIR/GOAL.md" 2>/dev/null | head -1 | awk '{print $2}' || echo "regression-prevention")
    local diff_out
    diff_out=$(python3 "$SCRIPT_DIR/score-diff.py" \
      --baseline "$TASK_DIR/BASELINE.md" \
      --current  "$score_json" \
      --mode     "$mode" \
      --no-improvement-history "$TASK_DIR/scores/aggregate-trend.json" 2>&1) || {
        log "Score regression detected: $diff_out"
        # 写 STOPPED 让 Goal 下次循环看到自停
        echo "STOPPED: score-regression ($milestone)" >> "$TASK_DIR/STATUS.md"
        notify_human "Score regression at $milestone" "$diff_out"
        return 0
      }
    log "Score diff OK: $diff_out"
  fi

  # 4. 把分数 + 截图推给人类（IM 会话才推）
  if [[ -n "${CC_SESSION_KEY:-}" ]] && command -v cc-connect > /dev/null 2>&1; then
    local agg
    agg=$(jq -r .aggregate "$score_json" 2>/dev/null || echo "?")
    local delta
    delta=$(jq -r '.delta_vs_baseline.aggregate // "?"' "$score_json" 2>/dev/null || echo "?")
    local notes
    notes=$(jq -r .notes "$score_json" 2>/dev/null || echo "")

    local msg="[$TASK_ID] MILESTONE: $milestone
Aggregate: $agg (Δ vs baseline: $delta)
$notes

Reply: continue / pause / abort / adjust: <text>"

    # 取所有该 milestone 的截图
    local screenshots=()
    while IFS= read -r f; do screenshots+=(--image "$f"); done < <(find "$scores_dir/screenshots" -name "*.png" 2>/dev/null | head -5)

    cc-connect send --message "$msg" "${screenshots[@]}" 2>>"$LOG" \
      || log "cc-connect send failed (non-fatal)"
  fi
}

handle_stalled() {
  local stall_count_file="$TASK_DIR/.stall-count"
  local count=$(cat "$stall_count_file" 2>/dev/null || echo 0)
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
  notify_human "Goal stopped: $reason" "
Codex self-stopped. See STATUS.md for details.

Likely human action needed."
}

# === 主循环 ===
log "Watcher started for task $TASK_ID (interval=${INTERVAL}s)"

while true; do
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
      log "DONE"
      reset_stall_count
      trigger_review
      cleanup_codex
      log "Watcher exiting (task complete)"
      exit 0
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
