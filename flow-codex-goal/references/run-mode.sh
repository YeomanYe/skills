#!/usr/bin/env bash
# run-mode.sh — 三种运行模式探测
#
# 用法:
#   ./run-mode.sh detect       → 输出 CLI-YOLO | CLI-EXEC | SUBAGENT
#   ./run-mode.sh capabilities → 输出探测细节 JSON
#
# 三种模式：
#   CLI-YOLO   : 有 TTY + 终端 shell + worktree 隔离 OK，能 codex --yolo 长跑
#   CLI-EXEC   : 无 TTY 但能 spawn 子进程，每个 Phase 单次 codex exec
#   SUBAGENT   : 主进程能派 subagent（如 Claude Code Agent 工具），每次一 Phase

set -u

CMD="${1:-detect}"

has_tty() {
  tty -s 2>/dev/null && return 0 || return 1
}

has_codex() {
  command -v codex > /dev/null 2>&1
}

is_in_worktree() {
  [[ -d ".git" ]] || git rev-parse --is-inside-work-tree > /dev/null 2>&1
}

# Subagent 探测：环境变量 / IPC socket 暗示
is_in_subagent_capable_env() {
  # Claude Code: Agent 工具一般会留 CLAUDE_AGENT_* 之类
  # Codex CLI: 通常不会 nest subagent
  # 这里用启发式：CC_PROJECT 存在或 ANTHROPIC_AGENT_* 存在
  [[ -n "${CC_PROJECT:-}" ]] || [[ -n "${ANTHROPIC_AGENT_RUNTIME:-}" ]] || return 1
}

detect_mode() {
  if ! has_codex; then
    echo "ERROR: codex not installed" >&2
    return 2
  fi
  if ! is_in_worktree; then
    echo "ERROR: not in a git worktree" >&2
    return 2
  fi
  if has_tty; then
    echo "CLI-YOLO"
  elif is_in_subagent_capable_env; then
    echo "SUBAGENT"
  else
    echo "CLI-EXEC"
  fi
}

print_capabilities() {
  local tty_ok="false"; has_tty && tty_ok="true"
  local codex_ok="false"; has_codex && codex_ok="true"
  local worktree_ok="false"; is_in_worktree && worktree_ok="true"
  local subagent_hint="false"; is_in_subagent_capable_env && subagent_hint="true"
  local codex_version=""; has_codex && codex_version=$(codex --version 2>/dev/null | head -1)

  cat <<EOF
{
  "tty": $tty_ok,
  "codex_installed": $codex_ok,
  "codex_version": "$codex_version",
  "in_worktree": $worktree_ok,
  "subagent_env_hint": $subagent_hint,
  "shell": "$SHELL",
  "uname": "$(uname -s)"
}
EOF
}

case "$CMD" in
  detect)       detect_mode ;;
  capabilities) print_capabilities ;;
  *)            echo "Usage: $0 detect|capabilities" >&2; exit 1 ;;
esac
