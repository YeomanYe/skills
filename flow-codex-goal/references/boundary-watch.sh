#!/usr/bin/env bash
# boundary-watch.sh — codex 不沙箱时的边界守卫
#
# 因为本 skill 要求 codex --dangerously-bypass-approvals-and-sandbox（host 真实环境），
# 必须靠这个守卫脚本 + worktree 隔离防止 codex 越界。
#
# 用法: 由 watcher.sh 内部周期调用（每 30 秒）
#   ./boundary-watch.sh <task-id>
# 输出: 状态字符串
#   ok                  → 一切正常
#   stop-boundary       → 检测到越界（codex 改了 worktree 外文件 / 主分支被切 / git remote 被改）
#
# 副作用:
#   触发 stop-boundary 时写 SIGNAL 文件到 .agent/tasks/<id>/.boundary-violation

set -u

TASK_ID="${1:?task-id required}"
TASK_DIR=".agent/tasks/$TASK_ID"
WORKTREE="${WORKTREE:-$(pwd)}"

violation_log="$TASK_DIR/logs/boundary-violations.log"
mkdir -p "$(dirname "$violation_log")"

log_violation() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$violation_log"
}

# === 1. 当前在不在 WORKTREE 内？===
PWD_ABS=$(pwd -P 2>/dev/null || pwd)
WORKTREE_ABS=$(cd "$WORKTREE" 2>/dev/null && pwd -P)
if [[ "$PWD_ABS" != "$WORKTREE_ABS"* ]]; then
  log_violation "pwd outside worktree: pwd=$PWD_ABS worktree=$WORKTREE_ABS"
  touch "$TASK_DIR/.boundary-violation"
  echo "stop-boundary"
  exit 0
fi

# === 2. 当前 branch 还是不是 goal/<id>？===
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
EXPECTED_PREFIX="goal/"
if [[ "$CURRENT_BRANCH" != ${EXPECTED_PREFIX}* ]]; then
  log_violation "branch changed: current=$CURRENT_BRANCH expected prefix=$EXPECTED_PREFIX"
  touch "$TASK_DIR/.boundary-violation"
  echo "stop-boundary"
  exit 0
fi

# === 3. git remote 有没有被改？===
REMOTE_FILE="$TASK_DIR/.original-remote"
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -f "$REMOTE_FILE" ]]; then
  ORIGINAL=$(cat "$REMOTE_FILE")
  if [[ "$CURRENT_REMOTE" != "$ORIGINAL" ]]; then
    log_violation "remote changed: $ORIGINAL → $CURRENT_REMOTE"
    touch "$TASK_DIR/.boundary-violation"
    echo "stop-boundary"
    exit 0
  fi
else
  # 第一次跑，记录基准
  echo "$CURRENT_REMOTE" > "$REMOTE_FILE"
fi

# === 4. 有没有改主 worktree 的文件？===
# 通过检查 worktree list 中其他 worktree 的文件 mtime
# 这是启发式检测——精确的话需要 fanotify，但 macOS 没有
# 这里只检查关键文件
MAIN_WORKTREE=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree/{print $2; exit}')
if [[ -n "$MAIN_WORKTREE" ]] && [[ "$MAIN_WORKTREE" != "$WORKTREE_ABS" ]]; then
  # 检查主 worktree 的 .git/index 和关键源文件最近 5 分钟内是否被改
  STALE_LIMIT="${BOUNDARY_STALE_SEC:-300}"  # 默认 5 分钟，可通过环境变量覆盖
  NOW=$(date +%s)
  for f in \
    "$MAIN_WORKTREE/.git/index" \
    "$MAIN_WORKTREE/package.json" \
    "$MAIN_WORKTREE/pnpm-workspace.yaml" \
    "$MAIN_WORKTREE/Cargo.toml" \
    "$MAIN_WORKTREE/go.mod" \
    "$MAIN_WORKTREE/pyproject.toml" \
    "$MAIN_WORKTREE/Pipfile" \
    "$MAIN_WORKTREE/Gemfile" \
    "$MAIN_WORKTREE/composer.json"; do
    [[ -f "$f" ]] || continue
    MTIME=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
    AGE=$((NOW - MTIME))
    if [[ $AGE -lt $STALE_LIMIT ]]; then
      log_violation "main worktree file changed within ${STALE_LIMIT}s: $f (age=${AGE}s)"
      touch "$TASK_DIR/.boundary-violation"
      echo "stop-boundary"
      exit 0
    fi
  done
fi

# === 5. 有没有破坏性 git 命令痕迹？===
# 检查 reflog 最近 N 条有没有 force-update / hard reset
RECENT_REFLOG=$(git reflog -10 2>/dev/null | grep -iE "reset.*hard|force|push --force" || true)
if [[ -n "$RECENT_REFLOG" ]]; then
  log_violation "destructive git op in reflog: $RECENT_REFLOG"
  touch "$TASK_DIR/.boundary-violation"
  echo "stop-boundary"
  exit 0
fi

echo "ok"
