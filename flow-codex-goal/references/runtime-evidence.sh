#!/usr/bin/env bash
# runtime-evidence.sh — 启动项目 + 跑用户旅程 + 截图
#
# 用法: ./runtime-evidence.sh <task-id> <stage>
#   stage = baseline | milestone-N | final
#
# 输出:
#   .agent/tasks/<task-id>/<stage>/screenshots/journey-N.png
#   .agent/tasks/<task-id>/<stage>/runtime.log
#   .agent/tasks/<task-id>/<stage>/test.txt / build.txt / lint.txt（仅 baseline / milestone）
#
# 依赖:
#   - jq（解析 GOAL.md 的 user journeys）
#   - chromium / playwright / chrome MCP（任一可用即可）
#   - 项目本身能跑（pnpm dev / npm start / cargo run 等）

set -euo pipefail

TASK_ID="${1:?task-id required}"
STAGE="${2:?stage required (baseline|milestone-N|final)}"
TASK_DIR=".agent/tasks/$TASK_ID"
STAGE_DIR="$TASK_DIR/$STAGE"
SCREENSHOTS="$STAGE_DIR/screenshots"
LOG="$STAGE_DIR/runtime.log"

mkdir -p "$SCREENSHOTS"
: > "$LOG"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"
}

log "Starting runtime evidence collection for stage=$STAGE"

# === 1. 跑 EVAL 命令（baseline / milestone 用，final 不重复跑）===
if [[ "$STAGE" != final* ]]; then
  log "Running EVAL commands"
  if [[ -f package.json ]]; then
    PM="npm"
    [[ -f pnpm-lock.yaml ]] && PM="pnpm"
    [[ -f yarn.lock ]] && PM="yarn"
    $PM test  > "$STAGE_DIR/test.txt"  2>&1 || log "test failed (recorded)"
    $PM run lint > "$STAGE_DIR/lint.txt" 2>&1 || log "lint failed (recorded)"
    $PM run build > "$STAGE_DIR/build.txt" 2>&1 || log "build failed (recorded)"
  elif [[ -f Cargo.toml ]]; then
    cargo test    > "$STAGE_DIR/test.txt"  2>&1 || log "cargo test failed"
    cargo clippy  > "$STAGE_DIR/lint.txt"  2>&1 || log "cargo clippy failed"
    cargo build   > "$STAGE_DIR/build.txt" 2>&1 || log "cargo build failed"
  elif [[ -f go.mod ]]; then
    go test ./... > "$STAGE_DIR/test.txt"  2>&1 || log "go test failed"
    go vet ./...  > "$STAGE_DIR/lint.txt"  2>&1 || log "go vet failed"
    go build ./... > "$STAGE_DIR/build.txt" 2>&1 || log "go build failed"
  fi
fi

# === 2. 启动项目（开发服务器或 binary）===
APP_PID=""
APP_URL=""
APP_TYPE="unknown"

if [[ -f package.json ]]; then
  if grep -q '"dev":' package.json; then
    APP_TYPE="web-dev"
    log "Starting dev server (background)"
    PM="npm"
    [[ -f pnpm-lock.yaml ]] && PM="pnpm"
    [[ -f yarn.lock ]] && PM="yarn"
    nohup $PM run dev > "$STAGE_DIR/dev-server.log" 2>&1 &
    APP_PID=$!
    sleep 8
    # 探测端口（next.js 默认 3000，vite 默认 5173）
    for port in 3000 5173 4321 8080 8000; do
      if curl -sf "http://localhost:$port" > /dev/null 2>&1; then
        APP_URL="http://localhost:$port"
        break
      fi
    done
    log "Dev server PID=$APP_PID URL=$APP_URL"
  fi
elif [[ -f Cargo.toml ]]; then
  if grep -q '\[\[bin\]\]\|\[bin\]\|^name =' Cargo.toml; then
    APP_TYPE="cli"
    log "Cargo binary detected — interactive runtime check requires reviewer"
  fi
elif [[ -f go.mod ]]; then
  APP_TYPE="cli-or-server"
  log "Go project detected — reviewer should determine entrypoint"
fi

# === 3. 跑 user journeys ===
# GOAL.md 中 User Journeys 段是 markdown checklist，每行格式: "- [ ] J<n>: <desc>"
USER_JOURNEYS_FILE="$TASK_DIR/GOAL.md"

if [[ -f "$USER_JOURNEYS_FILE" ]]; then
  log "Extracting user journeys from GOAL.md"
  awk '/^## User Journeys/,/^## /' "$USER_JOURNEYS_FILE" | grep -E "^- \[" > "$STAGE_DIR/journeys.txt" || true
  N=$(wc -l < "$STAGE_DIR/journeys.txt" | tr -d ' ')
  log "Found $N user journeys"

  if [[ -n "$APP_URL" ]] && [[ $N -gt 0 ]]; then
    # 这里给个 stub：实际截图由 reviewer codex / chrome MCP 完成
    # 本脚本只负责"准备好环境 + 列出待跑 journeys"
    log "App ready at $APP_URL — reviewer should now run each journey via chrome MCP / playwright"
    log "Save screenshots to: $SCREENSHOTS/journey-N.png"
  else
    log "No web URL detected — reviewer should run journeys via CLI / unit-test smoke"
  fi
fi

# === 4. 收集运行时 log ===
if [[ -f "$STAGE_DIR/dev-server.log" ]]; then
  tail -200 "$STAGE_DIR/dev-server.log" >> "$LOG"
fi

# === 5. 关闭服务（baseline / milestone 用完就关；final 让 reviewer 自己关）===
if [[ "$STAGE" != final* ]] && [[ -n "$APP_PID" ]]; then
  log "Stopping dev server PID=$APP_PID"
  kill "$APP_PID" 2>/dev/null || true
  sleep 2
  ps -p "$APP_PID" > /dev/null 2>&1 && kill -9 "$APP_PID" 2>/dev/null || true
fi

log "Runtime evidence collection done for stage=$STAGE"
echo "$STAGE_DIR"
