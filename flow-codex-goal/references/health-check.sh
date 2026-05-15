#!/usr/bin/env bash
# health-check.sh — 单次健康检查
#
# 用法: ./health-check.sh <task-id>
# 输出: 状态字符串 (running | done | stalled | failed)
# 副作用: 更新 .agent/tasks/<task-id>/health.json
#
# 设计原则: 6 维度综合判定
#   1. 进程存活
#   2. worktree 文件 mtime
#   3. 日志增长
#   4. STATUS.md mtime
#   5. GOAL_DONE / STOPPED 信号
#   6. 修改文件计数（用于 budget 检查）

# 注意：用 `set -u` 而非 `set -euo pipefail`
# 历史 bug：管道（如 find | xargs | sort | head）在 head 提前关闭时会 SIGPIPE，
# 配合 `pipefail` 会让脚本异常退出，导致 watcher 死循环报 "check-error"。
# 改成 `set -u`（只对未定义变量报错）就稳了。
set -u

TASK_ID="${1:?task-id required}"
TASK_DIR=".agent/tasks/$TASK_ID"
WORKTREE="${WORKTREE:-$(pwd)}"

# 配置（可被环境变量覆盖）
STALL_FILE_MIN="${STALL_FILE_MIN:-10}"        # 文件无改动判 stall 的分钟数
STALL_STATUS_MIN="${STALL_STATUS_MIN:-15}"    # STATUS.md 无更新判 stall 的分钟数
STALL_LOG_GROWTH_BYTES="${STALL_LOG_GROWTH_BYTES:-100}" # 日志增长 < N bytes 视为停滞

[[ -d "$TASK_DIR" ]] || { echo "task-dir-missing"; exit 2; }

STATE_FILE="$TASK_DIR/health.json"
PID_FILE="$TASK_DIR/codex.pid"
STATUS_FILE="$TASK_DIR/STATUS.md"
GOAL_LOG="$TASK_DIR/logs/goal.log"
MARKER="$TASK_DIR/.last-check"

NOW=$(date +%s)

# === 1. 进程存活 ===
PROCESS_STATE="unknown"
CODEX_PID=""
if [[ -f "$PID_FILE" ]]; then
  CODEX_PID=$(cat "$PID_FILE")
  if ps -p "$CODEX_PID" > /dev/null 2>&1; then
    PROCESS_STATE="alive"
  else
    PROCESS_STATE="dead"
  fi
fi

# === 2. worktree 文件 mtime（最新文件距今分钟数）===
LATEST_FILE_AGE=999999
if [[ -d "$WORKTREE" ]]; then
  LATEST_TS=$(find "$WORKTREE" \
    -path "$WORKTREE/node_modules" -prune -o \
    -path "$WORKTREE/.git" -prune -o \
    -path "$WORKTREE/dist" -prune -o \
    -path "$WORKTREE/.next" -prune -o \
    -path "$WORKTREE/$TASK_DIR" -prune -o \
    -type f -print 2>/dev/null \
    | xargs stat -f %m 2>/dev/null \
    | sort -nr | head -1)
  [[ -n "$LATEST_TS" ]] && LATEST_FILE_AGE=$(( (NOW - LATEST_TS) / 60 ))
fi

# === 3. 日志增长 ===
PREV_LOG_SIZE=0
[[ -f "$STATE_FILE" ]] && PREV_LOG_SIZE=$(jq -r '.log_size // 0' "$STATE_FILE" 2>/dev/null || echo 0)
CUR_LOG_SIZE=0
[[ -f "$GOAL_LOG" ]] && CUR_LOG_SIZE=$(stat -f %z "$GOAL_LOG" 2>/dev/null || echo 0)
LOG_GROWTH=$((CUR_LOG_SIZE - PREV_LOG_SIZE))

# === 4. STATUS.md mtime ===
STATUS_AGE=999999
if [[ -f "$STATUS_FILE" ]]; then
  STATUS_TS=$(stat -f %m "$STATUS_FILE" 2>/dev/null || echo 0)
  STATUS_AGE=$(( (NOW - STATUS_TS) / 60 ))
fi

# === 5. 完成 / 停止信号 / milestone ===
DONE=0
STOPPED_REASON=""
MILESTONE_NEW=""
LAST_MILESTONE_FILE="$TASK_DIR/.last-milestone"
LAST_MILESTONE=""
[[ -f "$LAST_MILESTONE_FILE" ]] && LAST_MILESTONE=$(cat "$LAST_MILESTONE_FILE")

if [[ -f "$STATUS_FILE" ]]; then
  grep -q "^GOAL_DONE" "$STATUS_FILE" && DONE=1
  STOPPED_REASON=$(grep -E "^STOPPED:" "$STATUS_FILE" | tail -1 | sed 's/^STOPPED: //' || true)
  CURRENT_MILESTONE=$(grep -E "^MILESTONE:" "$STATUS_FILE" | tail -1 | sed 's/^MILESTONE: //' || true)
  if [[ -n "$CURRENT_MILESTONE" ]] && [[ "$CURRENT_MILESTONE" != "$LAST_MILESTONE" ]]; then
    MILESTONE_NEW="$CURRENT_MILESTONE"
    echo "$CURRENT_MILESTONE" > "$LAST_MILESTONE_FILE"
  fi
fi

# === 6. 修改文件计数 ===
FILES_CHANGED=0
if [[ -d "$WORKTREE/.git" ]]; then
  FILES_CHANGED=$(cd "$WORKTREE" && git diff --name-only main 2>/dev/null | wc -l | tr -d ' ' || echo 0)
fi

# === 综合判定 ===
# 优先级：done > stopped > failed > milestone(新) > stalled > running
STATE="running"
if [[ $DONE -eq 1 ]]; then
  STATE="done"
elif [[ -n "$STOPPED_REASON" ]]; then
  STATE="stopped"
elif [[ "$PROCESS_STATE" == "dead" ]]; then
  STATE="failed"
elif [[ -n "$MILESTONE_NEW" ]]; then
  STATE="milestone"
elif [[ "$PROCESS_STATE" == "alive" ]] \
  && [[ $LATEST_FILE_AGE -gt $STALL_FILE_MIN ]] \
  && [[ $LOG_GROWTH -lt $STALL_LOG_GROWTH_BYTES ]] \
  && [[ $STATUS_AGE -gt $STALL_STATUS_MIN ]]; then
  STATE="stalled"
fi

# === 写状态 ===
jq -n \
  --arg state "$STATE" \
  --arg pid "$CODEX_PID" \
  --arg process_state "$PROCESS_STATE" \
  --arg stopped_reason "$STOPPED_REASON" \
  --arg milestone_new "$MILESTONE_NEW" \
  --argjson log_size "$CUR_LOG_SIZE" \
  --argjson log_growth "$LOG_GROWTH" \
  --argjson latest_file_age_min "$LATEST_FILE_AGE" \
  --argjson status_age_min "$STATUS_AGE" \
  --argjson files_changed "$FILES_CHANGED" \
  --argjson ts "$NOW" \
  '{
    state: $state,
    ts: $ts,
    pid: $pid,
    process_state: $process_state,
    stopped_reason: $stopped_reason,
    milestone_new: $milestone_new,
    log_size: $log_size,
    log_growth: $log_growth,
    latest_file_age_min: $latest_file_age_min,
    status_age_min: $status_age_min,
    files_changed: $files_changed
  }' > "$STATE_FILE"

touch "$MARKER"
echo "$STATE"
